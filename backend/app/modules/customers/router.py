import math
from typing import Any, List, Optional
import uuid
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.core.dependencies import get_current_tenant, get_current_user, require_roles
from app.modules.customers.schemas import (
    CustomerCreate,
    CustomerResponse,
    CustomerSummaryResponse,
    CustomerUpdate,
)
from app.modules.customers.service import CustomerService
from app.modules.tenants.models import Tenant
from app.modules.users.models import User
from app.shared.schemas import PaginatedResponse, PaginationMeta, StandardResponse

router = APIRouter(prefix="/customers", tags=["Customers"])


@router.get("", response_model=PaginatedResponse[CustomerResponse])
async def list_customers(
    page: int = Query(default=1, ge=1, description="Nomor halaman"),
    page_size: int = Query(default=20, ge=1, le=100, description="Item per halaman"),
    q: Optional[str] = Query(default=None, max_length=100, description="Pencarian nama atau nomor telepon"),
    is_active: Optional[bool] = Query(default=None, description="Filter status aktif/arsip"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    current_tenant: Tenant = Depends(get_current_tenant),
):
    """Lists customers strictly isolated to the authenticated tenant."""
    service = CustomerService(db)
    items, total = await service.list_customers(
        tenant_id=current_tenant.id,
        page=page,
        page_size=page_size,
        q=q,
        is_active=is_active,
    )
    total_pages = math.ceil(total / page_size) if total > 0 else 0
    return PaginatedResponse(
        success=True,
        data=[CustomerResponse.model_validate(c) for c in items],
        meta=PaginationMeta(
            page=page,
            page_size=page_size,
            total=total,
            total_pages=total_pages,
        ),
    )


@router.post("", response_model=StandardResponse[CustomerResponse], status_code=status.HTTP_201_CREATED)
async def create_customer(
    payload: CustomerCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    current_tenant: Tenant = Depends(get_current_tenant),
):
    """Registers a new customer for the active business."""
    service = CustomerService(db)
    customer = await service.create_customer(current_tenant.id, payload)
    return StandardResponse(
        success=True,
        data=CustomerResponse.model_validate(customer),
    )


@router.get("/{customer_id}", response_model=StandardResponse[CustomerResponse])
async def get_customer(
    customer_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    current_tenant: Tenant = Depends(get_current_tenant),
):
    """Retrieves single customer detail with IDOR protection."""
    service = CustomerService(db)
    customer = await service.get_customer_by_id(current_tenant.id, customer_id)
    return StandardResponse(
        success=True,
        data=CustomerResponse.model_validate(customer),
    )


@router.patch("/{customer_id}", response_model=StandardResponse[CustomerResponse])
async def update_customer(
    customer_id: uuid.UUID,
    payload: CustomerUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    current_tenant: Tenant = Depends(get_current_tenant),
):
    """Updates customer information under tenant scope."""
    service = CustomerService(db)
    customer = await service.update_customer(current_tenant.id, customer_id, payload)
    return StandardResponse(
        success=True,
        data=CustomerResponse.model_validate(customer),
    )


@router.delete("/{customer_id}", response_model=StandardResponse[CustomerResponse])
async def archive_customer(
    customer_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_roles("owner", "admin")),
    current_tenant: Tenant = Depends(get_current_tenant),
):
    """Soft-deletes / archives customer to protect transaction audit trail."""
    service = CustomerService(db)
    customer = await service.archive_customer(current_tenant.id, customer_id)
    return StandardResponse(
        success=True,
        data=CustomerResponse.model_validate(customer),
    )


@router.get("/{customer_id}/orders", response_model=StandardResponse[List[Any]])
async def get_customer_orders(
    customer_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    current_tenant: Tenant = Depends(get_current_tenant),
):
    """Returns historical order records for this customer (empty list in Phase 2 baseline)."""
    service = CustomerService(db)
    await service.get_customer_by_id(current_tenant.id, customer_id)
    return StandardResponse(success=True, data=[])


@router.get("/{customer_id}/summary", response_model=StandardResponse[CustomerSummaryResponse])
async def get_customer_summary(
    customer_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    current_tenant: Tenant = Depends(get_current_tenant),
):
    """Returns order and spending summary metrics for the customer."""
    service = CustomerService(db)
    summary = await service.get_customer_summary(current_tenant.id, customer_id)
    return StandardResponse(
        success=True,
        data=summary,
    )
