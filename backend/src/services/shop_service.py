"""Shop catalog and purchase logic.

The catalog lives on the server so items/prices can change without an app
release; clients always fetch it from GET /shop/items.
"""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.models.user_model import Purchase, User

# type "avatar" items are equippable via PATCH /users/me.
SHOP_ITEMS: list[dict] = [
    {"id": "av_dice", "type": "avatar", "emoji": "\U0001F3B2", "label": "Lucky Dice", "price_coins": 0, "price_gems": 0},
    {"id": "av_cat", "type": "avatar", "emoji": "\U0001F431", "label": "Cat", "price_coins": 150, "price_gems": 0},
    {"id": "av_fox", "type": "avatar", "emoji": "\U0001F98A", "label": "Fox", "price_coins": 250, "price_gems": 0},
    {"id": "av_panda", "type": "avatar", "emoji": "\U0001F43C", "label": "Panda", "price_coins": 400, "price_gems": 0},
    {"id": "av_unicorn", "type": "avatar", "emoji": "\U0001F984", "label": "Unicorn", "price_coins": 0, "price_gems": 25},
    {"id": "av_dragon", "type": "avatar", "emoji": "\U0001F409", "label": "Dragon", "price_coins": 800, "price_gems": 0},
    {"id": "av_alien", "type": "avatar", "emoji": "\U0001F47D", "label": "Alien", "price_coins": 0, "price_gems": 60},
    {"id": "av_robot", "type": "avatar", "emoji": "\U0001F916", "label": "Robot", "price_coins": 500, "price_gems": 0},
    {"id": "av_king", "type": "avatar", "emoji": "\U0001F934", "label": "King", "price_coins": 1200, "price_gems": 0},
    {"id": "av_mage", "type": "avatar", "emoji": "\U0001F9D9", "label": "Mage", "price_coins": 0, "price_gems": 90},
]

FREE_ITEM_IDS = {item["id"] for item in SHOP_ITEMS if item["price_coins"] == 0 and item["price_gems"] == 0}


def serialize_item(item: dict) -> dict:
    return dict(item)


def find_item(item_id: str) -> dict | None:
    return next((i for i in SHOP_ITEMS if i["id"] == item_id), None)


async def owned_item_ids(db: AsyncSession, user_id: int) -> set[str]:
    result = await db.execute(select(Purchase.item_id).where(Purchase.user_id == user_id))
    return {row for row in result.scalars().all()}


async def is_avatar_unlocked(db: AsyncSession, user: User, emoji: str) -> bool:
    """An avatar emoji is usable when its catalog item is free or purchased."""
    item = next((i for i in SHOP_ITEMS if i["emoji"] == emoji), None)
    if item is None:
        return False
    if item["id"] in FREE_ITEM_IDS:
        return True
    return item["id"] in await owned_item_ids(db, user.id)


def serialize_shop(user: User, owned: set[str]) -> list[dict]:
    return [
        {
            **item,
            "owned": item["id"] in owned or item["id"] in FREE_ITEM_IDS,
            "equipped": user.avatar == item["emoji"],
        }
        for item in SHOP_ITEMS
    ]


async def purchase_item_service(db: AsyncSession, user: User, item_id: str) -> dict:
    item = find_item(item_id)
    if item is None:
        return {"error": True, "message": "Item not found", "status": 404}

    owned = await owned_item_ids(db, user.id)
    if item["id"] in owned or item["id"] in FREE_ITEM_IDS:
        return {"error": True, "message": "You already own this item", "status": 400}

    if user.coins < item["price_coins"]:
        return {"error": True, "message": "Not enough coins", "status": 400}
    if user.gems < item["price_gems"]:
        return {"error": True, "message": "Not enough gems", "status": 400}

    user.coins -= item["price_coins"]
    user.gems -= item["price_gems"]
    db.add(
        Purchase(
            user_id=user.id,
            item_id=item["id"],
            price_coins=item["price_coins"],
            price_gems=item["price_gems"],
        )
    )
    try:
        await db.commit()
        await db.refresh(user)
    except Exception as e:
        await db.rollback()
        return {"error": True, "message": f"Purchase failed: {str(e)}", "status": 500}

    return {
        "error": False,
        "user": user,
        "item": item,
        "owned": await owned_item_ids(db, user.id),
    }


async def shop_items_service(db: AsyncSession, user: User) -> dict:
    owned = await owned_item_ids(db, user.id)
    return {"error": False, "items": serialize_shop(user, owned)}
