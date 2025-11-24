from __future__ import annotations

import platform
import socket
import uuid
from datetime import datetime, timezone
from typing import Any, Dict


def generate_heartbeat(extra: Dict[str, Any] | None = None) -> Dict[str, Any]:
    extra = extra or {}
    heartbeat = {
        "id": str(uuid.uuid4()),
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "status": "ok",
        "host": socket.gethostname(),
        "platform": platform.platform(),
    }
    heartbeat.update(extra)
    return heartbeat
