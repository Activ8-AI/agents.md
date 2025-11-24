from __future__ import annotations

from typing import Any, Dict


def send_slack_message(channel: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    return {"status": "sent", "channel": channel, "payload": payload}
