# python/db.py
import os

import pymysql
from dotenv import load_dotenv

# python/.env 파일의 접속 정보를 불러옴 (.env는 git에 올라가지 않음)
load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))


# 공용 DB 연결 (모든 라우터에서 from db import connect 로 사용)
def connect():
    return pymysql.connect(
        host=os.getenv("DB_HOST"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
        database=os.getenv("DB_NAME"),
        charset="utf8",
    )
