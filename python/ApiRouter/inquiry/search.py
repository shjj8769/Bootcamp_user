"""Create and list customer inquiries without changing the database schema."""
from datetime import datetime

from fastapi import APIRouter, Body, HTTPException

from db import connect

router = APIRouter()


@router.get("/customer/{email}")
def select_customer_inquiries(email: str):
    conn = connect()
    try:
        with conn.cursor() as curs:
            curs.execute(
                """
                SELECT i_seq, post, i_option, i_date, inquiry_detail,
                       d_date, i_state, i_comment_seq, level, email, e_id
                FROM inquiry WHERE email = %s ORDER BY i_date DESC, i_seq DESC
                """,
                (email.strip().casefold(),),
            )
            rows = curs.fetchall()
        return {"results": [
            {
                "i_seq": row[0], "post": row[1], "i_option": row[2],
                "i_date": row[3].isoformat() if row[3] else None,
                "inquiry_detail": row[4],
                "d_date": row[5].isoformat() if row[5] else None,
                "i_state": row[6], "i_comment_seq": row[7], "level": row[8],
                "email": row[9], "e_id": row[10],
            }
            for row in rows
        ]}
    except Exception as exc:
        raise HTTPException(status_code=500, detail="문의 내역 조회에 실패했습니다") from exc
    finally:
        conn.close()


@router.post("/customer/{email}", status_code=201)
def create_customer_inquiry(email: str, payload: dict = Body(...)):
    """Store only the subject and body in columns confirmed in MySQL metadata."""
    subject = payload.get("post")
    detail = payload.get("inquiry_detail")
    normalized_email = email.strip().casefold()
    if not normalized_email or not isinstance(subject, str) or not subject.strip():
        raise HTTPException(status_code=422, detail="문의 제목을 입력해 주세요")
    if not isinstance(detail, str) or not detail.strip():
        raise HTTPException(status_code=422, detail="문의 내용을 입력해 주세요")
    if len(subject.strip()) > 255:
        raise HTTPException(status_code=422, detail="문의 제목이 너무 깁니다")

    conn = connect()
    try:
        with conn.cursor() as curs:
            curs.execute(
                """
                INSERT INTO inquiry (post, i_date, inquiry_detail, email)
                VALUES (%s, %s, %s, %s)
                """,
                (subject.strip(), datetime.now(), detail.strip(), normalized_email),
            )
            inquiry_id = curs.lastrowid
        conn.commit()
        return {"result": "OK", "i_seq": inquiry_id}
    except Exception as exc:
        conn.rollback()
        raise HTTPException(status_code=500, detail="문의 등록에 실패했습니다") from exc
    finally:
        conn.close()
