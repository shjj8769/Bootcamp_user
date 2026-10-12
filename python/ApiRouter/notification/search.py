"""Build truthful order notifications from purchase and pickup records."""
from fastapi import APIRouter, HTTPException

from db import connect

router = APIRouter()


@router.get("/customer/{email}")
def select_customer_notifications(email: str):
    conn = connect()
    try:
        with conn.cursor() as curs:
            curs.execute(
                """
                SELECT pur.p_id, pur.p_date, pur.SKU, pur.store_seq,
                       pro.pr_name, st.name,
                       pk.p_date
                FROM purchase pur
                LEFT JOIN product pro ON pro.SKU = pur.SKU
                LEFT JOIN store st ON st.seq = pur.store_seq
                LEFT JOIN pick_up pk
                    ON pk.purchase_p_id = pur.p_id AND pk.email = pur.email
                WHERE pur.email = %s
                ORDER BY COALESCE(pk.p_date, pur.p_date) DESC, pur.p_id DESC
                """,
                (email.strip().casefold(),),
            )
            rows = curs.fetchall()
        return {"results": [
            {
                "p_id": row[0],
                "created_at": row[1].isoformat() if row[1] else None,
                "SKU": row[2],
                "store_seq": row[3],
                "pr_name": row[4] or row[2],
                "store_name": row[5] or "수령 매장",
                "status": "수령 완료" if row[6] else "주문 접수",
                "status_at": row[6].isoformat() if row[6] else (
                    row[1].isoformat() if row[1] else None
                ),
            }
            for row in rows
        ]}
    except Exception as exc:
        raise HTTPException(status_code=500, detail="알림을 불러오지 못했습니다") from exc
    finally:
        conn.close()
