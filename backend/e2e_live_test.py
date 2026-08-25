"""Full live E2E test against the REAL server + REAL Supabase 'ludo' DB.

Requires the API to be running:  python src/server.py   (port 8000)

Covers: health, config, register/login/guest/social-validation, shop,
profile, leaderboard, rooms (create/join/ready/leave/open), full online
game vs CPU-free flow (2 humans simulated), rewards, and history.
"""

import random
import sys

import httpx

BASE = "http://localhost:8000/api/v1"

passed = 0


def ok(label: str, cond: bool, extra: str = "") -> None:
    global passed
    if cond:
        passed += 1
        print(f"[PASS] {label}" + (f" ({extra})" if extra else ""))
    else:
        print(f"[FAIL] {label} {extra}")
        sys.exit(1)


def main() -> None:
    c = httpx.Client(base_url=BASE, timeout=30)

    # ---------- basics ----------
    r = c.get("/health")
    ok("health", r.json()["success"] is True)
    r = c.get("/config/app")
    ok("config/app", "announcement" in r.json()["data"])

    # ---------- auth ----------
    suffix = random.randint(100000, 999999)
    ua = {"username": f"liveA{suffix}", "email": f"livea{suffix}@t.io", "password": "Secret123!"}
    ub = {"username": f"liveB{suffix}", "email": f"liveb{suffix}@t.io", "password": "Secret456?"}

    r = c.post("/auth/register", json=ua)
    ok("register A", r.json()["success"])
    r = c.post("/auth/register", json=ua)
    ok("duplicate register rejected", r.json()["success"] is False)

    r = c.post("/auth/login", json={"identifier": ua["username"], "password": "WRONG"})
    ok("wrong password rejected", r.json()["success"] is False)
    r = c.post("/auth/login", json={"identifier": ua["username"], "password": ua["password"]})
    tok_a = r.json()["data"]["access_token"]
    ok("login A", bool(tok_a))
    r = c.post("/auth/register", json=ub)
    r = c.post("/auth/login", json={"identifier": ub["username"], "password": ub["password"]})
    tok_b = r.json()["data"]["access_token"]
    ok("login B", bool(tok_b))

    ha = {"Authorization": f"Bearer {tok_a}"}
    hb = {"Authorization": f"Bearer {tok_b}"}

    r = c.get("/users/me", headers=ha)
    me_a = r.json()["data"]
    ok("users/me", me_a["username"] == ua["username"], f"id={me_a['id']} coins={me_a['coins']}")
    coins0 = me_a["coins"]

    r = c.get("/users/me")
    ok("unauthorized blocked", r.status_code == 401)

    r = c.post("/auth/guest")
    g = r.json()["data"]
    ok("guest login", g["user"]["username"].startswith("Guest"))

    r = c.post("/auth/google", json={"token": "garbage-token"})
    ok("google rejects fake token", r.json()["success"] is False)
    r = c.post("/auth/facebook", json={"token": "garbage-token"})
    ok("facebook rejects fake token", r.json()["success"] is False)

    # ---------- shop ----------
    r = c.get("/shop/items", headers=ha)
    items = r.json()["data"]
    cat = next(i for i in items if i["id"] == "av_cat")
    ok("shop catalog", len(items) >= 8, f"{len(items)} items")
    r = c.patch("/users/me", json={"avatar": cat["emoji"]}, headers=ha)
    ok("locked avatar blocked", r.json()["success"] is False)
    r = c.post("/shop/purchase", json={"item_id": "av_cat"}, headers=ha)
    ok("purchase av_cat", r.json()["success"])
    r = c.post("/shop/purchase", json={"item_id": "av_cat"}, headers=ha)
    ok("double purchase blocked", r.json()["success"] is False)
    r = c.patch("/users/me", json={"avatar": cat["emoji"]}, headers=ha)
    ok("equip purchased avatar", r.json()["success"])

    # ---------- leaderboard ----------
    r = c.get("/users/leaderboard")
    lb = r.json()["data"]
    ok("leaderboard", isinstance(lb, list) and len(lb) >= 1, f"{len(lb)} players")

    # ---------- rooms ----------
    r = c.post("/rooms", json={"name": "LiveE2E", "max_players": 2}, headers=ha)
    room = r.json()["data"]
    code = room["code"]
    ok("room created", len(code) == 6, f"code={code}")

    r = c.get(f"/rooms/{code}")
    ok("get room public", r.json()["success"])
    r = c.get("/rooms/open")
    ok("open rooms lists it", any(x["code"] == code for x in r.json()["data"]))

    r = c.post("/rooms/join", json={"code": code}, headers=hb)
    ok("B joins room", r.json()["success"])

    r = c.post(f"/rooms/{code}/ready", headers=hb)
    b_ready = r.json()["data"]["players"]
    ok("B ready toggled", next(p["is_ready"] for p in b_ready if p["user_id"] != room["host_id"]))
    r = c.post(f"/rooms/{code}/ready", headers=hb)
    ok("B ready toggled back", r.json()["success"])

    # ---------- online game (A red vs B green) ----------
    r = c.post("/games/start", json={"mode": "online", "room_code": code}, headers=ha)
    game = r.json()["data"]
    gid = game["id"]
    ok("game started", game["status"] == "active", f"game={gid} turn={game['current_turn']}")
    parts = {p["color"]: p for p in game["state"]["participants"]}
    ok("participants correct",
       parts["red"]["user_id"] == me_a["id"] and parts["green"]["is_bot"] is False)

    r = c.post("/games/start", json={"mode": "online", "room_code": code}, headers=hb)
    ok("only host starts", r.json()["success"] is False)

    # Play the whole game efficiently: one request per turn, no re-polling.
    tokens = {tok_a: "red", tok_b: "green"}
    state = c.get(f"/games/{gid}", headers=ha).json()["data"]
    turns = 0
    while state["status"] == "active":
        turns += 1
        assert turns < 1200, f"game stalled after {turns} turns"
        if turns % 100 == 0:
            print(f"   ..turn {turns}: {state['state']['tokens']}")
        color = state["current_turn"]
        h = {"Authorization": f"Bearer {next(t for t, cl in tokens.items() if cl == color)}"}
        toks = state["state"]["tokens"][color]
        dice = state["dice_value"]

        if dice is None:
            rl = c.post(f"/games/{gid}/roll", headers=h).json()
            assert rl["success"], rl
            d = rl["data"]
            state = {
                "status": d["status"],
                "current_turn": d["current_turn"],
                # Server sends 0 (not null) when the turn passed - normalize.
                "dice_value": d["dice_value"] or None,
                "state": d["state"],
            }
            continue

        legal_exact = []
        for i, p in enumerate(toks):
            if p == 57:
                continue
            if p == -1 and dice == 6:
                legal_exact.append(i)
            elif p >= 0 and p + dice <= 57:
                legal_exact.append(i)
        assert legal_exact, f"server set dice={dice} with no legal moves: {toks}"

        mv = c.post(f"/games/{gid}/move", json={"token_index": legal_exact[0]}, headers=h).json()
        assert mv["success"], mv
        state = mv["data"]

    final = c.get(f"/games/{gid}", headers=ha).json()["data"]
    ok("online game finished", final["status"] == "finished", f"winner={final['winner_id']} cycles={turns}")

    r = c.get("/games/history", headers=ha)
    hist = r.json()["data"]
    ok("history recorded", any(hx["game_id"] == gid for hx in hist))
    me_now = c.get("/users/me", headers=ha).json()["data"]
    ok("rewards credited", me_now["coins"] != coins0, f"{coins0}->{me_now['coins']}")

    # ---------- computer mode quick sanity ----------
    r = c.post("/games/start", json={"mode": "computer"}, headers=hb)
    cg = r.json()["data"]
    cp = {p["color"]: p for p in cg["state"]["participants"]}
    ok("computer mode diagonal seats",
       set(cp.keys()) == {"red", "yellow"} and cp["yellow"]["is_bot"], f"game={cg['id']}")
    rr = c.post(f"/games/{cg['id']}/roll", headers=hb)
    ok("roll in cpu mode", rr.json()["success"])

    # ---------- leave room ----------
    r = c.post(f"/rooms/{code}/leave", headers=hb)
    ok("B left room", r.json()["success"])
    r = c.get(f"/rooms/{code}")
    ok("room still alive for host", r.json()["success"])

    print(f"\nALL {passed} LIVE CHECKS PASSED - backend + Supabase 'ludo' DB are READY")


if __name__ == "__main__":
    main()
