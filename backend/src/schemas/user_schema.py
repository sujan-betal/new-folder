def serialize_user(user) -> dict:
    return {
        "id": user.id,
        "username": user.username,
        "email": user.email,
        "avatar": user.avatar,
        "coins": user.coins,
        "gems": user.gems,
        "wins": user.wins,
        "losses": user.losses,
        "level": user.level,
        "xp": user.xp,
    }


def public_user(user) -> dict:
    return {
        "id": user.id,
        "username": user.username,
        "avatar": user.avatar,
        "level": user.level,
        "wins": user.wins,
    }
