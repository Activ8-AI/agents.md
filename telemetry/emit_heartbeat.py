"""Telemetry heartbeat emitter for MAOS MVP."""

from __future__ import annotations

from datetime import datetime

import pytz
import yaml

from custody.custodian_ledger import default_custody_ledger


def _load_config() -> dict:
    with open("configs/global_config.yaml", "r", encoding="utf-8") as fh:
        return yaml.safe_load(fh)


def emit_heartbeat(source: str = "autonomy-loop") -> None:
    config = _load_config()
    tz = pytz.timezone(config["timezone"])
    timestamp = datetime.now(tz).isoformat()
    ledger = default_custody_ledger()
    ledger.record(
        "TELEMETRY_HEARTBEAT",
        {
            "source": source,
            "timestamp": timestamp,
            "primary_identity": config["primary_identity"],
        },
    )


if __name__ == "__main__":
    emit_heartbeat()
