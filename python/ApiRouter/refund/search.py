# python/APIRouter/refund/search.py
from fastapi import APIRouter, HTTPException

from db import connect

router = APIRouter()


# 반품 + 구매 항목 + 제품 정보를 함께 조회하는 공통 SELECT
# p_return.purchase_p_id = purchase.p_id 로 구매 항목을 찾고,
# purchase.product_pr_code = product.pr_code 로 제품 정보를 가져옴
SELECT_SQL = """
    SELECT ret.p_r_id, ret.customer_customer_id, ret.purchase_p_id, ret.e_id,
        ret.p_r_reason, ret.p_r_image, ret.p_r_date, ret.is_refunded,
        pur.p_count, pur.p_price,
        pro.pr_code, pro.pr_name, pro.pr_brand, pro.size, pro.color
    FROM p_return ret
    LEFT JOIN purchase pur
        ON pur.p_id = ret.purchase_p_id
    LEFT JOIN product pro
        ON pro.pr_code = pur.product_pr_code
"""


# DB 결과 한 줄을 응답 형식으로 변환 (번호는 SELECT_SQL 컬럼 순서)
def to_dict(row):
    return {
        "p_r_id": row[0],
        "customer_customer_id": row[1],
        "purchase_p_id": row[2],
        "e_id": row[3],
        "p_r_reason": row[4],
        "p_r_image": row[5],
        "p_r_date": row[6],
        "is_refunded": row[7],
        "p_count": row[8],
        "p_price": row[9],
        "pr_code": row[10],
        "pr_name": row[11],
        "pr_brand": row[12],
        "size": row[13],
        "color": row[14],
    }


# 전체 반품 내역 조회
@router.get("/")
def select_refunds():
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = SELECT_SQL + " ORDER BY ret.p_r_date DESC"
            curs.execute(sql)
            rows = curs.fetchall()
        return {"results": [to_dict(row) for row in rows]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"반품 조회 실패: {e}")
    finally:
        conn.close()


# 고객별 반품 내역 조회
@router.get("/customer/{customer_customer_id}")
def select_refunds_by_customer(customer_customer_id: str):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = SELECT_SQL + """
                WHERE ret.customer_customer_id = %s
                ORDER BY ret.p_r_date DESC
            """
            curs.execute(sql, (customer_customer_id,))
            rows = curs.fetchall()
        return {"results": [to_dict(row) for row in rows]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"반품 조회 실패: {e}")
    finally:
        conn.close()


# 반품 1건 조회
@router.get("/{p_r_id}")
def select_refund(p_r_id: int):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = SELECT_SQL + " WHERE ret.p_r_id = %s"
            curs.execute(sql, (p_r_id,))
            row = curs.fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="반품 내역이 없습니다")
        return to_dict(row)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"반품 조회 실패: {e}")
    finally:
        conn.close()
