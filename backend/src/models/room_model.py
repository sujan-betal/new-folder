from datetime import datetime

from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import relationship

from src.config.database import Base


class Room(Base):
    __tablename__ = "ludo_rooms"

    id = Column(Integer, primary_key=True, index=True)
    code = Column(String(6), unique=True, index=True, nullable=False)
    name = Column(String(100), nullable=False, default="Private Room")
    host_id = Column(Integer, ForeignKey("ludo_users.id"), nullable=False)
    max_players = Column(Integer, nullable=False, default=4)
    bet_amount = Column(Integer, nullable=False, default=0)
    status = Column(String(20), nullable=False, default="waiting")
    created_at = Column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)

    host = relationship("User")
    players = relationship("RoomPlayer", back_populates="room", cascade="all, delete-orphan")


class RoomPlayer(Base):
    __tablename__ = "ludo_room_players"
    __table_args__ = (UniqueConstraint("room_id", "user_id", name="uq_room_user"),)

    id = Column(Integer, primary_key=True, index=True)
    room_id = Column(Integer, ForeignKey("ludo_rooms.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("ludo_users.id"), nullable=False)
    color = Column(String(10), nullable=True)
    seat = Column(Integer, nullable=False, default=0)
    is_ready = Column(Boolean, nullable=False, default=False)
    joined_at = Column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)

    room = relationship("Room", back_populates="players")
    user = relationship("User")
