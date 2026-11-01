from typing import Generic, List, Optional, TypeVar
from pydantic import BaseModel, Field

T = TypeVar("T")


class PaginationMeta(BaseModel):
    page: int = Field(ge=1, description="Nomor halaman saat ini")
    page_size: int = Field(ge=1, le=100, description="Jumlah item per halaman")
    total: int = Field(ge=0, description="Total item")
    total_pages: int = Field(ge=0, description="Total halaman")


class PaginatedResponse(BaseModel, Generic[T]):
    success: bool = True
    data: List[T]
    meta: PaginationMeta


class StandardResponse(BaseModel, Generic[T]):
    success: bool = True
    data: T
