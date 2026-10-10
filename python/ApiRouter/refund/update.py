# python/APIRouter/refund/update.py
from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from db import connect

router = APIRouter()


# 반품 처리 상태 변경 (p_r_id는 주소로 받음)
class RefundUpdate(BaseModel):
    is_refunded: int                # 0: 환불 전, 1: 환불 완료
    e_id: Optional[str] = None      # 처리한 직원 (비어 있으면 기존 값 유지)


@router.put("/{p_r_id}")
def update_refund(p_r_id: int, refund: RefundUpdate):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = """
                UPDATE p_return
                SET is_refunded = %s, e_id = COALESCE(%s, e_id)
                WHERE p_r_id = %s
            """
            curs.execute(sql, (
                refund.is_refunded,
                refund.e_id,
                p_r_id,
            ))
            if curs.rowcount == 0:
                raise HTTPException(status_code=404, detail="수정할 반품 내역이 없습니다")
        conn.commit()
        return {"result": "OK"}
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"반품 수정 실패: {e}")
    finally:
        conn.close()
