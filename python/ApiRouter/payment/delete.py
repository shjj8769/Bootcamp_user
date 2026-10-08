# python/APIRouter/payment/delete.py
from fastapi import APIRouter, HTTPException

from db import connect

router = APIRouter()


@router.delete("/{seq}")
def delete_payment(seq: int):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = "DELETE FROM payment WHERE seq = %s"
            curs.execute(sql, (seq,))
            if curs.rowcount == 0:
                raise HTTPException(status_code=404, detail="삭제할 결제 내역이 없습니다")
        conn.commit()
        return {"result": "OK"}
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"결제 삭제 실패: {e}")
    finally:
        conn.close()
