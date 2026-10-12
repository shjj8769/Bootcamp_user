# python/APIRouter/purchase/update.py
# 구매 항목 수정 API → PUT /purchase/{p_id}
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from db import connect  # 공용 DB 연결 함수 (python/db.py)

router = APIRouter()


# 수정할 값 (p_id는 주소로 받음)
# 결제번호/고객/제품은 구매의 주체라 수정 대상에서 제외 → 바꾸려면 삭제 후 다시 등록
class PurchaseUpdate(BaseModel):
    p_count: int                         # 구매수량
    p_date: Optional[datetime] = None    # 비어 있으면 현재 시각으로 저장
    p_price: int                         # 구매가격
    store_seq: int                       # 수령 대리점 변경


@router.put("/{p_id}")
def update_purchase(p_id: int, purchase: PurchaseUpdate):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = """
                UPDATE purchase
                SET p_count = %s, p_date = %s, p_price = %s, store_seq = %s
                WHERE p_id = %s
            """
            curs.execute(sql, (
                purchase.p_count,
                purchase.p_date or datetime.now(),  # 날짜가 없으면 지금 시각
                purchase.p_price,
                purchase.store_seq,
                p_id,  # WHERE 조건 (마지막 %s)
            ))
            # rowcount: 바뀐 행 수 → 0이면 해당 구매번호가 없음
            if curs.rowcount == 0:
                raise HTTPException(status_code=404, detail="수정할 구매 내역이 없습니다")
        conn.commit()  # 실제 DB에 저장 확정
        return {"result": "OK"}
    except HTTPException:
        raise  # 위에서 만든 404는 500으로 바뀌지 않게 그대로 전달
    except Exception as e:
        conn.rollback()  # 에러 시 변경 내용 되돌림
        raise HTTPException(status_code=500, detail=f"구매 수정 실패: {e}")
    finally:
        conn.close()  # DB 연결 종료
