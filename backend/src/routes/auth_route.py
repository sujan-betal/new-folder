from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from src.config.database import get_db
from src.schemas.auth_schema import LoginRequest, RegisterRequest
from src.schemas.user_schema import serialize_user
from src.services.auth_service import login_service, register_service
from src.services.social_service import (
    facebook_login_service,
    google_login_service,
    guest_login_service,
)
from src.utils.deps import get_current_user
from src.utils.response import StatusCode, api_response_error, api_response_success

router = APIRouter(prefix="/auth", tags=["auth"])


class SocialTokenRequest(BaseModel):
    token: str


@router.post("/register")
async def register(payload: RegisterRequest, db: AsyncSession = Depends(get_db)):
    result = await register_service(db, payload)
    if result["error"]:
        return api_response_error(
            message=result["message"],
            status_code=StatusCode.conflict,
        )
    return api_response_success(
        data=serialize_user(result["user"]),
        message="Account created successfully",
        status_code=StatusCode.created,
    )


@router.post("/login")
async def login(payload: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await login_service(db, payload.identifier, payload.password)
    if result["error"]:
        return api_response_error(
            message=result["message"],
            status_code=StatusCode.unauthorized,
        )
    return api_response_success(
        data={"access_token": result["token"], "token_type": "bearer"},
        message="Login successful",
    )


@router.get("/me")
async def me(current_user=Depends(get_current_user)):
    return api_response_success(
        data=serialize_user(current_user),
        message="User profile fetched successfully",
    )


@router.post("/logout")
async def logout():
    return api_response_success(message="Logged out successfully")


@router.post("/guest")
async def guest(db: AsyncSession = Depends(get_db)):
    result = await guest_login_service(db)
    if result["error"]:
        return api_response_error(message=result["message"], status_code=StatusCode.internalServerError)
    return api_response_success(
        data={
            "access_token": result["token"],
            "token_type": "bearer",
            "user": serialize_user(result["user"]),
        },
        message="Playing as guest",
    )


@router.post("/google")
async def google(payload: SocialTokenRequest, db: AsyncSession = Depends(get_db)):
    result = await google_login_service(db, payload.token)
    if result["error"]:
        return api_response_error(message=result["message"], status_code=StatusCode.unauthorized)
    return api_response_success(
        data={
            "access_token": result["token"],
            "token_type": "bearer",
            "user": serialize_user(result["user"]),
        },
        message="Google login successful",
    )


@router.post("/facebook")
async def facebook(payload: SocialTokenRequest, db: AsyncSession = Depends(get_db)):
    result = await facebook_login_service(db, payload.token)
    if result["error"]:
        return api_response_error(message=result["message"], status_code=StatusCode.unauthorized)
    return api_response_success(
        data={
            "access_token": result["token"],
            "token_type": "bearer",
            "user": serialize_user(result["user"]),
        },
        message="Facebook login successful",
    )
