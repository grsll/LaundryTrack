from datetime import datetime
import math
from typing import List, Optional
import uuid

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_tenant, require_roles
from app.modules.payments.schemas import (
    PaymentCreate,
    PaymentDetailResponse,
    PaymentResponse,
    RefundCreate,
    RefundResponse,
)
from app.modules.payments.service import PaymentService
from app.modules.tenants.models import Tenant
from app.modules.users.models import User
from app.shared.schemas import PaginatedResponse, PaginationMeta, StandardResponse

router = APIRouter(tags=["Payments"])


@router.post(
    "/orders/{order_id}/payments",
    response_model=StandardResponse[PaymentResponse],
    status_code=status.HTTP_201_CREATED,
)
async def record_payment(
    order_id: uuid.UUID,
    payload: PaymentCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_roles("owner", "admin", "cashier")),
    current_tenant: Tenant = Depends(get_current_tenant),
):
    """
    Records a new payment for a customer order.
    Enforces atomic transaction, Decimal arithmetic, and prevents overpayment.
    """
    token_payload = getattr(current_user, "_token_payload", {})
    token_outlet_str = token_payload.get("outlet_id")
    token_outlet_id = None
    if token_outlet_str:
        try:
            token_outlet_id = uuid.UUID(str(token_outlet_str))
        except (ValueError, TypeError):
            token_outlet_id = None

    service = PaymentService(db)
    payment = await service.record_payment(
        tenant_id=current_tenant.id,
        order_id=order_id,
        user_id=current_user.id,
        payload=payload,
        outlet_id=token_outlet_id,
    )
    return StandardResponse(data=payment)


@router.get(
    "/orders/{order_id}/payments",
    response_model=StandardResponse[List[PaymentResponse]],
)
async def list_order_payments(
    order_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_roles("owner", "admin", "cashier", "operator")),
    current_tenant: Tenant = Depends(get_current_tenant),
):
    """
    Retrieves all payment transactions and their refunds for an order.
    """
    service = PaymentService(db)
    payments = await service.list_order_payments(
        tenant_id=current_tenant.id,
        order_id=order_id,
    )
    return StandardResponse(data=payments)


@router.get(
    "/payments",
    response_model=PaginatedResponse[PaymentResponse],
)
async def list_payments(
    page: int = Query(default=1, ge=1, description="Nomor halaman"),
    page_size: int = Query(default=20, ge=1, le=100, description="Jumlah item per halaman"),
    outlet_id: Optional[uuid.UUID] = Query(default=None, description="Filter ID outlet"),
    order_id: Optional[uuid.UUID] = Query(default=None, description="Filter ID pesanan"),
    payment_method: Optional[str] = Query(default=None, description="Filter metode pembayaran"),
    status: Optional[str] = Query(default=None, description="Filter status pembayaran"),
    date_from: Optional[datetime] = Query(default=None, description="Filter rentang tanggal awal"),
    date_to: Optional[datetime] = Query(default=None, description="Filter rentang tanggal akhir"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_roles("owner", "admin", "cashier")),
    current_tenant: Tenant = Depends(get_current_tenant),
):
    """
    Retrieves paginated payments for the tenant with optional filtering.
    Restricts cashier to their assigned outlet.
    """
    token_payload = getattr(current_user, "_token_payload", {})
    user_role = token_payload.get("role")
    token_outlet_str = token_payload.get("outlet_id")

    effective_outlet_id = outlet_id
    if user_role == "cashier" and token_outlet_str:
        try:
            effective_outlet_id = uuid.UUID(str(token_outlet_str))
        except (ValueError, TypeError):
            pass

    service = PaymentService(db)
    payments, total = await service.list_payments(
        tenant_id=current_tenant.id,
        outlet_id=effective_outlet_id,
        order_id=order_id,
        payment_method=payment_method,
        status=status,
        date_from=date_from,
        date_to=date_to,
        page=page,
        page_size=page_size,
    )

    total_pages = math.ceil(total / page_size) if total > 0 else 0
    return PaginatedResponse(
        data=payments,
        meta=PaginationMeta(
            page=page,
            page_size=page_size,
            total=total,
            total_pages=total_pages,
        ),
    )


@router.get(
    "/payments/{payment_id}",
    response_model=StandardResponse[PaymentDetailResponse],
)
async def get_payment_detail(
    payment_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_roles("owner", "admin", "cashier", "operator")),
    current_tenant: Tenant = Depends(get_current_tenant),
):
    """
    Retrieves detailed information for a single payment.
    """
    service = PaymentService(db)
    payment = await service.get_payment_detail_by_id(
        tenant_id=current_tenant.id,
        payment_id=payment_id,
    )
    return StandardResponse(data=payment)


@router.post(
    "/payments/{payment_id}/refunds",
    response_model=StandardResponse[RefundResponse],
    status_code=status.HTTP_201_CREATED,
)
async def record_refund(
    payment_id: uuid.UUID,
    payload: RefundCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_roles("owner", "admin")),
    current_tenant: Tenant = Depends(get_current_tenant),
):
    """
    Records a refund against a payment transaction.
    Restricted to Owner and Admin roles.
    Pessimistically locks Payment and Order rows to prevent financial inconsistencies.
    """
    token_payload = getattr(current_user, "_token_payload", {})
    token_outlet_str = token_payload.get("outlet_id")
    token_outlet_id = None
    if token_outlet_str:
        try:
            token_outlet_id = uuid.UUID(str(token_outlet_str))
        except (ValueError, TypeError):
            token_outlet_id = None

    service = PaymentService(db)
    refund = await service.record_refund(
        tenant_id=current_tenant.id,
        payment_id=payment_id,
        user_id=current_user.id,
        payload=payload,
        outlet_id=token_outlet_id,
    )
    return StandardResponse(data=refund)
