from datetime import datetime
from decimal import Decimal
from typing import List, Optional
import uuid
from pydantic import BaseModel, ConfigDict, Field
from app.modules.orders.models import OrderStatus, PaymentStatus


class OrderItemCreate(BaseModel):
    service_id: uuid.UUID = Field(..., description="ID layanan yang dipilih")
    quantity: Decimal = Field(
        ...,
        gt=Decimal("0.00"),
        le=Decimal("99999.99"),
        description="Kuantitas atau berat (kg / pcs)",
    )
    notes: Optional[str] = Field(default=None, max_length=500, description="Catatan khusus item")


class OrderItemResponse(BaseModel):
    id: uuid.UUID
    service_id: Optional[uuid.UUID]
    service_name_snapshot: str
    price_type_snapshot: str
    unit_snapshot: str
    unit_price_snapshot: Decimal
    quantity: Decimal
    subtotal: Decimal
    notes: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class OrderCreate(BaseModel):
    customer_id: uuid.UUID = Field(..., description="ID pelanggan")
    outlet_id: Optional[uuid.UUID] = Field(
        default=None,
        description="ID outlet transaksi (opsional, default outlet user aktif)",
    )
    items: List[OrderItemCreate] = Field(
        ...,
        min_length=1,
        max_length=50,
        description="Daftar item layanan (1 - 50 item)",
    )
    discount_amount: Decimal = Field(
        default=Decimal("0.00"),
        ge=Decimal("0.00"),
        le=Decimal("999999999.99"),
        description="Potongan diskon",
    )
    estimated_completion_at: Optional[datetime] = Field(
        default=None,
        description="Estimasi waktu selesai pengerjaan (UTC)",
    )
    notes: Optional[str] = Field(
        default=None,
        max_length=1000,
        description="Catatan umum pesanan",
    )


class OrderUpdate(BaseModel):
    notes: Optional[str] = Field(default=None, max_length=1000)
    estimated_completion_at: Optional[datetime] = None


class OrderStatusTransitionRequest(BaseModel):
    status: OrderStatus = Field(..., description="Target status baru")
    notes: Optional[str] = Field(default=None, max_length=500, description="Catatan perubahan status")


class OrderCancelRequest(BaseModel):
    reason: str = Field(..., min_length=3, max_length=500, description="Alasan pembatalan wajib diisi")


class OrderStatusLogResponse(BaseModel):
    id: uuid.UUID
    previous_status: Optional[str] = None
    new_status: str
    notes: Optional[str] = None
    changed_by_id: Optional[uuid.UUID] = None
    changed_by_name: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class OrderResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    outlet_id: uuid.UUID
    outlet_name: Optional[str] = None
    customer_id: uuid.UUID
    customer_name: Optional[str] = None
    customer_phone: Optional[str] = None
    order_number: str
    status: str
    payment_status: str
    received_at: datetime
    estimated_completion_at: Optional[datetime] = None
    subtotal: Decimal
    discount_amount: Decimal
    total_amount: Decimal
    paid_amount: Decimal
    remaining_amount: Decimal
    notes: Optional[str] = None
    cancellation_reason: Optional[str] = None
    cancelled_at: Optional[datetime] = None
    tracking_token: Optional[str] = None
    receipt_printed_at: Optional[datetime] = None
    reprint_count: int = 0
    items_count: int = 0
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class OrderDetailResponse(OrderResponse):
    items: List[OrderItemResponse] = []
    status_logs: List[OrderStatusLogResponse] = []
