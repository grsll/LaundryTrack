from datetime import datetime
from decimal import Decimal
import secrets
from typing import Optional
import uuid
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from app.core.exceptions import AppException
from app.modules.orders.models import Order, OrderStatus, PaymentStatus
from app.modules.tracking.schemas import (
    PublicTrackingItemResponse,
    PublicTrackingResponse,
    PublicTrackingTimelineResponse,
    TrackingLinkResponse,
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


def mask_name(name: Optional[str]) -> str:
    if not name or not name.strip():
        return "***"
    parts = name.strip().split()
    if not parts:
        return "***"
    if len(parts) == 1:
        first = parts[0]
        if len(first) <= 2:
            return first[0] + "*" * (len(first) - 1)
        return first[:2] + "*" * (len(first) - 2)
    first_word = parts[0]
    masked_rest = []
    for p in parts[1:]:
        masked_rest.append(p[0] + "*" * min(5, max(3, len(p) - 1)))
    return f"{first_word} {' '.join(masked_rest)}"


def mask_phone(phone: Optional[str]) -> str:
    if not phone or not phone.strip():
        return ""
    digits = phone.strip()
    if len(digits) <= 6:
        return digits[:2] + "****" if len(digits) >= 2 else "****"
    return f"{digits[:4]}****{digits[-4:]}"


def build_whatsapp_message(
    customer_name: str,
    order_number: str,
    outlet_name: str,
    total_amount: Decimal,
    payment_status_label: str,
    tracking_url: str,
) -> str:
    formatted_total = f"{total_amount:,.0f}".replace(",", ".")
    return (
        f"Halo Kak {customer_name},\n\n"
        f"Pesanan laundry Anda *{order_number}* telah diterima di *{outlet_name}*.\n"
        f"Total: *Rp {formatted_total}* (Status: {payment_status_label})\n\n"
        f"Pantau proses pengerjaan cucian Anda secara langsung melalui tautan berikut:\n"
        f"{tracking_url}\n\n"
        f"Terima kasih telah menggunakan layanan kami!"
    )


class TrackingService:
    @staticmethod
    async def get_public_tracking_by_token(
        db: AsyncSession,
        token: str,
    ) -> PublicTrackingResponse:
        stmt = (
            select(Order)
            .options(
                selectinload(Order.customer),
                selectinload(Order.outlet),
                selectinload(Order.items),
                selectinload(Order.status_logs),
            )
            .where(Order.tracking_token == token)
        )
        result = await db.execute(stmt)
        order = result.scalar_one_or_none()

        if not order:
            raise AppException(
                status_code=404,
                message="Data pesanan dengan token pelacakan tersebut tidak ditemukan.",
                code="TRACKING_NOT_FOUND",
            )

        items_data = [
            PublicTrackingItemResponse(
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

        # Build timeline from status logs
        timeline_data = [
            PublicTrackingTimelineResponse(
                status=log.new_status,
                status_label=STATUS_LABELS.get(log.new_status, log.new_status),
                timestamp=log.created_at,
                notes=log.notes,
            )
            for log in order.status_logs
        ]

        # If no status logs yet, provide the initial received status
        if not timeline_data:
            timeline_data.append(
                PublicTrackingTimelineResponse(
                    status=order.status,
                    status_label=STATUS_LABELS.get(order.status, order.status),
                    timestamp=order.received_at,
                    notes="Pesanan diterima di kasir",
                )
            )

        customer_name = order.customer.name if order.customer else "Pelanggan"
        customer_phone = order.customer.phone if order.customer else ""

        return PublicTrackingResponse(
            order_number=order.order_number,
            status=order.status,
            status_label=STATUS_LABELS.get(order.status, order.status),
            payment_status=order.payment_status,
            payment_status_label=PAYMENT_STATUS_LABELS.get(
                order.payment_status, order.payment_status
            ),
            customer_name_masked=mask_name(customer_name),
            customer_phone_masked=mask_phone(customer_phone),
            received_at=order.received_at,
            estimated_completion_at=order.estimated_completion_at,
            completed_at=None,
            delivered_at=None,
            outlet_name=order.outlet.name if order.outlet else "Laundry Outlet",
            outlet_phone=order.outlet.phone if order.outlet else None,
            outlet_address=order.outlet.address if order.outlet else None,
            items=items_data,
            subtotal=order.subtotal,
            discount_amount=order.discount_amount,
            total_amount=order.total_amount,
            paid_amount=order.paid_amount,
            remaining_amount=order.remaining_amount,
            timeline=timeline_data,
        )

    @staticmethod
    async def get_tracking_link(
        db: AsyncSession,
        tenant_id: uuid.UUID,
        user_role: str,
        user_outlet_id: Optional[uuid.UUID],
        order_id: uuid.UUID,
        base_url: Optional[str] = None,
    ) -> TrackingLinkResponse:
        stmt = (
            select(Order)
            .options(
                selectinload(Order.customer),
                selectinload(Order.outlet),
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
                message="Pesanan tidak ditemukan atau berada di luar outlet Anda.",
                code="ORDER_NOT_FOUND",
            )

        web_base = base_url.rstrip("/") if base_url else "http://localhost:3000"
        tracking_url = f"{web_base}/#/track/{order.tracking_token}"

        customer_name = order.customer.name if order.customer else "Pelanggan"
        outlet_name = order.outlet.name if order.outlet else "Laundry Outlet"
        payment_label = PAYMENT_STATUS_LABELS.get(
            order.payment_status, order.payment_status
        )

        wa_text = build_whatsapp_message(
            customer_name=customer_name,
            order_number=order.order_number,
            outlet_name=outlet_name,
            total_amount=order.total_amount,
            payment_status_label=payment_label,
            tracking_url=tracking_url,
        )

        return TrackingLinkResponse(
            order_id=order.id,
            order_number=order.order_number,
            tracking_token=order.tracking_token,
            tracking_url=tracking_url,
            whatsapp_share_text=wa_text,
        )

    @staticmethod
    async def regenerate_tracking_token(
        db: AsyncSession,
        tenant_id: uuid.UUID,
        user_role: str,
        user_outlet_id: Optional[uuid.UUID],
        order_id: uuid.UUID,
        base_url: Optional[str] = None,
    ) -> TrackingLinkResponse:
        stmt = (
            select(Order)
            .options(
                selectinload(Order.customer),
                selectinload(Order.outlet),
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
                message="Pesanan tidak ditemukan atau berada di luar outlet Anda.",
                code="ORDER_NOT_FOUND",
            )

        # Generate new 256-bit safe token
        new_token = secrets.token_urlsafe(32)
        order.tracking_token = new_token
        await db.commit()
        await db.refresh(order)

        web_base = base_url.rstrip("/") if base_url else "http://localhost:3000"
        tracking_url = f"{web_base}/#/track/{order.tracking_token}"

        customer_name = order.customer.name if order.customer else "Pelanggan"
        outlet_name = order.outlet.name if order.outlet else "Laundry Outlet"
        payment_label = PAYMENT_STATUS_LABELS.get(
            order.payment_status, order.payment_status
        )

        wa_text = build_whatsapp_message(
            customer_name=customer_name,
            order_number=order.order_number,
            outlet_name=outlet_name,
            total_amount=order.total_amount,
            payment_status_label=payment_label,
            tracking_url=tracking_url,
        )

        return TrackingLinkResponse(
            order_id=order.id,
            order_number=order.order_number,
            tracking_token=order.tracking_token,
            tracking_url=tracking_url,
            whatsapp_share_text=wa_text,
        )
