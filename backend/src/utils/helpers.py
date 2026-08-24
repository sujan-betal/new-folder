import secrets
import string

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.models.room_model import Room

CODE_ALPHABET = string.ascii_uppercase + string.digits


async def generate_room_code(db: AsyncSession) -> str:
    while True:
        code = "".join(secrets.choice(CODE_ALPHABET) for _ in range(6))
        result = await db.execute(select(Room).where(Room.code == code))
        if result.scalar_one_or_none() is None:
            return code
