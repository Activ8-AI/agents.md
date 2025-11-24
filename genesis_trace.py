"""CLI helper for writing to the genesis trace log."""

from __future__ import annotations

import argparse
import json

from charter.logging_spine import record_genesis_trace


def main() -> None:
    parser = argparse.ArgumentParser(description="Append an event to the genesis trace")
    parser.add_argument("--event", required=True, help="JSON string representing the event payload")
    args = parser.parse_args()

    payload = json.loads(args.event)
    path = record_genesis_trace(payload)
    print(f"Trace appended to {path}")


if __name__ == "__main__":
    main()
