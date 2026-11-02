from typing import Optional
import uuid
from fastapi import APIRouter, Depends, Header, Query, Request, Response, status
from fastapi.responses import HTMLResponse
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app.core.database import get_db
from app.core.dependencies import get_current_tenant, require_roles
from app.modules.receipts.schemas import (
    ReceiptReprintRequest,
    ReceiptReprintResponse,
    ReceiptResponse,
)
from app.modules.receipts.service import ReceiptService
from app.modules.tenants.models import Tenant
from app.modules.users.models import User

router = APIRouter(tags=["Receipts"])


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
    fallback_name = current_user.full_name or current_user.email
    return user_role, user_outlet_id, fallback_name


@router.get(
    "/orders/{id}/receipt",
    response_model=dict,
    status_code=status.HTTP_200_OK,
    summary="Get complete digital receipt details (Staff Auth)",
)
async def get_order_receipt(
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
    user_role, user_outlet_id, fallback_name = extract_user_context(current_user)
    data = await ReceiptService.get_receipt_data(
        db,
        current_tenant.id,
        user_role,
        user_outlet_id,
        fallback_name,
        id,
        base_url,
    )
    return {
        "success": True,
        "data": data,
    }


@router.get(
    "/orders/{id}/receipt/pdf",
    status_code=status.HTTP_200_OK,
    summary="Download or stream PDF receipt (Staff Auth)",
)
async def get_order_receipt_pdf(
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
    user_role, user_outlet_id, fallback_name = extract_user_context(current_user)
    pdf_bytes = await ReceiptService.generate_receipt_pdf(
        db,
        current_tenant.id,
        user_role,
        user_outlet_id,
        fallback_name,
        id,
        base_url,
    )
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'inline; filename="receipt_{id}.pdf"',
            "Content-Type": "application/pdf",
        },
    )


@router.get(
    "/orders/{id}/receipt/thermal",
    response_class=HTMLResponse,
    status_code=status.HTTP_200_OK,
    summary="Render 58mm/80mm thermal receipt HTML for browser printing (Staff Auth)",
)
async def get_order_receipt_thermal(
    id: uuid.UUID,
    request: Request,
    width: int = Query(
        default=58, ge=40, le=120, description="Paper width in mm (default 58)"
    ),
    origin: Optional[str] = Header(None),
    referer: Optional[str] = Header(None),
    current_user: User = Depends(
        require_roles("owner", "admin", "cashier", "operator")
    ),
    current_tenant: Tenant = Depends(get_current_tenant),
    db: AsyncSession = Depends(get_db),
):
    base_url = resolve_base_url(request, origin, referer)
    user_role, user_outlet_id, fallback_name = extract_user_context(current_user)
    html_content = await ReceiptService.generate_thermal_html(
        db,
        current_tenant.id,
        user_role,
        user_outlet_id,
        fallback_name,
        id,
        width,
        base_url,
    )
    return HTMLResponse(content=html_content)


@router.post(
    "/orders/{id}/receipt/reprint",
    response_model=dict,
    status_code=status.HTTP_200_OK,
    summary="Record receipt reprint audit log and increment reprint count (Staff Auth)",
)
async def record_order_receipt_reprint(
    id: uuid.UUID,
    payload: ReceiptReprintRequest,
    current_user: User = Depends(require_roles("owner", "admin", "cashier")),
    current_tenant: Tenant = Depends(get_current_tenant),
    db: AsyncSession = Depends(get_db),
):
    user_role, user_outlet_id, _ = extract_user_context(current_user)
    data = await ReceiptService.record_reprint(
        db,
        current_tenant.id,
        user_role,
        user_outlet_id,
        current_user.id,
        id,
        print_type=payload.print_type,
        notes=payload.notes,
    )
    return {
        "success": True,
        "data": data,
    }
