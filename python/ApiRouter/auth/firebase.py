# python/ApiRouter/auth/firebase.py
# 인증 관련 API가 공통으로 사용하는 Firebase Admin SDK와 Firestore 연결 설정입니다.
import os
from functools import lru_cache
from pathlib import Path
from urllib.parse import quote

import firebase_admin
from dotenv import load_dotenv
from firebase_admin import credentials, firestore
from google.cloud.firestore_v1.base_query import FieldFilter

# 기존 DB 설정과 같이 프로젝트 루트의 .env 파일을 사용합니다.
load_dotenv(Path(__file__).resolve().parents[3] / ".env")


# 초기화된 Firebase 앱을 재사용해 요청마다 같은 이름의 앱을 생성하지 않습니다.
@lru_cache(maxsize=1)
def get_firebase_app():
    # 인증 정보는 서버의 환경 변수에서 읽고, 첫 요청 때 한 번 초기화합니다.
    project_id = os.getenv("FIREBASE_PROJECT_ID", "shoes-bc377")
    # .env의 GOOGLE_APPLICATION_CREDENTIALS에 지정한 서비스 계정 키를 읽습니다.
    credential = credentials.ApplicationDefault()
    return firebase_admin.initialize_app(
        credential, {"projectId": project_id}, name="shoes_backend"
    )


def connect():
    # 프로젝트의 (default) Firestore 데이터베이스 클라이언트를 반환합니다.
    return firestore.client(app=get_firebase_app())


def customer_document_id(email):
    # 이메일의 경로 구분 문자를 인코딩해 안전한 문서 ID로 사용합니다.
    return quote(email, safe="")


def find_customer(db, email):
    document = db.collection("customer").document(customer_document_id(email)).get()
    if document.exists:
        return document
    # 이전 형식의 문서 ID로 저장한 회원도 이메일로 찾습니다.
    documents = list(db.collection("customer").where(
        filter=FieldFilter("email", "==", email)
    ).limit(2).stream())
    if len(documents) > 1:
        raise ValueError("동일 이메일의 회원 문서가 여러 개 있습니다")
    return documents[0] if documents else None
