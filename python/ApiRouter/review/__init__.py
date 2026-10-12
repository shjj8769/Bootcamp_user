"""Customer product review endpoints."""
from fastapi import APIRouter

from .manage import router as manage_router
from .search import router as search_router

review_router = APIRouter()
review_router.include_router(search_router, tags=["Review Search"])
review_router.include_router(manage_router, tags=["Review Management"])
