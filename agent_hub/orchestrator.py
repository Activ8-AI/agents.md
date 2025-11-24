from __future__ import annotations

from typing import Any, Dict

from telemetry.emit_heartbeat import generate_heartbeat


class Orchestrator:
    def __init__(self, ledger, relays) -> None:
        self.ledger = ledger
        self.relays = relays

    def log(self, event_type: str, payload: Dict[str, Any] | None = None) -> None:
        self.ledger.log_event(event_type, payload or {})

    def run_command(self, cmd: str, payload: Dict[str, Any] | None = None) -> Dict[str, Any]:
        self.log("ORCH_COMMAND_RECEIVED", {"cmd": cmd})

        handler = getattr(self, f"cmd_{cmd}", None)
        if not handler:
            self.log("ORCH_COMMAND_UNKNOWN", {"cmd": cmd})
            return {"status": "unknown_command"}

        try:
            result = handler(payload or {})
            self.log("ORCH_COMMAND_SUCCESS", {"cmd": cmd})
            return {"status": "ok", "result": result}
        except Exception as exc:  # pragma: no cover - defensive
            self.log("ORCH_COMMAND_FAILURE", {"cmd": cmd, "error": str(exc)})
            return {"status": "error", "error": str(exc)}

    def cmd_mvp_health_check(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        res = {
            "mcp": "ok",
            "heartbeat": None,
            "ledger": "unknown",
        }

        heartbeat = generate_heartbeat()
        self.log("ORCH_STEP_HEARTBEAT", heartbeat)
        res["heartbeat"] = heartbeat
        res["ledger"] = "ok"
        return res
