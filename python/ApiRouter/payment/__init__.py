# python/APIRouter/payment/__init__.py
from fastapi import APIRouter
from .insert import router as insert_router
from .search import router as search_router
from .update import router as update_router
from .delete import router as delete_router

# payment 전체를 아우르는 메인 라우터 생성
payment_router = APIRouter()

# 각각의 하위 라우터들을 등록 (필요시 tags나 prefix 분리 가능)
payment_router.include_router(insert_router, tags=["Payment Insert"])
payment_router.include_router(search_router, tags=["Payment Search"])
payment_router.include_router(update_router, tags=["Payment Update"])
payment_router.include_router(delete_router, tags=["Payment Delete"])
