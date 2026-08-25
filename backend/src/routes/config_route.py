from fastapi import APIRouter

from src.config.app_config import APP_CONFIG

router = APIRouter(prefix="/config", tags=["config"])


@router.get("/app")
async def app_config():
    return {
        "success": True,
        "message": "App config fetched successfully",
        "data": APP_CONFIG,
    }
