# python/APIRouter/purchase/insert.py
# 구매 항목 등록 API → POST /purchase/
# 고객이 선택한 상품 1개(SKU)를 결제(payment.seq)에 묶어서 저장 (purchase 테이블)
from datetime import datetime

from fastapi import APIRouter, HTTPException

from db import connect  # 공용 DB 연결 함수 (python/db.py)
from .models import Purchase

router = APIRouter()


@router.post("/")
def insert_purchase(purchase: Purchase):
    conn = connect()  # DB 연결
    try:
        with conn.cursor() as curs:
            # %s 자리에 값이 순서대로 들어감 (SQL 인젝션 방지)
            # 컬럼 순서는 DB 순서와 동일 (p_id, p_seq, p_count, p_date, p_price, email, SKU, store_seq)
            sql = """
                INSERT INTO purchase
                    (p_id, p_seq, p_count, p_date, p_price, email, SKU, store_seq)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """
            curs.execute(sql, (
                purchase.p_id,  # None이면 AUTO_INCREMENT 컬럼에 NULL → DB가 다음 번호 자동 부여
                purchase.p_seq,
                purchase.p_count,
                purchase.p_date or datetime.now(),  # 날짜가 없으면 지금 시각
                purchase.p_price,
                purchase.email,
                purchase.SKU,
                purchase.store_seq,
            ))
            p_id = curs.lastrowid  # 방금 생성(또는 입력)된 구매번호
        conn.commit()  # 실제 DB에 저장 확정
        return {"result": "OK", "p_id": p_id}
    except Exception as e:
        conn.rollback()  # 에러 시 저장하지 않고 되돌림
        raise HTTPException(status_code=500, detail=f"구매 등록 실패: {e}")
    finally:
        conn.close()  # DB 연결 종료
