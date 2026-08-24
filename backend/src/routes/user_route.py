from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from src.config.database import get_db
from src.schemas.user_schema import public_user, serialize_user
from src.services.user_service import (
    get_user_by_id,
    leaderboard_service,
    update_profile_service,
)
from src.utils.deps import get_current_user
from src.utils.response import StatusCode, api_response_error, api_response_success

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/leaderboard")
async def get_leaderboard(db: AsyncSession = Depends(get_db)):
    users = await leaderboard_service(db)
    return api_response_success(
        data=[public_user(u) for u in users],
        message="Leaderboard fetched successfully",
    )


@router.get("/me")
async def my_profile(current_user=Depends(get_current_user)):
    return api_response_success(data=serialize_user(current_user))


@router.patch("/me")
async def update_me(
    payload: dict,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await update_profile_service(db, current_user, payload.get("avatar"))
    if result["error"]:
        return api_response_error(message=result["message"], status_code=StatusCode.badRequest)
    return api_response_success(
        data=serialize_user(result["user"]),
        message="Profile updated successfully",
    )


@router.get("/{user_id}")
async def get_user(user_id: int, db: AsyncSession = Depends(get_db)):
    user = await get_user_by_id(db, user_id)
    if user is None:
        return api_response_error(message="User not found", status_code=StatusCode.notFound)
    return api_response_success(data=serialize_user(user), message="User fetched successfully")
