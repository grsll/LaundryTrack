from datetime import datetime
import math
from typing import List, Optional
import uuid

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_tenant, get_current_user, require_roles
from app.modules.orders.models import Order, OrderStatus, OrderStatusLog
from app.modules.orders.schemas import (
    OrderCancelRequest,
    OrderCreate,
    OrderDetailResponse,
    OrderItemResponse,
    OrderResponse,
    OrderStatusLogResponse,
    OrderStatusTransitionRequest,
    OrderUpdate,
)
from app.modules.orders.service import OrderService
from app.modules.tenants.models import Tenant
from app.modules.users.models import User
from app.shared.schemas import PaginatedResponse, PaginationMeta, StandardResponse

router = APIRouter(prefix="/orders", tags=["Orders"])


def serialize_order_response(order: Order) -> OrderResponse:
    return OrderResponse(
        id=order.id,
        tenant_id=order.tenant_id,
        outlet_id=order.outlet_id,
        outlet_name=order.outlet.name if order.outlet else None,
        customer_id=order.customer_id,
        customer_name=order.customer.name if order.customer else None,
        customer_phone=order.customer.phone if order.customer else None,
        order_number=order.order_number,
        status=order.status,
        payment_status=order.payment_status,
        received_at=order.received_at,
        estimated_completion_at=order.estimated_completion_at,
        subtotal=order.subtotal,
        discount_amount=order.discount_amount,
        total_amount=order.total_amount,
        paid_amount=order.paid_amount,
        remaining_amount=order.remaining_amount,
        notes=order.notes,
        cancellation_reason=order.cancellation_reason,
        cancelled_at=order.cancelled_at,
        tracking_token=order.tracking_token,
        receipt_printed_at=order.receipt_printed_at,
        reprint_count=order.reprint_count,
        items_count=len(order.items) if order.items else 0,
        created_at=order.created_at,
        updated_at=order.updated_at,
    )


def serialize_order_detail(order: Order) -> OrderDetailResponse:
    base = serialize_order_response(order)
    items = [OrderItemResponse.model_validate(it) for it in (order.items or [])]
    status_logs = [
        OrderStatusLogResponse(
            id=log.id,
            previous_status=log.previous_status,
            new_status=log.new_status,
            notes=log.notes,
            changed_by_id=log.changed_by_id,
            changed_by_name=log.changed_by.full_name if log.changed_by else None,
            created_at=log.created_at,
        )
        for log in (order.status_logs or [])
    ]
    return OrderDetailResponse(
        **base.model_dump(),
        items=items,
        status_logs=status_logs,
    )


@router.post("", response_model=StandardResponse[OrderDetailResponse], status_code=status.HTTP_201_CREATED)
async def create_order(
    payload: OrderCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_roles("owner", "admin", "cashier")),
    current_tenant: Tenant = Depends(get_current_tenant),
):
    """
    Creates a new laundry order with snapshotting, atomic numbering,
    and automatic line item subtotal calculation.
    """
    token_payload = getattr(current_user, "_token_payload", {})
    token_outlet_str = token_payload.get("outlet_id")
    token_outlet_id = None
    if token_outlet_str:
        try:
            token_outlet_id = uuid.UUID(str(token_outlet_str))
        except (ValueError, TypeError):
            token_outlet_id = None

    service = OrderService(db)
    order = await service.create_order(
        tenant_id=current_tenant.id,
        user_id=current_user.id,
        token_outlet_id=token_outlet_id,
        payload=payload,
    )
    return StandardResponse(data=serialize_order_detail(order))


