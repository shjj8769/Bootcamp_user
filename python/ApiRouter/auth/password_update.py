# 현재 비밀번호를 확인한 후 Firestore 회원 문서의 비밀번호를 변경합니다.
import logging

from fastapi import APIRouter, HTTPException
from firebase_admin import firestore
from pydantic import BaseModel, ConfigDict, EmailStr, Field, SecretStr, field_validator

from .firebase import connect, find_customer
from .login import matches_password

router = APIRouter()
logger = logging.getLogger(__name__)


# 변경 요청에는 이메일, 현재 비밀번호, 새 비밀번호가 필요합니다.
class PasswordUpdateCustomer(BaseModel):
    model_config = ConfigDict(extra="forbid", hide_input_in_errors=True)

    email: EmailStr = Field(max_length=254)
    current_password: SecretStr = Field(min_length=6, max_length=128)
    new_password: SecretStr = Field(min_length=6, max_length=128)

    @field_validator("email", mode="before")
    @classmethod
    def trim_email(cls, value):
        return value.strip() if isinstance(value, str) else value


def update_password_transaction(transaction, document_ref, customer):
    # 읽은 문서가 다른 요청으로 변경되면 트랜잭션이 재시도되어 비밀번호를 다시 확인합니다.
    document = document_ref.get(transaction=transaction)
    profile = document.to_dict() if document.exists else None
    if not profile or not matches_password(
        customer.current_password.get_secret_value(), profile
    ):
        raise HTTPException(status_code=401, detail="이메일 또는 현재 비밀번호가 올바르지 않습니다")

    changes = {"password": customer.new_password.get_secret_value()}
    # 비밀번호 관련 필드만 변경하고 이름·주소 등 기존 회원 정보는 유지합니다.
    transaction.update(document_ref, changes)


# PATCH /auth/password_update: 현재 비밀번호 확인 → 새 비밀번호 저장
@router.patch("/password_update")
def update_customer_password(customer: PasswordUpdateCustomer):
    try:
        if customer.current_password.get_secret_value() == customer.new_password.get_secret_value():
            raise HTTPException(status_code=400, detail="새 비밀번호는 현재 비밀번호와 달라야 합니다")

        db = connect()
        email = str(customer.email).casefold()
        document = find_customer(db, email)
        if document is None:
            raise HTTPException(status_code=401, detail="이메일 또는 현재 비밀번호가 올바르지 않습니다")
        uid = document.id
        document_ref = document.reference
        # 비밀번호 확인과 저장이 함께 성공해야 트랜잭션이 커밋됩니다.
        firestore.transactional(update_password_transaction)(
            db.transaction(), document_ref, customer
        )
        return {"result": "OK", "uid": uid}
    # 비밀번호 불일치 등 명시적인 요청 오류의 상태 코드를 유지합니다.
    except HTTPException:
        raise
    except Exception:
        logger.exception("비밀번호 변경 처리 실패")
        raise HTTPException(status_code=500, detail="비밀번호 변경 처리에 실패했습니다")
