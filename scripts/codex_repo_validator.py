from __future__ import annotations

import json
import os
from typing import Dict, List

REQUIRED_PATHS = [
    "configs/global_config.yaml",
    "orchestration/MCP/relay_server.py",
    "memory/sql_store/sql_store.py",
    "memory/vector_store/vector_store.py",
    "custody/custodian_ledger.py",
    "scripts/load_secrets_from_notion.py",
    "scripts/start_autonomy_loop.py",
    "agent_hub/activate.py",
    "telemetry/emit_heartbeat.py",
    "relay/notion_relay.py",
    "relay/slack_signal.py",
    "relay/teamwork_sink.py",
]


def validate_paths() -> Dict[str, List[str] | str]:
    missing = [path for path in REQUIRED_PATHS if not os.path.exists(path)]
    status = "ok" if not missing else "fail"
    return {"missing": missing, "status": status}


if __name__ == "__main__":
    print(json.dumps(validate_paths(), indent=2))
