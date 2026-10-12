# python/APIRouter/purchase/delete.py
# 구매 항목 삭제 API → DELETE /purchase/{p_id}
# 주소로 구매번호만 받으므로 BaseModel class 없음
# 주의: 반품/수령 기록이 연결된 구매는 외래키 때문에 삭제가 실패할 수 있음 (500)
from fastapi import APIRouter, HTTPException

from db import connect  # 공용 DB 연결 함수 (python/db.py)

router = APIRouter()


@router.delete("/{p_id}")
def delete_purchase(p_id: int):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = "DELETE FROM purchase WHERE p_id = %s"
            curs.execute(sql, (p_id,))
            # rowcount: 삭제된 행 수 → 0이면 해당 구매번호가 없음
            if curs.rowcount == 0:
                raise HTTPException(status_code=404, detail="삭제할 구매 내역이 없습니다")
        conn.commit()  # 실제 DB에 삭제 확정
        return {"result": "OK"}
    except HTTPException:
        raise  # 위에서 만든 404는 500으로 바뀌지 않게 그대로 전달
    except Exception as e:
        conn.rollback()  # 에러 시 삭제 취소
        raise HTTPException(status_code=500, detail=f"구매 삭제 실패: {e}")
    finally:
        conn.close()  # DB 연결 종료
