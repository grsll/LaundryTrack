from typing import Optional
import uuid
from pydantic import BaseModel, EmailStr, Field


class RegisterBusinessRequest(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=150, examples=["Budi Santoso"])
    email: EmailStr = Field(..., examples=["budi@laundrybersih.com"])
    phone: str = Field(..., min_length=8, max_length=30, examples=["081234567890"])
    password: str = Field(..., min_length=8, max_length=128, examples=["Rahasia123!"])
    business_name: str = Field(..., min_length=2, max_length=150, examples=["Berkah Laundry Clean"])
    outlet_name: Optional[str] = Field("Outlet Utama", max_length=150, examples=["Outlet Utama"])
    outlet_address: Optional[str] = Field(None, examples=["Jl. Melati No. 12, Jakarta"])
    outlet_phone: Optional[str] = Field(None, max_length=30, examples=["081234567890"])


class LoginRequest(BaseModel):
    email_or_phone: str = Field(..., min_length=3, max_length=255, examples=["budi@laundrybersih.com"])
    password: str = Field(..., min_length=1, max_length=128, examples=["Rahasia123!"])


class RefreshTokenRequest(BaseModel):
    refresh_token: str = Field(..., min_length=20)


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class UserSummary(BaseModel):
    id: uuid.UUID
    full_name: str
    email: str
    phone: str
    user_type: str
    role: str


class TenantSummary(BaseModel):
    id: uuid.UUID
    name: str
    slug: str


class OutletSummary(BaseModel):
    id: uuid.UUID
    name: str


class SubscriptionSummary(BaseModel):
    plan: str
    status: str


class AuthData(BaseModel):
    user: UserSummary
    tenant: TenantSummary
    outlet: OutletSummary
    subscription: SubscriptionSummary
    tokens: TokenResponse


class AuthResponse(BaseModel):
    success: bool = True
    data: AuthData


class UserProfileData(BaseModel):
    user: UserSummary
    tenant: TenantSummary
    outlet: Optional[OutletSummary] = None
    subscription: Optional[SubscriptionSummary] = None


class UserProfileResponse(BaseModel):
    success: bool = True
    data: UserProfileData


class SimpleMessageResponse(BaseModel):
    success: bool = True
    message: str
