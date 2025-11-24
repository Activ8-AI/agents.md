"""Shared configuration for the Meta Mega Codex stack."""

from __future__ import annotations

from datetime import timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CHARTER_ROOT = REPO_ROOT / "charter"
ARTIFACT_DIR = REPO_ROOT / "charter_artifacts"
LOG_DIR = REPO_ROOT / "charter_logs"
CACHE_DIR = ARTIFACT_DIR / "cache"
STATE_FILE = ARTIFACT_DIR / "charter_state.json"
DEFAULT_BACKOFF_SECONDS = (1, 3, 5)
UTC = timezone.utc

for path in (ARTIFACT_DIR, LOG_DIR, CACHE_DIR):
    path.mkdir(parents=True, exist_ok=True)

if not STATE_FILE.exists():
    STATE_FILE.write_text("{}", encoding="utf-8")
