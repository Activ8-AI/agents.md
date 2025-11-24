"""Append-only SQL ledger used for custody tracking and telemetry storage."""

from __future__ import annotations

import json
import sqlite3
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Optional


@dataclass(frozen=True)
class LedgerEvent:
    """Represents a single ledger entry."""

    id: int
    timestamp: str
    event_type: str
    payload: dict


class SQLLedger:
    """Simple append-only ledger backed by SQLite."""

    def __init__(self, db_path: str) -> None:
        self._path = Path(db_path)
        self._path.parent.mkdir(parents=True, exist_ok=True)
        self._conn = sqlite3.connect(self._path)
        self._conn.row_factory = sqlite3.Row
        self._ensure_schema()

    def _ensure_schema(self) -> None:
        with self._conn:
            self._conn.execute(
                """
                CREATE TABLE IF NOT EXISTS ledger (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp TEXT NOT NULL,
                    event_type TEXT NOT NULL,
                    payload TEXT NOT NULL
                )
                """
            )

    def append(self, timestamp: str, event_type: str, payload: dict) -> int:
        """Append a new event and return its row id."""
        with self._conn:
            cursor = self._conn.execute(
                "INSERT INTO ledger(timestamp, event_type, payload) VALUES (?, ?, ?)",
                (timestamp, event_type, json.dumps(payload)),
            )
        return int(cursor.lastrowid)

    def fetch_all(self, limit: Optional[int] = None) -> Iterable[LedgerEvent]:
        """Fetch events ordered newest first."""
        query = "SELECT * FROM ledger ORDER BY id DESC"
        if limit:
            query += f" LIMIT {int(limit)}"
        rows = self._conn.execute(query).fetchall()
        return [
            LedgerEvent(
                id=row["id"],
                timestamp=row["timestamp"],
                event_type=row["event_type"],
                payload=json.loads(row["payload"]),
            )
            for row in rows
        ]

    def latest(self) -> Optional[LedgerEvent]:
        """Return the most recent event if any."""
        row = self._conn.execute(
            "SELECT * FROM ledger ORDER BY id DESC LIMIT 1"
        ).fetchone()
        if not row:
            return None
        return LedgerEvent(
            id=row["id"],
            timestamp=row["timestamp"],
            event_type=row["event_type"],
            payload=json.loads(row["payload"]),
        )

    def close(self) -> None:
        self._conn.close()
