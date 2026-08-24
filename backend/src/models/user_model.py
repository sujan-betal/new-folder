from datetime import datetime

from sqlalchemy import Boolean, Column, DateTime, Integer, String

from src.config.database import Base


class User(Base):
    __tablename__ = "ludo_users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, index=True, nullable=False)
    email = Column(String(120), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    avatar = Column(String(10), nullable=False, default="\U0001F3B2")
    coins = Column(Integer, nullable=False, default=1000)
    gems = Column(Integer, nullable=False, default=50)
    wins = Column(Integer, nullable=False, default=0)
    losses = Column(Integer, nullable=False, default=0)
    level = Column(Integer, nullable=False, default=1)
    xp = Column(Integer, nullable=False, default=0)
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)
