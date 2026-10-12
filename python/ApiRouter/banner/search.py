"""Read-only endpoints for the campaign images stored in shoes.banner_image."""
from fastapi import APIRouter, HTTPException, Response

from db import connect

router = APIRouter()


@router.get("/")
def select_banners():
    """Return banner identifiers only; image bytes are fetched on demand."""
    conn = connect()
    try:
        with conn.cursor() as curs:
            curs.execute("SELECT b_seq FROM banner_image ORDER BY b_seq")
            rows = curs.fetchall()
        return {"results": [{"b_seq": row[0]} for row in rows]}
    except Exception as exc:
        raise HTTPException(status_code=500, detail="배너 목록 조회 실패") from exc
    finally:
        conn.close()


@router.get("/{b_seq}/image")
def select_banner_image(b_seq: int):
    """Stream a stored image blob without inventing a substitute asset."""
    conn = connect()
    try:
        with conn.cursor() as curs:
            curs.execute(
                "SELECT b_image FROM banner_image WHERE b_seq = %s", (b_seq,)
            )
            row = curs.fetchone()
        if row is None or row[0] is None:
            raise HTTPException(status_code=404, detail="배너 이미지가 없습니다")

        image = bytes(row[0])
        if image.startswith(b"\x89PNG\r\n\x1a\n"):
            media_type = "image/png"
        elif image.startswith(b"GIF87a") or image.startswith(b"GIF89a"):
            media_type = "image/gif"
        elif image.startswith(b"RIFF") and image[8:12] == b"WEBP":
            media_type = "image/webp"
        else:
            media_type = "image/jpeg"
        return Response(content=image, media_type=media_type)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail="배너 이미지 조회 실패") from exc
    finally:
        conn.close()
