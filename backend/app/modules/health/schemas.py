from datetime import datetime
from pydantic import BaseModel, Field


class HealthCheckResponse(BaseModel):
    status: str = Field(..., examples=["healthy"])
    app_name: str = Field(..., examples=["LaundryTrack"])
    environment: str = Field(..., examples=["development"])
    version: str = Field(..., examples=["1.0.0"])
    database: str = Field(..., examples=["healthy"])
    timestamp: datetime = Field(...)
