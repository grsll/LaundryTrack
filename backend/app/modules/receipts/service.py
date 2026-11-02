import base64
from datetime import datetime, timezone
from decimal import Decimal
import html
import io
from typing import Optional
import uuid
from reportlab.lib.colors import HexColor
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    HRFlowable,
    Image as RLImage,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
import qrcode
from app.core.exceptions import AppException
from app.modules.orders.models import Order, OrderStatus, PaymentStatus
from app.modules.payments.models import Payment
from app.modules.receipts.models import ReceiptLog, ReceiptPrintType
from app.modules.receipts.schemas import (
    ReceiptItemResponse,
    ReceiptPaymentResponse,
    ReceiptReprintResponse,
    ReceiptResponse,
)

STATUS_LABELS = {
    OrderStatus.RECEIVED.value: "Diterima Kasir",
    OrderStatus.WASHING.value: "Sedang Dicuci",
    OrderStatus.DRYING.value: "Sedang Dikeringkan",
    OrderStatus.IRONING.value: "Sedang Disetrika",
    OrderStatus.PACKAGING.value: "Sedang Dikemas",
    OrderStatus.READY.value: "Siap Diambil",
    OrderStatus.COMPLETED.value: "Selesai / Sudah Diambil",
    OrderStatus.CANCELLED.value: "Dibatalkan",
}

PAYMENT_STATUS_LABELS = {
    PaymentStatus.UNPAID.value: "Belum Lunas",
    PaymentStatus.PARTIAL.value: "Sebagian (DP)",
    PaymentStatus.PAID.value: "Lunas",
    PaymentStatus.REFUNDED.value: "Dikembalikan (Refund)",
}


def format_currency(val: Decimal) -> str:
    return f"Rp {val:,.0f}".replace(",", ".")


