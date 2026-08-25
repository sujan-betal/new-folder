"""Server-driven app configuration.

The client fetches this via GET /config/app, so announcements, rewards and
compatibility rules can be tuned without shipping a new app build.
"""

APP_CONFIG = {
    "announcement": "Welcome to Ludo Master! Play online with friends.",
    "maintenance_mode": False,
    "min_supported_version": "1.0.0",
    "rewards": {
        "win_coins": 100,
        "participation_coins": 25,
        "win_xp": 50,
        "participation_xp": 15,
    },
    "daily_bonus_coins": 50,
}
