from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from src.config.database import get_db
from src.schemas.room_schema import RoomCreate, RoomJoin
from src.services.room_service import (
    create_room_service,
    get_room_by_code,
    join_room_service,
    leave_room_service,
    open_rooms_service,
    serialize_room,
    toggle_ready_service,
)
from src.utils.deps import get_current_user
from src.utils.response import StatusCode, api_response_error, api_response_success

router = APIRouter(prefix="/rooms", tags=["rooms"])


class ReadyRequest(BaseModel):
    pass


@router.post("")
async def create(payload: RoomCreate, current_user=Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    result = await create_room_service(db, current_user, payload)
    if result["error"]:
        return api_response_error(
            message=result.get("message", "Room creation failed"),
            status_code=result.get("status", StatusCode.internalServerError),
        )
    return api_response_success(data=result["data"], message="Room created successfully", status_code=StatusCode.created)


@router.post("/join")
async def join(payload: RoomJoin, current_user=Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    result = await join_room_service(db, current_user, payload.code)
    if result["error"]:
        return api_response_error(
            message=result.get("message", "Join failed"),
            status_code=result.get("status", StatusCode.badRequest),
        )
    return api_response_success(data=result["data"], message="Joined room successfully")


@router.get("/open")
async def open_rooms(db: AsyncSession = Depends(get_db)):
    rooms = await open_rooms_service(db)
    return api_response_success(data=rooms, message="Open rooms fetched successfully")


@router.get("/{code}")
async def get_one(code: str, db: AsyncSession = Depends(get_db)):
    result = await get_room_by_code(db, code)
    if result["error"]:
        return api_response_error(message=result["message"], status_code=StatusCode.notFound)
    return api_response_success(data=serialize_room(result["room"]), message="Room fetched successfully")


@router.post("/{code}/ready")
async def ready(code: str, current_user=Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    result = await toggle_ready_service(db, current_user, code)
    if result["error"]:
        return api_response_error(
            message=result.get("message", "Ready toggle failed"),
            status_code=result.get("status", StatusCode.badRequest),
        )
    return api_response_success(data=result["data"], message="Ready status updated")


@router.post("/{code}/leave")
async def leave(code: str, current_user=Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    result = await leave_room_service(db, current_user, code)
    if result["error"]:
        return api_response_error(
            message=result.get("message", "Leave failed"),
            status_code=result.get("status", StatusCode.badRequest),
        )
    return api_response_success(data=result["data"], message="Left room successfully")
