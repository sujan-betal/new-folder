from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class RoomPlayerOut(BaseModel):
    id: int
    user_id: int
    username: str
    avatar: str
    color: str | None
    seat: int
    is_ready: bool


class RoomCreate(BaseModel):
    name: str = Field(default="Private Room", max_length=100)
    max_players: int = Field(default=4, ge=2, le=4)
    bet_amount: int = Field(default=0, ge=0)


class RoomJoin(BaseModel):
    code: str = Field(min_length=6, max_length=6)


class RoomOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    code: str
    name: str
    host_id: int
    max_players: int
    bet_amount: int
    status: str
    created_at: datetime
    players: list[RoomPlayerOut] = []
