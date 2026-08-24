from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from src.config.database import get_db
from src.schemas.auth_schema import LoginRequest, RegisterRequest
from src.services.auth_service import login_service, register_service
from src.schemas.user_schema import serialize_user
from src.utils.deps import get_current_user
from src.utils.response import StatusCode, api_response_error, api_response_success

router = APIRouter(prefix="/auth", tags=["auth"])


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
