# 회원 인증 API

프로젝트 루트의 .env.example을 .env로 복사하고 DB 설정 및 Firebase 서비스 계정 키 경로를 입력합니다.
키와 .env는 커밋하지 않습니다. Authentication 설정 없이 기본 Firestore 데이터베이스를 사용합니다.

실행: pip install -r python/requirements.txt
서버: python3 python/main.py (192.168.20.68:8000 에서만 수신)

- POST /auth/signup: 이메일, 비밀번호, 전화번호, 이름, 성별, 주소, 사이즈로 회원가입
- POST /auth/login: 이메일과 비밀번호 확인
- PATCH /auth/password_update: 이메일, current_password, new_password로 비밀번호 변경

비밀번호는 요청된 저장 방식에 따라 password 필드에 원문으로 저장합니다.
로그인 성공 응답은 result와 uid이며 세션이나 토큰을 발급하지 않습니다.
신규 문서 ID는 정규화한 이메일을 경로 인코딩한 값이며 기존 문서도 이메일로 조회합니다.
비밀번호 변경은 현재 비밀번호를 확인한 뒤 트랜잭션으로 처리합니다.
