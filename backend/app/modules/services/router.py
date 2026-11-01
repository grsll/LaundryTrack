import math
from typing import Optional
import uuid
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.core.dependencies import get_current_tenant, get_current_user, require_roles
from app.modules.services.schemas import (
    PriceType,
    ServiceCreate,
    ServiceResponse,
    ServiceUpdate,
)
from app.modules.services.service import ServiceService
from app.modules.tenants.models import Tenant
from app.modules.users.models import User
from app.shared.schemas import PaginatedResponse, PaginationMeta, StandardResponse

router = APIRouter(prefix="/services", tags=["Services"])


@router.get("", response_model=PaginatedResponse[ServiceResponse])
async def list_services(
    page: int = Query(default=1, ge=1, description="Nomor halaman"),
    page_size: int = Query(default=50, ge=1, le=100, description="Item per halaman"),
    q: Optional[str] = Query(default=None, max_length=100, description="Pencarian nama layanan"),
    price_type: Optional[PriceType] = Query(default=None, description="Filter jenis harga (per_kg / per_item)"),
    is_active: Optional[bool] = Query(default=None, description="Filter status aktif/nonaktif"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    current_tenant: Tenant = Depends(get_current_tenant),
):
    """Lists services for the authenticated business with search and filtering."""
    service = ServiceService(db)
    items, total = await service.list_services(
        tenant_id=current_tenant.id,
        page=page,
        page_size=page_size,
        q=q,
        price_type=price_type.value if price_type else None,
        is_active=is_active,
    )
    total_pages = math.ceil(total / page_size) if total > 0 else 0
    return PaginatedResponse(
        success=True,
        data=[ServiceResponse.model_validate(s) for s in items],
        meta=PaginationMeta(
            page=page,
            page_size=page_size,
            total=total,
            total_pages=total_pages,
        ),
    )


@router.post("", response_model=StandardResponse[ServiceResponse], status_code=status.HTTP_201_CREATED)
async def create_service(
    payload: ServiceCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_roles("owner", "admin")),
    current_tenant: Tenant = Depends(get_current_tenant),
):
    """Creates a new laundry service for the active tenant."""
    service = ServiceService(db)
    new_service = await service.create_service(current_tenant.id, payload)
    return StandardResponse(
        success=True,
        data=ServiceResponse.model_validate(new_service),
    )


@router.get("/{service_id}", response_model=StandardResponse[ServiceResponse])
async def get_service(
    service_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    current_tenant: Tenant = Depends(get_current_tenant),
):
    """Retrieves service detail with IDOR protection."""
    service = ServiceService(db)
    item = await service.get_service_by_id(current_tenant.id, service_id)
    return StandardResponse(
        success=True,
        data=ServiceResponse.model_validate(item),
    )


@router.patch("/{service_id}", response_model=StandardResponse[ServiceResponse])
async def update_service(
    service_id: uuid.UUID,
    payload: ServiceUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_roles("owner", "admin")),
    current_tenant: Tenant = Depends(get_current_tenant),
):
    """Updates laundry service pricing and details."""
    service = ServiceService(db)
    updated = await service.update_service(current_tenant.id, service_id, payload)
    return StandardResponse(
        success=True,
        data=ServiceResponse.model_validate(updated),
    )


@router.delete("/{service_id}", response_model=StandardResponse[ServiceResponse])
async def archive_service(
    service_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_roles("owner", "admin")),
    current_tenant: Tenant = Depends(get_current_tenant),
):
    """Deactivates a service so it is unavailable for future orders."""
    service = ServiceService(db)
    archived = await service.archive_service(current_tenant.id, service_id)
    return StandardResponse(
        success=True,
        data=ServiceResponse.model_validate(archived),
    )
