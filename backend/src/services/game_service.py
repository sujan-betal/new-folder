import random

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from sqlalchemy.orm.attributes import flag_modified

from src.models.game_model import Game, MatchResult, Move
from src.models.room_model import Room, RoomPlayer
from src.models.user_model import User
from src.services.user_service import add_rewards
from src.utils import ludo_engine

BOT_USERNAME = "__cpu_bot__"
MAX_SIX_STREAK = 3


def serialize_game(game: Game) -> dict:
    return {
        "id": game.id,
        "room_id": game.room_id,
        "mode": game.mode,
        "status": game.status,
        "current_turn": game.current_turn,
        "dice_value": game.dice_value,
        "winner_id": game.winner_id,
        "state": game.state,
    }


async def get_game_by_id(db: AsyncSession, game_id: int) -> Game | None:
    result = await db.execute(select(Game).where(Game.id == game_id))
    return result.scalar_one_or_none()


async def _get_or_create_bot(db: AsyncSession) -> User:
    result = await db.execute(select(User).where(User.username == BOT_USERNAME))
    bot = result.scalar_one_or_none()
    if bot is None:
        bot = User(
            username=BOT_USERNAME,
            email="cpu@ludo.local",
            hashed_password="-",
            avatar="\U0001F916",
        )
        db.add(bot)
        await db.flush()
    return bot


def _participant_for_user(game: Game, user_id: int) -> dict | None:
    for p in game.state.get("participants", []):
        if p["user_id"] == user_id and not p.get("is_bot", False):
            return p
    return None


async def start_game_service(db: AsyncSession, user: User, mode: str, room_code: str | None) -> dict:
    try:
        if mode == "online":
            room_result = await db.execute(
                select(Room).where(Room.code == (room_code or "").upper())
            )
            room = room_result.scalar_one_or_none()
            if room is None:
                return {"error": True, "message": "Room not found", "status": 404}

            players_result = await db.execute(
                select(RoomPlayer)
                .where(RoomPlayer.room_id == room.id, RoomPlayer.color.isnot(None))
                .options(selectinload(RoomPlayer.user))
            )
            players = list(players_result.scalars().all())

            if len(players) < 2:
                return {"error": True, "message": "Need at least 2 players to start", "status": 400}
            if room.host_id != user.id:
                return {"error": True, "message": "Only the host can start the game", "status": 403}

            participants = [
                {
                    "color": p.color,
                    "user_id": p.user_id,
                    "is_bot": False,
                    "username": p.user.username if p.user else f"Player {p.seat + 1}",
                    "avatar": (p.user.avatar if p.user else "") or "\U0001F3B2",
                }
                for p in sorted(players, key=lambda x: x.seat)
            ]
            state = ludo_engine.initial_state(participants)
            game = Game(room_id=room.id, mode="online", state=state)
            room.status = "playing"
        else:
            bot = await _get_or_create_bot(db)
            participants = [
                {
                    "color": "red",
                    "user_id": user.id,
                    "is_bot": False,
                    "username": user.username,
                    "avatar": user.avatar or "\U0001F3B2",
                },
                {
                    "color": "blue",
                    "user_id": bot.id,
                    "is_bot": True,
                    "username": "CPU",
                    "avatar": "\U0001F916",
                },
            ]
            state = ludo_engine.initial_state(participants)
            game = Game(mode="computer", state=state)

        db.add(game)
        await db.commit()
        await db.refresh(game)

        return {"error": False, "data": serialize_game(game)}
    except Exception as e:
        await db.rollback()
        return {"error": True, "message": f"Failed to start game: {str(e)}", "status": 500}


