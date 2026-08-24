from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.schemas.auth_schema import RegisterRequest
from src.models.user_model import User
from src.services.user_service import get_user_by_email, get_user_by_username
from src.utils.security import create_access_token, hash_password, verify_password


async def register_service(db: AsyncSession, payload: RegisterRequest) -> dict:
    try:
        if await get_user_by_username(db, payload.username):
            return {"error": True, "message": "Username already taken"}

        if await get_user_by_email(db, payload.email):
            return {"error": True, "message": "Email already registered"}

        user = User(
            username=payload.username,
            email=payload.email,
            hashed_password=hash_password(payload.password),
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)

        return {"error": False, "user": user}
    except Exception as e:
        await db.rollback()
        return {"error": True, "message": f"Registration failed: {str(e)}"}


async def login_service(db: AsyncSession, identifier: str, password: str) -> dict:
    try:
        user = await get_user_by_username(db, identifier)
        if user is None:
            user = await get_user_by_email(db, identifier)

        if user is None or not verify_password(password, user.hashed_password):
            return {"error": True, "message": "Incorrect username or password"}

        token = create_token_for_user(user)
        return {"error": False, "token": token}
    except Exception as e:
        await db.rollback()
        return {"error": True, "message": f"Login failed: {str(e)}"}


def create_token_for_user(user: User) -> str:
    return create_access_token(str(user.id))
