from datetime import datetime
from decimal import Decimal
import enum
from typing import Optional
import uuid
from pydantic import BaseModel, ConfigDict, Field


class PriceType(str, enum.Enum):
    PER_KG = "per_kg"
    PER_ITEM = "per_item"


class ServiceBase(BaseModel):
    name: str = Field(min_length=1, max_length=255, description="Nama layanan (misal: Cuci Komplit, Setrika Kilat)")
    description: Optional[str] = Field(default=None, description="Deskripsi detail layanan")
    price_type: PriceType = Field(default=PriceType.PER_KG, description="Jenis penetapan harga (per_kg atau per_item)")
    unit: str = Field(default="kg", min_length=1, max_length=32, description="Satuan ukuran (misal: kg, pcs, meter, pasang)")
    price: Decimal = Field(
        gt=Decimal("0.00"),
        le=Decimal("999999999.99"),
        description="Harga satuan dalam Rupiah (Decimal, maksimal 999 juta)",
    )
    estimated_duration_hours: Optional[int] = Field(default=None, ge=1, description="Estimasi waktu pengerjaan dalam jam")
    is_active: bool = Field(default=True, description="Status ketersediaan layanan")


class ServiceCreate(ServiceBase):
    pass


class ServiceUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=255)
    description: Optional[str] = None
    price_type: Optional[PriceType] = None
    unit: Optional[str] = Field(default=None, max_length=32)
    price: Optional[Decimal] = Field(default=None, gt=Decimal("0.00"), le=Decimal("999999999.99"))
    estimated_duration_hours: Optional[int] = Field(default=None, ge=1)
    is_active: Optional[bool] = None


class ServiceResponse(ServiceBase):
    id: uuid.UUID
    tenant_id: uuid.UUID
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
