import random

COLORS = ("red", "green", "yellow", "blue")
START_OFFSETS = {"red": 0, "green": 13, "yellow": 26, "blue": 39}
SAFE_SQUARES = {0, 8, 13, 21, 26, 34, 39, 47}

BASE_POS = -1
TRACK_END = 51
HOME_DONE = 58
TOKENS_PER_PLAYER = 4


def roll_dice() -> int:
    return random.randint(1, 6)


def initial_state(participants: list[dict]) -> dict:
    return {
        "tokens": {p["color"]: [BASE_POS] * TOKENS_PER_PLAYER for p in participants},
        "participants": participants,
    }


def legal_moves(tokens: list[int], dice: int) -> list[dict]:
    moves = []
    for index, pos in enumerate(tokens):
        if pos == HOME_DONE:
            continue
        if pos == BASE_POS:
            if dice == 6:
                moves.append({"token_index": index, "to_pos": 0})
            continue
        target = pos + dice
        if target <= HOME_DONE:
            moves.append({"token_index": index, "to_pos": target})
    return moves


def abs_square(color: str, pos: int) -> int | None:
    if pos < 0 or pos > TRACK_END:
        return None
    return (START_OFFSETS[color] + pos) % 52


def apply_move(state: dict, color: str, token_index: int, dice: int) -> dict:
    tokens = state["tokens"][color]
    current = tokens[token_index]

    if current == BASE_POS:
        target = 0
    else:
        target = current + dice
        if target > HOME_DONE:
            raise ValueError("Move overshoots home")

    tokens[token_index] = target

    captured = False
    absolute = abs_square(color, target)
    if absolute is not None and absolute not in SAFE_SQUARES:
        for other in state["tokens"]:
            if other == color:
                continue
            offset = START_OFFSETS[other]
            for i, opp_pos in enumerate(state["tokens"][other]):
                if opp_pos < 0 or opp_pos > TRACK_END:
                    continue
                if (offset + opp_pos) % 52 == absolute:
                    state["tokens"][other][i] = BASE_POS
                    captured = True

    return {
        "captured": captured,
        "reached_home": target == HOME_DONE,
        "finished": all(p == HOME_DONE for p in tokens),
    }


def progress(color_tokens: list[int]) -> int:
    return sum(1 for p in color_tokens if p != BASE_POS)


def is_color_finished(state: dict, color: str) -> bool:
    return all(p == HOME_DONE for p in state["tokens"][color])


def next_turn(participants: list[dict], current_color: str, state: dict) -> str:
    colors = [p["color"] for p in participants]
    index = colors.index(current_color)
    for step in range(1, len(colors) + 1):
        candidate = colors[(index + step) % len(colors)]
        if not is_color_finished(state, candidate):
            return candidate
    return current_color
