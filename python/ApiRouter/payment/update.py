# python/APIRouter/payment/update.py
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from db import connect

router = APIRouter()


# 수정할 값 (seq는 주소로 받음)
class PaymentUpdate(BaseModel):
    pay_code: str
    pay_date: Optional[datetime] = None  # 비어 있으면 현재 시각으로 저장
    pay_price: int


@router.put("/{seq}")
def update_payment(seq: int, payment: PaymentUpdate):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = """
                UPDATE payment
                SET pay_code = %s, pay_date = %s, pay_price = %s
                WHERE seq = %s
            """
            curs.execute(sql, (
                payment.pay_code,
                payment.pay_date or datetime.now(),
                payment.pay_price,
                seq,
            ))
            if curs.rowcount == 0:
                raise HTTPException(status_code=404, detail="수정할 결제 내역이 없습니다")
        conn.commit()
        return {"result": "OK"}
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"결제 수정 실패: {e}")
    finally:
        conn.close()
