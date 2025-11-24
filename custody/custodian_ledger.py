"""Custodian ledger facade ensuring all critical operations are tracked."""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

from memory.sql_store import SQLLedger


class CustodianLedger:
    """Single entry point for custody events."""

    def __init__(self, db_path: str) -> None:
        self._ledger = SQLLedger(db_path)

    @staticmethod
    def _timestamp() -> str:
        now = datetime.now(timezone.utc)
        return now.astimezone().isoformat()

    def record(self, event_type: str, payload: dict) -> int:
        """Record an event with the current timestamp."""
        payload = dict(payload)
        payload["path"] = payload.get("path", "")
        return self._ledger.append(self._timestamp(), event_type, payload)


def default_custody_ledger() -> CustodianLedger:
    """Helper that reads the configured ledger location."""
    config_path = Path("configs/global_config.yaml")
    db_path = "memory/sql_store/ledger.db"
    if config_path.exists():
        import yaml

        config = yaml.safe_load(config_path.read_text())
        db_path = config.get("paths", {}).get("custody_ledger", db_path)
    return CustodianLedger(db_path)
