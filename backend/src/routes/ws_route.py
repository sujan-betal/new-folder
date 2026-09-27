import json

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from src.config.database import get_db
from src.models.game_model import Game
from src.models.room_model import Room, RoomPlayer
from src.models.user_model import User
from src.services.game_service import serialize_game
from src.services.room_service import serialize_room
from src.utils.security import decode_token
from src.utils.ws_hub import subscribe, unsubscribe

router = APIRouter(prefix="/ws", tags=["websocket"])


async def _authenticate(websocket: WebSocket) -> User | None:
    """Extract the Bearer token from the Authorization header or ?token=."""
    token: str | None = None

    header = websocket.headers.get("authorization", "")
    if header.lower().startswith("bearer "):
        token = header[7:].strip()
    if not token:
        raw = websocket.query_params.get("token")
        if raw:
            token = raw.strip()

    if not token:
        return None
    payload = decode_token(token)
    if payload is None or "sub" not in payload:
        return None

    async for db in get_db():
        result = await db.execute(select(User).where(User.id == int(payload["sub"])))
        user = result.scalar_one_or_none()
        return user if (user and user.is_active) else None
    return None


async def _require_player_in_room(db: AsyncSession, user: User, room: Room) -> bool:
    result = await db.execute(
        select(RoomPlayer).where(
            RoomPlayer.room_id == room.id,
            RoomPlayer.user_id == user.id,
        )
    )
    return result.scalar_one_or_none() is not None


async def _require_player_in_game(db: AsyncSession, user: User, game: Game) -> bool:
    for p in game.state.get("participants", []):
        if p["user_id"] == user.id and not p.get("is_bot", False):
            return True
    return False


async def _load_room(db: AsyncSession, code: str) -> Room | None:
    result = await db.execute(
        select(Room)
        .where(Room.code == code.upper())
        .options(selectinload(Room.players).joinedload(RoomPlayer.user))
    )
    return result.scalar_one_or_none()


async def _attach_active_game(db: AsyncSession, room: Room) -> None:
    game_result = await db.execute(
        select(Game.id)
        .where(Game.room_id == room.id, Game.status == "active")
        .order_by(Game.started_at.desc())
        .limit(1)
    )
    room.active_game_id = game_result.scalar_one_or_none()


async def _room_snapshot(db: AsyncSession, room: Room) -> dict:
    await _attach_active_game(db, room)
    return serialize_room(room)


@router.websocket("/room/{code}")
async def room_stream(websocket: WebSocket, code: str) -> None:
    user = await _authenticate(websocket)
    if user is None:
        await websocket.close(code=4001, reason="Unauthorized")
        return

    topic = f"room:{code.upper()}"

    async for db in get_db():
        room = await _load_room(db, code)
        if room is None or not await _require_player_in_room(db, user, room):
            await websocket.close(code=4004, reason="Not in room")
            return
        await websocket.accept()
        sent = await subscribe(topic, websocket)
        # Retained payload (if any) is sent by subscribe(); otherwise push a
        # fresh snapshot so the client is guaranteed up to date.
        if not sent:
            await websocket.send_text(
                json.dumps({"kind": "room", "room": await _room_snapshot(db, room)})
            )
        break

    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        await unsubscribe(topic, websocket)


@router.websocket("/game/{game_id:int}")
async def game_stream(websocket: WebSocket, game_id: int) -> None:
    user = await _authenticate(websocket)
    if user is None:
        await websocket.close(code=4001, reason="Unauthorized")
        return

    topic = f"game:{game_id}"

    async for db in get_db():
        result = await db.execute(select(Game).where(Game.id == game_id))
        game = result.scalar_one_or_none()
        if game is None or not await _require_player_in_game(db, user, game):
            await websocket.close(code=4004, reason="Not in game")
            return
        await websocket.accept()
        sent = await subscribe(topic, websocket)
        if not sent:
            await websocket.send_text(
                json.dumps({"kind": "game", "game": serialize_game(game)})
            )
        break

    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        await unsubscribe(topic, websocket)