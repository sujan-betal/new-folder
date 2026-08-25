# Ludo Master — Full-Stack Ludo Game

A Ludo King-style game: Flutter app + FastAPI backend with online multiplayer,
vs Computer, and pass-and-play modes.

## Project layout

```
backend/        FastAPI + SQLAlchemy (auth, rooms, games, server-side ludo engine)
flutter_app/    Flutter client (game engine, board UI, online lobby)
```

## Features

- **Pass & Play** — 2–4 players on one device, full Ludo rules
- **Play vs Computer** — 1–3 heuristic AI opponents
- **Online Multiplayer** — create/join rooms by code, ready-up, host starts,
  turn-based play synced via the REST API with polling, real player names/avatars
- **Shop** — server-driven avatar catalog, buy with coins/gems, equip in profile
- **Profile** — live stats, XP progress, avatar equipping, match history from API
- **Dynamic app config** — announcements/rewards served from `GET /config/app`
- **Ranked matches** — coins/XP rewards, match history, leaderboard
- Real rules: roll 6 to exit base, captures on non-safe squares, extra turns
  (6 / capture / reaching home), three-sixes forfeit, exact roll to finish
- Smooth animated board: sliding tokens, glowing movable pieces, pip dice

## Run the backend

Requires Python 3.12+ and a PostgreSQL database.

```bash
cd backend
pip install -r requirements.txt
# configure database URL in src/config/settings.py or a .env file
python -m src.server            # serves http://0.0.0.0:8000
```

Health check: `GET /api/v1/health`

Key endpoints:

| Method | Path | Purpose |
| ------ | ---- | ------- |
| POST | `/api/v1/auth/register` `/login` `/me` | accounts |
| POST | `/api/v1/auth/guest` | **instant guest session** |
| POST | `/api/v1/auth/google` `{token}` | Google Sign-In (ID token verified) |
| POST | `/api/v1/auth/facebook` `{token}` | Facebook Login (token via Graph API) |
| GET/PATCH | `/api/v1/users/me`, `/users/leaderboard` | profile, ranking |
| POST/GET | `/api/v1/rooms`, `/rooms/open`, `/rooms/{code}` | rooms |
| POST | `/rooms/join` `{code}` · `/rooms/{code}/ready` · `/rooms/{code}/leave` | room flow |
| POST | `/games/start` `{mode: computer\|online, room_code?}` | start game |
| GET | `/games/{id}` | poll game state |
| POST | `/games/{id}/roll` · `/games/{id}/move` `{token_index}` | play |
| GET | `/games/history` | your match history |
| GET | `/shop/items` · POST `/shop/purchase` `{item_id}` | shop |
| PATCH | `/users/me` `{avatar}` | equip an owned avatar |
| GET | `/config/app` | announcements, rewards, version gate |

The server is authoritative: dice rolls, legal-move validation, bot turns,
captures and win/rewards are computed in `src/utils/ludo_engine.py`.
Game participants embed `username`/`avatar`, so all clients render real players.

## End-to-end smoke test

Boots the real API against a scratch SQLite DB and plays a full game:

```bash
cd backend
pip install aiosqlite httpx
python smoke_test.py    # register -> shop -> purchase -> equip -> play -> rewards
```

## Run the Flutter app

```bash
cd flutter_app
flutter pub get
flutter run                     # Android emulator reaches backend at 10.0.2.2:8000
```

- Local modes work fully offline.
- Online mode needs the backend running; the base URL is set in
  `lib/core/constants/api_endpoints.dart` (`10.0.2.2` for the Android
  emulator, change to your LAN IP for physical devices).

## Social logins

- **Guest** — works out of the box: one tap creates a temporary account
  (`Guest123456`) and a full session; guests can play every mode incl. online.
- **Google** — fully wired. Add your OAuth Web Client ID to
  `flutter_app/lib/core/constants/social_config.dart` and optionally set
  `GOOGLE_CLIENT_ID` in the backend env to enforce the audience check.
- **Facebook** — backend endpoint is live and verifies tokens via Graph API.
  Add `flutter_facebook_auth` on the client, then pass its token to
  `loginWithSocialToken(provider: 'facebook', ...)`. Set `FACEBOOK_APP_ID`
  / `FACEBOOK_APP_SECRET` to enforce app checks.

## Tests

```bash
cd flutter_app && flutter test      # engine + AI + widget tests
```
