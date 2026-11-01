import math
from typing import List, Optional, Tuple
import uuid
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import status
from app.core.exceptions import AppException
from app.modules.services.models import Service
from app.modules.services.schemas import ServiceCreate, ServiceUpdate


class ServiceService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_service(
        self, tenant_id: uuid.UUID, payload: ServiceCreate
    ) -> Service:
        """Registers a new laundry service under the active tenant."""
        service = Service(
            tenant_id=tenant_id,
            name=payload.name.strip(),
            description=payload.description.strip() if payload.description else None,
            price_type=payload.price_type.value,
            unit=payload.unit.strip().lower(),
            price=payload.price,
            estimated_duration_hours=payload.estimated_duration_hours,
            is_active=payload.is_active,
        )
        self.db.add(service)
        await self.db.commit()
        await self.db.refresh(service)
        return service

    async def get_service_by_id(
        self, tenant_id: uuid.UUID, service_id: uuid.UUID
    ) -> Service:
        """Retrieves a single service with strict tenant isolation (IDOR prevention)."""
        stmt = select(Service).where(
            Service.tenant_id == tenant_id,
            Service.id == service_id,
        )
        res = await self.db.execute(stmt)
        service = res.scalar_one_or_none()
        if not service:
            raise AppException(
                status_code=status.HTTP_404_NOT_FOUND,
                code="SERVICE_NOT_FOUND",
                message="Layanan laundry tidak ditemukan pada bisnis Anda.",
            )
        return service

    async def list_services(
        self,
        tenant_id: uuid.UUID,
        page: int = 1,
        page_size: int = 50,
        q: Optional[str] = None,
        price_type: Optional[str] = None,
        is_active: Optional[bool] = None,
    ) -> Tuple[List[Service], int]:
        """Lists services for the tenant with optional search, price type, and active status filters."""
        base_filters = [Service.tenant_id == tenant_id]

        if is_active is not None:
            base_filters.append(Service.is_active.is_(is_active))

        if price_type:
            base_filters.append(Service.price_type == price_type)

        if q and q.strip():
            escaped_q = q.strip().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
            base_filters.append(Service.name.ilike(f"%{escaped_q}%"))

        # Count total
        count_stmt = select(func.count(Service.id)).where(*base_filters)
        total_res = await self.db.execute(count_stmt)
        total = total_res.scalar() or 0

        # Query items
        offset = (page - 1) * page_size
        stmt = (
            select(Service)
            .where(*base_filters)
            .order_by(Service.name.asc())
            .offset(offset)
            .limit(page_size)
        )
        res = await self.db.execute(stmt)
        items = list(res.scalars().all())

        return items, total

    async def update_service(
        self,
        tenant_id: uuid.UUID,
        service_id: uuid.UUID,
        payload: ServiceUpdate,
    ) -> Service:
        """Updates service attributes. Existing orders preserve immutable snapshot prices."""
        service = await self.get_service_by_id(tenant_id, service_id)

        update_data = payload.model_dump(exclude_unset=True)
        if "name" in update_data and update_data["name"]:
            service.name = update_data["name"].strip()
        if "description" in update_data:
            service.description = (
                update_data["description"].strip() if update_data["description"] else None
            )
        if "price_type" in update_data and update_data["price_type"]:
            service.price_type = update_data["price_type"].value
        if "unit" in update_data and update_data["unit"]:
            service.unit = update_data["unit"].strip().lower()
        if "price" in update_data and update_data["price"] is not None:
            service.price = update_data["price"]
        if "estimated_duration_hours" in update_data:
            service.estimated_duration_hours = update_data["estimated_duration_hours"]
        if "is_active" in update_data and update_data["is_active"] is not None:
            service.is_active = update_data["is_active"]

        await self.db.commit()
        await self.db.refresh(service)
        return service

    async def archive_service(
        self, tenant_id: uuid.UUID, service_id: uuid.UUID
    ) -> Service:
        """Deactivates a service so it cannot be selected for new orders, preserving historical data."""
        service = await self.get_service_by_id(tenant_id, service_id)
        service.is_active = False
        await self.db.commit()
        await self.db.refresh(service)
        return service
