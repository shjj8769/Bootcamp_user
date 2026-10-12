# python/APIRouter/payment/search.py
# 결제 조회 API
#   GET /payment/                          전체 결제 내역
#   GET /payment/customer/{customer_id}    고객별 구매 내역 (상품 정보 포함)
#   GET /payment/{seq}                     결제 1건
# 조회만 하고 받는 값(body)이 없어서 BaseModel class 없음
from fastapi import APIRouter, HTTPException

from db import connect  # 공용 DB 연결 함수 (python/db.py)

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
            rows = curs.fetchall()  # 결과 전체를 (값, 값, ...) 튜플 목록으로 받음
        # 튜플 → 앱에서 쓰기 쉬운 dict(JSON)로 변환
        # row[번호]는 SELECT에 적은 컬럼 순서 (0부터 시작)
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
# LEFT JOIN: 연결된 구매 항목이 없는 결제도 빠지지 않고 나옴 (항목 값은 None)
@router.get("/customer/{customer_customer_id}")
def select_payments_by_customer(customer_customer_id: str):
    conn = connect()
    try:
        with conn.cursor() as curs:
            # pay / pur / pro 는 테이블 별칭 (payment / purchase / product)
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
        # (JOIN 결과는 상품 1개당 1줄이라 같은 결제 정보가 상품 수만큼 반복됨)
        payments = {}  # {결제번호: 결제 정보} 형태로 모음
        for row in rows:
            seq = row[0]
            if seq not in payments:  # 처음 나온 결제번호일 때만 결제 정보 생성
                payments[seq] = {
                    "seq": seq,
                    "customer_customer_id": row[1],
                    "head_office_id": row[2],
                    "pay_code": row[3],
                    "pay_date": row[4],
                    "pay_price": row[5],
                    "items": [],        # 상품 목록
                }
            if row[6] is not None:  # 연결된 구매 항목이 있을 때만 추가
                payments[seq]["items"].append({
                    "p_id": row[6],       # 구매번호
                    "p_count": row[7],    # 구매수량
                    "p_price": row[8],    # 구매가격
                    "p_date": row[9],     # 구매일
                    "pr_code": row[10],   # 제품 코드
                    "pr_name": row[11],   # 제품명
                    "pr_brand": row[12],  # 브랜드명
                    "size": row[13],      # 사이즈
                    "color": row[14],     # 색상
                })
        return {"results": list(payments.values())}  # dict의 값(결제들)만 리스트로 반환
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"결제 조회 실패: {e}")
    finally:
        conn.close()


# 결제 1건 조회
# 주의: "/customer/..." 보다 아래에 있어야 "customer"가 seq로 잘못 인식되지 않음
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
            curs.execute(sql, (seq,))  # 값이 1개여도 튜플이라 (seq,) 처럼 쉼표 필요
            row = curs.fetchone()  # 1건만 받음 (없으면 None)
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
        raise  # 위에서 만든 404는 500으로 바뀌지 않게 그대로 전달
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"결제 조회 실패: {e}")
    finally:
        conn.close()
