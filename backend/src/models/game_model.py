from sqlalchemy import JSON, Column, DateTime, ForeignKey, Integer, String
from datetime import datetime

from src.config.database import Base


class Game(Base):
    __tablename__ = "ludo_games"

    id = Column(Integer, primary_key=True, index=True)
    room_id = Column(Integer, ForeignKey("ludo_rooms.id"), nullable=True)
    mode = Column(String(20), nullable=False, default="online")
    status = Column(String(20), nullable=False, default="active")
    current_turn = Column(String(10), nullable=False, default="red")
    dice_value = Column(Integer, nullable=True)
    six_streak = Column(Integer, nullable=False, default=0)
    state = Column(JSON, nullable=False, default=dict)
    winner_id = Column(Integer, ForeignKey("ludo_users.id"), nullable=True)
    started_at = Column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)
    finished_at = Column(DateTime(timezone=True), nullable=True)


class Move(Base):
    __tablename__ = "ludo_moves"

    id = Column(Integer, primary_key=True, index=True)
    game_id = Column(Integer, ForeignKey("ludo_games.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("ludo_users.id"), nullable=False)
    color = Column(String(10), nullable=False)
    dice_value = Column(Integer, nullable=False)
    token_index = Column(Integer, nullable=False)
    from_pos = Column(Integer, nullable=False)
    to_pos = Column(Integer, nullable=False)
    created_at = Column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)


class MatchResult(Base):
    __tablename__ = "ludo_match_results"

    id = Column(Integer, primary_key=True, index=True)
    game_id = Column(Integer, ForeignKey("ludo_games.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("ludo_users.id"), nullable=False)
    color = Column(String(10), nullable=False)
    placement = Column(Integer, nullable=False)
    coins_earned = Column(Integer, nullable=False, default=0)
    xp_earned = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)
