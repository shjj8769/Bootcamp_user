"""Request schemas for authentication endpoints."""

from pydantic import BaseModel, ConfigDict, EmailStr, Field, SecretStr, field_validator


class LoginCustomer(BaseModel):
    model_config = ConfigDict(extra="forbid", hide_input_in_errors=True)

    email: EmailStr = Field(max_length=254)
    password: SecretStr = Field(min_length=6, max_length=128)

    @field_validator("email", mode="before")
    @classmethod
    def trim_email(cls, value):
        return value.strip() if isinstance(value, str) else value


class PasswordUpdateCustomer(BaseModel):
    model_config = ConfigDict(extra="forbid", hide_input_in_errors=True)

    email: EmailStr = Field(max_length=254)
    current_password: SecretStr = Field(min_length=6, max_length=128)
    new_password: SecretStr = Field(min_length=6, max_length=128)

    @field_validator("email", mode="before")
    @classmethod
    def trim_email(cls, value):
        return value.strip() if isinstance(value, str) else value


class Customer(BaseModel):
    """Member registration payload. SecretStr masks repr; it does not hash."""

    model_config = ConfigDict(extra="forbid", hide_input_in_errors=True)

    email: EmailStr = Field(max_length=45)
    password: SecretStr = Field(min_length=6, max_length=128)
    tel: str = Field(min_length=1, max_length=30)
    c_name: str = Field(min_length=1, max_length=45)
    c_gender: str = Field(min_length=1, max_length=20)
    c_address: str = Field(min_length=1, max_length=45)
    c_path: str = Field(default="", max_length=2048)
    c_size: str = Field(min_length=1, max_length=20)

    @field_validator(
        "email", "tel", "c_name", "c_gender", "c_address", "c_size", mode="before"
    )
    @classmethod
    def trim_text(cls, value):
        return value.strip() if isinstance(value, str) else value
