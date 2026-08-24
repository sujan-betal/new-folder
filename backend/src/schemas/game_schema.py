from pydantic import BaseModel, Field


class GameStartRequest(BaseModel):
    mode: str = Field(default="computer", pattern="^(computer|online)$")
    room_code: str | None = None


class MoveRequest(BaseModel):
    token_index: int = Field(ge=0, le=3)


class GameStateData(BaseModel):
    id: int
    room_id: int | None
    mode: str
    status: str
    current_turn: str
    dice_value: int | None
    winner_id: int | None
    state: dict
