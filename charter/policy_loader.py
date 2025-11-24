"""Deterministic policy loading with caching and immutability guarantees."""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Dict

from .config import CACHE_DIR, UTC


@dataclass(frozen=True)
class PolicyEnvelope:
    """Represents a policy plus metadata about how/when it was loaded."""

    name: str
    path: Path
    sha256: str
    loaded_at: str
    payload: Dict[str, Any]

    def as_dict(self) -> Dict[str, Any]:
        return {
            "name": self.name,
            "path": str(self.path),
            "sha256": self.sha256,
            "loaded_at": self.loaded_at,
            "payload": self.payload,
        }


def _hash_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _cache_path(policy_path: Path, digest: str) -> Path:
    return CACHE_DIR / f"{policy_path.name}.{digest}.json"


def load_policy(path: str | Path) -> PolicyEnvelope:
    """Load a policy JSON file, snapshotting it into the cache directory."""

    policy_path = Path(path).resolve()
    if not policy_path.exists():
        raise FileNotFoundError(f"Policy not found: {policy_path}")

    raw_bytes = policy_path.read_bytes()
    digest = _hash_bytes(raw_bytes)
    payload = json.loads(raw_bytes)
    loaded_at = datetime.utcnow().replace(tzinfo=UTC).isoformat()

    cache_path = _cache_path(policy_path, digest)
    if not cache_path.exists():
        cache_payload = {
            "name": policy_path.name,
            "path": str(policy_path),
            "sha256": digest,
            "cached_at": loaded_at,
            "payload": payload,
        }
        cache_path.write_text(json.dumps(cache_payload, indent=2), encoding="utf-8")

    return PolicyEnvelope(
        name=policy_path.name,
        path=policy_path,
        sha256=digest,
        loaded_at=loaded_at,
        payload=payload,
    )
