# python/main.py
# 서버 시작점 → `python3 python/main.py` 로 실행
# API 문서: http://192.168.20.68:8000/docs
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from ApiRouter.auth import auth_router
from ApiRouter.log import log_router
from ApiRouter.payment import payment_router  # 구조화된 라우터 불러오기
from ApiRouter.refund import refund_router    # 반품 라우터
from ApiRouter.purchase import purchase_router  # 구매 라우터
from ApiRouter.pickup import pickup_router    # 수령 라우터
from ApiRouter.product import product_router  # 제품 라우터
from ApiRouter.banner import banner_router  # 배너 이미지 조회 라우터
from ApiRouter.review import review_router  # 상품 리뷰 조회 라우터
from ApiRouter.store import store_router  # 매장 조회 라우터
from ApiRouter.inquiry import inquiry_router  # 고객 문의 라우터
from ApiRouter.notification import notification_router  # 주문 상태 알림 라우터

# FastAPI 서버 객체 (uvicorn이 이 app을 실행함)
app = FastAPI(title="Shoes API", version="0.1.0")

# Flutter web is served from this Mac's LAN address. CORS controls browser
# origins; uvicorn below separately controls the network interface to bind.
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://192.168.20.68:5000",
        "http://192.168.20.68:8081",
    ],
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization"],
)


@app.get("/health", tags=["Health"])
def health() -> dict[str, str]:
    """Return process health without accessing external services."""
    return {"status": "ok", "service": "shoes"}

# 기능별 라우터를 주소(prefix)에 연결
# 예: payment_router 안의 "/" → 실제 주소는 "/payment/"
app.include_router(payment_router, prefix="/payment")  # 결제
app.include_router(refund_router, prefix="/refund")    # 반품
app.include_router(purchase_router, prefix="/purchase")  # 구매
app.include_router(pickup_router, prefix="/pickup")    # 수령
app.include_router(product_router, prefix="/product")  # 제품
app.include_router(banner_router, prefix="/banner")  # 배너 조회 전용
app.include_router(review_router, prefix="/review")  # 상품 리뷰 조회
app.include_router(store_router, prefix="/store")  # 매장 조회
app.include_router(inquiry_router, prefix="/inquiry")  # 고객 문의
app.include_router(notification_router, prefix="/notification")  # 주문 상태 알림
# 회원가입·로그인·비밀번호 변경 API
app.include_router(auth_router, prefix="/auth")

# 로그 API 주소는 기존 /auth/log/... 형식을 유지합니다.
app.include_router(log_router, prefix="/auth", tags=["Auth Log"])


if __name__ == "__main__":
    import uvicorn

    # Bind only to the requested LAN address, not 0.0.0.0 or localhost.
    uvicorn.run(app, host="192.168.20.68", port=8000)
