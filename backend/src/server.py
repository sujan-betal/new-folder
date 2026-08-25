import asyncio
import os
import sys
from contextlib import asynccontextmanager
from pathlib import Path

# Allow starting both ways:  python -m src.server   |   python src/server.py
_BACKEND_ROOT = str(Path(__file__).resolve().parents[1])
if _BACKEND_ROOT not in sys.path:
    sys.path.insert(0, _BACKEND_ROOT)

if sys.platform == "win32":
    # psycopg async mode requires a selector loop. This must be set BEFORE any
    # event loop is created, i.e. before uvicorn boots the app.
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from src.config.database import Base, engine
from src.config.settings import settings
from src.routes.auth_route import router as auth_router
from src.models.game_model import Game, MatchResult, Move  # noqa: F401
from src.routes.game_route import router as game_router
from src.models.room_model import Room, RoomPlayer  # noqa: F401
from src.routes.room_route import router as room_router
from src.models.user_model import Purchase, User  # noqa: F401
from src.routes.user_route import router as user_router
from src.routes.shop_route import router as shop_router
from src.routes.config_route import router as config_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    await engine.dispose()


def create_app() -> FastAPI:
    application = FastAPI(title=settings.PROJECT_NAME, lifespan=lifespan)

    application.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    for router in (auth_router, user_router, room_router, game_router, shop_router, config_router):
        application.include_router(router, prefix=settings.API_V1_PREFIX)

    @application.get(f"{settings.API_V1_PREFIX}/health", tags=["health"])
    async def health():
        return {"success": True, "message": "API is running", "data": None}

    return application


app = create_app()


if __name__ == "__main__":
    # NOTE: do NOT start this file via `uvicorn src.server:app` on Windows.
    # Recent uvicorn versions force a ProactorEventLoop there, which breaks
    # psycopg async. Starting from here keeps our selector-loop policy.
    port = int(os.getenv("PORT", str(settings.PORT)))
    config = uvicorn.Config(
        app,
        host="0.0.0.0",
        port=port,
        loop="none",  # respect the policy set above instead of uvicorn's proactor default
        log_level="info",
    )
    server = uvicorn.Server(config)
    server.run()