@router.get("", response_model=PaginatedResponse[OrderResponse])
async def list_orders(
    page: int = Query(default=1, ge=1, description="Nomor halaman"),
    page_size: int = Query(default=20, ge=1, le=100, description="Jumlah item per halaman"),
    outlet_id: Optional[uuid.UUID] = Query(default=None, description="Filter ID outlet"),
    status: Optional[str] = Query(default=None, description="Filter status pengerjaan"),
    payment_status: Optional[str] = Query(default=None, description="Filter status pembayaran"),
    customer_id: Optional[uuid.UUID] = Query(default=None, description="Filter ID pelanggan"),
    q: Optional[str] = Query(default=None, max_length=100, description="Pencarian nomor nota / nama pelanggan"),
    start_date: Optional[datetime] = Query(default=None, description="Filter rentang tanggal awal"),
    end_date: Optional[datetime] = Query(default=None, description="Filter rentang tanggal akhir"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    current_tenant: Tenant = Depends(get_current_tenant),
):
    """
    Lists orders strictly isolated to the authenticated tenant.
    """
    service = OrderService(db)
    orders, total = await service.list_orders(
        tenant_id=current_tenant.id,
        outlet_id=outlet_id,
        status=status,
        payment_status=payment_status,
        customer_id=customer_id,
        q=q,
        start_date=start_date,
        end_date=end_date,
        page=page,
        page_size=page_size,
    )
    total_pages = math.ceil(total / page_size) if total > 0 else 0

    return PaginatedResponse(
        success=True,
        data=[serialize_order_response(o) for o in orders],
        meta=PaginationMeta(
            page=page,
            page_size=page_size,
            total=total,
            total_pages=total_pages,
        ),
    )


@router.get("/{order_id}", response_model=StandardResponse[OrderDetailResponse])
async def get_order_detail(
    order_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    current_tenant: Tenant = Depends(get_current_tenant),
):
    """
    Retrieves full details of an order including snapshot line items and lifecycle logs.
    """
    service = OrderService(db)
    order = await service.get_order_by_id(tenant_id=current_tenant.id, order_id=order_id)
    return StandardResponse(data=serialize_order_detail(order))


@router.patch("/{order_id}", response_model=StandardResponse[OrderDetailResponse])
async def update_order(
    order_id: uuid.UUID,
    payload: OrderUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_roles("owner", "admin", "cashier")),
    current_tenant: Tenant = Depends(get_current_tenant),
):
    """Updates editable order notes or estimated completion timestamp."""
    service = OrderService(db)
    order = await service.update_order(
        tenant_id=current_tenant.id,
        order_id=order_id,
        payload=payload,
    )
    return StandardResponse(data=serialize_order_detail(order))


@router.post("/{order_id}/status", response_model=StandardResponse[OrderDetailResponse])
async def transition_order_status(
    order_id: uuid.UUID,
    payload: OrderStatusTransitionRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_roles("owner", "admin", "cashier", "operator")),
    current_tenant: Tenant = Depends(get_current_tenant),
):
    """
    Advances the order along the workflow pipeline:
    received -> washing -> drying -> ironing -> packaging -> ready -> completed.
    """
    service = OrderService(db)
    order = await service.transition_status(
        tenant_id=current_tenant.id,
        order_id=order_id,
        user_id=current_user.id,
        new_status=payload.status,
        notes=payload.notes,
    )
    return StandardResponse(data=serialize_order_detail(order))


@router.post("/{order_id}/cancel", response_model=StandardResponse[OrderDetailResponse])
async def cancel_order(
    order_id: uuid.UUID,
    payload: OrderCancelRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_roles("owner", "admin", "cashier")),
    current_tenant: Tenant = Depends(get_current_tenant),
):
    """
    Cancels an active order with a mandatory cancellation reason.
    Completed orders cannot be cancelled.
    """
    service = OrderService(db)
    order = await service.cancel_order(
        tenant_id=current_tenant.id,
        order_id=order_id,
        user_id=current_user.id,
        reason=payload.reason,
    )
    return StandardResponse(data=serialize_order_detail(order))


@router.get("/{order_id}/timeline", response_model=StandardResponse[List[OrderStatusLogResponse]])
async def get_order_timeline(
    order_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    current_tenant: Tenant = Depends(get_current_tenant),
):
    """
    Retrieves chronological status logs of an order.
    """
    service = OrderService(db)
    logs = await service.get_order_timeline(
        tenant_id=current_tenant.id,
        order_id=order_id,
    )
    return StandardResponse(
        data=[
            OrderStatusLogResponse(
                id=log.id,
                previous_status=log.previous_status,
                new_status=log.new_status,
                notes=log.notes,
                changed_by_id=log.changed_by_id,
                changed_by_name=log.changed_by.full_name if log.changed_by else None,
                created_at=log.created_at,
            )
            for log in logs
        ]
    )
