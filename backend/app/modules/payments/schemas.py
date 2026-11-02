from datetime import datetime
from decimal import Decimal
import enum
from typing import List, Optional
import uuid
from pydantic import BaseModel, ConfigDict, Field, field_validator
from app.modules.payments.models import PaymentMethod, PaymentRecordStatus


class PaymentCreate(BaseModel):
    amount: Decimal = Field(
        ...,
        gt=Decimal("0.00"),
        max_digits=12,
        decimal_places=2,
        description="Nominal pembayaran (maksimal 2 desimal)",
    )
    payment_method: PaymentMethod = Field(default=PaymentMethod.CASH, description="Metode pembayaran")
    reference_number: Optional[str] = Field(default=None, max_length=64, description="Nomor referensi / bukti transaksi")
    notes: Optional[str] = Field(default=None, max_length=500, description="Catatan pembayaran opsional")

    @field_validator("reference_number", "notes", mode="before")
    @classmethod
    def strip_and_clean(cls, v: Optional[str]) -> Optional[str]:
        if isinstance(v, str):
            cleaned = v.strip()
            return cleaned if cleaned else None
        return v


class RefundCreate(BaseModel):
    amount: Decimal = Field(
        ...,
        gt=Decimal("0.00"),
        max_digits=12,
        decimal_places=2,
        description="Nominal pengembalian dana (maksimal 2 desimal)",
    )
    reason: str = Field(..., min_length=3, max_length=500, description="Alasan pengembalian dana wajib diisi")

    @field_validator("reason", mode="before")
    @classmethod
    def validate_reason(cls, v: str) -> str:
        if isinstance(v, str):
            cleaned = v.strip()
            if len(cleaned) < 3:
                raise ValueError("Alasan refund harus memiliki minimal 3 karakter.")
            return cleaned
        raise ValueError("Alasan refund wajib diisi.")


class RefundResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    tenant_id: uuid.UUID
    outlet_id: uuid.UUID
    payment_id: uuid.UUID
    order_id: uuid.UUID
    refunded_by_id: Optional[uuid.UUID] = None
    refunded_by_name: Optional[str] = None
    amount: Decimal
    reason: str
    refunded_at: datetime
    created_at: datetime


class PaymentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    tenant_id: uuid.UUID
    outlet_id: uuid.UUID
    order_id: uuid.UUID
    received_by_id: Optional[uuid.UUID] = None
    received_by_name: Optional[str] = None
    amount: Decimal
    payment_method: str
    reference_number: Optional[str] = None
    status: str
    paid_at: datetime
    notes: Optional[str] = None
    created_at: datetime
    refunds: List[RefundResponse] = []
    total_refunded: Decimal = Decimal("0.00")
    net_amount: Decimal = Decimal("0.00")


class PaymentDetailResponse(PaymentResponse):
    order_number: Optional[str] = None
    order_total_amount: Optional[Decimal] = None
    order_remaining_amount: Optional[Decimal] = None
    order_payment_status: Optional[str] = None
