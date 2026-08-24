from pydantic import BaseModel, EmailStr, Field


class RegisterRequest(BaseModel):
    username: str = Field(min_length=3, max_length=30)
    email: EmailStr
    password: str = Field(min_length=6, max_length=72)


class LoginRequest(BaseModel):
    identifier: str
    password: str


class TokenData(BaseModel):
    access_token: str
    token_type: str = "bearer"
