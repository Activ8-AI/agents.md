"""Policy-enforced sweep for Personal charter scope."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from charter.governor_base import Governor, GovernorError

ROOT = Path(__file__).resolve().parent


def build_governor() -> Governor:
    return Governor(
        name="personal",
        domain_policy=str(ROOT / "personal_domain_policy.json"),
        copilot_policy=str(ROOT / "personal-copilot.json"),
        token_env="PAT_PERSONAL",
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Personal Governor Sweep")
    parser.add_argument("--print-report", action="store_true", help="Print evidence JSON to stdout")
    args = parser.parse_args()

    try:
        report = build_governor().run()
    except GovernorError as exc:
        raise SystemExit(f"Personal governor failed: {exc}") from exc

    if args.print_report:
        print(json.dumps(report.as_dict(), indent=2))


if __name__ == "__main__":
    main()
