from __future__ import annotations

from typing import Any, Dict


def send_to_notion(payload: Dict[str, Any]) -> Dict[str, Any]:
    return {"status": "sent", "payload": payload}
