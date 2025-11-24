"""Autonomy loop that emits heartbeat telemetry."""

from __future__ import annotations

import argparse
import time

from telemetry.emit_heartbeat import emit_heartbeat


def run(oneshot: bool = False, interval: int = 60) -> None:
    if oneshot:
        emit_heartbeat(source="autonomy-loop")
        return

    while True:
        emit_heartbeat(source="autonomy-loop")
        time.sleep(interval)


def main() -> None:
    parser = argparse.ArgumentParser(description="Start the MAOS autonomy loop.")
    parser.add_argument("--oneshot", action="store_true", help="Emit a single heartbeat and exit.")
    parser.add_argument("--interval", type=int, default=60, help="Seconds between heartbeats.")
    args = parser.parse_args()
    run(oneshot=args.oneshot, interval=args.interval)


if __name__ == "__main__":
    main()
