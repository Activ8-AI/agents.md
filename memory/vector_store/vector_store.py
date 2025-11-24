"""Minimal JSON-based vector index for MVP usage."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import List, Sequence


@dataclass
class VectorEntry:
    key: str
    vector: List[float]
    metadata: dict


class VectorIndex:
    """Very small JSON-backed vector store suitable for MVP prototypes."""

    def __init__(self, index_path: str) -> None:
        self._path = Path(index_path)
        self._path.parent.mkdir(parents=True, exist_ok=True)
        self._entries: List[VectorEntry] = []
        self._load()

    def _load(self) -> None:
        if not self._path.exists():
            self._entries = []
            return
        self._entries = [
            VectorEntry(**entry) for entry in json.loads(self._path.read_text())
        ]

    def _persist(self) -> None:
        payload = [entry.__dict__ for entry in self._entries]
        self._path.write_text(json.dumps(payload, indent=2))

    def add(self, key: str, vector: Sequence[float], metadata: dict | None = None) -> None:
        entry = VectorEntry(key=key, vector=list(vector), metadata=metadata or {})
        self._entries.append(entry)
        self._persist()

    def top_k(self, query: Sequence[float], k: int = 3) -> List[VectorEntry]:
        """Return the k closest entries using naive dot-product similarity."""
        if not self._entries:
            return []
        query_vec = list(query)
        scored = []
        for entry in self._entries:
            score = sum(a * b for a, b in zip(entry.vector, query_vec))
            scored.append((score, entry))
        scored.sort(key=lambda item: item[0], reverse=True)
        return [entry for _, entry in scored[:k]]
