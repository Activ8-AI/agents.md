"""Detect stale governors and escalate when needed."""

from __future__ import annotations

import argparse

from charter.resilience import stale_governors


def main() -> None:
    parser = argparse.ArgumentParser(description="Meta Mega Codex watchdog")
    parser.add_argument(
        "--threshold-minutes",
        type=int,
        default=60,
        help="Maximum allowed staleness before triggering escalation",
    )
    args = parser.parse_args()

    stale = list(stale_governors(args.threshold_minutes))
    if stale:
        raise SystemExit(f"Watchdog escalation: stale governors detected {stale}")
    print("All governors refreshed within threshold.")


if __name__ == "__main__":
    main()
