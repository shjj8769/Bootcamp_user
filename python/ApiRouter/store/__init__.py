from fastapi import APIRouter

from .search import router as search_router

store_router = APIRouter()
store_router.include_router(search_router, tags=["Store Search"])
