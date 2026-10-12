import secrets
from datetime import datetime

from fastapi import APIRouter, Body, HTTPException
from pymysql.err import IntegrityError

from db import connect

router = APIRouter()


@router.post("/checkout")
def checkout_order(payload: dict = Body(...)):
    """Create one simulated payment and its purchase rows in one transaction."""
    email = str(payload.get("email", "")).strip().casefold()
    store_seq = payload.get("store_seq")
    items = payload.get("items")
    payment_method = str(payload.get("payment_method", "")).strip()
    if not email or not isinstance(store_seq, int) or store_seq < 1:
        raise HTTPException(status_code=422, detail="고객 이메일과 수령 매장을 확인해 주세요")
    if payment_method not in {"01", "02", "03"}:
        raise HTTPException(status_code=422, detail="결제 방법을 확인해 주세요")
    if not isinstance(items, list) or not items:
        raise HTTPException(status_code=422, detail="주문 상품이 비어 있습니다")

    requested = []
    seen_skus = set()
    for item in items:
        if not isinstance(item, dict):
            raise HTTPException(status_code=422, detail="주문 상품 형식이 올바르지 않습니다")
        sku = str(item.get("SKU", "")).strip()
        quantity = item.get("quantity")
        if not sku or not isinstance(quantity, int) or isinstance(quantity, bool) or quantity < 1:
            raise HTTPException(status_code=422, detail="상품 코드 또는 수량을 확인해 주세요")
        if sku in seen_skus:
            raise HTTPException(status_code=422, detail="같은 SKU는 한 줄로 합쳐 주문해 주세요")
        seen_skus.add(sku)
        requested.append((sku, quantity))

    conn = connect()
    try:
        conn.begin()
        with conn.cursor() as curs:
            curs.execute("SELECT email FROM customer WHERE email = %s", (email,))
            if curs.fetchone() is None:
                raise HTTPException(status_code=404, detail="회원 정보를 찾을 수 없습니다")
            curs.execute("SELECT seq FROM store WHERE seq = %s", (store_seq,))
            if curs.fetchone() is None:
                raise HTTPException(status_code=404, detail="선택한 매장을 찾을 수 없습니다")

            # Resolve a real employee FK from the existing sales team.
            curs.execute(
                "SELECT e_id FROM employee WHERE e_team = %s ORDER BY e_id LIMIT 1",
                ("영업팀",),
            )
            employee = curs.fetchone()
            if employee is None:
                raise HTTPException(status_code=409, detail="결제를 처리할 영업팀 직원이 없습니다")
            employee_id = employee[0]

            purchase_lines = []
            total = 0
            for sku, quantity in requested:
                curs.execute("SELECT pr_price FROM product WHERE SKU = %s LIMIT 1", (sku,))
                product = curs.fetchone()
                if product is None:
                    raise HTTPException(status_code=404, detail=f"상품을 찾을 수 없습니다: {sku}")
                line_total = int(product[0]) * quantity
                total += line_total
                purchase_lines.append((sku, quantity, line_total))

            # purchase.p_seq references payment.pay_id in the live DB, not seq.
            pay_id = None
            for _ in range(8):
                candidate = secrets.randbelow(2_000_000_000) + 1
                curs.execute("SELECT 1 FROM payment WHERE pay_id = %s", (candidate,))
                if curs.fetchone() is None:
                    pay_id = candidate
                    break
            if pay_id is None:
                raise HTTPException(status_code=503, detail="결제 번호를 생성하지 못했습니다")

            now = datetime.now()
            curs.execute(
                """
                INSERT INTO payment (pay_id, pay_date, pay_price, e_id, email)
                VALUES (%s, %s, %s, %s, %s)
                """,
                (pay_id, now, total, employee_id, email),
            )
            payment_seq = curs.lastrowid
            purchase_ids = []
            for sku, quantity, line_total in purchase_lines:
                curs.execute(
                    """
                    INSERT INTO purchase
                        (p_seq, p_count, p_date, p_price, email, SKU, store_seq)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    """,
                    (pay_id, quantity, now, line_total, email, sku, store_seq),
                )
                purchase_ids.append(curs.lastrowid)

        conn.commit()
        return {
            "result": "OK",
            "payment_seq": payment_seq,
            "pay_id": pay_id,
            "purchase_ids": purchase_ids,
            "total": total,
            "payment_method": payment_method,
            "simulated": True,
        }
    except HTTPException:
        conn.rollback()
        raise
    except IntegrityError as exc:
        conn.rollback()
        raise HTTPException(status_code=409, detail="주문 정보가 DB 제약조건과 일치하지 않습니다") from exc
    except Exception as exc:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"주문 등록 실패: {exc}") from exc
    finally:
        conn.close()
