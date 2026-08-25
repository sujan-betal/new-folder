from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from src.config.database import get_db
from src.schemas.user_schema import serialize_user
from src.services.shop_service import purchase_item_service, shop_items_service
from src.utils.deps import get_current_user
from src.utils.response import StatusCode, api_response_error, api_response_success

router = APIRouter(prefix="/shop", tags=["shop"])


class PurchaseRequest(BaseModel):
    item_id: str


@router.get("/items")
async def items(
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await shop_items_service(db, current_user)
    if result["error"]:
        return api_response_error(message=result.get("message", "Shop failed"), status_code=StatusCode.internalServerError)
    return api_response_success(data=result["items"], message="Shop items fetched successfully")


@router.post("/purchase")
async def purchase(
    payload: PurchaseRequest,
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await purchase_item_service(db, current_user, payload.item_id)
    if result["error"]:
        return api_response_error(
            message=result.get("message", "Purchase failed"),
            status_code=result.get("status", StatusCode.badRequest),
        )
    return api_response_success(
        data={
            "user": serialize_user(result["user"]),
            "item": result["item"],
            "owned": sorted(result["owned"]),
        },
        message=f"Purchased {result['item']['label']}!",
    )
