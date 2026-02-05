#!/usr/bin/env bash
# =============================================================================
# run_enrichment.sh — Phase 3: Enrichment Orchestrator
# =============================================================================
# Reads a dispatch ledger and runs enrichment tasks for each job.
# Coordinates ga4_pull, ads_pull, fathom_sweep, and claude_analysis.
#
# Usage:
#   ./scripts/reports/run_enrichment.sh [--dispatch PATH] [--task TYPE] [--dry-run]
#
# Options:
#   --dispatch PATH    Path to dispatch ledger (default: latest)
#   --task TYPE        Run only one task type (ga4_pull|ads_pull|fathom_sweep|claude_analysis)
#   --dry-run          Generate request templates without calling APIs
#
# Outputs:
#   reports/monthly/{client}/{period}/enrichment/ga4_data.json
#   reports/monthly/{client}/{period}/enrichment/ads_data.json
#   reports/monthly/{client}/{period}/enrichment/fathom_data.json
#   reports/monthly/{client}/{period}/enrichment/claude_analysis.json
#   vault/ledger/report_jobs/enrichment_{timestamp}.json
#
# References:
#   - orchestration_specs/reporting_orchestration.v1.md (Phase 3)
#   - config/identity.v1.json (auth mappings)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENRICHMENT_DIR="$SCRIPT_DIR/enrichment"
LEDGER_DIR="$REPO_ROOT/vault/ledger/report_jobs"
TIMESTAMP=$(date -u +"%Y%m%dT%H%M%S")

DISPATCH_FILE=""
TASK_FILTER=""
DRY_RUN=false

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dispatch) DISPATCH_FILE="$2"; shift 2 ;;
    --task) TASK_FILTER="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

# --- Find latest dispatch if not specified ---
if [ -z "$DISPATCH_FILE" ]; then
  DISPATCH_FILE=$(ls -t "$LEDGER_DIR"/dispatch_*.json 2>/dev/null | head -1)
  if [ -z "$DISPATCH_FILE" ]; then
    echo "STOP: No dispatch ledger found. Run dispatch_monthly_jobs.sh first."
    exit 1
  fi
fi

DRY_FLAG=""
if [ "$DRY_RUN" = true ]; then
  DRY_FLAG="--dry-run"
fi

echo "============================================="
echo "  LMAOS Phase 3 — Enrichment Orchestrator"
echo "============================================="
echo "Timestamp:  $TIMESTAMP"
echo "Dispatch:   $DISPATCH_FILE"
echo "Task:       ${TASK_FILTER:-all}"
echo "Dry run:    $DRY_RUN"
echo ""

