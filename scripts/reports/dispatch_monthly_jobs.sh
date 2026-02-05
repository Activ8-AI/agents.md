#!/usr/bin/env bash
# =============================================================================
# dispatch_monthly_jobs.sh — Phase 2: Job Dispatch
# =============================================================================
# Reads generated draft reports and dispatches enrichment jobs to agents
# via MCP agent-comms (port 5060) or relay (port 5055).
#
# Usage:
#   ./scripts/reports/dispatch_monthly_jobs.sh [--manifest PATH] [--dry-run]
#
# Outputs:
#   vault/ledger/report_jobs/dispatch_{timestamp}.json
#
# References:
#   - orchestration_specs/reporting_orchestration.v1.md (Phase 2)
#   - schemas/weekly_report_schema.v1.json
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPORTS_DIR="$REPO_ROOT/reports/monthly"
LEDGER_DIR="$REPO_ROOT/vault/ledger/report_jobs"
TIMESTAMP=$(date -u +"%Y%m%dT%H%M%S")

# MCP endpoints
AGENT_COMMS_URL="http://localhost:5060/invoke"
RELAY_URL="http://localhost:5055/relay"

DRY_RUN=false
MANIFEST_FILE=""

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest) MANIFEST_FILE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

# --- Find latest manifest if not specified ---
if [ -z "$MANIFEST_FILE" ]; then
  MANIFEST_FILE=$(ls -t "$REPORTS_DIR"/manifest_*.json 2>/dev/null | head -1)
  if [ -z "$MANIFEST_FILE" ]; then
    echo "STOP: No manifest found. Run run_monthly_reports.sh first."
    exit 1
  fi
fi

echo "=== LMAOS Job Dispatch — Phase 2 ==="
echo "Timestamp: $TIMESTAMP"
echo "Manifest: $MANIFEST_FILE"
echo "Dry run: $DRY_RUN"
echo ""

mkdir -p "$LEDGER_DIR"

# --- JSON helper ---
json_query() {
  local file="$1" query="$2"
  if command -v jq &>/dev/null; then
    jq -r "$query" "$file"
  else
    python3 -c "
import json
with open('$file') as f:
    data = json.load(f)
query = '''$query'''
if query == '.entries | length':
    print(len(data.get('entries', [])))
elif '.entries[' in query:
    idx = int(query.split('[')[1].split(']')[0])
    field = query.split('.')[-1]
    print(data['entries'][idx].get(field, ''))
"
  fi
}

# --- Generate UUID ---
gen_uuid() {
  cat /proc/sys/kernel/random/uuid 2>/dev/null || \
    python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null || \
    echo "$(date +%s)-$(( RANDOM ))"
}

# --- Dispatch a single job ---
dispatch_job() {
  local client_slug="$1"
  local period="$2"
  local report_path="$3"
  local job_id
  job_id=$(gen_uuid)

  local tasks='[
    {"task_id": "'"$(gen_uuid)"'", "type": "ga4_pull", "assigned_to": "prime", "status": "queued", "created_at": "'"$(date -u +"%Y-%m-%dT%H:%M:%SZ")"'"},
    {"task_id": "'"$(gen_uuid)"'", "type": "ads_pull", "assigned_to": "prime", "status": "queued", "created_at": "'"$(date -u +"%Y-%m-%dT%H:%M:%SZ")"'"},
    {"task_id": "'"$(gen_uuid)"'", "type": "fathom_sweep", "assigned_to": "codex", "status": "queued", "created_at": "'"$(date -u +"%Y-%m-%dT%H:%M:%SZ")"'"},
    {"task_id": "'"$(gen_uuid)"'", "type": "claude_analysis", "assigned_to": "claude", "status": "queued", "created_at": "'"$(date -u +"%Y-%m-%dT%H:%M:%SZ")"'"}
  ]'

  local job_payload='{
    "job_id": "'"$job_id"'",
    "client_slug": "'"$client_slug"'",
    "period": "'"$period"'",
    "report_path": "'"$report_path"'",
    "tasks": '"$tasks"',
    "status": "dispatched",
    "dispatched_at": "'"$(date -u +"%Y-%m-%dT%H:%M:%SZ")"'"
  }'

  local dispatch_status="logged"
  local message_id="none"

  if [ "$DRY_RUN" = false ]; then
    # Try MCP agent-comms first
    if curl -s --connect-timeout 3 "$AGENT_COMMS_URL" >/dev/null 2>&1; then
      local response
      response=$(curl -s -X POST "$AGENT_COMMS_URL" \
        -H "Content-Type: application/json" \
        -d '{
          "tool": "agentComms.handoff",
          "params": {
            "from_agent": "reporting-pipeline",
            "to_agent": "enrichment-coordinator",
            "payload": '"$job_payload"'
          }
        }' 2>/dev/null || echo '{"status": "failed"}')

      if echo "$response" | grep -q '"accepted"' 2>/dev/null; then
        dispatch_status="accepted"
        message_id=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('message_id','unknown'))" 2>/dev/null || echo "unknown")
      fi
    # Fallback to relay
    elif curl -s --connect-timeout 3 "$RELAY_URL" >/dev/null 2>&1; then
      curl -s -X POST "$RELAY_URL" \
        -H "Content-Type: application/json" \
        -d "$job_payload" >/dev/null 2>&1
      dispatch_status="relayed"
    fi
  fi

  echo "{\"job_id\":\"$job_id\",\"client\":\"$client_slug\",\"period\":\"$period\",\"status\":\"$dispatch_status\",\"message_id\":\"$message_id\"}"
}

# --- Process manifest entries ---
ENTRY_COUNT=$(json_query "$MANIFEST_FILE" '.entries | length')
echo "Reports to dispatch: $ENTRY_COUNT"
echo ""

DISPATCH_RESULTS=""
DISPATCHED=0

for i in $(seq 0 $((ENTRY_COUNT - 1))); do
  CLIENT=$(json_query "$MANIFEST_FILE" ".entries[$i].client")
  PERIOD=$(json_query "$MANIFEST_FILE" ".entries[$i].period")
  PATH_REL=$(json_query "$MANIFEST_FILE" ".entries[$i].path")

  echo "  Dispatching: $CLIENT / $PERIOD"
  RESULT=$(dispatch_job "$CLIENT" "$PERIOD" "$PATH_REL")
  STATUS=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null || echo "logged")
  echo "    -> Status: $STATUS"

  DISPATCH_RESULTS="${DISPATCH_RESULTS}${RESULT},"
  DISPATCHED=$((DISPATCHED + 1))
done

DISPATCH_RESULTS="${DISPATCH_RESULTS%,}"  # Remove trailing comma

# --- Write dispatch ledger ---
DISPATCH_FILE="$LEDGER_DIR/dispatch_${TIMESTAMP}.json"

cat > "$DISPATCH_FILE" <<ENDDISPATCH
{
  "dispatch_id": "dispatch_${TIMESTAMP}",
  "dispatched_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "pipeline_version": "1.0",
  "manifest_source": "$MANIFEST_FILE",
  "total_dispatched": $DISPATCHED,
  "agent_comms_endpoint": "$AGENT_COMMS_URL",
  "relay_endpoint": "$RELAY_URL",
  "dry_run": $DRY_RUN,
  "jobs": [${DISPATCH_RESULTS}]
}
ENDDISPATCH

echo ""
echo "=== Phase 2 Complete ==="
echo "Jobs dispatched: $DISPATCHED"
echo "Ledger: $DISPATCH_FILE"
