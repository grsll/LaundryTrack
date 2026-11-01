from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import Depends
from app.core.database import get_db

# Re-export database dependency
DatabaseSession = Depends(get_db)