# --- Parse dispatch ledger ---
JOB_COUNT=$(python3 -c "
import json
with open('$DISPATCH_FILE') as f:
    data = json.load(f)
print(len(data.get('jobs', [])))
")

echo "Jobs to process: $JOB_COUNT"
echo ""

RESULTS=()
COMPLETED=0
FAILED=0
SKIPPED=0

for i in $(seq 0 $((JOB_COUNT - 1))); do
  JOB_INFO=$(python3 -c "
import json
with open('$DISPATCH_FILE') as f:
    data = json.load(f)
job = data['jobs'][$i]
print(f\"{job['client']}|{job['period']}|{job['job_id']}\")
")

  CLIENT=$(echo "$JOB_INFO" | cut -d'|' -f1)
  PERIOD=$(echo "$JOB_INFO" | cut -d'|' -f2)
  JOB_ID=$(echo "$JOB_INFO" | cut -d'|' -f3)

  echo "--- Job $((i+1))/$JOB_COUNT: $CLIENT / $PERIOD ---"

  # GA4 Pull
  if [ -z "$TASK_FILTER" ] || [ "$TASK_FILTER" = "ga4_pull" ]; then
    echo "  [ga4_pull] Running..."
    if bash "$ENRICHMENT_DIR/ga4_pull.sh" --client "$CLIENT" --period "$PERIOD" $DRY_FLAG 2>&1 | tail -3; then
      echo "  [ga4_pull] Done"
    else
      echo "  [ga4_pull] Failed (non-fatal)"
      FAILED=$((FAILED + 1))
    fi
  fi

  # Ads Pull
  if [ -z "$TASK_FILTER" ] || [ "$TASK_FILTER" = "ads_pull" ]; then
    echo "  [ads_pull] Running..."
    if bash "$ENRICHMENT_DIR/ads_pull.sh" --client "$CLIENT" --period "$PERIOD" $DRY_FLAG 2>&1 | tail -3; then
      echo "  [ads_pull] Done"
    else
      echo "  [ads_pull] Failed (non-fatal)"
      FAILED=$((FAILED + 1))
    fi
  fi

  # Fathom Sweep (uses existing transcripts in vault/meetings/)
  if [ -z "$TASK_FILTER" ] || [ "$TASK_FILTER" = "fathom_sweep" ]; then
    echo "  [fathom_sweep] Checking for transcripts..."
    FATHOM_DIR="$REPO_ROOT/vault/meetings/by_client/$CLIENT"
    ENRICHMENT_OUT="$REPO_ROOT/reports/monthly/$CLIENT/$PERIOD/enrichment"
    mkdir -p "$ENRICHMENT_OUT"

    python3 -c "
import json, datetime, os, glob

client = '$CLIENT'
period = '$PERIOD'
fathom_dir = '$FATHOM_DIR'
out_dir = '$ENRICHMENT_OUT'

# Parse period to date range
if period.endswith('-MTD'):
    base = period.replace('-MTD','')
    y, m = map(int, base.split('-'))
    start = datetime.date(y, m, 1)
    end = datetime.date.today()
else:
    y, m = map(int, period.split('-'))
    start = datetime.date(y, m, 1)
    import calendar
    last = calendar.monthrange(y, m)[1]
    end = datetime.date(y, m, last)

# Find matching transcripts
meetings = []
if os.path.isdir(fathom_dir):
    for f in sorted(glob.glob(os.path.join(fathom_dir, '*.json'))):
        basename = os.path.basename(f)
        # Extract date from filename (YYYY-MM-DD_...)
        try:
            date_str = basename[:10]
            file_date = datetime.date.fromisoformat(date_str)
            if start <= file_date <= end:
                meetings.append({
                    'file': basename,
                    'date': str(file_date),
                    'path': f
                })
        except (ValueError, IndexError):
            pass

output = {
    'client_slug': client,
    'period': period,
    'date_range': {'start': str(start), 'end': str(end)},
    'status': 'complete' if meetings else 'no_data',
    'swept_at': datetime.datetime.utcnow().isoformat() + 'Z',
    'meetings_found': len(meetings),
    'meetings': [{'file': m['file'], 'date': m['date']} for m in meetings],
    'evidence': [
        {'type': 'local_file', 'source': fathom_dir},
        {'type': 'api', 'source': 'Fathom API (previously synced)'}
    ]
}

with open(os.path.join(out_dir, 'fathom_data.json'), 'w') as f:
    json.dump(output, f, indent=2)
print(f'  [fathom_sweep] {len(meetings)} meetings found for {period}')
" 2>/dev/null || echo "  [fathom_sweep] No transcript data available"
  fi

  # Claude Analysis (generates analysis stub for human/agent review)
  if [ -z "$TASK_FILTER" ] || [ "$TASK_FILTER" = "claude_analysis" ]; then
    echo "  [claude_analysis] Generating analysis template..."
    ENRICHMENT_OUT="$REPO_ROOT/reports/monthly/$CLIENT/$PERIOD/enrichment"
    mkdir -p "$ENRICHMENT_OUT"

    python3 -c "
import json, datetime, os

client = '$CLIENT'
period = '$PERIOD'
out_dir = '$ENRICHMENT_OUT'

# Check what enrichment data is available
ga4_exists = os.path.exists(os.path.join(out_dir, 'ga4_data.json'))
ads_exists = os.path.exists(os.path.join(out_dir, 'ads_data.json'))
fathom_exists = os.path.exists(os.path.join(out_dir, 'fathom_data.json'))

ga4_status = 'available' if ga4_exists else 'missing'
ads_status = 'available' if ads_exists else 'missing'
fathom_status = 'available' if fathom_exists else 'missing'

output = {
    'client_slug': client,
    'period': period,
    'status': 'pending_review',
    'generated_at': datetime.datetime.utcnow().isoformat() + 'Z',
    'assigned_to': 'claude',
    'data_sources': {
        'ga4_data': ga4_status,
        'ads_data': ads_status,
        'fathom_data': fathom_status
    },
    'analysis': {
        'executive_summary': 'PENDING — Claude to synthesize from enrichment data',
        'key_metrics_narrative': 'PENDING — Derive from ga4_data + ads_data',
        'meeting_insights': 'PENDING — Extract themes from fathom_data',
        'recommendations': [],
        'risk_flags': [],
        'opportunities': []
    },
    'governance': {
        'rule': 'No metrics fabrication — use only data from ga4_data.json and ads_data.json',
        'missing_data_handling': 'Mark as pending, do not estimate',
        'review_required': True
    },
    'evidence': [
        {'type': 'enrichment', 'source': 'ga4_data.json', 'status': ga4_status},
        {'type': 'enrichment', 'source': 'ads_data.json', 'status': ads_status},
        {'type': 'enrichment', 'source': 'fathom_data.json', 'status': fathom_status}
    ]
}

with open(os.path.join(out_dir, 'claude_analysis.json'), 'w') as f:
    json.dump(output, f, indent=2)
print(f'  [claude_analysis] Template written (data: GA4={ga4_status}, Ads={ads_status}, Fathom={fathom_status})')
"
  fi

  COMPLETED=$((COMPLETED + 1))
  echo ""
done

# --- Write enrichment ledger ---
ENRICHMENT_LEDGER="$LEDGER_DIR/enrichment_${TIMESTAMP}.json"

python3 -c "
import json, datetime

output = {
    'enrichment_id': 'enrichment_${TIMESTAMP}',
    'timestamp': datetime.datetime.utcnow().isoformat() + 'Z',
    'pipeline_version': '1.0',
    'phase': 3,
    'dispatch_source': '$DISPATCH_FILE',
    'task_filter': '${TASK_FILTER:-all}',
    'dry_run': $( [ "$DRY_RUN" = true ] && echo "True" || echo "False" ),
    'jobs_processed': $COMPLETED,
    'jobs_failed': $FAILED,
    'auth_identity': 'access@theleverageway.com',
    'enrichment_tasks': ['ga4_pull', 'ads_pull', 'fathom_sweep', 'claude_analysis'],
    'evidence': [
        {'type': 'github_file', 'path': 'config/identity.v1.json'},
        {'type': 'github_file', 'path': '$DISPATCH_FILE'}
    ]
}

with open('$ENRICHMENT_LEDGER', 'w') as f:
    json.dump(output, f, indent=2)
"

echo "============================================="
echo "  Phase 3 Complete"
echo "============================================="
echo "Jobs processed: $COMPLETED"
echo "Failures:       $FAILED"
echo "Ledger:         $ENRICHMENT_LEDGER"
