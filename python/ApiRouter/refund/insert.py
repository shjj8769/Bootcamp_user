# python/APIRouter/refund/insert.py
# 반품 접수 API → POST /refund/
# 고객이 대리점에 방문해 반품을 요청할 때 사용 (p_return 테이블)
from datetime import datetime

from fastapi import APIRouter, HTTPException

from db import connect  # 공용 DB 연결 함수 (python/db.py)
from .models import Refund

router = APIRouter()


@router.post("/")
def insert_refund(refund: Refund):
    conn = connect()  # DB 연결
    try:
        with conn.cursor() as curs:
            # 마지막 값 0 = is_refunded(환불 전) 고정
            sql = """
                INSERT INTO p_return
                    (email, p_r_id, e_id,
                    p_r_reason, p_r_image, p_r_date, is_refunded)
                VALUES (%s, %s, %s, %s, %s, %s, 0)
            """
            curs.execute(sql, (
                refund.email,
                refund.p_r_id,
                refund.e_id,
                refund.p_r_reason,
                refund.p_r_image,
                refund.p_r_date or datetime.now(),  # 날짜가 없으면 지금 시각
            ))
        conn.commit()  # 실제 DB에 저장 확정
        return {"result": "OK", "p_r_id": refund.p_r_id}
    except Exception as e:
        conn.rollback()  # 에러 시 저장하지 않고 되돌림
        raise HTTPException(status_code=500, detail=f"반품 등록 실패: {e}")
    finally:
        conn.close()  # DB 연결 종료
