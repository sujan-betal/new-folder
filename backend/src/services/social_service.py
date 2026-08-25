"""Social & guest authentication.

Google: verifies the ID token sent by the client's google_sign_in plugin
against Google's public keys (signature + issuer), and - when configured -
the audience must match settings.GOOGLE_CLIENT_ID.

Facebook: validates the access token against the Graph API and (when
configured) checks the token was issued for settings.FACEBOOK_APP_ID.

Accounts are linked by email, so a user can log in with password or social
and always land on the same profile.
"""

import random

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.config.settings import settings
from src.models.user_model import User
from src.services.user_service import get_user_by_email, get_user_by_username
from src.utils.security import create_access_token, hash_password

GUEST_PREFIX = "Guest"


def _random_suffix() -> str:
    return "".join(str(random.randint(0, 9)) for _ in range(6))


def _create_token(user: User) -> str:
    return create_access_token(str(user.id))


async def _unique_username(db: AsyncSession, base: str) -> str:
    base = base[:30].strip() or "Player"
    candidate = base
    while await get_user_by_username(db, candidate) is not None:
        candidate = f"{base}{_random_suffix()}"
    return candidate


async def _get_or_create_social_user(
    db: AsyncSession,
    *,
    email: str | None,
    display_name: str,
    avatar: str = "\U0001F3B2",
) -> User:
    user = None
    if email:
        user = await get_user_by_email(db, email)
    if user is None:
        username = await _unique_username(db, display_name or "Player")
        user = User(
            username=username,
            email=email or f"{username.lower().replace(' ', '')}{_random_suffix()}@social.local",
            hashed_password=hash_password(_random_suffix() * 4),
            avatar=avatar,
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)
    return user


async def guest_login_service(db: AsyncSession) -> dict:
    """Instant play: create a throwaway account and hand back a session."""
    try:
        suffix = _random_suffix()
        username = f"{GUEST_PREFIX}{suffix}"
        while await get_user_by_username(db, username) is not None:
            suffix = _random_suffix()
            username = f"{GUEST_PREFIX}{suffix}"

        user = User(
            username=username,
            email=f"guest_{suffix}@guest.local",
            hashed_password=hash_password(_random_suffix() * 6),
            avatar=random.choice(["\U0001F3B2", "\U0001F0CF", "\U0001F3AF", "\u2694\uFE0F"]),
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)

        return {"error": False, "token": _create_token(user), "user": user}
    except Exception as e:
        await db.rollback()
        return {"error": True, "message": f"Guest login failed: {str(e)}"}


async def google_login_service(db: AsyncSession, id_token: str) -> dict:
    try:
        from google.auth.transport import requests as google_requests
        from google.oauth2 import id_token as google_id_token

        try:
            info = google_id_token.verify_oauth2_token(
                id_token, google_requests.Request()
            )
        except ValueError as ve:
            return {"error": True, "message": f"Invalid Google token: {ve}"}

        issuer = info.get("iss", "")
        if issuer not in ("accounts.google.com", "https://accounts.google.com"):
            return {"error": True, "message": "Token is not from Google"}

        client_id = settings.GOOGLE_CLIENT_ID
        if client_id and info.get("aud") != client_id:
            return {"error": True, "message": "Google token was issued to another app"}

        email = info.get("email")
        name = info.get("name") or (email.split("@")[0] if email else "Google Player")

        user = await _get_or_create_social_user(
            db, email=email, display_name=name.replace(" ", "")
        )
        return {"error": False, "token": _create_token(user), "user": user}
    except Exception as e:
        await db.rollback()
        return {"error": True, "message": f"Google login failed: {str(e)}"}


async def facebook_login_service(db: AsyncSession, access_token: str) -> dict:
    try:
        fields = "id,name,email,picture.type(small)"
        async with httpx.AsyncClient(timeout=10) as client:
            me = await client.get(
                "https://graph.facebook.com/me",
                params={"fields": fields, "access_token": access_token},
            )
        if me.status_code != 200:
            return {"error": True, "message": "Invalid Facebook token"}

        data = me.json()

        if settings.FACEBOOK_APP_ID:
            async with httpx.AsyncClient(timeout=10) as client:
                dbg = await client.get(
                    "https://graph.facebook.com/debug_token",
                    params={
                        "input_token": access_token,
                        "access_token": (
                            f"{settings.FACEBOOK_APP_ID}|"
                            f"{settings.FACEBOOK_APP_SECRET}"
                        ),
                    },
                )
            if dbg.status_code == 200:
                token_data = dbg.json().get("data", {})
                if token_data.get("app_id") != settings.FACEBOOK_APP_ID:
                    return {
                        "error": True,
                        "message": "Facebook token was issued to another app",
                    }

        fb_id = str(data.get("id", ""))
        email = data.get("email") or (f"{fb_id}@facebook.local" if fb_id else None)
        name = data.get("name") or "Facebook Player"

        user = await _get_or_create_social_user(
            db, email=email, display_name=name.replace(" ", "")
        )
        return {"error": False, "token": _create_token(user), "user": user}
    except Exception as e:
        await db.rollback()
        return {"error": True, "message": f"Facebook login failed: {str(e)}"}
