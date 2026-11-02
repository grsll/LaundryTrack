from datetime import datetime, timezone
from decimal import Decimal
from typing import List, Optional, Tuple
import uuid

import sqlalchemy as sa
from sqlalchemy import func, or_, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload, joinedload

from app.core.exceptions import AppException, BadRequestException, EntityNotFoundException
from app.modules.customers.models import Customer
from app.modules.orders.models import Order, OrderItem, OrderSequence, OrderStatus, PaymentStatus, OrderStatusLog
from app.modules.orders.schemas import OrderCreate, OrderStatusTransitionRequest, OrderUpdate
from app.modules.outlets.models import Outlet
from app.modules.services.models import Service


try:
    from zoneinfo import ZoneInfo
    TZ_WIB = ZoneInfo("Asia/Jakarta")
except Exception:
    TZ_WIB = timezone.utc

VALID_TRANSITIONS = {
    OrderStatus.RECEIVED.value: {OrderStatus.WASHING.value},
    OrderStatus.WASHING.value: {OrderStatus.DRYING.value},
    OrderStatus.DRYING.value: {OrderStatus.IRONING.value, OrderStatus.PACKAGING.value},
    OrderStatus.IRONING.value: {OrderStatus.PACKAGING.value, OrderStatus.READY.value},
    OrderStatus.PACKAGING.value: {OrderStatus.READY.value},
    OrderStatus.READY.value: {OrderStatus.COMPLETED.value},
    OrderStatus.COMPLETED.value: set(),
    OrderStatus.CANCELLED.value: set(),
}