async def roll_dice_service(db: AsyncSession, user: User, game_id: int) -> dict:
    try:
        game = await get_game_by_id(db, game_id)
        if game is None:
            return {"error": True, "message": "Game not found", "status": 404}
        if game.status != "active":
            return {"error": True, "message": "Game is over", "status": 400}

        me = _participant_for_user(game, user.id)
        if me is None:
            return {"error": True, "message": "You are not part of this game", "status": 403}

        color = me["color"]
        if game.current_turn != color:
            return {"error": True, "message": "Not your turn", "status": 400}

        dice = ludo_engine.roll_dice()
        legal = ludo_engine.legal_moves(game.state["tokens"][color], dice)

        extra_turn = True
        if dice == 6:
            game.six_streak += 1
            if game.six_streak >= MAX_SIX_STREAK:
                game.six_streak = 0
                extra_turn = False
                legal = []
        else:
            game.six_streak = 0

        if not legal:
            extra_turn = False
        else:
            game.dice_value = dice

        if not extra_turn:
            game.dice_value = None
            game.current_turn = ludo_engine.next_turn(
                game.state["participants"], color, game.state
            )

        await db.commit()

        game = await _play_bot_turns(db, game)

        return {
            "error": False,
            "data": {
                "game_id": game.id,
                "color": color,
                "dice_value": game.dice_value if legal and extra_turn else 0,
                "legal_moves": legal if legal and extra_turn else [],
                "current_turn": game.current_turn,
                "status": game.status,
                "state": game.state,
            },
        }
    except Exception as e:
        await db.rollback()
        return {"error": True, "message": f"Roll failed: {str(e)}", "status": 500}


async def make_move_service(db: AsyncSession, user: User, game_id: int, token_index: int) -> dict:
    try:
        game = await get_game_by_id(db, game_id)
        if game is None:
            return {"error": True, "message": "Game not found", "status": 404}
        if game.status != "active":
            return {"error": True, "message": "Game is over", "status": 400}
        if game.dice_value is None:
            return {"error": True, "message": "Roll the dice first", "status": 400}

        me = _participant_for_user(game, user.id)
        if me is None:
            return {"error": True, "message": "You are not part of this game", "status": 403}

        color = me["color"]
        if game.current_turn != color:
            return {"error": True, "message": "Not your turn", "status": 400}

        legal = {
            m["token_index"]: m["to_pos"]
            for m in ludo_engine.legal_moves(game.state["tokens"][color], game.dice_value)
        }
        if token_index not in legal:
            return {"error": True, "message": "Illegal move", "status": 400}

        from_pos = game.state["tokens"][color][token_index]
        dice_used = game.dice_value
        result = ludo_engine.apply_move(game.state, color, token_index, dice_used)
        to_pos = game.state["tokens"][color][token_index]
        # JSON columns are not tracked for in-place mutations.
        flag_modified(game, "state")

        db.add(
            Move(
                game_id=game.id,
                user_id=user.id,
                color=color,
                dice_value=dice_used,
                token_index=token_index,
                from_pos=from_pos,
                to_pos=to_pos,
            )
        )

        if result["finished"]:
            await _finish_game(db, game, winner_color=color)
            return {"error": False, "data": serialize_game(game), "finished": True}

        extra_turn = dice_used == 6 or result["captured"] or result["reached_home"]

        if not extra_turn:
            game.current_turn = ludo_engine.next_turn(
                game.state["participants"], color, game.state
            )
            game.six_streak = 0

        game.dice_value = None
        await db.commit()

        game = await _play_bot_turns(db, game)

        return {
            "error": False,
            "data": serialize_game(game),
            "finished": game.status != "active",
        }
    except Exception as e:
        await db.rollback()
        return {"error": True, "message": f"Move failed: {str(e)}", "status": 500}


