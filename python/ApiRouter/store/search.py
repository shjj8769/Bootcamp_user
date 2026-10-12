import os
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from fastapi import APIRouter, HTTPException, Response

from db import connect

router = APIRouter()


@router.get("/map/config")
def select_map_config():
    """Return the public Naver Dynamic Map client ID (never the server secret)."""
    client_id = os.getenv("NAVER_MAP_CLIENT_ID")
    if not client_id:
        raise HTTPException(status_code=503, detail="네이버 지도 Client ID 설정이 없습니다")
    return {"client_id": client_id}


@router.get("/")
def select_stores():
    """Return the actual MySQL branches used for customer pickup."""
    conn = connect()
    try:
        with conn.cursor() as curs:
            curs.execute(
                """
                SELECT seq, name, dealer_number, address, lat, lng
                FROM store
                ORDER BY name
                """
            )
            rows = curs.fetchall()
        return {
            "results": [
                {
                    "seq": row[0],
                    "name": row[1],
                    "dealer_number": row[2],
                    "address": row[3],
                    "lat": row[4],
                    "lng": row[5],
                }
                for row in rows
            ]
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"매장 조회 실패: {exc}")
    finally:
        conn.close()


@router.get("/{store_seq}/map", name="get_store_map")
def get_store_map(store_seq: int):
    """Proxy a Naver Static Map image so the API secret stays server-side."""
    client_id = os.getenv("NAVER_API_KEY_ID") or os.getenv("NAVER_MAP_CLIENT_ID")
    client_secret = os.getenv("NAVER_API_KEY_SECRET")
    if not client_id or not client_secret:
        raise HTTPException(status_code=503, detail="네이버 지도 API 설정이 없습니다")

    conn = connect()
    try:
        with conn.cursor() as curs:
            curs.execute("SELECT name, lat, lng FROM store WHERE seq = %s", (store_seq,))
            row = curs.fetchone()
        if row is None or row[1] is None or row[2] is None:
            raise HTTPException(status_code=404, detail="매장 위치를 찾을 수 없습니다")
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail="매장 위치 조회에 실패했습니다") from exc
    finally:
        conn.close()

    query = urlencode({
        "w": 720,
        "h": 360,
        "center": f"{row[2]},{row[1]}",
        "level": 16,
        "markers": f"type:d|size:mid|pos:{row[2]} {row[1]}|label:{row[0]}",
    })
    request = Request(
        f"https://naveropenapi.apigw.ntruss.com/map-static/v2/raster?{query}",
        headers={
            "x-ncp-apigw-api-key-id": client_id,
            "x-ncp-apigw-api-key": client_secret,
        },
    )
    try:
        with urlopen(request, timeout=8) as response:
            content = response.read()
            content_type = response.headers.get("Content-Type", "image/png")
        return Response(content=content, media_type=content_type)
    except (HTTPError, URLError, TimeoutError) as exc:
        raise HTTPException(status_code=502, detail="네이버 지도 이미지를 불러오지 못했습니다") from exc
