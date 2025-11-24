"""Append-only logging spine for custodian and trace records."""

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from typing import Any, Dict

from .config import LOG_DIR, UTC


def _append_log(path: Path, entry: Dict[str, Any]) -> None:
    timestamped = {"timestamp": datetime.utcnow().replace(tzinfo=UTC).isoformat()}
    timestamped.update(entry)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(timestamped) + "\n")


def record_custodian_event(context: Dict[str, Any]) -> Path:
    """Write an entry to the custodian log."""

    path = LOG_DIR / "custodian.log"
    _append_log(path, context)
    return path


def record_genesis_trace(context: Dict[str, Any]) -> Path:
    """Write an entry to the genesis trace log."""

    path = LOG_DIR / "genesis_trace.log"
    _append_log(path, context)
    return path
