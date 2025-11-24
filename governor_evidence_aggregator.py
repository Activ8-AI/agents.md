"""Aggregate evidence across all governors into a single artifact."""

from __future__ import annotations

import json
from datetime import datetime
from typing import Any, Dict, List

from charter.config import ARTIFACT_DIR, UTC


def _collect_evidence() -> List[Dict]:
    evidence_files = sorted(ARTIFACT_DIR.glob("*_evidence.json"))
    reports: List[Dict] = []
    for file in evidence_files:
        try:
            reports.append(json.loads(file.read_text(encoding="utf-8")))
        except json.JSONDecodeError as exc:
            reports.append({"governor": file.stem, "error": str(exc), "path": str(file)})
    return reports


def _write_dashboard(summary: Dict[str, Any]) -> None:
    dashboard = ARTIFACT_DIR / "evidence_dashboard.md"
    lines = ["# Meta Mega Codex Evidence Dashboard", ""]
    for report in summary["reports"]:
        governor = report.get("governor", "unknown")
        status = report.get("evidence", {}).get("status") if "evidence" in report else report.get("status")
        lines.append(f"- **{governor}** — status: `{status}`")
    dashboard.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    reports = _collect_evidence()
    generated_at = datetime.utcnow().replace(tzinfo=UTC).isoformat()
    summary = {"generated_at": generated_at, "reports": reports}
    aggregate_path = ARTIFACT_DIR / "evidence_aggregate.json"
    aggregate_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    _write_dashboard(summary)
    print(f"Evidence aggregated into {aggregate_path}")


if __name__ == "__main__":
    main()
