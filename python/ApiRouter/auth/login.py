# Firestore 회원 정보로 로그인 자격 증명을 확인합니다. 세션이나 토큰은 발급하지 않습니다.
import hmac
import logging

from fastapi import APIRouter, HTTPException
from .firebase import connect, find_customer
from .models import LoginCustomer

router = APIRouter()
logger = logging.getLogger(__name__)


def matches_password(password: str, profile: dict) -> bool:
    # 저장된 원문 비밀번호와 입력값을 비교합니다.
    stored_password = profile.get("password")
    return isinstance(stored_password, str) and hmac.compare_digest(
        password.encode("utf-8"), stored_password.encode("utf-8")
    )


# POST /auth/login: 회원 조회 → 비밀번호 확인 → 회원 문서 ID 반환
@router.post("/login")
def login_customer(customer: LoginCustomer):
    try:
        db = connect()
        # 회원가입과 동일하게 이메일을 정규화합니다.
        email = str(customer.email).casefold()
        document = find_customer(db, email)
        profile = document.to_dict() if document is not None else None
        # 없는 계정과 비밀번호 불일치에 동일한 오류를 반환합니다.
        if not profile or not matches_password(
            customer.password.get_secret_value(), profile
        ):
            raise HTTPException(status_code=401, detail="이메일 또는 비밀번호가 올바르지 않습니다")

        # 비밀번호는 응답에 포함하지 않습니다.
        return {"result": "OK", "uid": document.id}
    # 의도적으로 만든 401 응답을 일반 서버 오류인 500으로 바꾸지 않습니다.
    except HTTPException:
        raise
    except Exception:
        logger.exception("로그인 처리 실패")
        raise HTTPException(status_code=500, detail="로그인 처리에 실패했습니다")
