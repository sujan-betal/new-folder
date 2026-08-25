"""End-to-end smoke test: real API, scratch SQLite DB.

Runs the full dynamic journey:
register -> shop catalog -> purchase -> equip avatar -> config ->
start game vs CPU -> roll -> move -> poll state -> history.
"""

import asyncio
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

os.environ["DATABASE_URL"] = "sqlite+aiosqlite:///./_smoke_test.db"

from httpx import AsyncClient, ASGITransport  # noqa: E402

from src.config.database import Base, engine  # noqa: E402
from src.server import app  # noqa: E402


async def main() -> None:
    # The httpx ASGITransport does not run FastAPI lifespan, so create tables.
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Health + public config
        r = await client.get("/api/v1/health")
        assert r.json()["success"] is True
        r = await client.get("/api/v1/config/app")
        assert "announcement" in r.json()["data"], "config endpoint broken"
        print("[ok] health + config/app")

        # Register then login (token comes from /auth/login)
        import random
        suffix = random.randint(1000, 999999)
        creds = {"username": f"smoke{suffix}", "email": f"smoke{suffix}@test.io", "password": "Secret123!"}
        r = await client.post("/api/v1/auth/register", json=creds)
        body = r.json()
        assert body["success"], body

        r = await client.post("/api/v1/auth/login", json={"identifier": creds["username"], "password": creds["password"]})
        body = r.json()
        assert body["success"], body
        token = body["data"]["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        me = (await client.get("/api/v1/users/me", headers=headers)).json()["data"]
        user_id = me["id"]
        coins_before = me["coins"]
        print(f"[ok] register+login user_id={user_id} coins={coins_before}")

        # Shop catalog requires auth and embeds ownership flags
        r = await client.get("/api/v1/shop/items", headers=headers)
        items = r.json()["data"]
        assert any(i["id"] == "av_dice" and i["owned"] for i in items), "free item not owned"
        cat = next(i for i in items if i["id"] == "av_cat")
        assert cat["owned"] is False and cat["price_coins"] > 0
        print(f"[ok] shop items fetched ({len(items)}), av_cat locked at {cat['price_coins']} coins")

        # Equipping a locked avatar must fail
        r = await client.patch("/api/v1/users/me", json={"avatar": cat["emoji"]}, headers=headers)
        assert r.json()["success"] is False, "lock bypassed!"
        print("[ok] locked avatar equip rejected")

        # Purchase it
        r = await client.post("/api/v1/shop/purchase", json={"item_id": "av_cat"}, headers=headers)
        body = r.json()
        assert body["success"], body
        coins_after = body["data"]["user"]["coins"]
        assert coins_after == coins_before - cat["price_coins"]
        print(f"[ok] purchased av_cat; coins {coins_before} -> {coins_after}")

        # Double purchase must fail
        r = await client.post("/api/v1/shop/purchase", json={"item_id": "av_cat"}, headers=headers)
        assert r.json()["success"] is False
        print("[ok] duplicate purchase rejected")

        # Equip now works
        r = await client.patch("/api/v1/users/me", json={"avatar": cat["emoji"]}, headers=headers)
        assert r.json()["success"] and r.json()["data"]["avatar"] == cat["emoji"]
        print("[ok] avatar equipped")

        # Start vs-CPU game - participants must carry username/avatar
        r = await client.post("/api/v1/games/start", json={"mode": "computer"}, headers=headers)
        game = r.json()["data"]
        parts = {p["color"]: p for p in game["state"]["participants"]}
        assert parts["red"]["username"] == creds["username"]
        assert parts["red"]["avatar"] == cat["emoji"]
        assert parts["blue"]["is_bot"] and parts["blue"]["username"] == "CPU"
        gid = game["id"]
        print(f"[ok] game {gid} started with dynamic participants")

        # Roll until we get moves, then move; loop until CPU finishes or N turns
        import random as _rnd
        turns = 0
        stats = {"wait": 0, "passed": 0, "nolegal": 0, "moved": 0}
        last_roll = {}
        while True:
            turns += 1
            assert turns < 3000, (
                f"stalled; stats={stats} last_roll={last_roll}")
            state = (await client.get(f"/api/v1/games/{gid}", headers=headers)).json()["data"]
            if state["status"] != "active":
                break
            if turns % 250 == 0:
                print(f"   ..cycle {turns}: {stats} turn={state['current_turn']} "
                      f"dice={state['dice_value']} tokens={state['state']['tokens']}")
            if state["current_turn"] != "red" or state["dice_value"] is not None:
                stats["wait"] += 1
                await asyncio.sleep(0.001)
                continue
            roll = (await client.post(f"/api/v1/games/{gid}/roll", headers=headers)).json()
            assert roll["success"], roll
            data = roll["data"]
            last_roll = {"dice": data.get("dice_value"), "moves": len(data.get("legal_moves", [])),
                         "turn": data.get("current_turn")}
            if data["current_turn"] != "red":
                stats["passed"] += 1
                continue
            if not data["legal_moves"]:
                stats["nolegal"] += 1
                continue
            choice = _rnd.choice(data["legal_moves"]) if _rnd.random() < 0.7 else data["legal_moves"][0]
            mv = (await client.post(
                f"/api/v1/games/{gid}/move",
                json={"token_index": choice["token_index"]},
                headers=headers,
            ))
            assert mv.json()["success"], mv.json()
            stats["moved"] += 1

        final = (await client.get(f"/api/v1/games/{gid}", headers=headers)).json()["data"]
        assert final["status"] == "finished"
        print(f"[ok] full game finished in {turns} cycles, winner_id={final['winner_id']}")

        # Match history recorded + rewards actually credited
        r = await client.get("/api/v1/games/history", headers=headers)
        hist = r.json()["data"]
        assert len(hist) >= 1 and hist[0]["game_id"] == gid
        print(f"[ok] history: placement={hist[0]['placement']}, coins={hist[0]['coins_earned']}, xp={hist[0]['xp_earned']}")

        me = (await client.get("/api/v1/users/me", headers=headers)).json()["data"]
        assert me["coins"] == 850 + 100, f"rewards not credited: coins={me['coins']}"
        assert me["wins"] == 1 and me["xp"] == 50, f"stats wrong: {me}"
        print(f"[ok] rewards credited: coins={me['coins']}, wins={me['wins']}, xp={me['xp']}")

        # ---- Guest login: instant session, playable everywhere ----
        r = await client.post("/api/v1/auth/guest")
        body = r.json()
        assert body["success"] and body["data"]["user"]["username"].startswith("Guest"), body
        guest_headers = {"Authorization": f"Bearer {body['data']['access_token']}"}
        g = (await client.post(
            "/api/v1/games/start", json={"mode": "computer"}, headers=guest_headers
        )).json()
        assert g["success"], g
        print(f"[ok] guest '{body['data']['user']['username']}' started game {g['data']['id']} instantly")

        # Guest appears in online rooms too (join a room)
        r = (await client.post("/api/v1/rooms", json={"name": "G", "max_players": 2}, headers=headers)).json()
        code = r["data"]["code"]
        r = (await client.post("/api/v1/rooms/join", json={"code": code}, headers=guest_headers)).json()
        assert r["success"], r
        print(f"[ok] guest joined online room {code}")

        # ---- Social endpoints verify tokens properly ----
        r = await client.post("/api/v1/auth/google", json={"token": "not-a-real-token"})
        assert r.json()["success"] is False, "google accepted garbage token!"
        print("[ok] google rejects invalid token")
        r = await client.post("/api/v1/auth/facebook", json={"token": "not-a-real-token"})
        assert r.json()["success"] is False, "facebook accepted garbage token!"
        print("[ok] facebook rejects invalid token")

    print("\nALL E2E CHECKS PASSED")


if __name__ == "__main__":
    asyncio.run(main())
