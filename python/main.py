# python/main.py
from fastapi import FastAPI
from ApiRouter.payment import payment_router  # 구조화된 라우터 불러오기

app = FastAPI()

# /payment 주소로 들어오는 모든 요청을 연결
app.include_router(payment_router, prefix="/payment")
