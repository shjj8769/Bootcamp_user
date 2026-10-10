# python/APIRouter/refund/insert.py
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from db import connect

router = APIRouter()


# p_return 테이블 형식에 맞춘 요청 바디
class Refund(BaseModel):
    customer_customer_id: str
    purchase_p_id: int                  # 반품할 구매 항목 (purchase.p_id)
    e_id: Optional[str] = None          # 접수한 대리점 직원
    p_r_reason: str
    p_r_image: Optional[str] = None     # 반품 사진 (Firebase Storage URL)
    p_r_date: Optional[datetime] = None  # 비어 있으면 현재 시각으로 저장


@router.post("/")
def insert_refund(refund: Refund):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = """
                INSERT INTO p_return
                    (customer_customer_id, purchase_p_id, e_id,
                     p_r_reason, p_r_image, p_r_date, is_refunded)
                VALUES (%s, %s, %s, %s, %s, %s, 0)
            """
            curs.execute(sql, (
                refund.customer_customer_id,
                refund.purchase_p_id,
                refund.e_id,
                refund.p_r_reason,
                refund.p_r_image,
                refund.p_r_date or datetime.now(),
            ))
            p_r_id = curs.lastrowid
        conn.commit()
        return {"result": "OK", "p_r_id": p_r_id}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"반품 등록 실패: {e}")
    finally:
        conn.close()
