# 로그 API에서 사용하는 요청 데이터 모델입니다.
from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator


# 회원가입(register)과 비밀번호 변경(change) 기록에 사용하는 공통 요청 모델입니다.
# BaseModel로 필수 입력값의 타입과 길이를 검증합니다.
class CustomerLog(BaseModel):
    # 정의하지 않은 필드는 거부하고 검증 오류 메시지에서 입력값을 숨깁니다.
    model_config = ConfigDict(extra="forbid", hide_input_in_errors=True)

    # 기록할 회원의 이메일입니다. customer 컬렉션에 존재하는지 별도로 확인합니다.
    email: EmailStr = Field(max_length=254)
    # 기록에 연결할 직원 ID입니다. main_server 컬렉션의 e_id를 참조합니다.
    e_id: str = Field(min_length=1, max_length=100)

    # 타입과 길이를 검증하기 전에 이메일과 직원 ID의 앞뒤 공백을 제거합니다.
    @field_validator("email", "e_id", mode="before")
    @classmethod
    def trim_text(cls, value):
        return value.strip() if isinstance(value, str) else value


# 로그인(connect) 기록용 요청 모델입니다.
# CustomerLog의 email, e_id와 검증 설정을 상속하고 로그인 위치를 추가합니다.
# 접속 IP와 기록 날짜는 서버에서 채우므로 요청 필드로 받지 않습니다.
class ConnectLog(CustomerLog):
    # IP에서 위치를 추측하지 않고 요청에 전달된 위치를 사용합니다.
    c_location: str = Field(min_length=1, max_length=500)

    # 공백만 입력한 위치가 길이 검증을 통과하지 않도록 먼저 공백을 제거합니다.
    @field_validator("c_location", mode="before")
    @classmethod
    def trim_location(cls, value):
        return value.strip() if isinstance(value, str) else value
