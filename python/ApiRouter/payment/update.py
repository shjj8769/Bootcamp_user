# python/APIRouter/payment/update.py
# 결제 수정 API → PUT /payment/{seq}
from datetime import datetime

from fastapi import APIRouter, HTTPException

from db import connect  # 공용 DB 연결 함수 (python/db.py)
from .models import PaymentUpdate

router = APIRouter()


@router.put("/{seq}")
def update_payment(seq: int, payment: PaymentUpdate):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = """
                UPDATE payment
                SET pay_id = %s, pay_date = %s, pay_price = %s
                WHERE seq = %s
            """
            curs.execute(sql, (
                payment.pay_id,
                payment.pay_date or datetime.now(),  # 날짜가 없으면 지금 시각
                payment.pay_price,
                seq,
            ))
            # rowcount: SQL로 바뀐 행 수 → 0이면 해당 결제번호가 없음
            if curs.rowcount == 0:
                raise HTTPException(status_code=404, detail="수정할 결제 내역이 없습니다")
        conn.commit()  # 실제 DB에 저장 확정
        return {"result": "OK"}
    except HTTPException:
        raise  # 위에서 만든 404는 500으로 바뀌지 않게 그대로 전달
    except Exception as e:
        conn.rollback()  # 에러 시 변경 내용 되돌림
        raise HTTPException(status_code=500, detail=f"결제 수정 실패: {e}")
    finally:
        conn.close()  # DB 연결 종료
