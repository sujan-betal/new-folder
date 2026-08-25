from datetime import datetime

from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import relationship

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

    purchases = relationship("Purchase", back_populates="user", cascade="all, delete-orphan")


class Purchase(Base):
    __tablename__ = "ludo_purchases"
    __table_args__ = (UniqueConstraint("user_id", "item_id", name="uq_user_item"),)

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("ludo_users.id"), nullable=False, index=True)
    item_id = Column(String(50), nullable=False)
    price_coins = Column(Integer, nullable=False, default=0)
    price_gems = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)

    user = relationship("User", back_populates="purchases")
