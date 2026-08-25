# Google Login — Final Setup (2 minutes)

The ENTIRE code path is already implemented and tested:

    Flutter button → google_sign_in plugin → Google ID token
      → POST /api/v1/auth/google → backend verifies token with Google
      → creates/links account by email → returns your app JWT

The ONLY thing missing is **your free Google OAuth Client ID** (Google
requires every app to register itself — no app can skip this).

## Get the ID

1. Open https://console.cloud.google.com/apis/credentials
2. Sign in with any Google account
3. **Create Credentials → OAuth client ID → Web application**
4. Authorized JavaScript origins:
   - `http://localhost:57872`   (Flutter web dev server)
   - `http://localhost:8000`
5. Copy the ID that looks like `1234567890-abc123.apps.googleusercontent.com`

## Paste it in exactly these places

| # | File | Location |
|---|------|----------|
| 1 | `flutter_app/web/index.html` | `<meta name="google-signin-client_id" content="PASTE-HERE">` |
| 2 | `flutter_app/lib/core/constants/social_config.dart` | `googleServerClientId = 'PASTE-HERE'` |
| 3 | `backend/.env` | `GOOGLE_CLIENT_ID=PASTE-HERE` (optional, enables strict audience check) |

Then restart the Flutter app. The white **Google** button on the login
screen will open the real Google account chooser and log you into the game.

## How it works after login

- First-time Google users get an account created automatically
  (username from their Google name, avatar 🎲).
- Returning users land on the SAME profile (linked by email),
  coins/wins/history intact.
- Password login + Google login both work on the same account.
