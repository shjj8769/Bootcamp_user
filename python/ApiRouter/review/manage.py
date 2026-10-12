"""Owner-scoped review update and delete endpoints."""
from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from db import connect

router = APIRouter()
MAX_IMAGE_BYTES = 5 * 1024 * 1024


def image_mime(data: bytes) -> str | None:
    """Detect supported image formats from their bytes, not the client filename."""
    if data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if data.startswith(b"RIFF") and data[8:12] == b"WEBP":
        return "image/webp"
    return None


@router.put("/{r_seq}")
async def update_customer_review(
    r_seq: int,
    email: str = Form(..., min_length=3, max_length=254),
    post: str = Form(..., min_length=1, max_length=45),
    rating: float = Form(..., ge=0.5, le=5),
    fit: str = Form("", max_length=45),
    image: UploadFile | None = File(None),
):
    """Update only a review owned by the supplied customer email."""
    normalized_email = email.strip().casefold()
    normalized_post = post.strip()
    if not normalized_post:
        raise HTTPException(status_code=422, detail="리뷰 내용을 입력해 주세요")
    if round(rating * 2) != rating * 2:
        raise HTTPException(status_code=422, detail="평점은 0.5 단위로 입력해 주세요")

    image_bytes = None
    if image is not None:
        image_bytes = await image.read(MAX_IMAGE_BYTES + 1)
        if len(image_bytes) > MAX_IMAGE_BYTES:
            raise HTTPException(status_code=413, detail="사진은 5MB 이하로 선택해 주세요")
        if image_mime(image_bytes) is None:
            raise HTTPException(status_code=415, detail="JPEG, PNG, WEBP 사진만 등록할 수 있습니다")

    conn = connect()
    try:
        with conn.cursor() as curs:
            curs.execute(
                "SELECT r_seq FROM review WHERE r_seq = %s AND email = %s LIMIT 1",
                (r_seq, normalized_email),
            )
            if curs.fetchone() is None:
                raise HTTPException(status_code=404, detail="수정할 리뷰를 찾을 수 없습니다")

            if image_bytes is None:
                curs.execute(
                    "UPDATE review SET post = %s, rating = %s, fit = %s WHERE r_seq = %s AND email = %s",
                    (normalized_post, rating, fit.strip(), r_seq, normalized_email),
                )
            else:
                curs.execute(
                    "UPDATE review SET post = %s, rating = %s, fit = %s, image = %s WHERE r_seq = %s AND email = %s",
                    (normalized_post, rating, fit.strip(), image_bytes, r_seq, normalized_email),
                )
        conn.commit()
        return {"result": "OK", "r_seq": r_seq}
    except HTTPException:
        conn.rollback()
        raise
    except Exception as exc:
        conn.rollback()
        raise HTTPException(status_code=500, detail="리뷰 수정에 실패했습니다") from exc
    finally:
        conn.close()


@router.delete("/{r_seq}")
def delete_customer_review(r_seq: int, email: str):
    """Delete only a review owned by the supplied customer email."""
    normalized_email = email.strip().casefold()
    conn = connect()
    try:
        with conn.cursor() as curs:
            curs.execute(
                "DELETE FROM review WHERE r_seq = %s AND email = %s",
                (r_seq, normalized_email),
            )
            if curs.rowcount == 0:
                raise HTTPException(status_code=404, detail="삭제할 리뷰를 찾을 수 없습니다")
        conn.commit()
        return {"result": "OK", "r_seq": r_seq}
    except HTTPException:
        conn.rollback()
        raise
    except Exception as exc:
        conn.rollback()
        raise HTTPException(status_code=500, detail="리뷰 삭제에 실패했습니다") from exc
    finally:
        conn.close()
