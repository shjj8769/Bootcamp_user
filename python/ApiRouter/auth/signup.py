# python/ApiRouter/auth/signup.py
import logging

from fastapi import APIRouter, HTTPException
from google.api_core.exceptions import AlreadyExists
from pydantic import BaseModel, ConfigDict, EmailStr, Field, SecretStr, field_validator

from .firebase import connect, customer_document_id, find_customer

router = APIRouter()
logger = logging.getLogger(__name__)


# 회원가입 요청 데이터 (비밀번호는 입력한 값으로 저장합니다)
class Customer(BaseModel):
    # 정의하지 않은 필드는 거부하고 검증 오류에 입력값이 노출되지 않도록 설정합니다.
    model_config = ConfigDict(extra="forbid", hide_input_in_errors=True)

    email: EmailStr = Field(max_length=254)
    # SecretStr은 객체 출력 시 값을 가립니다. 저장 시 암호화하는 기능은 아닙니다.
    password: SecretStr = Field(min_length=6, max_length=128)
    tel: str = Field(min_length=1, max_length=30)
    c_name: str = Field(min_length=1, max_length=100)
    c_gender: str = Field(min_length=1, max_length=20)
    c_address: str = Field(min_length=1, max_length=500)
    c_path: str = Field(default="", max_length=2048)
    c_size: str = Field(min_length=1, max_length=20)

    @field_validator("email", "tel", "c_name", "c_gender", "c_address", "c_size", mode="before")
    @classmethod
    def trim_text(cls, value):
        # 입력한 문자열 앞뒤의 공백을 제거합니다.
        if isinstance(value, str):
            return value.strip()
        return value


# POST /auth/signup: 입력값을 검증하고 Firestore에 신규 회원 문서를 생성합니다.
@router.post("/signup", status_code=201)
def signup_customer(customer: Customer):
    try:
        db = connect()
        # 이메일을 정규화하고 동일한 문서 ID를 사용해 동시 요청의 중복도 막습니다.
        email = str(customer.email).casefold()
        if find_customer(db, email) is not None:
            raise HTTPException(status_code=409, detail="이미 가입된 이메일입니다")
        uid = customer_document_id(email)
        # SecretStr의 마스킹 문자열이 저장되지 않도록 비밀번호를 따로 꺼냅니다.
        profile = customer.model_dump(exclude={"password"}, mode="json")
        profile["email"] = email
        profile["password"] = customer.password.get_secret_value()
        # create는 기존 문서를 덮어쓰지 않습니다. _erd 문서는 수정하지 않습니다.
        db.collection("customer").document(uid).create(profile)
        return {"result": "OK", "uid": uid}
    # 같은 이메일 문서가 이미 있으면 중복 가입으로 응답합니다.
    except AlreadyExists:
        raise HTTPException(status_code=409, detail="이미 가입된 이메일입니다")
    except HTTPException:
        raise
    except Exception:
        logger.exception("회원가입 처리 실패")
        raise HTTPException(status_code=500, detail="회원가입 처리에 실패했습니다")
