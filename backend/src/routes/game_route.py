from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from src.config.database import get_db
from src.schemas.game_schema import GameStartRequest, MoveRequest
from src.services.game_service import (
    game_history_service,
    get_game_by_id,
    make_move_service,
    roll_dice_service,
    serialize_game,
    start_game_service,
)
from src.utils.deps import get_current_user
from src.utils.response import StatusCode, api_response_error, api_response_success

router = APIRouter(prefix="/games", tags=["games"])


@router.post("/start")
async def start(payload: GameStartRequest, current_user=Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    result = await start_game_service(db, current_user, payload.mode, payload.room_code)
    if result["error"]:
        return api_response_error(
            message=result.get("message", "Failed to start"),
            status_code=result.get("status", StatusCode.badRequest),
        )
    return api_response_success(data=result["data"], message="Game started successfully")


@router.get("/history")
async def history(current_user=Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    result = await game_history_service(db, current_user)
    if result["error"]:
        return api_response_error(
            message=result.get("message", "History failed"),
            status_code=result.get("status", StatusCode.internalServerError),
        )
    return api_response_success(data=result["data"], message="Match history fetched successfully")


@router.get("/{game_id}")
async def get_one(game_id: int, db: AsyncSession = Depends(get_db)):
    game = await get_game_by_id(db, game_id)
    if game is None:
        return api_response_error(message="Game not found", status_code=StatusCode.notFound)
    return api_response_success(data=serialize_game(game), message="Game fetched successfully")


@router.post("/{game_id}/roll")
async def roll(game_id: int, current_user=Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    result = await roll_dice_service(db, current_user, game_id)
    if result["error"]:
        return api_response_error(
            message=result.get("message", "Roll failed"),
            status_code=result.get("status", StatusCode.badRequest),
        )
    return api_response_success(data=result["data"], message="Dice rolled")


@router.post("/{game_id}/move")
async def move(
    game_id: int,
    payload: MoveRequest,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await make_move_service(db, current_user, game_id, payload.token_index)
    if result["error"]:
        return api_response_error(
            message=result.get("message", "Move failed"),
            status_code=result.get("status", StatusCode.badRequest),
        )
    return api_response_success(data=result["data"], message="Move applied")
