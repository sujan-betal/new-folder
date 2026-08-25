import asyncio
import sys
from contextlib import asynccontextmanager

import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

if sys.platform == "win32":
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

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
    uvicorn.run("src.server:app", host="0.0.0.0", port=8000, reload=True)
