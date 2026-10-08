# python/APIRouter/payment/insert.py
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from db import connect

router = APIRouter()


class Payment(BaseModel):
    customer_customer_id: str
    head_office_id: str
    pay_code: str
    pay_date: Optional[datetime] = None  # 비어 있으면 현재 시각으로 저장
    pay_price: int


@router.post("/")
def insert_payment(payment: Payment):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = """
                INSERT INTO payment
                    (customer_customer_id, head_office_id, pay_code, pay_date, pay_price)
                VALUES (%s, %s, %s, %s, %s)
            """
            curs.execute(sql, (
                payment.customer_customer_id,
                payment.head_office_id,
                payment.pay_code,
                payment.pay_date or datetime.now(),
                payment.pay_price,
            ))
            seq = curs.lastrowid
        conn.commit()
        return {"result": "OK", "seq": seq}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"결제 등록 실패: {e}")
    finally:
        conn.close()
