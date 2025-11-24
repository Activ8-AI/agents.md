from __future__ import annotations

from typing import Any, Dict, List


class SQLStore:
    def __init__(self) -> None:
        self._rows: List[Dict[str, Any]] = []

    def insert(self, row: Dict[str, Any]) -> None:
        self._rows.append(row)

    def all(self) -> List[Dict[str, Any]]:
        return list(self._rows)
