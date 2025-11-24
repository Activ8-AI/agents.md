from __future__ import annotations

from typing import Any, Dict, List

from custody.custodian_ledger import log_event


def activate(relays: List[str] | None = None, metadata: Dict[str, Any] | None = None) -> Dict[str, Any]:
    relays = relays or []
    metadata = metadata or {}
    payload = {"relays": relays, **metadata}
    log_event("AGENT_ACTIVATION", payload)
    return {"status": "activated", "relays": relays}
