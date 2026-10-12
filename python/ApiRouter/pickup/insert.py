# python/APIRouter/pickup/insert.py
# 수령 처리 API → POST /pickup/
# 고객이 대리점에 방문해 구매한 제품을 찾아갈 때, 대리점 직원이 확인 후 기록 (pick_up 테이블)
from datetime import datetime

from fastapi import APIRouter, HTTPException

from db import connect  # 공용 DB 연결 함수 (python/db.py)
from .models import Pickup

router = APIRouter()


@router.post("/")
def insert_pickup(pickup: Pickup):
    conn = connect()  # DB 연결
    try:
        with conn.cursor() as curs:
            # %s 자리에 값이 순서대로 들어감 (SQL 인젝션 방지)
            sql = """
                INSERT INTO pick_up
                    (e_id, email, SKU, store_seq, p_date)
                VALUES (%s, %s, %s, %s, %s)
            """
            curs.execute(sql, (
                pickup.e_id,
                pickup.email,
                pickup.SKU,
                pickup.store_seq,
                pickup.p_date or datetime.now(),  # 날짜가 없으면 지금 시각
            ))
            p_id = curs.lastrowid  # 방금 생성된 수령id
        conn.commit()  # 실제 DB에 저장 확정
        return {"result": "OK", "p_id": p_id}
    except Exception as e:
        conn.rollback()  # 에러 시 저장하지 않고 되돌림
        raise HTTPException(status_code=500, detail=f"수령 등록 실패: {e}")
    finally:
        conn.close()  # DB 연결 종료
