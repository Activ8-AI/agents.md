"""Structured failover runner with retries/backoff for all governors."""

from __future__ import annotations

import argparse
from typing import Callable, Dict, Iterable, List

from charter.resilience import RetryPlan, run_with_backoff

import activ8_governor
import lma_governor
import personal_governor

GOVERNOR_BUILDERS: Dict[str, Callable[[], object]] = {
    "activ8": activ8_governor.build_governor,
    "lma": lma_governor.build_governor,
    "personal": personal_governor.build_governor,
}


def _run_governor(name: str, retries: int, backoff: List[int]) -> None:
    def runner():
        governor = GOVERNOR_BUILDERS[name]()
        report = governor.run()
        print(f"{name} governor status: {report.status}")
        return report

    plan = RetryPlan(attempts=retries, backoff=tuple(backoff))
    run_with_backoff(runner, plan)


def run(targets: Iterable[str], retries: int, backoff: List[int]) -> None:
    for name in targets:
        if name not in GOVERNOR_BUILDERS:
            raise SystemExit(f"Unknown governor: {name}")
        _run_governor(name, retries, backoff)


def main() -> None:
    parser = argparse.ArgumentParser(description="Resilient governor runner")
    parser.add_argument(
        "--targets",
        nargs="+",
        default=["activ8", "lma", "personal"],
        help="Governors to execute",
    )
    parser.add_argument("--retries", type=int, default=3, help="Retry attempts per governor")
    parser.add_argument(
        "--backoff",
        nargs="+",
        type=int,
        default=[1, 3, 5],
        help="Backoff schedule in seconds",
    )
    args = parser.parse_args()

    run(args.targets, args.retries, args.backoff)


if __name__ == "__main__":
    main()
