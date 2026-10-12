"""Customer-facing order-state notification endpoints."""
from fastapi import APIRouter

from .search import router as search_router

notification_router = APIRouter()
notification_router.include_router(search_router, tags=["Notification"])
