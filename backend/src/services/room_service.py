from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload, selectinload

from src.models.room_model import Room, RoomPlayer
from src.models.user_model import User
from src.schemas.room_schema import RoomCreate
from src.utils.helpers import generate_room_code

COLOR_CYCLE = ["red", "green", "yellow", "blue"]


def serialize_room(room: Room) -> dict:
    return {
        "id": room.id,
        "code": room.code,
        "name": room.name,
        "host_id": room.host_id,
        "max_players": room.max_players,
        "bet_amount": room.bet_amount,
        "status": room.status,
        "created_at": str(room.created_at),
        "players": [
            {
                "id": p.id,
                "user_id": p.user_id,
                "username": p.user.username if p.user else "?",
                "avatar": p.user.avatar if p.user else "",
                "color": p.color,
                "seat": p.seat,
                "is_ready": p.is_ready,
            }
            for p in sorted(room.players, key=lambda x: x.seat)
        ],
    }


async def get_room_by_code(db: AsyncSession, code: str) -> dict:
    result = await db.execute(
        select(Room)
        .where(Room.code == code.upper())
        .options(selectinload(Room.players).joinedload(RoomPlayer.user))
    )
    room = result.scalar_one_or_none()
    if room is None:
        return {"error": True, "message": "Room not found", "status": 404}
    return {"error": False, "room": room}


async def create_room_service(db: AsyncSession, user: User, payload: RoomCreate) -> dict:
    try:
        code = await generate_room_code(db)
        room = Room(
            code=code,
            name=payload.name,
            host_id=user.id,
            max_players=payload.max_players,
            bet_amount=payload.bet_amount,
        )
        db.add(room)
        await db.flush()

        player = RoomPlayer(
            room_id=room.id,
            user_id=user.id,
            color=COLOR_CYCLE[0],
            seat=0,
            is_ready=True,
        )
        db.add(player)
        await db.commit()
        await db.refresh(room)

        refreshed = await get_room_by_code(db, room.code)
        return {"error": False, "data": serialize_room(refreshed["room"])}
    except Exception as e:
        await db.rollback()
        return {"error": True, "message": f"Room creation failed: {str(e)}", "status": 500}


async def join_room_service(db: AsyncSession, user: User, code: str) -> dict:
    try:
        fetched = await get_room_by_code(db, code)
        if fetched["error"]:
            return fetched
        room = fetched["room"]

        if room.status != "waiting":
            return {"error": True, "message": "Room is not accepting players", "status": 400}

        existing = next((p for p in room.players if p.user_id == user.id), None)
        if existing:
            return {"error": False, "data": serialize_room(room)}

        if len(room.players) >= room.max_players:
            return {"error": True, "message": "Room is full", "status": 400}

        used_colors = {p.color for p in room.players}
        used_seats = {p.seat for p in room.players}
        color = next((c for c in COLOR_CYCLE if c not in used_colors), None)
        seat = next((s for s in range(room.max_players) if s not in used_seats), 0)

        db.add(RoomPlayer(room_id=room.id, user_id=user.id, color=color, seat=seat))
        await db.commit()

        refreshed = await get_room_by_code(db, room.code)
        return {"error": False, "data": serialize_room(refreshed["room"])}
    except Exception as e:
        await db.rollback()
        return {"error": True, "message": f"Join failed: {str(e)}", "status": 500}


async def toggle_ready_service(db: AsyncSession, user: User, code: str) -> dict:
    try:
        fetched = await get_room_by_code(db, code)
        if fetched["error"]:
            return fetched
        room = fetched["room"]

        player = next((p for p in room.players if p.user_id == user.id), None)
        if player is None:
            return {"error": True, "message": "You are not in this room", "status": 403}

        player.is_ready = not player.is_ready
        await db.commit()
        return {"error": False, "data": serialize_room(room)}
    except Exception as e:
        await db.rollback()
        return {"error": True, "message": f"Ready toggle failed: {str(e)}", "status": 500}


async def leave_room_service(db: AsyncSession, user: User, code: str) -> dict:
    try:
        fetched = await get_room_by_code(db, code)
        if fetched["error"]:
            return fetched
        room = fetched["room"]

        player = next((p for p in room.players if p.user_id == user.id), None)
        if player is None:
            return {"error": True, "message": "You are not in this room", "status": 404}

        remaining = [p for p in room.players if p.user_id != user.id]
        await db.delete(player)

        if not remaining:
            await db.delete(room)
            await db.commit()
            return {"error": False, "data": {"code": code, "status": "closed"}}

        if room.host_id == user.id:
            room.host_id = remaining[0].user_id

        await db.commit()
        return {"error": False, "data": serialize_room(room)}
    except Exception as e:
        await db.rollback()
        return {"error": True, "message": f"Leave failed: {str(e)}", "status": 500}


async def open_rooms_service(db: AsyncSession) -> list[dict]:
    result = await db.execute(
        select(Room)
        .where(Room.status == "waiting")
        .order_by(Room.created_at.desc())
        .limit(50)
        .options(selectinload(Room.players).joinedload(RoomPlayer.user))
    )
    rooms = result.scalars().all()
    return [serialize_room(r) for r in rooms]
