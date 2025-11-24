"""CLI helper for writing to the custodian log in an append-only fashion."""

from __future__ import annotations

import argparse
import json

from charter.logging_spine import record_custodian_event


def main() -> None:
    parser = argparse.ArgumentParser(description="Append an event to the custodian log")
    parser.add_argument("--event", required=True, help="JSON string representing the event payload")
    args = parser.parse_args()

    payload = json.loads(args.event)
    path = record_custodian_event(payload)
    print(f"Event appended to {path}")


if __name__ == "__main__":
    main()
