"""Evidence helpers for aggregating governor outputs."""

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from typing import Any, Dict

from .config import ARTIFACT_DIR, STATE_FILE, UTC


def _timestamp() -> str:
    return datetime.utcnow().replace(tzinfo=UTC).isoformat()


def write_evidence(governor: str, evidence: Dict[str, Any]) -> Path:
    path = ARTIFACT_DIR / f"{governor}_evidence.json"
    payload = {"governor": governor, "recorded_at": _timestamp(), "evidence": evidence}
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return path


def read_state() -> Dict[str, Any]:
    text = STATE_FILE.read_text(encoding="utf-8").strip() or "{}"
    return json.loads(text)


def write_state(state: Dict[str, Any]) -> None:
    STATE_FILE.write_text(json.dumps(state, indent=2), encoding="utf-8")


def update_state(governor: str, status: str, evidence_path: Path) -> Dict[str, Any]:
    state = read_state()
    state[governor] = {"status": status, "updated_at": _timestamp(), "evidence": str(evidence_path)}
    write_state(state)
    return state
