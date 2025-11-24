from __future__ import annotations

import json
import time

from custody.custodian_ledger import log_event
from telemetry.emit_heartbeat import generate_heartbeat


def run_single_cycle() -> dict:
    heartbeat = generate_heartbeat()
    log_event("AUTONOMY_LOOP", heartbeat)
    return heartbeat


def start(loop_count: int = 1, delay_seconds: float = 0.0) -> None:
    for _ in range(loop_count):
        hb = run_single_cycle()
        print(json.dumps(hb, indent=2))
        if delay_seconds:
            time.sleep(delay_seconds)


if __name__ == "__main__":
    start()
