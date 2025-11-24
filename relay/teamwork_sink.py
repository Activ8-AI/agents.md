from __future__ import annotations

from typing import Any, Dict


def archive_event(payload: Dict[str, Any]) -> Dict[str, Any]:
    return {"status": "archived", "payload": payload}
