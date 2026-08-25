from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import declarative_base

from src.config.settings import settings

def _build_engine_kwargs() -> dict:
    kwargs: dict = {"pool_pre_ping": True, "echo": False}
    if settings.DATABASE_URL.startswith("postgresql"):
        # psycopg-specific: avoid prepared-statement pooling issues with pgbouncer
        kwargs["connect_args"] = {"prepare_threshold": None}
    return kwargs


engine = create_async_engine(settings.DATABASE_URL, **_build_engine_kwargs())
AsyncSessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

Base = declarative_base()


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        yield session
