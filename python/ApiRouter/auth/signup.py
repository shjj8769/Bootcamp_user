# python/ApiRouter/auth/signup.py
import logging

from fastapi import APIRouter, HTTPException
from google.api_core.exceptions import AlreadyExists
from pymysql.err import IntegrityError

from db import connect as sql_connect

from .firebase import connect, customer_document_id, find_customer
from .models import Customer

router = APIRouter()
logger = logging.getLogger(__name__)


# POST /auth/signup: SQL customer와 Firestore에 신규 회원 정보를 저장합니다.
@router.post("/signup", status_code=201)
def signup_customer(customer: Customer):
    conn = None
    document_ref = None
    firestore_created = False
    committed = False
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
        # 누적 구매 금액은 가입 요청에서 받지 않고 항상 0으로 시작합니다.
        conn = sql_connect()
        with conn.cursor() as curs:
            curs.execute("SELECT email FROM customer WHERE email = %s LIMIT 1", (email,))
            if curs.fetchone() is not None:
                raise HTTPException(status_code=409, detail="이미 가입된 이메일입니다")
            sql = """
                INSERT INTO customer
                    (email, password, tel, c_name, c_gender, c_address, c_totalprice)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
            """
            curs.execute(sql, (
                email, profile["password"], customer.tel, customer.c_name,
                customer.c_gender, customer.c_address, 0,
            ))
        # create는 기존 문서를 덮어쓰지 않습니다. _erd 문서는 수정하지 않습니다.
        document_ref = db.collection("customer").document(uid)
        document_ref.create(profile)
        firestore_created = True
        conn.commit()
        committed = True
        return {"result": "OK", "uid": uid}
    # 같은 이메일 문서가 이미 있으면 중복 가입으로 응답합니다.
    except AlreadyExists:
        raise HTTPException(status_code=409, detail="이미 가입된 이메일입니다")
    except IntegrityError as exc:
        if exc.args and exc.args[0] == 1062:
            raise HTTPException(status_code=409, detail="이미 등록된 회원 정보입니다")
        logger.error("회원가입 SQL 제약조건 오류")
        raise HTTPException(status_code=500, detail="회원가입 처리에 실패했습니다")
    except HTTPException:
        raise
    except Exception:
        logger.exception("회원가입 처리 실패")
        raise HTTPException(status_code=500, detail="회원가입 처리에 실패했습니다")
    finally:
        # SQL과 Firestore는 분산 트랜잭션이 아니므로 실패 시 정리를 시도합니다.
        if conn is not None:
            if not committed:
                try:
                    conn.rollback()
                except Exception:
                    logger.error("회원가입 SQL 롤백 실패")
            try:
                conn.close()
            except Exception:
                logger.error("회원가입 SQL 연결 종료 실패")
        if firestore_created and not committed:
            try:
                document_ref.delete()
            except Exception:
                logger.error("회원가입 Firestore 문서 정리 필요: uid=%s", uid)