class OrderService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def generate_order_number(self, tenant_id: uuid.UUID, outlet_id: uuid.UUID) -> str:
        """
        Generates an atomic, collision-free order sequence number formatted as:
        LDR-YYYYMMDD-XXXX (e.g. LDR-20261102-0001).
        Utilizes PostgreSQL atomic ON CONFLICT DO UPDATE RETURNING.
        """
        date_str = datetime.now(TZ_WIB).strftime("%Y%m%d")

        stmt = (
            pg_insert(OrderSequence)
            .values(
                id=uuid.uuid4(),
                tenant_id=tenant_id,
                outlet_id=outlet_id,
                date_str=date_str,
                last_sequence=1,
            )
            .on_conflict_do_update(
                index_elements=["tenant_id", "date_str"],
                set_={"last_sequence": OrderSequence.last_sequence + 1},
            )
            .returning(OrderSequence.last_sequence)
        )
        res = await self.db.execute(stmt)
        seq_val = res.scalar_one()
        return f"LDR-{date_str}-{seq_val:04d}"

    async def create_order(
        self,
        tenant_id: uuid.UUID,
        user_id: Optional[uuid.UUID],
        token_outlet_id: Optional[uuid.UUID],
        payload: OrderCreate,
    ) -> Order:
        """
        Creates an order with full tenant isolation, snapshotting service items,
        and atomic Decimal calculations.
        """
        # 1. Resolve & Validate Outlet
        target_outlet_id = payload.outlet_id or token_outlet_id
        if not target_outlet_id:
            # Fallback to the first active outlet of the tenant
            outlet_stmt = (
                select(Outlet)
                .where(Outlet.tenant_id == tenant_id, Outlet.is_active.is_(True))
                .limit(1)
            )
            outlet_res = await self.db.execute(outlet_stmt)
            active_outlet = outlet_res.scalar_one_or_none()
            if not active_outlet:
                raise BadRequestException("Bisnis ini belum memiliki outlet aktif untuk mencatat pesanan.")
            target_outlet_id = active_outlet.id
        else:
            outlet_stmt = select(Outlet).where(
                Outlet.id == target_outlet_id,
                Outlet.tenant_id == tenant_id,
                Outlet.is_active.is_(True),
            )
            outlet_res = await self.db.execute(outlet_stmt)
            if not outlet_res.scalar_one_or_none():
                raise BadRequestException("Outlet yang dipilih tidak ditemukan atau nonaktif.")

        # 2. Validate Customer
        cust_stmt = select(Customer).where(
            Customer.id == payload.customer_id,
            Customer.tenant_id == tenant_id,
            Customer.is_active.is_(True),
        )
        cust_res = await self.db.execute(cust_stmt)
        customer = cust_res.scalar_one_or_none()
        if not customer:
            raise BadRequestException("Pelanggan tidak ditemukan atau tidak aktif pada bisnis Anda.")

        # 3. Validate and fetch Services for line items
        service_ids = {item.service_id for item in payload.items}
        svc_stmt = select(Service).where(
            Service.id.in_(service_ids),
            Service.tenant_id == tenant_id,
            Service.is_active.is_(True),
        )
        svc_res = await self.db.execute(svc_stmt)
        services = svc_res.scalars().all()
        service_map = {s.id: s for s in services}

        if len(service_map) != len(service_ids):
            raise BadRequestException("Satu atau lebih layanan yang dipilih tidak valid, tidak aktif, atau bukan milik bisnis Anda.")

        # 4. Calculate Subtotals with Decimal precision and prepare OrderItem snapshots
        prepared_items: List[OrderItem] = []
        total_subtotal = Decimal("0.00")

        for item_in in payload.items:
            svc = service_map[item_in.service_id]
            unit_price = Decimal(str(svc.price)).quantize(Decimal("0.01"))
            qty = Decimal(str(item_in.quantity)).quantize(Decimal("0.01"))
            item_subtotal = (qty * unit_price).quantize(Decimal("0.01"))
            total_subtotal += item_subtotal

            prepared_items.append(
                OrderItem(
                    id=uuid.uuid4(),
                    tenant_id=tenant_id,
                    service_id=svc.id,
                    service_name_snapshot=svc.name,
                    price_type_snapshot=svc.price_type,
                    unit_snapshot=svc.unit,
                    unit_price_snapshot=unit_price,
                    quantity=qty,
                    subtotal=item_subtotal,
                    notes=item_in.notes.strip() if item_in.notes else None,
                )
            )

        # 5. Financial totals calculation
        discount = Decimal(str(payload.discount_amount or 0)).quantize(Decimal("0.01"))
        if discount > total_subtotal:
            discount = total_subtotal

        total_amount = total_subtotal - discount
        paid_amount = Decimal("0.00")
        remaining_amount = total_amount

        # 6. Generate sequential order number
        order_number = await self.generate_order_number(tenant_id, target_outlet_id)

        # 7. Create Order record
        order = Order(
            id=uuid.uuid4(),
            tenant_id=tenant_id,
            outlet_id=target_outlet_id,
            customer_id=payload.customer_id,
            created_by_id=user_id,
            order_number=order_number,
            status=OrderStatus.RECEIVED.value,
            payment_status=PaymentStatus.UNPAID.value,
            received_at=datetime.now(timezone.utc),
            estimated_completion_at=payload.estimated_completion_at,
            subtotal=total_subtotal,
            discount_amount=discount,
            total_amount=total_amount,
            paid_amount=paid_amount,
            remaining_amount=remaining_amount,
            notes=payload.notes.strip() if payload.notes else None,
        )

        # Bind items to order
        for item in prepared_items:
            item.order_id = order.id
            order.items.append(item)

        # Add initial status audit log
        init_log = OrderStatusLog(
            id=uuid.uuid4(),
            tenant_id=tenant_id,
            order_id=order.id,
            changed_by_id=user_id,
            previous_status=None,
            new_status=OrderStatus.RECEIVED.value,
            notes="Pesanan dibuat dan diterima di kasir.",
        )
        order.status_logs.append(init_log)

        self.db.add(order)
        await self.db.commit()

        # Reload with relationships
        return await self.get_order_by_id(tenant_id, order.id)

    async def list_orders(
        self,
        tenant_id: uuid.UUID,
        outlet_id: Optional[uuid.UUID] = None,
        status: Optional[str] = None,
        payment_status: Optional[str] = None,
        customer_id: Optional[uuid.UUID] = None,
        q: Optional[str] = None,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
        page: int = 1,
        page_size: int = 20,
    ) -> Tuple[List[Order], int]:
        """
        Lists orders filtered by status, outlet, customer, date range, or keyword search.
        Strictly isolated to active tenant.
        """
        base_filters = [Order.tenant_id == tenant_id]

        if outlet_id:
            base_filters.append(Order.outlet_id == outlet_id)
        if status:
            base_filters.append(Order.status == status)
        if payment_status:
            base_filters.append(Order.payment_status == payment_status)
        if customer_id:
            base_filters.append(Order.customer_id == customer_id)
        if start_date:
            base_filters.append(Order.received_at >= start_date)
        if end_date:
            base_filters.append(Order.received_at <= end_date)

        if q and q.strip():
            escaped_q = q.strip().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
            clean_q = f"%{escaped_q}%"
            base_filters.append(
                or_(
                    Order.order_number.ilike(clean_q),
                    Customer.name.ilike(clean_q),
                    Customer.phone.ilike(clean_q),
                )
            )

        # Count total matching records
        count_stmt = (
            select(func.count(Order.id))
            .join(Customer, Customer.id == Order.customer_id)
            .where(*base_filters)
        )
        total_res = await self.db.execute(count_stmt)
        total = total_res.scalar() or 0

        # Query paginated orders with customer and outlet loaded
        offset = (page - 1) * page_size
        stmt = (
            select(Order)
            .join(Customer, Customer.id == Order.customer_id)
            .options(
                joinedload(Order.customer),
                joinedload(Order.outlet),
                selectinload(Order.items),
            )
            .where(*base_filters)
            .order_by(Order.received_at.desc())
            .offset(offset)
            .limit(page_size)
        )
        res = await self.db.execute(stmt)
        orders = list(res.scalars().unique().all())

        return orders, total

    async def get_order_by_id(self, tenant_id: uuid.UUID, order_id: uuid.UUID) -> Order:
        """
        Retrieves a single order with items, customer, outlet, and audit logs.
        Strictly enforces tenant isolation to prevent IDOR vulnerabilities.
        """
        stmt = (
            select(Order)
            .options(
                joinedload(Order.customer),
                joinedload(Order.outlet),
                selectinload(Order.items),
                selectinload(Order.status_logs).joinedload(OrderStatusLog.changed_by),
            )
            .where(Order.id == order_id, Order.tenant_id == tenant_id)
        )
        res = await self.db.execute(stmt)
        order = res.scalars().unique().one_or_none()
        if not order:
            raise EntityNotFoundException("Pesanan", str(order_id))
        return order

    async def update_order(
        self,
        tenant_id: uuid.UUID,
        order_id: uuid.UUID,
        payload: OrderUpdate,
    ) -> Order:
        """Updates editable metadata on an active order with pessimistic locking."""
        stmt = (
            select(Order)
            .where(Order.id == order_id, Order.tenant_id == tenant_id)
            .with_for_update()
        )
        res = await self.db.execute(stmt)
        order = res.scalar_one_or_none()
        if not order:
            raise EntityNotFoundException("Pesanan", str(order_id))

        if order.status in (OrderStatus.COMPLETED.value, OrderStatus.CANCELLED.value):
            raise BadRequestException(f"Pesanan dengan status '{order.status}' sudah final dan tidak dapat diubah.")

        if payload.notes is not None:
            order.notes = payload.notes.strip() if payload.notes else None
        if payload.estimated_completion_at is not None:
            order.estimated_completion_at = payload.estimated_completion_at

        await self.db.commit()
        return await self.get_order_by_id(tenant_id, order.id)

    async def transition_status(
        self,
        tenant_id: uuid.UUID,
        order_id: uuid.UUID,
        user_id: Optional[uuid.UUID],
        new_status: OrderStatus,
        notes: Optional[str] = None,
    ) -> Order:
        """
        Advances the order processing pipeline according to allowed state transitions.
        Strictly logs every state change with actor and timestamp.
        """
        # Fetch with lock to prevent race conditions during rapid state transitions
        stmt = (
            select(Order)
            .where(Order.id == order_id, Order.tenant_id == tenant_id)
            .with_for_update()
        )
        res = await self.db.execute(stmt)
        order = res.scalar_one_or_none()
        if not order:
            raise EntityNotFoundException("Pesanan", str(order_id))

        current_st = order.status
        target_st = new_status.value

        if new_status == OrderStatus.CANCELLED:
            raise BadRequestException(
                "Pembatalan pesanan wajib dilakukan melalui endpoint pembatalan resmi (/orders/{id}/cancel) dan menyertakan alasan pembatalan."
            )

        if current_st in (OrderStatus.COMPLETED.value, OrderStatus.CANCELLED.value):
            raise BadRequestException(
                f"Pesanan berstatus '{current_st}' sudah final dan tidak dapat diubah lagi."
            )

        allowed = VALID_TRANSITIONS.get(current_st, set())
        if target_st not in allowed:
            raise BadRequestException(
                f"Transisi status dari '{current_st}' ke '{target_st}' tidak diizinkan."
            )

        # Update order status
        order.status = target_st

        # Add audit log
        log_entry = OrderStatusLog(
            id=uuid.uuid4(),
            tenant_id=tenant_id,
            order_id=order.id,
            changed_by_id=user_id,
            previous_status=current_st,
            new_status=target_st,
            notes=notes.strip() if notes else None,
        )
        self.db.add(log_entry)

        await self.db.commit()
        return await self.get_order_by_id(tenant_id, order.id)

    async def cancel_order(
        self,
        tenant_id: uuid.UUID,
        order_id: uuid.UUID,
        user_id: Optional[uuid.UUID],
        reason: str,
    ) -> Order:
        """
        Cancels an order before it is completed.
        Mandatory cancellation reason is recorded.
        """
        stmt = (
            select(Order)
            .where(Order.id == order_id, Order.tenant_id == tenant_id)
            .with_for_update()
        )
        res = await self.db.execute(stmt)
        order = res.scalar_one_or_none()
        if not order:
            raise EntityNotFoundException("Pesanan", str(order_id))

        if order.status == OrderStatus.COMPLETED.value:
            raise BadRequestException("Pesanan yang sudah selesai (completed) tidak dapat dibatalkan.")
        if order.status == OrderStatus.CANCELLED.value:
            raise BadRequestException("Pesanan ini sudah berstatus dibatalkan.")

        clean_reason = reason.strip()
        if not clean_reason:
            raise BadRequestException("Alasan pembatalan pesanan wajib diisi.")

        previous_st = order.status
        order.status = OrderStatus.CANCELLED.value
        order.cancellation_reason = clean_reason
        order.cancelled_at = datetime.now(timezone.utc)

        log_entry = OrderStatusLog(
            id=uuid.uuid4(),
            tenant_id=tenant_id,
            order_id=order.id,
            changed_by_id=user_id,
            previous_status=previous_st,
            new_status=OrderStatus.CANCELLED.value,
            notes=f"Pembatalan pesanan: {clean_reason}",
        )
        self.db.add(log_entry)

        await self.db.commit()
        return await self.get_order_by_id(tenant_id, order.id)

    async def get_order_timeline(
        self, tenant_id: uuid.UUID, order_id: uuid.UUID
    ) -> List[OrderStatusLog]:
        """Retrieves chronological lifecycle status history for an order."""
        # Ensure order exists and belongs to tenant
        await self.get_order_by_id(tenant_id, order_id)

        stmt = (
            select(OrderStatusLog)
            .options(joinedload(OrderStatusLog.changed_by))
            .where(
                OrderStatusLog.order_id == order_id,
                OrderStatusLog.tenant_id == tenant_id,
            )
            .order_by(OrderStatusLog.created_at.asc())
        )
        res = await self.db.execute(stmt)
        return list(res.scalars().all())
