from datetime import datetime
from decimal import Decimal
from typing import List, Optional
import uuid
from pydantic import BaseModel, ConfigDict, Field


class PublicTrackingItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    service_name: str
    price_type: str
    unit: str
    quantity: Decimal
    unit_price: Decimal
    subtotal: Decimal
    notes: Optional[str] = None


class PublicTrackingTimelineResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    status: str
    status_label: str
    timestamp: datetime
    notes: Optional[str] = None


class PublicTrackingResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    order_number: str
    status: str
    status_label: str
    payment_status: str
    payment_status_label: str
    customer_name_masked: str
    customer_phone_masked: str
    received_at: datetime
    estimated_completion_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    delivered_at: Optional[datetime] = None
    outlet_name: str
    outlet_phone: Optional[str] = None
    outlet_address: Optional[str] = None
    items: List[PublicTrackingItemResponse]
    subtotal: Decimal
    discount_amount: Decimal
    total_amount: Decimal
    paid_amount: Decimal
    remaining_amount: Decimal
    timeline: List[PublicTrackingTimelineResponse]


class TrackingLinkResponse(BaseModel):
    order_id: uuid.UUID
    order_number: str
    tracking_token: str
    tracking_url: str
    whatsapp_share_text: str
