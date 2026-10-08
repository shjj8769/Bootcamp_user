# python/APIRouter/payment/search.py
from fastapi import APIRouter, HTTPException

from db import connect

router = APIRouter()


# 전체 결제 내역 조회
@router.get("/")
def select_payments():
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = """
                SELECT seq, customer_customer_id, head_office_id, pay_code, pay_date, pay_price
                FROM payment
                ORDER BY pay_date DESC
            """
            curs.execute(sql)
            rows = curs.fetchall()
        result = [
            {
                "seq": row[0],
                "customer_customer_id": row[1],
                "head_office_id": row[2],
                "pay_code": row[3],
                "pay_date": row[4],
                "pay_price": row[5],
            }
            for row in rows
        ]
        return {"results": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"결제 조회 실패: {e}")
    finally:
        conn.close()


# 고객별 구매 내역 조회 (결제 + 구매 항목 + 제품 정보)
# payment.seq = purchase.p_seq(결제번호) 로 구매 항목을 찾고,
# purchase.product_pr_code = product.pr_code 로 제품 정보를 가져옴
@router.get("/customer/{customer_customer_id}")
def select_payments_by_customer(customer_customer_id: str):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = """
                SELECT pay.seq, pay.customer_customer_id, pay.head_office_id,
                    pay.pay_code, pay.pay_date, pay.pay_price,
                    pur.p_id, pur.p_count, pur.p_price, pur.p_date,
                    pro.pr_code, pro.pr_name, pro.pr_brand, pro.size, pro.color
                FROM payment pay
                LEFT JOIN purchase pur
                    ON pur.p_seq = pay.seq
                LEFT JOIN product pro
                    ON pro.pr_code = pur.product_pr_code
                WHERE pay.customer_customer_id = %s
                ORDER BY pay.pay_date DESC, pay.seq DESC
            """
            curs.execute(sql, (customer_customer_id,))
            rows = curs.fetchall()

        # 결제 1건에 구매 항목 여러 개가 묶이도록 seq 기준으로 정리
        payments = {}
        for row in rows:
            seq = row[0]
            if seq not in payments:
                payments[seq] = {
                    "seq": seq,
                    "customer_customer_id": row[1],
                    "head_office_id": row[2],
                    "pay_code": row[3],
                    "pay_date": row[4],
                    "pay_price": row[5],
                    "items": [],
                }
            if row[6] is not None:  # 연결된 구매 항목이 있을 때만 추가
                payments[seq]["items"].append({
                    "p_id": row[6],
                    "p_count": row[7],
                    "p_price": row[8],
                    "p_date": row[9],
                    "pr_code": row[10],
                    "pr_name": row[11],
                    "pr_brand": row[12],
                    "size": row[13],
                    "color": row[14],
                })
        return {"results": list(payments.values())}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"결제 조회 실패: {e}")
    finally:
        conn.close()


# 결제 1건 조회
@router.get("/{seq}")
def select_payment(seq: int):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = """
                SELECT seq, customer_customer_id, head_office_id, pay_code, pay_date, pay_price
                FROM payment
                WHERE seq = %s
            """
            curs.execute(sql, (seq,))
            row = curs.fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="결제 내역이 없습니다")
        return {
            "seq": row[0],
            "customer_customer_id": row[1],
            "head_office_id": row[2],
            "pay_code": row[3],
            "pay_date": row[4],
            "pay_price": row[5],
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"결제 조회 실패: {e}")
    finally:
        conn.close()
