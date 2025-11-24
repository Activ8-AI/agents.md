"""Routes execution to the appropriate governor."""

from __future__ import annotations

import argparse
from typing import Callable, Dict

import activ8_governor
import lma_governor
import personal_governor

GOVERNOR_BUILDERS: Dict[str, Callable] = {
    "activ8": activ8_governor.build_governor,
    "lma": lma_governor.build_governor,
    "personal": personal_governor.build_governor,
}


def main() -> None:
    parser = argparse.ArgumentParser(description="MCP Governor Router")
    parser.add_argument(
        "--target",
        choices=sorted(GOVERNOR_BUILDERS.keys()) + ["all"],
        default="all",
        help="Governor target",
    )
    args = parser.parse_args()

    targets = (
        list(GOVERNOR_BUILDERS.keys())
        if args.target == "all"
        else [args.target]
    )

    for name in targets:
        report = GOVERNOR_BUILDERS[name]().run()
        print(f"{name} governor completed with status {report.status}")


if __name__ == "__main__":
    main()
