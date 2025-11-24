from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List

DB_PATH = Path(__file__).resolve().parent / "ledger.db"


def _get_connection() -> sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS ledger (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            event_type TEXT NOT NULL,
            payload TEXT NOT NULL
        )
        """
    )
    return conn


def log_event(event_type: str, payload: Dict[str, Any] | None = None) -> None:
    payload = payload or {}
    timestamp = datetime.now(timezone.utc).isoformat()
    with _get_connection() as conn:
        conn.execute(
            "INSERT INTO ledger (timestamp, event_type, payload) VALUES (?, ?, ?)",
            (timestamp, event_type, json.dumps(payload)),
        )
        conn.commit()


def get_last_events(n: int = 10) -> List[Dict[str, Any]]:
    with _get_connection() as conn:
        cursor = conn.execute(
            "SELECT timestamp, event_type, payload FROM ledger ORDER BY id DESC LIMIT ?",
            (n,),
        )
        rows = cursor.fetchall()
    return [
        {"timestamp": ts, "event": event, "payload": json.loads(payload)}
        for ts, event, payload in rows
    ]
