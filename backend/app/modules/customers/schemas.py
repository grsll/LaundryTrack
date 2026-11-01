from datetime import datetime
from decimal import Decimal
from typing import Optional
import uuid
from pydantic import BaseModel, ConfigDict, EmailStr, Field


class CustomerBase(BaseModel):
    name: str = Field(min_length=1, max_length=255, description="Nama pelanggan")
    phone: Optional[str] = Field(default=None, max_length=32, description="Nomor telepon/WhatsApp")
    email: Optional[EmailStr] = Field(default=None, description="Alamat email pelanggan")
    address: Optional[str] = Field(default=None, description="Alamat domisili/penjemputan")
    notes: Optional[str] = Field(default=None, description="Catatan khusus preferensi laundry")


class CustomerCreate(CustomerBase):
    pass


class CustomerUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=255)
    phone: Optional[str] = Field(default=None, max_length=32)
    email: Optional[EmailStr] = None
    address: Optional[str] = None
    notes: Optional[str] = None
    is_active: Optional[bool] = None


class CustomerResponse(CustomerBase):
    id: uuid.UUID
    tenant_id: uuid.UUID
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class CustomerSummaryResponse(BaseModel):
    customer_id: uuid.UUID
    customer_name: str
    total_orders: int = 0
    total_spent: Decimal = Field(default=Decimal("0.00"))
    active_orders: int = 0
