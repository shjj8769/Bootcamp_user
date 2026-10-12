from fastapi import APIRouter, Body, HTTPException

from db import connect as sql_connect

router = APIRouter()
PROFILE_COLUMNS = {
    "c_name": "c_name",
    "tel": "tel",
    "c_address": "c_address",
    "c_gender": "c_gender",
}


@router.get("/profile/{email}")
def select_customer_profile(email: str):
    conn = sql_connect()
    try:
        with conn.cursor() as curs:
            curs.execute(
                "SELECT email, c_name, tel, c_address, c_gender FROM customer WHERE email = %s",
                (email.strip().casefold(),),
            )
            row = curs.fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="회원 정보를 찾을 수 없습니다")
        return {
            "email": row[0], "c_name": row[1], "tel": row[2],
            "c_address": row[3], "c_gender": row[4],
        }
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"회원 정보 조회 실패: {exc}") from exc
    finally:
        conn.close()


@router.put("/profile/{email}")
def update_customer_profile(email: str, payload: dict = Body(...)):
    changes = {
        key: str(payload[key]).strip()
        for key in PROFILE_COLUMNS
        if key in payload and isinstance(payload[key], str) and payload[key].strip()
    }
    if not changes:
        raise HTTPException(status_code=422, detail="수정할 회원 정보가 없습니다")

    conn = sql_connect()
    try:
        with conn.cursor() as curs:
            assignments = ", ".join(f"{PROFILE_COLUMNS[key]} = %s" for key in changes)
            values = [*changes.values(), email.strip().casefold()]
            curs.execute(
                f"UPDATE customer SET {assignments} WHERE email = %s",
                values,
            )
            if curs.rowcount == 0:
                curs.execute("SELECT email FROM customer WHERE email = %s", (email.strip().casefold(),))
                if curs.fetchone() is None:
                    raise HTTPException(status_code=404, detail="회원 정보를 찾을 수 없습니다")
        conn.commit()
        return {"result": "OK"}
    except HTTPException:
        conn.rollback()
        raise
    except Exception as exc:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"회원 정보 수정 실패: {exc}") from exc
    finally:
        conn.close()