class ReceiptService:
    @staticmethod
    async def get_receipt_data(
        db: AsyncSession,
        tenant_id: uuid.UUID,
        user_role: str,
        user_outlet_id: Optional[uuid.UUID],
        cashier_fallback_name: str,
        order_id: uuid.UUID,
        base_url: Optional[str] = None,
    ) -> ReceiptResponse:
        stmt = (
            select(Order)
            .options(
                selectinload(Order.customer),
                selectinload(Order.outlet),
                selectinload(Order.tenant),
                selectinload(Order.creator),
                selectinload(Order.items),
                selectinload(Order.payments).selectinload(Payment.received_by),
            )
            .where(
                Order.id == order_id,
                Order.tenant_id == tenant_id,
            )
        )
        if user_role not in ["owner", "admin"]:
            if not user_outlet_id:
                raise AppException(
                    status_code=403,
                    message="Akses ditolak: Staf operasional wajib terikat pada outlet aktif.",
                    code="OUTLET_CONTEXT_REQUIRED",
                )
            stmt = stmt.where(Order.outlet_id == user_outlet_id)

        result = await db.execute(stmt)
        order = result.scalar_one_or_none()

        if not order:
            raise AppException(
                status_code=404,
                message="Pesanan tidak ditemukan atau berada di luar akses outlet Anda.",
                code="ORDER_NOT_FOUND",
            )

        web_base = base_url.rstrip("/") if base_url else "http://localhost:3000"
        tracking_url = f"{web_base}/#/track/{order.tracking_token}"

        cashier_name = (
            order.creator.full_name if order.creator else cashier_fallback_name
        )

        items_resp = [
            ReceiptItemResponse(
                service_name=item.service_name_snapshot,
                price_type=item.price_type_snapshot,
                unit=item.unit_snapshot,
                quantity=item.quantity,
                unit_price=item.unit_price_snapshot,
                subtotal=item.subtotal,
                notes=item.notes,
            )
            for item in order.items
        ]

        payments_resp = [
            ReceiptPaymentResponse(
                id=p.id,
                amount=p.amount,
                payment_method=p.payment_method,
                paid_at=p.paid_at,
                received_by_name=p.received_by.full_name if p.received_by else None,
                reference_number=p.reference_number,
            )
            for p in order.payments
        ]

        return ReceiptResponse(
            order_id=order.id,
            order_number=order.order_number,
            status=order.status,
            status_label=STATUS_LABELS.get(order.status, order.status),
            payment_status=order.payment_status,
            payment_status_label=PAYMENT_STATUS_LABELS.get(
                order.payment_status, order.payment_status
            ),
            received_at=order.received_at,
            estimated_completion_at=order.estimated_completion_at,
            completed_at=None,
            customer_name=order.customer.name if order.customer else "Pelanggan Umum",
            customer_phone=order.customer.phone if order.customer else None,
            customer_address=order.customer.address if order.customer else None,
            outlet_name=order.outlet.name if order.outlet else "Outlet Laundry",
            outlet_phone=order.outlet.phone if order.outlet else None,
            outlet_address=order.outlet.address if order.outlet else None,
            tenant_name=order.tenant.name if order.tenant else "LaundryTrack",
            cashier_name=cashier_name,
            items=items_resp,
            subtotal=order.subtotal,
            discount_amount=order.discount_amount,
            total_amount=order.total_amount,
            paid_amount=order.paid_amount,
            remaining_amount=order.remaining_amount,
            payments=payments_resp,
            tracking_token=order.tracking_token,
            tracking_url=tracking_url,
            receipt_printed_at=order.receipt_printed_at,
            reprint_count=order.reprint_count,
        )

    @staticmethod
    async def generate_receipt_pdf(
        db: AsyncSession,
        tenant_id: uuid.UUID,
        user_role: str,
        user_outlet_id: Optional[uuid.UUID],
        cashier_fallback_name: str,
        order_id: uuid.UUID,
        base_url: Optional[str] = None,
    ) -> bytes:
        receipt = await ReceiptService.get_receipt_data(
            db,
            tenant_id,
            user_role,
            user_outlet_id,
            cashier_fallback_name,
            order_id,
            base_url,
        )

        # Update initial printed_at timestamp if first time
        stmt = select(Order).where(Order.id == order_id, Order.tenant_id == tenant_id)
        result = await db.execute(stmt)
        order_model = result.scalar_one_or_none()
        if order_model and order_model.receipt_printed_at is None:
            order_model.receipt_printed_at = datetime.now(timezone.utc)
            await db.commit()

        # Dynamic height calculation based on item count
        item_count = len(receipt.items)
        payment_count = len(receipt.payments)
        doc_height_mm = max(180, 120 + (item_count * 12) + (payment_count * 8) + 40)

        buf = io.BytesIO()
        doc = SimpleDocTemplate(
            buf,
            pagesize=(80 * mm, doc_height_mm * mm),
            leftMargin=3 * mm,
            rightMargin=3 * mm,
            topMargin=5 * mm,
            bottomMargin=5 * mm,
        )

        styles = getSampleStyleSheet()
        title_style = ParagraphStyle(
            "ReceiptTitle",
            parent=styles["Normal"],
            fontName="Helvetica-Bold",
            fontSize=13,
            leading=15,
            alignment=1,  # Center
        )
        subtitle_style = ParagraphStyle(
            "ReceiptSubtitle",
            parent=styles["Normal"],
            fontName="Helvetica",
            fontSize=8,
            leading=10,
            alignment=1,
        )
        meta_left_style = ParagraphStyle(
            "MetaLeft",
            parent=styles["Normal"],
            fontName="Helvetica",
            fontSize=7.5,
            leading=9,
        )
        meta_right_style = ParagraphStyle(
            "MetaRight",
            parent=styles["Normal"],
            fontName="Helvetica-Bold",
            fontSize=7.5,
            leading=9,
            alignment=2,  # Right
        )
        bold_style = ParagraphStyle(
            "ReceiptBold",
            parent=styles["Normal"],
            fontName="Helvetica-Bold",
            fontSize=8,
            leading=10,
        )
        small_bold_right = ParagraphStyle(
            "SmallBoldRight",
            parent=styles["Normal"],
            fontName="Helvetica-Bold",
            fontSize=8,
            leading=10,
            alignment=2,
        )
        small_style = ParagraphStyle(
            "SmallText",
            parent=styles["Normal"],
            fontName="Helvetica",
            fontSize=7,
            leading=8.5,
            alignment=1,
        )

        elements = []

        # Header
        esc_outlet_name = html.escape(receipt.outlet_name.upper())
        elements.append(Paragraph(esc_outlet_name, title_style))
        if receipt.outlet_address:
            elements.append(Paragraph(html.escape(receipt.outlet_address), subtitle_style))
        if receipt.outlet_phone:
            elements.append(Paragraph(f"Telp: {html.escape(receipt.outlet_phone)}", subtitle_style))

        elements.append(Spacer(1, 2 * mm))
        elements.append(
            HRFlowable(
                width="100%",
                thickness=0.8,
                color=HexColor("#333333"),
                spaceBefore=1,
                spaceAfter=2,
            )
        )

        # Order Meta Details
        received_str = receipt.received_at.strftime("%d/%m/%Y %H:%M")
        meta_data = [
            [
                Paragraph("No. Order:", meta_left_style),
                Paragraph(html.escape(receipt.order_number), meta_right_style),
            ],
            [
                Paragraph("Tanggal Masuk:", meta_left_style),
                Paragraph(received_str, meta_right_style),
            ],
            [
                Paragraph("Pelanggan:", meta_left_style),
                Paragraph(html.escape(receipt.customer_name), meta_right_style),
            ],
            [
                Paragraph("No. Telepon:", meta_left_style),
                Paragraph(html.escape(receipt.customer_phone or "-"), meta_right_style),
            ],
            [
                Paragraph("Kasir:", meta_left_style),
                Paragraph(html.escape(receipt.cashier_name or "-"), meta_right_style),
            ],
        ]
        if receipt.estimated_completion_at:
            estim_str = receipt.estimated_completion_at.strftime("%d/%m/%Y %H:%M")
            meta_data.append(
                [
                    Paragraph("Estimasi Selesai:", meta_left_style),
                    Paragraph(estim_str, meta_right_style),
                ]
            )

        meta_table = Table(meta_data, colWidths=[28 * mm, 46 * mm])
        meta_table.setStyle(
            TableStyle(
                [
                    ("VALIGN", (0, 0), (-1, -1), "TOP"),
                    ("LEFTPADDING", (0, 0), (-1, -1), 0),
                    ("RIGHTPADDING", (0, 0), (-1, -1), 0),
                    ("TOPPADDING", (0, 0), (-1, -1), 1),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 1),
                ]
            )
        )
        elements.append(meta_table)

        elements.append(
            HRFlowable(
                width="100%",
                thickness=0.8,
                color=HexColor("#333333"),
                spaceBefore=2,
                spaceAfter=2,
            )
        )

        # Items Table
        items_header = [
            Paragraph("Layanan", bold_style),
            Paragraph("Qty", bold_style),
            Paragraph("Subtotal", small_bold_right),
        ]
        items_rows = [items_header]
        for it in receipt.items:
            qty_fmt = (
                f"{it.quantity:,.1f}"
                if it.quantity % 1 != 0
                else f"{it.quantity:,.0f}"
            )
            esc_service = html.escape(it.service_name)
            esc_unit = html.escape(it.unit)
            item_desc = f"{esc_service} ({qty_fmt} {esc_unit} @ {format_currency(it.unit_price)})"
            items_rows.append(
                [
                    Paragraph(item_desc, meta_left_style),
                    Paragraph(f"{qty_fmt} {esc_unit}", meta_left_style),
                    Paragraph(format_currency(it.subtotal), small_bold_right),
                ]
            )

        items_table = Table(items_rows, colWidths=[42 * mm, 14 * mm, 18 * mm])
        items_table.setStyle(
            TableStyle(
                [
                    ("VALIGN", (0, 0), (-1, -1), "TOP"),
                    ("LEFTPADDING", (0, 0), (-1, -1), 0),
                    ("RIGHTPADDING", (0, 0), (-1, -1), 0),
                    ("TOPPADDING", (0, 0), (-1, -1), 1),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 1),
                ]
            )
        )
        elements.append(items_table)

        elements.append(
            HRFlowable(
                width="100%",
                thickness=0.8,
                color=HexColor("#333333"),
                spaceBefore=2,
                spaceAfter=2,
            )
        )

        # Financial Summary
        totals_data = [
            [
                Paragraph("Subtotal:", meta_left_style),
                Paragraph(format_currency(receipt.subtotal), small_bold_right),
            ]
        ]
        if receipt.discount_amount > 0:
            totals_data.append(
                [
                    Paragraph("Diskon:", meta_left_style),
                    Paragraph(
                        f"-{format_currency(receipt.discount_amount)}", small_bold_right
                    ),
                ]
            )
        totals_data.extend(
            [
                [
                    Paragraph("Total Tagihan:", bold_style),
                    Paragraph(format_currency(receipt.total_amount), small_bold_right),
                ],
                [
                    Paragraph("Sudah Dibayar:", meta_left_style),
                    Paragraph(format_currency(receipt.paid_amount), small_bold_right),
                ],
                [
                    Paragraph("Sisa Tagihan:", bold_style),
                    Paragraph(
                        format_currency(receipt.remaining_amount), small_bold_right
                    ),
                ],
                [
                    Paragraph("Status Pembayaran:", bold_style),
                    Paragraph(html.escape(receipt.payment_status_label), small_bold_right),
                ],
            ]
        )

        totals_table = Table(totals_data, colWidths=[36 * mm, 38 * mm])
        totals_table.setStyle(
            TableStyle(
                [
                    ("VALIGN", (0, 0), (-1, -1), "TOP"),
                    ("LEFTPADDING", (0, 0), (-1, -1), 0),
                    ("RIGHTPADDING", (0, 0), (-1, -1), 0),
                    ("TOPPADDING", (0, 0), (-1, -1), 1),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 1),
                ]
            )
        )
        elements.append(totals_table)

        elements.append(Spacer(1, 2 * mm))

        # QR Code for Tracking
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_M,
            box_size=3,
            border=1,
        )
        qr.add_data(receipt.tracking_url)
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")
        img_buf = io.BytesIO()
        img.save(img_buf, format="PNG")
        img_buf.seek(0)

        elements.append(RLImage(img_buf, width=26 * mm, height=26 * mm))
        elements.append(
            Paragraph("Scan QR Code di atas untuk lacak cucian", subtitle_style)
        )
        if receipt.reprint_count > 0:
            elements.append(Spacer(1, 1 * mm))
            elements.append(
                Paragraph(
                    f"*** CETAK ULANG ({receipt.reprint_count}x) ***",
                    bold_style,
                )
            )

        elements.append(Spacer(1, 2 * mm))
        elements.append(
            Paragraph(
                "Syarat & Ketentuan:<br/>"
                "1. Pengambilan cucian wajib membawa nota ini.<br/>"
                "2. Komplain maksimal 1x24 jam setelah cucian diterima.<br/>"
                "3. Cucian tidak diambil > 30 hari di luar tanggung jawab kami.<br/>"
                "Terima kasih atas kepercayaan Anda!",
                small_style,
            )
        )

        doc.build(elements)
        return buf.getvalue()

    @staticmethod
    async def generate_thermal_html(
        db: AsyncSession,
        tenant_id: uuid.UUID,
        user_role: str,
        user_outlet_id: Optional[uuid.UUID],
        cashier_fallback_name: str,
        order_id: uuid.UUID,
        width: int = 58,
        base_url: Optional[str] = None,
    ) -> str:
        receipt = await ReceiptService.get_receipt_data(
            db,
            tenant_id,
            user_role,
            user_outlet_id,
            cashier_fallback_name,
            order_id,
            base_url,
        )

        # Update initial printed_at timestamp if first time
        stmt = select(Order).where(Order.id == order_id, Order.tenant_id == tenant_id)
        result = await db.execute(stmt)
        order_model = result.scalar_one_or_none()
        if order_model and order_model.receipt_printed_at is None:
            order_model.receipt_printed_at = datetime.now(timezone.utc)
            await db.commit()

        # Generate base64 QR Code
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_M,
            box_size=3,
            border=1,
        )
        qr.add_data(receipt.tracking_url)
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")
        img_buf = io.BytesIO()
        img.save(img_buf, format="PNG")
        img_b64 = base64.b64encode(img_buf.getvalue()).decode("utf-8")

        # Items HTML
        items_rows = ""
        for item in receipt.items:
            qty_fmt = (
                f"{item.quantity:,.1f}"
                if item.quantity % 1 != 0
                else f"{item.quantity:,.0f}"
            )
            esc_service = html.escape(item.service_name)
            esc_unit = html.escape(item.unit)
            items_rows += f"""
            <tr>
              <td colspan="2" style="font-weight:bold;">{esc_service}</td>
            </tr>
            <tr>
              <td>{qty_fmt} {esc_unit} x {format_currency(item.unit_price)}</td>
              <td class="text-right">{format_currency(item.subtotal)}</td>
            </tr>
            """

        reprint_badge = ""
        if receipt.reprint_count > 0:
            reprint_badge = f'<div class="text-center bold" style="margin: 4px 0; color: #555;">*** CETAK ULANG ({receipt.reprint_count}x) ***</div>'

        received_fmt = receipt.received_at.strftime("%d/%m/%Y %H:%M")
        estim_row = ""
        if receipt.estimated_completion_at:
            estim_row = f"""
            <tr>
              <td>Estimasi:</td>
              <td class="text-right">{receipt.estimated_completion_at.strftime("%d/%m/%Y %H:%M")}</td>
            </tr>
            """

        discount_row = ""
        if receipt.discount_amount > 0:
            discount_row = f"""
            <tr>
              <td>Diskon:</td>
              <td class="text-right">-{format_currency(receipt.discount_amount)}</td>
            </tr>
            """

        esc_outlet_name = html.escape(receipt.outlet_name.upper())
        esc_outlet_address = html.escape(receipt.outlet_address) if receipt.outlet_address else ""
        esc_outlet_phone = html.escape(receipt.outlet_phone) if receipt.outlet_phone else "-"
        esc_order_number = html.escape(receipt.order_number)
        esc_customer_name = html.escape(receipt.customer_name)
        esc_customer_phone = html.escape(receipt.customer_phone) if receipt.customer_phone else "-"
        esc_cashier_name = html.escape(receipt.cashier_name) if receipt.cashier_name else "-"
        esc_payment_label = html.escape(receipt.payment_status_label)

        html_content = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Nota {esc_order_number}</title>
  <style>
    @page {{
      size: {width}mm auto;
      margin: 0;
    }}
    body {{
      width: {width}mm;
      margin: 0 auto;
      padding: 6px 4px;
      font-family: 'Courier New', Courier, monospace;
      font-size: 11px;
      color: #000;
      line-height: 1.2;
    }}
    .text-center {{ text-align: center; }}
    .text-right {{ text-align: right; }}
    .bold {{ font-weight: bold; }}
    .divider {{ border-top: 1px dashed #000; margin: 4px 0; }}
    .double-divider {{ border-top: 2px dashed #000; margin: 5px 0; }}
    table {{ width: 100%; border-collapse: collapse; font-size: 11px; }}
    td {{ vertical-align: top; padding: 1px 0; }}
    .qr-container {{ text-align: center; margin: 6px 0; }}
    @media print {{
      .no-print {{ display: none; }}
    }}
  </style>
</head>
<body onload="window.print()">
  <div class="no-print" style="margin-bottom: 8px; text-align: center;">
    <button onclick="window.print()" style="padding: 6px 12px; font-weight: bold; cursor: pointer;">Cetak Thermal</button>
  </div>
  <div class="text-center bold" style="font-size: 13px;">{esc_outlet_name}</div>
  <div class="text-center">{esc_outlet_address}</div>
  <div class="text-center">Telp: {esc_outlet_phone}</div>
  {reprint_badge}
  <div class="double-divider"></div>

  <table>
    <tr><td>No. Order:</td><td class="text-right bold">{esc_order_number}</td></tr>
    <tr><td>Tanggal:</td><td class="text-right">{received_fmt}</td></tr>
    <tr><td>Pelanggan:</td><td class="text-right bold">{esc_customer_name}</td></tr>
    <tr><td>Telepon:</td><td class="text-right">{esc_customer_phone}</td></tr>
    <tr><td>Kasir:</td><td class="text-right">{esc_cashier_name}</td></tr>
    {estim_row}
  </table>

  <div class="divider"></div>
  <table>
    {items_rows}
  </table>

  <div class="divider"></div>
  <table>
    <tr><td>Subtotal:</td><td class="text-right">{format_currency(receipt.subtotal)}</td></tr>
    {discount_row}
    <tr><td class="bold">Total:</td><td class="text-right bold">{format_currency(receipt.total_amount)}</td></tr>
    <tr><td>Sudah Bayar:</td><td class="text-right">{format_currency(receipt.paid_amount)}</td></tr>
    <tr><td class="bold">Sisa:</td><td class="text-right bold">{format_currency(receipt.remaining_amount)}</td></tr>
    <tr><td class="bold">Status:</td><td class="text-right bold">{esc_payment_label}</td></tr>
  </table>

  <div class="divider"></div>
  <div class="qr-container">
    <img src="data:image/png;base64,{img_b64}" width="100" height="100" alt="Tracking QR Code" />
    <div style="font-size: 9px; margin-top: 2px;">Scan untuk lacak status cucian</div>
  </div>

  <div class="divider"></div>
  <div class="text-center" style="font-size: 9px;">
    Syarat & Ketentuan:<br/>
    1. Nota wajib dibawa saat ambil cucian.<br/>
    2. Komplain maks 1x24 jam sejak barang diterima.<br/>
    3. Cucian > 30 hari di luar tanggung jawab kami.<br/>
    Terima kasih telah mempercayakan cucian Anda!
  </div>
</body>
</html>"""
        return html_content

    @staticmethod
    async def record_reprint(
        db: AsyncSession,
        tenant_id: uuid.UUID,
        user_role: str,
        user_outlet_id: Optional[uuid.UUID],
        current_user_id: uuid.UUID,
        order_id: uuid.UUID,
        print_type: str = "thermal",
        notes: Optional[str] = None,
    ) -> ReceiptReprintResponse:
        stmt = select(Order).where(
            Order.id == order_id,
            Order.tenant_id == tenant_id,
        )
        if user_role not in ["owner", "admin"]:
            if not user_outlet_id:
                raise AppException(
                    status_code=403,
                    message="Akses ditolak: Staf operasional wajib terikat pada outlet aktif.",
                    code="OUTLET_CONTEXT_REQUIRED",
                )
            stmt = stmt.where(Order.outlet_id == user_outlet_id)

        result = await db.execute(stmt)
        order = result.scalar_one_or_none()

        if not order:
            raise AppException(
                status_code=404,
                message="Pesanan tidak ditemukan atau berada di luar outlet Anda.",
                code="ORDER_NOT_FOUND",
            )

        now = datetime.now(timezone.utc)
        order.reprint_count += 1
        order.receipt_printed_at = now

        # Add audit log
        log = ReceiptLog(
            tenant_id=order.tenant_id,
            outlet_id=order.outlet_id,
            order_id=order.id,
            printed_by_id=current_user_id,
            print_type=print_type,
            notes=notes,
        )
        db.add(log)
        await db.commit()
        await db.refresh(order)

        return ReceiptReprintResponse(
            order_id=order.id,
            reprint_count=order.reprint_count,
            receipt_printed_at=order.receipt_printed_at,
            print_type=print_type,
        )
