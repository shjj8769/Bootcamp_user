# Firestore의 회원가입·로그인·비밀번호 변경 기록을 처리합니다.
import logging

from fastapi import APIRouter, HTTPException, Request
from firebase_admin import firestore
from google.cloud.firestore_v1.base_query import FieldFilter
from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from .firebase import connect, find_customer

router = APIRouter()
logger = logging.getLogger(__name__)


class CustomerLog(BaseModel):
    model_config = ConfigDict(extra="forbid", hide_input_in_errors=True)

    email: EmailStr = Field(max_length=254)
    e_id: str = Field(min_length=1, max_length=100)

    @field_validator("email", "e_id", mode="before")
    @classmethod
    def trim_text(cls, value):
        return value.strip() if isinstance(value, str) else value


class ConnectLog(CustomerLog):
    # IP에서 위치를 추측하지 않고 요청에 전달된 위치를 사용합니다.
    c_location: str = Field(min_length=1, max_length=500)

    @field_validator("c_location", mode="before")
    @classmethod
    def trim_location(cls, value):
        return value.strip() if isinstance(value, str) else value


def check_log_references(db, email, e_id):
    # Firestore는 외래키를 강제하지 않으므로 기록 전에 참조 대상을 확인합니다.
    if find_customer(db, email) is None:
        raise HTTPException(status_code=404, detail="회원 정보를 찾을 수 없습니다")
    employees = db.collection("main_server").where(
        filter=FieldFilter("e_id", "==", e_id)
    ).limit(1).stream()
    if next(iter(employees), None) is None:
        raise HTTPException(status_code=404, detail="직원 정보를 찾을 수 없습니다")


def save_customer_log(db, collection_name, customer, client_ip=None):
    if collection_name not in {"register", "connect", "change"}:
        raise ValueError("지원하지 않는 기록 종류입니다")
    email = str(customer.email).casefold()
    check_log_references(db, email, customer.e_id)
    # 날짜는 클라이언트 입력이 아닌 Firestore 서버 시각으로 저장합니다.
    date_field = "r_date" if collection_name == "register" else "c_date"
    record = {"email": email, "e_id": customer.e_id, date_field: firestore.SERVER_TIMESTAMP}
    if collection_name == "connect":
        record["c_location"] = customer.c_location
        record["c_ip"] = client_ip
    document = db.collection(collection_name).document()
    # 자동 생성 ID를 사용해 반복 로그인도 각각 별도 기록으로 남깁니다.
    document.create(record)
    return {"result": "OK", "log_id": document.id}


def record_customer_log(collection_name, customer, client_ip=None):
    try:
        db = connect()
        return save_customer_log(db, collection_name, customer, client_ip)
    except HTTPException:
        raise
    except Exception:
        logger.exception("회원 활동 기록 저장 실패")
        raise HTTPException(status_code=500, detail="회원 활동 기록 저장에 실패했습니다")


# 회원가입 API와 별도로 호출하여 register 컬렉션에 가입 기록을 남깁니다.
@router.post("/log/register", status_code=201)
def register_log(customer: CustomerLog):
    return record_customer_log("register", customer)


# 로그인 위치는 요청에서 받고 IP는 서버가 받은 요청 정보를 사용합니다.
@router.post("/log/connect", status_code=201)
def connect_log(customer: ConnectLog, request: Request):
    if request.client is None:
        raise HTTPException(status_code=400, detail="접속 IP를 확인할 수 없습니다")
    return record_customer_log("connect", customer, request.client.host)


# 비밀번호 변경 API와 별도로 호출하여 change 컬렉션에 변경 기록을 남깁니다.
@router.post("/log/change", status_code=201)
def change_log(customer: CustomerLog):
    return record_customer_log("change", customer)
