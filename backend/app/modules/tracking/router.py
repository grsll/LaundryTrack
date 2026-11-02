from typing import Optional
import uuid
from fastapi import APIRouter, Depends, Header, Path, Request, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app.core.database import get_db
from app.core.dependencies import get_current_tenant, require_roles
from app.modules.tenants.models import Tenant
from app.modules.tracking.schemas import (
    PublicTrackingResponse,
    TrackingLinkResponse,
)
from app.modules.tracking.service import TrackingService
from app.modules.users.models import User

router = APIRouter(tags=["Tracking"])


def resolve_base_url(
    request: Request,
    origin: Optional[str] = None,
    referer: Optional[str] = None,
) -> str:
    """Helper to detect frontend client base URL safely validating against allowed origins."""
    allowed = {o.rstrip("/") for o in settings.CORS_ORIGINS}
    if origin and origin.rstrip("/") in allowed:
        return origin.rstrip("/")
    if referer:
        parts = referer.split("/")
        if len(parts) >= 3:
            candidate = f"{parts[0]}//{parts[2]}".rstrip("/")
            if candidate in allowed:
                return candidate
    return settings.CORS_ORIGINS[0] if settings.CORS_ORIGINS else str(request.base_url).rstrip("/")


def extract_user_context(current_user: User):
    payload = getattr(current_user, "_token_payload", {})
    user_role = payload.get("role", "staff")
    token_outlet_str = payload.get("outlet_id")
    user_outlet_id = None
    if token_outlet_str:
        try:
            user_outlet_id = uuid.UUID(str(token_outlet_str))
        except (ValueError, TypeError):
            user_outlet_id = None
    return user_role, user_outlet_id


@router.get(
    "/tracking/{token}",
    response_model=dict,
    status_code=status.HTTP_200_OK,
    summary="Get public order tracking data by token (No Auth Required)",
)
async def get_public_tracking(
    token: str = Path(..., min_length=20, max_length=128, description="Order public tracking token"),
    db: AsyncSession = Depends(get_db),
):
    """
    Public guest tracking portal.
    Exposes order laundry status, timeline, and masked customer information.
    Zero internal IDs or sensitive PII leaked.
    """
    data = await TrackingService.get_public_tracking_by_token(db, token)
    return {
        "success": True,
        "data": data,
    }


@router.get(
    "/orders/{id}/tracking-link",
    response_model=dict,
    status_code=status.HTTP_200_OK,
    summary="Get order tracking link and WhatsApp message (Staff Auth)",
)
async def get_order_tracking_link(
    id: uuid.UUID,
    request: Request,
    origin: Optional[str] = Header(None),
    referer: Optional[str] = Header(None),
    current_user: User = Depends(
        require_roles("owner", "admin", "cashier", "operator")
    ),
    current_tenant: Tenant = Depends(get_current_tenant),
    db: AsyncSession = Depends(get_db),
):
    base_url = resolve_base_url(request, origin, referer)
    user_role, user_outlet_id = extract_user_context(current_user)
    data = await TrackingService.get_tracking_link(
        db,
        current_tenant.id,
        user_role,
        user_outlet_id,
        id,
        base_url,
    )
    return {
        "success": True,
        "data": data,
    }


@router.post(
    "/orders/{id}/tracking-link/regenerate",
    response_model=dict,
    status_code=status.HTTP_200_OK,
    summary="Regenerate tracking token to invalidate leaked old link (Staff Auth)",
)
async def regenerate_order_tracking_link(
    id: uuid.UUID,
    request: Request,
    origin: Optional[str] = Header(None),
    referer: Optional[str] = Header(None),
    current_user: User = Depends(require_roles("owner", "admin", "cashier")),
    current_tenant: Tenant = Depends(get_current_tenant),
    db: AsyncSession = Depends(get_db),
):
    base_url = resolve_base_url(request, origin, referer)
    user_role, user_outlet_id = extract_user_context(current_user)
    data = await TrackingService.regenerate_tracking_token(
        db,
        current_tenant.id,
        user_role,
        user_outlet_id,
        id,
        base_url,
    )
    return {
        "success": True,
        "data": data,
    }
