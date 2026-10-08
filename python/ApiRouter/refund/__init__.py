# python/APIRouter/refund/__init__.py
from fastapi import APIRouter
from .insert import router as insert_router
from .search import router as search_router
from .update import router as update_router

# refund 전체를 아우르는 메인 라우터 생성
refund_router = APIRouter()

# 각각의 하위 라우터들을 등록 (반품 기록은 이력이라 delete는 두지 않음)
refund_router.include_router(insert_router, tags=["Refund Insert"])
refund_router.include_router(search_router, tags=["Refund Search"])
refund_router.include_router(update_router, tags=["Refund Update"])
