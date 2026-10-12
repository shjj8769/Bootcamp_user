"""Customer inquiry endpoints backed by the existing MySQL inquiry table."""
from fastapi import APIRouter

from .search import router as search_router

inquiry_router = APIRouter()
inquiry_router.include_router(search_router, tags=["Inquiry"])
