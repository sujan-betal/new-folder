"""Real-time (WebSocket) end-to-end check for rooms and online games.

Brings up the app against a scratch SQLite DB and verifies:
  1. Host creates a room and opens a WS room stream.
  2. Guest joins -> the host's stream receives a live 'room' push.
  3. Host starts the game -> the guest's stream receives a
     'game_started' push with an active_game_id.
  4. Guest opens the game WS stream; host rolls the dice -> the guest
     receives a live 'game' push with the new dice_value/token state.
"""

import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ["DATABASE_URL"] = "sqlite+aiosqlite:///./_ws_test.db"

from fastapi.testclient import TestClient  # noqa: E402

from src.config.database import Base, engine  # noqa: E402
from src.server import app  # noqa: E402


def _register(client: TestClient, username: str) -> dict:
    suffix = random.randint(1000, 999999)
    creds = {
        "username": f"{username}{suffix}",
        "email": f"{username}{suffix}@test.io",
        "password": "Secret123!",
    }
    r = client.post("/api/v1/auth/register", json=creds)
    assert r.json()["success"], r.json()
    r = client.post("/api/v1/auth/login", json={
        "identifier": creds["username"], "password": creds["password"]})
    body = r.json()
    assert body["success"], body
    return {"Authorization": f"Bearer {body['data']['access_token']}"}


def run() -> None:
    with TestClient(app) as client:
        host_headers = _register(client, "host")
        guest_headers = _register(client, "guest")

        r = client.post("/api/v1/rooms",
                        json={"name": "WS Room", "max_players": 2},
                        headers=host_headers)
        room = r.json()["data"]
        code = room["code"]
        print(f"[ok] room created: {code}")

        # 1) Host subscribes to the room stream.
        with client.websocket_connect(
            f"/api/v1/ws/room/{code}", headers=host_headers
        ) as host_ws:
            first = host_ws.receive_json()
            assert first["kind"] == "room", first
            assert first["room"]["code"] == code
            print("[ok] host WS received fresh room snapshot")

            # 2) Guest joins -> host stream should be pushed a new room state.
            r = client.post("/api/v1/rooms/join",
                            json={"code": code}, headers=guest_headers)
            assert r.json()["success"], r.json()
            pushed = host_ws.receive_json()
            assert pushed["kind"] == "room", pushed
            assert len(pushed["room"]["players"]) == 2, pushed
            print("[ok] guest join pushed live room update to host")

            # 3) Guest subscribes too, then host starts the game.
            with client.websocket_connect(
                f"/api/v1/ws/room/{code}", headers=guest_headers
            ) as guest_ws:
                guest_first = guest_ws.receive_json()
                assert guest_first["kind"] == "room"
                print("[ok] guest WS subscribed + got snapshot")

                r = client.post("/api/v1/games/start",
                                json={"mode": "online", "room_code": code},
                                headers=host_headers)
                assert r.json()["success"], r.json()
                game = r.json()["data"]
                gid = game["id"]

                # Host AND guest should both receive the game_started push.
                host_start = host_ws.receive_json()
                guest_start = guest_ws.receive_json()
                for msg in (host_start, guest_start):
                    assert msg["kind"] == "room", msg
                    assert msg.get("game_started") is True, msg
                    assert msg["room"]["active_game_id"] == gid, msg
                print("[ok] game start pushed to BOTH players (active_game_id set)")

                # 4) Game WS: guest subscribes; host rolls dice.
                with client.websocket_connect(
                    f"/api/v1/ws/game/{gid}", headers=guest_headers
                ) as game_ws:
                    snap = game_ws.receive_json()
                    assert snap["kind"] == "game" and snap["game"]["id"] == gid
                    print("[ok] guest game WS subscribed")

                    # Host is red (seat 0). Roll until red has the turn.
                    for _ in range(60):
                        state = client.get(
                            f"/api/v1/games/{gid}", headers=host_headers
                        ).json()["data"]
                        if state["current_turn"] == "red" and state["dice_value"] is None:
                            roll = client.post(
                                f"/api/v1/games/{gid}/roll", headers=host_headers
                            ).json()
                            assert roll["success"], roll
                            break
                    else:
                        raise AssertionError("host never got the turn")

                    live = game_ws.receive_json()
                    assert live["kind"] == "game", live
                    g = live["game"]
                    assert g["id"] == gid, live
                    if g["current_turn"] == "red" and g["dice_value"] is not None:
                        print(f"[ok] live roll pushed to guest: dice={g['dice_value']} "
                              f"turn={g['current_turn']}")
                    else:
                        print(f"[ok] live roll pushed to guest (turn moved to "
                              f"{g['current_turn']}, no legal moves for red)")

    print("\nALL WEBSOCKET CHECKS PASSED")


if __name__ == "__main__":
    run()