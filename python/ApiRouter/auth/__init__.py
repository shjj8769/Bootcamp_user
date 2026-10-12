# 회원가입·로그인·비밀번호 변경 라우터를 묶어 main.py에 전달합니다.
from fastapi import APIRouter
from .signup import router as signup_router
from .login import router as login_router
from .password_update import router as password_update_router
from .profile import router as profile_router

# auth 전체를 아우르는 메인 라우터 생성
auth_router = APIRouter()
# main.py의 prefix="/auth"와 각 파일의 경로가 합쳐져 최종 API 주소가 됩니다.
# tags는 /docs에서 API를 기능별로 구분하는 이름입니다.
auth_router.include_router(signup_router, tags=["Auth Signup"])
auth_router.include_router(login_router, tags=["Auth Login"])
auth_router.include_router(password_update_router, tags=["Auth Password Update"])
auth_router.include_router(profile_router, tags=["Auth Profile"])
