from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.models.user_model import User


async def get_user_by_id(db: AsyncSession, user_id: int) -> User | None:
    result = await db.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()


async def get_user_by_username(db: AsyncSession, username: str) -> User | None:
    result = await db.execute(select(User).where(User.username == username))
    return result.scalar_one_or_none()

async def get_user_by_email(db: AsyncSession, email: str) -> User | None:
    result = await db.execute(select(User).where(User.email == email))
    return result.scalar_one_or_none()


async def update_profile_service(db: AsyncSession, user: User, avatar: str | None) -> dict:
    try:
        if avatar is not None:
            user.avatar = avatar
            await db.commit()
            await db.refresh(user)
        return {"error": False, "user": user}
    except Exception as e:
        await db.rollback()
        return {"error": True, "message": f"Profile update failed: {str(e)}"}


async def leaderboard_service(db: AsyncSession, limit: int = 20) -> list[User]:
    try:
        result = await db.execute(
            select(User).order_by(User.wins.desc(), User.level.desc()).limit(limit)
        )
        return list(result.scalars().all())
    except Exception:
        await db.rollback()
        return []


async def add_rewards(
    db: AsyncSession,
    user: User,
    coins: int,
    xp: int,
    won: bool,
) -> None:
    user.coins += coins
    user.xp += xp
    if won:
        user.wins += 1
    else:
        user.losses += 1
    while user.xp >= user.level * 100:
        user.xp -= user.level * 100
        user.level += 1
    db.add(user)
