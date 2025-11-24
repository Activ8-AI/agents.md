from __future__ import annotations

from typing import Dict, List, Sequence


class VectorStore:
    def __init__(self) -> None:
        self._vectors: List[Dict[str, Sequence[float]]] = []

    def add(self, label: str, vector: Sequence[float]) -> None:
        self._vectors.append({"label": label, "vector": list(vector)})

    def all(self) -> List[Dict[str, Sequence[float]]]:
        return list(self._vectors)
