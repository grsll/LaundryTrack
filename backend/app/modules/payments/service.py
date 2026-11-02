from datetime import datetime, timezone
from decimal import Decimal
from typing import List, Optional, Tuple
import uuid
import sqlalchemy as sa
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import BadRequestException, EntityNotFoundException
from app.modules.orders.models import Order, OrderStatus, PaymentStatus
from app.modules.payments.models import Payment, PaymentMethod, PaymentRecordStatus, Refund
from app.modules.payments.schemas import (
    PaymentCreate,
    PaymentDetailResponse,
    PaymentResponse,
    RefundCreate,
    RefundResponse,
)


class PaymentService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def record_payment(
        self,
        tenant_id: uuid.UUID,
        order_id: uuid.UUID,
        user_id: Optional[uuid.UUID],
        payload: PaymentCreate,
        outlet_id: Optional[uuid.UUID] = None,
    ) -> PaymentResponse:
        """
        Records a new payment for an order.
        Uses pessimistic locking on the Order row to prevent race conditions.
        Enforces Decimal arithmetic and rejects overpayments.
        """
        # Lock Order row
        stmt = (
            select(Order)
            .where(Order.id == order_id, Order.tenant_id == tenant_id)
            .with_for_update()
        )
        res = await self.db.execute(stmt)
        order = res.scalar_one_or_none()
        if not order:
            raise EntityNotFoundException("Pesanan", str(order_id))

        if order.status == OrderStatus.CANCELLED.value:
            raise BadRequestException("Tidak dapat mencatat pembayaran untuk pesanan yang sudah dibatalkan.")

        if outlet_id and order.outlet_id != outlet_id:
            raise BadRequestException("Pesanan ini tidak berada di bawah outlet aktif Anda.")

        pay_amount = payload.amount.quantize(Decimal("0.01"))
        if pay_amount <= Decimal("0.00"):
            raise BadRequestException("Nominal pembayaran harus lebih besar dari Rp0.00.")

        if pay_amount > order.remaining_amount:
            raise BadRequestException(
                f"Nominal pembayaran (Rp{pay_amount:,.2f}) melebihi sisa tagihan (Rp{order.remaining_amount:,.2f})."
            )

        payment = Payment(
            id=uuid.uuid4(),
            tenant_id=tenant_id,
            outlet_id=order.outlet_id,
            order_id=order.id,
            received_by_id=user_id,
            amount=pay_amount,
            payment_method=payload.payment_method.value,
            reference_number=payload.reference_number,
            status=PaymentRecordStatus.PAID.value,
            paid_at=datetime.now(timezone.utc),
            notes=payload.notes,
        )
        self.db.add(payment)

        # Update order amounts
        order.paid_amount = (order.paid_amount + pay_amount).quantize(Decimal("0.01"))
        order.remaining_amount = (order.total_amount - order.paid_amount).quantize(Decimal("0.01"))

        if order.remaining_amount == Decimal("0.00"):
            order.payment_status = PaymentStatus.PAID.value
        else:
            order.payment_status = PaymentStatus.PARTIAL.value

        await self.db.commit()

        # Load fresh payment with relationships
        return await self.get_payment_response_by_id(tenant_id, payment.id)

    async def record_refund(
        self,
        tenant_id: uuid.UUID,
        payment_id: uuid.UUID,
        user_id: Optional[uuid.UUID],
        payload: RefundCreate,
        outlet_id: Optional[uuid.UUID] = None,
    ) -> RefundResponse:
        """
        Records a refund against a specific payment.
        Pessimistically locks both Payment and Order rows.
        Enforces that refund does not exceed net payment or order paid amount.
        """
        # Lock Payment row
        p_stmt = (
            select(Payment)
            .where(Payment.id == payment_id, Payment.tenant_id == tenant_id)
            .options(selectinload(Payment.refunds))
            .with_for_update()
        )
        p_res = await self.db.execute(p_stmt)
        payment = p_res.scalar_one_or_none()
        if not payment:
            raise EntityNotFoundException("Pembayaran", str(payment_id))

        if outlet_id and payment.outlet_id != outlet_id:
            raise BadRequestException("Transaksi pembayaran ini tidak berada di bawah outlet aktif Anda.")

        # Lock Order row
        o_stmt = (
            select(Order)
            .where(Order.id == payment.order_id, Order.tenant_id == tenant_id)
            .with_for_update()
        )
        o_res = await self.db.execute(o_stmt)
        order = o_res.scalar_one_or_none()
        if not order:
            raise EntityNotFoundException("Pesanan", str(payment.order_id))

        if order.status == OrderStatus.CANCELLED.value:
            raise BadRequestException("Tidak dapat memproses pengembalian dana untuk pesanan yang sudah dibatalkan.")

        refund_amount = payload.amount.quantize(Decimal("0.01"))
        if refund_amount <= Decimal("0.00"):
            raise BadRequestException("Nominal refund harus lebih besar dari Rp0.00.")

        existing_refunds_sum = sum((r.amount for r in payment.refunds), start=Decimal("0.00"))
        max_refundable_for_payment = (payment.amount - existing_refunds_sum).quantize(Decimal("0.01"))

        if refund_amount > max_refundable_for_payment:
            raise BadRequestException(
                f"Nominal refund (Rp{refund_amount:,.2f}) melebihi sisa dana pembayaran yang dapat direfund (Rp{max_refundable_for_payment:,.2f})."
            )

        if refund_amount > order.paid_amount:
            raise BadRequestException(
                f"Nominal refund (Rp{refund_amount:,.2f}) melebihi total pembayaran aktif pesanan (Rp{order.paid_amount:,.2f})."
            )

        clean_reason = payload.reason.strip()
        if len(clean_reason) < 3:
            raise BadRequestException("Alasan pengembalian dana wajib diisi minimal 3 karakter.")

        refund = Refund(
            id=uuid.uuid4(),
            tenant_id=tenant_id,
            outlet_id=payment.outlet_id,
            payment_id=payment.id,
            order_id=order.id,
            refunded_by_id=user_id,
            amount=refund_amount,
            reason=clean_reason,
            refunded_at=datetime.now(timezone.utc),
        )
        self.db.add(refund)

        # Update Payment status
        new_total_refunded = (existing_refunds_sum + refund_amount).quantize(Decimal("0.01"))
        if new_total_refunded == payment.amount:
            payment.status = PaymentRecordStatus.REFUNDED.value
        else:
            payment.status = PaymentRecordStatus.PARTIALLY_REFUNDED.value

        # Update Order amounts and payment_status
        order.paid_amount = (order.paid_amount - refund_amount).quantize(Decimal("0.01"))
        order.remaining_amount = (order.total_amount - order.paid_amount).quantize(Decimal("0.01"))

        if order.paid_amount == Decimal("0.00"):
            order.payment_status = PaymentStatus.REFUNDED.value
        elif order.remaining_amount == Decimal("0.00"):
            order.payment_status = PaymentStatus.PAID.value
        else:
            order.payment_status = PaymentStatus.PARTIAL.value

        await self.db.commit()

        # Load fresh refund with user
        r_stmt = (
            select(Refund)
            .where(Refund.id == refund.id, Refund.tenant_id == tenant_id)
            .options(selectinload(Refund.refunded_by))
        )
        r_loaded = (await self.db.execute(r_stmt)).scalar_one()

        return RefundResponse(
            id=r_loaded.id,
            tenant_id=r_loaded.tenant_id,
            outlet_id=r_loaded.outlet_id,
            payment_id=r_loaded.payment_id,
            order_id=r_loaded.order_id,
            refunded_by_id=r_loaded.refunded_by_id,
            refunded_by_name=r_loaded.refunded_by.full_name if r_loaded.refunded_by else None,
            amount=r_loaded.amount,
            reason=r_loaded.reason,
            refunded_at=r_loaded.refunded_at,
            created_at=r_loaded.created_at,
        )

    async def list_order_payments(
        self,
        tenant_id: uuid.UUID,
        order_id: uuid.UUID,
    ) -> List[PaymentResponse]:
        """
        Lists all payments made for a given order, including all associated refunds.
        """
        # Verify order belongs to tenant
        o_stmt = select(Order.id).where(Order.id == order_id, Order.tenant_id == tenant_id)
        if not (await self.db.execute(o_stmt)).scalar_one_or_none():
            raise EntityNotFoundException("Pesanan", str(order_id))

        stmt = (
            select(Payment)
            .where(Payment.order_id == order_id, Payment.tenant_id == tenant_id)
            .options(
                selectinload(Payment.received_by),
                selectinload(Payment.refunds).selectinload(Refund.refunded_by),
            )
            .order_by(Payment.paid_at.desc())
        )
        res = await self.db.execute(stmt)
        payments = res.scalars().all()

        return [self._build_payment_response(p) for p in payments]

    async def get_payment_detail_by_id(
        self,
        tenant_id: uuid.UUID,
        payment_id: uuid.UUID,
    ) -> PaymentDetailResponse:
        """
        Retrieves detailed information for a single payment.
        """
        stmt = (
            select(Payment)
            .where(Payment.id == payment_id, Payment.tenant_id == tenant_id)
            .options(
                selectinload(Payment.received_by),
                selectinload(Payment.refunds).selectinload(Refund.refunded_by),
                selectinload(Payment.order),
            )
        )
        res = await self.db.execute(stmt)
        payment = res.scalar_one_or_none()
        if not payment:
            raise EntityNotFoundException("Pembayaran", str(payment_id))

        base_res = self._build_payment_response(payment)
        order = payment.order

        return PaymentDetailResponse(
            **base_res.model_dump(),
            order_number=order.order_number if order else None,
            order_total_amount=order.total_amount if order else None,
            order_remaining_amount=order.remaining_amount if order else None,
            order_payment_status=order.payment_status if order else None,
        )

    async def get_payment_response_by_id(
        self,
        tenant_id: uuid.UUID,
        payment_id: uuid.UUID,
    ) -> PaymentResponse:
        """Helper to fetch and build a standard PaymentResponse."""
        stmt = (
            select(Payment)
            .where(Payment.id == payment_id, Payment.tenant_id == tenant_id)
            .options(
                selectinload(Payment.received_by),
                selectinload(Payment.refunds).selectinload(Refund.refunded_by),
            )
        )
        res = await self.db.execute(stmt)
        payment = res.scalar_one_or_none()
        if not payment:
            raise EntityNotFoundException("Pembayaran", str(payment_id))
        return self._build_payment_response(payment)

    async def list_payments(
        self,
        tenant_id: uuid.UUID,
        outlet_id: Optional[uuid.UUID] = None,
        order_id: Optional[uuid.UUID] = None,
        payment_method: Optional[str] = None,
        status: Optional[str] = None,
        date_from: Optional[datetime] = None,
        date_to: Optional[datetime] = None,
        page: int = 1,
        page_size: int = 20,
    ) -> Tuple[List[PaymentResponse], int]:
        """
        Paginated list of payments for the tenant with optional filters.
        """
        base_filters = [Payment.tenant_id == tenant_id]

        if outlet_id:
            base_filters.append(Payment.outlet_id == outlet_id)
        if order_id:
            base_filters.append(Payment.order_id == order_id)
        if payment_method:
            base_filters.append(Payment.payment_method == payment_method)
        if status:
            base_filters.append(Payment.status == status)
        if date_from:
            base_filters.append(Payment.paid_at >= date_from)
        if date_to:
            base_filters.append(Payment.paid_at <= date_to)

        count_stmt = select(func.count(Payment.id)).where(*base_filters)
        total_count = (await self.db.execute(count_stmt)).scalar() or 0

        offset = (page - 1) * page_size
        stmt = (
            select(Payment)
            .where(*base_filters)
            .options(
                selectinload(Payment.received_by),
                selectinload(Payment.refunds).selectinload(Refund.refunded_by),
            )
            .order_by(Payment.paid_at.desc())
            .offset(offset)
            .limit(page_size)
        )
        res = await self.db.execute(stmt)
        payments = res.scalars().all()

        return [self._build_payment_response(p) for p in payments], total_count

    def _build_payment_response(self, payment: Payment) -> PaymentResponse:
        refund_responses: List[RefundResponse] = []
        total_refunded = Decimal("0.00")

        for r in payment.refunds:
            total_refunded += r.amount
            refund_responses.append(
                RefundResponse(
                    id=r.id,
                    tenant_id=r.tenant_id,
                    outlet_id=r.outlet_id,
                    payment_id=r.payment_id,
                    order_id=r.order_id,
                    refunded_by_id=r.refunded_by_id,
                    refunded_by_name=r.refunded_by.full_name if r.refunded_by else None,
                    amount=r.amount,
                    reason=r.reason,
                    refunded_at=r.refunded_at,
                    created_at=r.created_at,
                )
            )

        net_amount = (payment.amount - total_refunded).quantize(Decimal("0.01"))

        return PaymentResponse(
            id=payment.id,
            tenant_id=payment.tenant_id,
            outlet_id=payment.outlet_id,
            order_id=payment.order_id,
            received_by_id=payment.received_by_id,
            received_by_name=payment.received_by.full_name if payment.received_by else None,
            amount=payment.amount,
            payment_method=payment.payment_method,
            reference_number=payment.reference_number,
            status=payment.status,
            paid_at=payment.paid_at,
            notes=payment.notes,
            created_at=payment.created_at,
            refunds=refund_responses,
            total_refunded=total_refunded.quantize(Decimal("0.01")),
            net_amount=net_amount,
        )
