# python/db.py
import os
from pathlib import Path

import pymysql
from dotenv import load_dotenv

# 프로젝트 루트의 .env 파일에서 접속 정보를 불러옵니다.
load_dotenv(Path(__file__).resolve().parents[1] / ".env")


# 공용 DB 연결 (모든 라우터에서 from db import connect 로 사용)
def connect():
    return pymysql.connect(
        host=os.getenv("DB_HOST"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
        database=os.getenv("DB_NAME"),
        charset="utf8",
        connect_timeout=5,
    )