async def _play_bot_turns(db: AsyncSession, game: Game) -> Game:
    guard = 0
    while game.status == "active" and guard < 500:
        guard += 1
        current = next(
            (p for p in game.state["participants"] if p["color"] == game.current_turn),
            None,
        )
        if current is None or not current.get("is_bot"):
            break

        dice = ludo_engine.roll_dice()
        color = current["color"]
        legal = ludo_engine.legal_moves(game.state["tokens"][color], dice)

        if not legal:
            if dice != 6:
                game.current_turn = ludo_engine.next_turn(
                    game.state["participants"], color, game.state
                )
                await db.commit()
                await db.refresh(game)
            continue

        choice = random.choice(legal)
        token_index = choice["token_index"]
        from_pos = game.state["tokens"][color][token_index]
        result = ludo_engine.apply_move(game.state, color, token_index, dice)
        to_pos = game.state["tokens"][color][token_index]
        flag_modified(game, "state")

        db.add(
            Move(
                game_id=game.id,
                user_id=current["user_id"],
                color=color,
                dice_value=dice,
                token_index=token_index,
                from_pos=from_pos,
                to_pos=to_pos,
            )
        )

        if result["finished"]:
            await _finish_game(db, game, winner_color=color)
            break

        extra = dice == 6 or result["captured"] or result["reached_home"]
        if not extra:
            game.current_turn = ludo_engine.next_turn(
                game.state["participants"], color, game.state
            )

        await db.commit()
        await db.refresh(game)

    return game


async def _finish_game(db: AsyncSession, game: Game, winner_color: str) -> None:
    from datetime import datetime, timezone

    from src.config.app_config import APP_CONFIG

    rewards_cfg = APP_CONFIG["rewards"]
    game.status = "finished"
    game.finished_at = datetime.now(timezone.utc)
    game.dice_value = None

    participants = game.state["participants"]
    ranked = sorted(
        participants,
        key=lambda p: (
            -ludo_engine.progress(game.state["tokens"][p["color"]]),
            0 if all(t == ludo_engine.HOME_DONE for t in game.state["tokens"][p["color"]]) else 1,
        ),
    )

    placement_map: dict[str, int] = {}
    placement = 0
    previous = None
    for index, p in enumerate(ranked):
        progress_value = ludo_engine.progress(game.state["tokens"][p["color"]])
        if progress_value != previous:
            placement = index + 1
            previous = progress_value
        placement_map[p["color"]] = placement

    for p in participants:
        won = placement_map[p["color"]] == 1
        coins = (
            rewards_cfg["win_coins"] if won else rewards_cfg["participation_coins"]
        )
        xp = rewards_cfg["win_xp"] if won else rewards_cfg["participation_xp"]

        if not p.get("is_bot"):
            target_result = await db.execute(select(User).where(User.id == p["user_id"]))
            target = target_result.scalar_one_or_none()
            if target is not None:
                await add_rewards(db, target, coins, xp, won)

        db.add(
            MatchResult(
                game_id=game.id,
                user_id=p["user_id"],
                color=p["color"],
                placement=placement_map[p["color"]],
                coins_earned=coins,
                xp_earned=xp,
            )
        )

    winner = next((p for p in ranked if p["color"] == winner_color), None)
    game.winner_id = winner["user_id"] if winner else None

    if game.room_id:
        room_result = await db.execute(select(Room).where(Room.id == game.room_id))
        room = room_result.scalar_one_or_none()
        if room is not None:
            room.status = "finished"

    await db.commit()


async def game_history_service(db: AsyncSession, user: User) -> dict:
    try:
        result = await db.execute(
            select(MatchResult)
            .where(MatchResult.user_id == user.id)
            .order_by(MatchResult.created_at.desc())
            .limit(20)
        )
        results = list(result.scalars().all())

        data = [
            {
                "game_id": r.game_id,
                "color": r.color,
                "placement": r.placement,
                "coins_earned": r.coins_earned,
                "xp_earned": r.xp_earned,
                "played_at": str(r.created_at),
            }
            for r in results
        ]
        return {"error": False, "data": data}
    except Exception as e:
        await db.rollback()
        return {"error": True, "message": f"History failed: {str(e)}", "status": 500}
