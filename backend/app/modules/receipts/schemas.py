from datetime import datetime
from decimal import Decimal
from typing import List, Literal, Optional
import uuid
from pydantic import BaseModel, ConfigDict, Field


class ReceiptItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    service_name: str
    price_type: str
    unit: str
    quantity: Decimal
    unit_price: Decimal
    subtotal: Decimal
    notes: Optional[str] = None


class ReceiptPaymentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    amount: Decimal
    payment_method: str
    paid_at: datetime
    received_by_name: Optional[str] = None
    reference_number: Optional[str] = None


class ReceiptResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    order_id: uuid.UUID
    order_number: str
    status: str
    status_label: str
    payment_status: str
    payment_status_label: str
    received_at: datetime
    estimated_completion_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    customer_name: str
    customer_phone: Optional[str] = None
    customer_address: Optional[str] = None
    outlet_name: str
    outlet_phone: Optional[str] = None
    outlet_address: Optional[str] = None
    tenant_name: str
    cashier_name: Optional[str] = None
    items: List[ReceiptItemResponse]
    subtotal: Decimal
    discount_amount: Decimal
    total_amount: Decimal
    paid_amount: Decimal
    remaining_amount: Decimal
    payments: List[ReceiptPaymentResponse]
    tracking_token: str
    tracking_url: str
    receipt_printed_at: Optional[datetime] = None
    reprint_count: int = 0


class ReceiptReprintRequest(BaseModel):
    print_type: Literal["thermal", "pdf", "digital"] = Field(
        default="thermal", description="thermal, pdf, or digital"
    )
    notes: Optional[str] = Field(default=None, max_length=255)


class ReceiptReprintResponse(BaseModel):
    order_id: uuid.UUID
    reprint_count: int
    receipt_printed_at: datetime
    print_type: str
