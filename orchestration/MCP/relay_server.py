from __future__ import annotations

from typing import Any, Dict


class RelayServer:
    def __init__(self) -> None:
        self._handlers = {}

    def register(self, name: str, handler) -> None:
        self._handlers[name] = handler

    def handle(self, name: str, payload: Dict[str, Any]) -> Dict[str, Any]:
        handler = self._handlers.get(name)
        if not handler:
            return {"status": "unknown_handler", "handler": name}
        return handler(payload)
