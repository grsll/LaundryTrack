from datetime import datetime, timezone
from fastapi import APIRouter, status
from fastapi.responses import JSONResponse
from app.core.config import settings
from app.core.database import check_db_health
from app.modules.health.schemas import HealthCheckResponse

router = APIRouter(tags=["Health"])


@router.get(
    "/health",
    response_model=HealthCheckResponse,
    status_code=status.HTTP_200_OK,
    summary="Application & Database Health Probe",
    description="Probes application runtime and active PostgreSQL connection on VPS.",
)
async def get_health_status():
    db_healthy = await check_db_health()
    current_time = datetime.now(timezone.utc)

    response_payload = {
        "status": "healthy" if db_healthy else "degraded",
        "app_name": settings.APP_NAME,
        "environment": settings.ENVIRONMENT,
        "version": settings.APP_VERSION,
        "database": "healthy" if db_healthy else "unreachable",
        "timestamp": current_time.isoformat(),
    }

    status_code = status.HTTP_200_OK if db_healthy else status.HTTP_503_SERVICE_UNAVAILABLE
    return JSONResponse(status_code=status_code, content=response_payload)
