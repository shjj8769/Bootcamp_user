"""Read reviews attached to the selected MySQL product SKU."""
from fastapi import APIRouter, HTTPException, Request, Response

from db import connect
from .manage import image_mime

router = APIRouter()


@router.get("/customer/{email}")
def select_customer_reviews(email: str, request: Request):
    """Return the signed-in customer's own reviews, newest first."""
    conn = connect()
    try:
        with conn.cursor() as curs:
            curs.execute(
                """
                SELECT r.r_seq, r.r_date, r.post, r.rating, r.fit,
                    r.`like count`, r.image IS NOT NULL, p.SKU,
                    p.pr_name, p.pr_brand, p.color, p.size
                FROM review AS r
                LEFT JOIN product AS p ON p.SKU = r.SKU
                WHERE r.email = %s
                ORDER BY r.r_date DESC, r.r_seq DESC
                LIMIT 100
                """,
                (email.strip().casefold(),),
            )
            rows = curs.fetchall()
        return {"results": [
            {
                "r_seq": row[0],
                "r_date": row[1].isoformat() if row[1] else "",
                "post": row[2] or "",
                "rating": float(row[3] or 0),
                "fit": row[4] or "",
                "like_count": int(row[5] or 0),
                "image_url": (
                    str(request.url_for("get_review_image", r_seq=row[0]))
                    if row[6] else None
                ),
                "SKU": row[7],
                "pr_name": row[8] or row[7],
                "pr_brand": row[9] or "",
                "color": row[10] or "",
                "size": row[11],
            }
            for row in rows
        ]}
    except Exception as exc:
        raise HTTPException(status_code=500, detail="내 리뷰 조회에 실패했습니다") from exc
    finally:
        conn.close()


@router.get("/product/{SKU}")
def select_product_reviews(SKU: str, request: Request):
    """Return reviews for every size/color SKU of the selected model."""
    conn = connect()
    try:
        with conn.cursor() as curs:
            curs.execute(
                "SELECT pr_code, pr_name, pr_brand FROM product WHERE SKU = %s LIMIT 1",
                (SKU,),
            )
            model = curs.fetchone()
            if model is None:
                raise HTTPException(status_code=404, detail="상품이 없습니다")

            if model[0]:
                model_where = "p.pr_code = %s"
                model_params = (model[0],)
            else:
                model_where = "p.pr_name = %s AND p.pr_brand = %s"
                model_params = (model[1], model[2])

            curs.execute(
                f"""
                SELECT r.r_seq, r.r_date, r.post, r.rating, r.fit,
                    r.`like count`, r.image IS NOT NULL, p.color, p.size
                FROM review AS r
                INNER JOIN product AS p ON p.SKU = r.SKU
                WHERE {model_where}
                ORDER BY r.r_date DESC, r.r_seq DESC
                LIMIT 100
                """,
                model_params,
            )
            rows = curs.fetchall()
        return {
            "results": [
                {
                    "r_seq": row[0],
                    "r_date": row[1].isoformat() if row[1] else "",
                    "post": row[2] or "",
                    "rating": float(row[3] or 0),
                    "fit": row[4] or "",
                    "like_count": int(row[5] or 0),
                    "image_url": (
                        str(request.url_for("get_review_image", r_seq=row[0]))
                        if row[6]
                        else None
                    ),
                    "color": row[7] or "",
                    "size": row[8] or "",
                }
                for row in rows
            ]
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail="리뷰 조회에 실패했습니다") from exc
    finally:
        conn.close()


@router.get("/{r_seq}/image", name="get_review_image")
def select_review_image(r_seq: int):
    """Return the optional review image stored as a MySQL BLOB."""
    conn = connect()
    try:
        with conn.cursor() as curs:
            curs.execute("SELECT image FROM review WHERE r_seq = %s", (r_seq,))
            row = curs.fetchone()
        if row is None or row[0] is None:
            raise HTTPException(status_code=404, detail="리뷰 이미지가 없습니다")
        return Response(content=row[0], media_type=image_mime(row[0]) or "application/octet-stream")
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail="리뷰 이미지 조회에 실패했습니다") from exc
    finally:
        conn.close()
