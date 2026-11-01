import pytest
from datetime import datetime
from unittest.mock import AsyncMock, patch, MagicMock
from app.core.exceptions import EntityNotFoundException, CrossTenantAccessException
from app.core.database import check_db_health


def test_root_endpoint_metadata_and_headers(client):
    """Verify that root endpoint responds with application metadata and security headers."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["app"] == "LaundryTrack"
    assert data["status"] == "online"
    assert data["version"] == "1.0.0"
    assert "health" in data

    # Verify Security Headers
    assert response.headers.get("X-Content-Type-Options") == "nosniff"
    assert response.headers.get("X-Frame-Options") == "DENY"
    assert response.headers.get("Referrer-Policy") == "strict-origin-when-cross-origin"


def test_health_endpoint_unit_success(client):
    """Verify health endpoint structure in isolated unit environment."""
    with patch("app.modules.health.router.check_db_health", new_callable=AsyncMock) as mock_db:
        mock_db.return_value = True
        response = client.get("/api/v1/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["database"] == "healthy"
        assert data["app_name"] == "LaundryTrack"
        assert data["environment"] == "development"
        assert data["version"] == "1.0.0"
        # Validate timestamp parseability
        assert datetime.fromisoformat(data["timestamp"])


def test_health_endpoint_live_vps_connection(client):
    """Integration test: validates real live connection to VPS PostgreSQL database."""
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["database"] == "healthy"


def test_health_endpoint_database_degraded(client):
    """Verify that health endpoint properly reports degraded status when DB is unreachable."""
    with patch("app.modules.health.router.check_db_health", new_callable=AsyncMock) as mock_db:
        mock_db.return_value = False
        response = client.get("/api/v1/health")
        assert response.status_code == 503
        data = response.json()
        assert data["status"] == "degraded"
        assert data["database"] == "unreachable"


def test_app_exception_standard_format():
    """Verify that AppException subclasses produce standard JSON error structure."""
    exc = EntityNotFoundException("Customer", "cust-123")
    assert exc.status_code == 404
    detail = exc.detail
    assert detail["success"] is False
    assert detail["error"]["code"] == "ENTITY_NOT_FOUND"
    assert "Customer with identifier 'cust-123' was not found." in detail["error"]["message"]

    cross_exc = CrossTenantAccessException()
    assert cross_exc.status_code == 403
    assert cross_exc.detail["error"]["code"] == "FORBIDDEN_TENANT_ACCESS"


@pytest.mark.asyncio
async def test_check_db_health_success_probe():
    """Verify check_db_health returns True when SELECT 1 returns 1."""
    mock_session = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalar.return_value = 1
    mock_session.execute.return_value = mock_result

    with patch("app.core.database.AsyncSessionLocal") as mock_session_factory:
        mock_session_factory.return_value.__aenter__.return_value = mock_session
        healthy = await check_db_health()
        assert healthy is True


@pytest.mark.asyncio
async def test_check_db_health_exception_handled():
    """Verify check_db_health catches database exceptions and safely returns False."""
    mock_session = AsyncMock()
    mock_session.execute.side_effect = TimeoutError("Connection timed out")

    with patch("app.core.database.AsyncSessionLocal") as mock_session_factory:
        mock_session_factory.return_value.__aenter__.return_value = mock_session
        healthy = await check_db_health()
        assert healthy is False
