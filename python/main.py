# python/main.py
# 서버 시작점 → python 폴더에서 `uvicorn main:app --reload` 로 실행
# 실행 후 http://127.0.0.1:8000/docs 에서 모든 API 테스트 가능
from fastapi import FastAPI
from ApiRouter.payment import payment_router  # 구조화된 라우터 불러오기
from ApiRouter.refund import refund_router    # 반품 라우터
from ApiRouter.product import product_router  # 제품 라우터

# FastAPI 서버 객체 (uvicorn이 이 app을 실행함)
app = FastAPI()

# 기능별 라우터를 주소(prefix)에 연결
# 예: payment_router 안의 "/" → 실제 주소는 "/payment/"
app.include_router(payment_router, prefix="/payment")  # 결제
app.include_router(refund_router, prefix="/refund")    # 반품
app.include_router(product_router, prefix="/product")  # 제품
