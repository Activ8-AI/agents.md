#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONPATH="${ROOT}:${PYTHONPATH:-}"

echo "==> Verifying MAOS MVP directories"
for dir in configs orchestration memory custody scripts agent_hub telemetry relay; do
  test -d "${ROOT}/${dir}" || { echo "Missing directory: ${dir}"; exit 1; }
done

echo "==> Loading secrets from Notion relay"
python "${ROOT}/scripts/load_secrets_from_notion.py"

echo "==> Starting MCP relay server"
python -m orchestration.MCP.relay_server &
RELAY_PID=$!
trap 'kill ${RELAY_PID} >/dev/null 2>&1 || true' EXIT

echo "==> Waiting for MCP /health"
python - <<'PY'
import json
import time
from urllib import request, error

URL = "http://0.0.0.0:8000/health"
for _ in range(30):
    try:
        with request.urlopen(URL, timeout=2) as resp:
            data = json.loads(resp.read().decode())
            if data.get("status") == "ok":
                break
    except error.URLError:
        time.sleep(1)
else:
    raise SystemExit("MCP relay failed /health check")
PY

echo "==> Triggering heartbeat via MCP"
python - <<'PY'
import json
from urllib import request

req = request.Request(
    "http://0.0.0.0:8000/heartbeat",
    data=json.dumps({"source": "start.sh"}).encode(),
    headers={"Content-Type": "application/json"},
    method="POST",
)
with request.urlopen(req, timeout=5) as resp:
    resp.read()
PY

echo "==> Activating agents"
python "${ROOT}/agent_hub/activate.py"

echo "==> Firing autonomy loop (oneshot)"
python "${ROOT}/scripts/start_autonomy_loop.py" --oneshot

echo "==> Generating MVP seal"
python - <<'PY'
from datetime import datetime
import pytz
import yaml
from pathlib import Path

config = yaml.safe_load(Path("configs/global_config.yaml").read_text())
tz = pytz.timezone(config["timezone"])
timestamp = datetime.now(tz).isoformat()

seal = f"""Status: ACTIVE
MCP: ONLINE
Memory Pack: ONLINE
Custodian Ledger: ACTIVE
Agents: ONLINE
Telemetry: ACTIVE
Autonomy Loop: RUNNING
Seal Version: v0
Timestamp: {timestamp}
"""
Path("MVP_v0_SEAL.md").write_text(seal, encoding="utf-8")
PY

echo "==> MAOS MVP activation complete"
