from fastapi import APIRouter

from .search import router as search_router

banner_router = APIRouter()
banner_router.include_router(search_router, tags=["Banner Search"])
