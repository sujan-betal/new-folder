"""In-process pub/sub hub for real-time room & game updates.

FastAPI ships one event loop per process, so simple in-memory bookkeeping is
safe. Every WebSocket client subscribes to one topic (`room:<code>` or
`game:<id>`); any server code publishes JSON blobs to that topic and the hub
forwards them to every connected socket best-effort.

Topics are also *retained*: a late subscriber immediately receives the last
published payload so it never misses a state change (and no request/poll loop
is needed to bootstrap the socket).
"""

from __future__ import annotations

import asyncio
import json
import logging
from typing import Any

logger = logging.getLogger("ws_hub")


class _Topic:
    __slots__ = ("sockets", "retained", "lock")

    def __init__(self) -> None:
        self.sockets: set[Any] = set()
        self.retained: dict[str, Any] | None = None
        self.lock = asyncio.Lock()


_topics: dict[str, _Topic] = {}
_topics_lock = asyncio.Lock()


async def _get_topic(name: str) -> _Topic:
    async with _topics_lock:
        topic = _topics.get(name)
        if topic is None:
            topic = _Topic()
            _topics[name] = topic
        return topic


async def subscribe(name: str, websocket: Any) -> bool:
    """Attach a client to a topic, sending any retained payload immediately.

    Returns True when a retained payload was delivered (so the caller can skip
    building/sending its own redundant snapshot).
    """
    topic = await _get_topic(name)
    async with topic.lock:
        topic.sockets.add(websocket)
        retained = topic.retained
    if retained is not None:
        try:
            await websocket.send_text(json.dumps(retained))
        except Exception:  # noqa: BLE001 - client may race-disconnect
            return True
        return True
    return False


async def unsubscribe(name: str, websocket: Any) -> None:
    async with _topics_lock:
        topic = _topics.get(name)
    if topic is None:
        return
    async with topic.lock:
        topic.sockets.discard(websocket)
        if not topic.sockets:
            _topics.pop(name, None)


async def publish(name: str, payload: dict[str, Any]) -> None:
    """Retain + fan out a payload to every subscriber of the topic."""
    topic = await _get_topic(name)
    async with topic.lock:
        topic.retained = payload
        targets = list(topic.sockets)

    text = json.dumps(payload)
    for ws in targets:
        try:
            await ws.send_text(text)
        except Exception:  # noqa: BLE001
            topic.sockets.discard(ws)