import math
from typing import List, Optional, Tuple
import uuid
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import status
from app.core.exceptions import AppException, EntityNotFoundException
from app.modules.customers.models import Customer
from app.modules.customers.schemas import (
    CustomerCreate,
    CustomerSummaryResponse,
    CustomerUpdate,
)


class CustomerService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_customer(
        self, tenant_id: uuid.UUID, payload: CustomerCreate
    ) -> Customer:
        """Creates a new customer record strictly scoped to the active tenant."""
        clean_phone = payload.phone.strip() if payload.phone else None
        clean_email = payload.email.strip().lower() if payload.email else None

        customer = Customer(
            tenant_id=tenant_id,
            name=payload.name.strip(),
            phone=clean_phone,
            email=clean_email,
            address=payload.address.strip() if payload.address else None,
            notes=payload.notes.strip() if payload.notes else None,
            is_active=True,
        )
        self.db.add(customer)
        await self.db.commit()
        await self.db.refresh(customer)
        return customer

    async def get_customer_by_id(
        self, tenant_id: uuid.UUID, customer_id: uuid.UUID
    ) -> Customer:
        """Retrieves a single customer, strictly enforcing tenant ownership to prevent IDOR."""
        stmt = select(Customer).where(
            Customer.tenant_id == tenant_id,
            Customer.id == customer_id,
        )
        res = await self.db.execute(stmt)
        customer = res.scalar_one_or_none()
        if not customer:
            raise AppException(
                status_code=status.HTTP_404_NOT_FOUND,
                code="CUSTOMER_NOT_FOUND",
                message="Data pelanggan tidak ditemukan pada outlet/bisnis Anda.",
            )
        return customer

    async def list_customers(
        self,
        tenant_id: uuid.UUID,
        page: int = 1,
        page_size: int = 20,
        q: Optional[str] = None,
        is_active: Optional[bool] = None,
    ) -> Tuple[List[Customer], int]:
        """Lists customers belonging to the active tenant with search and pagination."""
        base_filters = [Customer.tenant_id == tenant_id]

        if is_active is not None:
            base_filters.append(Customer.is_active.is_(is_active))

        if q and q.strip():
            escaped_q = q.strip().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
            clean_q = f"%{escaped_q}%"
            base_filters.append(
                or_(
                    Customer.name.ilike(clean_q),
                    Customer.phone.ilike(clean_q),
                )
            )

        # Count total matching records
        count_stmt = select(func.count(Customer.id)).where(*base_filters)
        total_res = await self.db.execute(count_stmt)
        total = total_res.scalar() or 0

        # Query paginated records
        offset = (page - 1) * page_size
        stmt = (
            select(Customer)
            .where(*base_filters)
            .order_by(Customer.created_at.desc())
            .offset(offset)
            .limit(page_size)
        )
        res = await self.db.execute(stmt)
        items = list(res.scalars().all())

        return items, total

    async def update_customer(
        self,
        tenant_id: uuid.UUID,
        customer_id: uuid.UUID,
        payload: CustomerUpdate,
    ) -> Customer:
        """Updates customer details under tenant verification."""
        customer = await self.get_customer_by_id(tenant_id, customer_id)

        update_data = payload.model_dump(exclude_unset=True)
        if "name" in update_data and update_data["name"]:
            customer.name = update_data["name"].strip()
        if "phone" in update_data:
            customer.phone = update_data["phone"].strip() if update_data["phone"] else None
        if "email" in update_data:
            customer.email = update_data["email"].strip().lower() if update_data["email"] else None
        if "address" in update_data:
            customer.address = update_data["address"].strip() if update_data["address"] else None
        if "notes" in update_data:
            customer.notes = update_data["notes"].strip() if update_data["notes"] else None
        if "is_active" in update_data and update_data["is_active"] is not None:
            customer.is_active = update_data["is_active"]

        await self.db.commit()
        await self.db.refresh(customer)
        return customer

    async def archive_customer(
        self, tenant_id: uuid.UUID, customer_id: uuid.UUID
    ) -> Customer:
        """Soft-deletes / archives a customer to preserve historical audit integrity."""
        customer = await self.get_customer_by_id(tenant_id, customer_id)
        customer.is_active = False
        await self.db.commit()
        await self.db.refresh(customer)
        return customer

    async def get_customer_summary(
        self, tenant_id: uuid.UUID, customer_id: uuid.UUID
    ) -> CustomerSummaryResponse:
        """Provides transaction summary for the given customer."""
        customer = await self.get_customer_by_id(tenant_id, customer_id)
        # Orders will be connected in Phase 3; default metrics are provided
        return CustomerSummaryResponse(
            customer_id=customer.id,
            customer_name=customer.name,
            total_orders=0,
            active_orders=0,
        )
