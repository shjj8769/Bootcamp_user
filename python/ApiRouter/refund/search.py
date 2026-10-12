# python/APIRouter/refund/search.py
# 반품 조회 API
#   GET /refund/                          전체 반품 내역 (대리점·본사용)
#   GET /refund/customer/{customer_id}    고객별 반품 내역
#   GET /refund/{p_r_id}                  반품 1건
# 조회만 하고 받는 값(body)이 없어서 BaseModel class 없음
from fastapi import APIRouter, HTTPException

from db import connect  # 공용 DB 연결 함수 (python/db.py)

router = APIRouter()


# 반품 + 구매 항목 + 제품 정보를 함께 조회하는 공통 SELECT
# p_return.purchase_p_id = purchase.p_id 로 구매 항목을 찾고,
# purchase.product_pr_code = product.pr_code 로 제품 정보를 가져옴
# 세 API가 같은 SELECT를 쓰므로 한 번만 작성하고 뒤에 WHERE/ORDER BY만 붙여서 사용
# ret / pur / pro 는 테이블 별칭 (p_return / purchase / product)
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
# → SELECT_SQL의 컬럼을 추가하거나 순서를 바꾸면 여기 번호도 같이 수정해야 함
def to_dict(row):
    return {
        "p_r_id": row[0],                # 반품id
        "customer_customer_id": row[1],  # 고객
        "purchase_p_id": row[2],         # 반품한 구매번호
        "e_id": row[3],                  # 처리 직원
        "p_r_reason": row[4],            # 반품 사유
        "p_r_image": row[5],             # 반품 사진 URL
        "p_r_date": row[6],              # 반품일
        "is_refunded": row[7],           # 환불여부 (0: 전, 1: 완료)
        "p_count": row[8],               # 구매수량
        "p_price": row[9],               # 구매가격
        "pr_code": row[10],              # 제품 코드
        "pr_name": row[11],              # 제품명
        "pr_brand": row[12],             # 브랜드명
        "size": row[13],                 # 사이즈
        "color": row[14],                # 색상
    }


# 전체 반품 내역 조회 (최신순)
@router.get("/")
def select_refunds():
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = SELECT_SQL + " ORDER BY ret.p_r_date DESC"
            curs.execute(sql)
            rows = curs.fetchall()  # 결과 전체를 튜플 목록으로 받음
        return {"results": [to_dict(row) for row in rows]}  # 한 줄씩 dict로 변환
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"반품 조회 실패: {e}")
    finally:
        conn.close()


# 고객별 반품 내역 조회 (최신순)
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
# 주의: "/customer/..." 보다 아래에 있어야 "customer"가 p_r_id로 잘못 인식되지 않음
@router.get("/{p_r_id}")
def select_refund(p_r_id: int):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = SELECT_SQL + " WHERE ret.p_r_id = %s"
            curs.execute(sql, (p_r_id,))
            row = curs.fetchone()  # 1건만 받음 (없으면 None)
        if row is None:
            raise HTTPException(status_code=404, detail="반품 내역이 없습니다")
        return to_dict(row)
    except HTTPException:
        raise  # 위에서 만든 404는 500으로 바뀌지 않게 그대로 전달
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"반품 조회 실패: {e}")
    finally:
        conn.close()
