# python/main.py
from fastapi import FastAPI
from APIRouter.payment import payment_router  # 구조화된 라우터 불러오기
from ApiRouter.refund import refund_router 

app = FastAPI()

# /payment 주소로 들어오는 모든 요청을 연결
app.include_router(payment_router, prefix="/payment")
app.include_router(refund_router, prefix="/refund")
