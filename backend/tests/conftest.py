import sys
from pathlib import Path
import pytest
from fastapi.testclient import TestClient

# Ensure app package is importable
backend_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(backend_dir))

from app.main import app


@pytest.fixture
def client():
    """Provides a TestClient for FastAPI."""
    with TestClient(app) as test_client:
        yield test_client
