#!/usr/bin/env bash
# =============================================================================
# run_monthly_reports.sh — Phase 1: Report Generation
# =============================================================================
# Generates draft reports for all active clients in config/clients.v1.json
# for the specified periods (full month + MTD).
#
# Usage:
#   ./scripts/reports/run_monthly_reports.sh [--month YYYY-MM] [--mtd]
#
# Outputs:
#   reports/monthly/{client_slug}/{period}/draft_report.json
#   reports/monthly/{client_slug}/{period}/draft_report.md
#   reports/monthly/manifest_{timestamp}.json
#
# References:
#   - orchestration_specs/reporting_orchestration.v1.md (Phase 1)
#   - schemas/weekly_report_schema.v1.json
#   - config/clients.v1.json
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$REPO_ROOT/config/clients.v1.json"
REPORTS_DIR="$REPO_ROOT/reports/monthly"
TIMESTAMP=$(date -u +"%Y%m%dT%H%M%S")

# --- Defaults ---
CURRENT_YEAR=$(date -u +"%Y")
CURRENT_MONTH=$(date -u +"%m")
PREV_MONTH=$(date -u -d "$(date -u +%Y-%m-01) -1 month" +"%Y-%m" 2>/dev/null || date -u -v-1m +"%Y-%m" 2>/dev/null || echo "${CURRENT_YEAR}-01")
GENERATE_MTD=true
FULL_MONTH="$PREV_MONTH"

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --month) FULL_MONTH="$2"; shift 2 ;;
    --mtd) GENERATE_MTD=true; shift ;;
    --no-mtd) GENERATE_MTD=false; shift ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

MTD_PERIOD="${CURRENT_YEAR}-${CURRENT_MONTH}-MTD"

# --- Validate config ---
if [ ! -f "$CONFIG_FILE" ]; then
  echo "STOP: Config file not found: $CONFIG_FILE"
  exit 1
fi

if ! command -v jq &>/dev/null && ! command -v python3 &>/dev/null; then
  echo "STOP: Requires jq or python3 for JSON processing"
  exit 1
fi

# --- JSON helper (works with jq or python3 fallback) ---
json_query() {
  local file="$1" query="$2"
  if command -v jq &>/dev/null; then
    jq -r "$query" "$file"
  else
    python3 -c "
import json, sys
with open('$file') as f:
    data = json.load(f)
# Simplified query support
query = '''$query'''
if query == '.clients | length':
    print(len(data['clients']))
elif '.clients[' in query:
    idx = int(query.split('[')[1].split(']')[0])
    field = query.split('.')[-1]
    print(data['clients'][idx].get(field, ''))
"
  fi
}

# --- Generate report JSON ---
generate_report_json() {
  local client_slug="$1"
  local display_name="$2"
  local period_label="$3"
  local period_start="$4"
  local period_end="$5"
  local period_type="$6"
  local teamwork_id="$7"
  local report_id
  report_id=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null || echo "rpt-${client_slug}-${period_start}")

  cat <<ENDJSON
{
  "report_id": "$report_id",
  "schema_version": "1.0",
  "client": {
    "slug": "$client_slug",
    "display_name": "$display_name",
    "teamwork_project_id": "$teamwork_id",
    "notion_portal_id": null
  },
  "period": {
    "label": "$period_label",
    "start_date": "$period_start",
    "end_date": "$period_end",
    "type": "$period_type"
  },
  "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "status": "draft",
  "sections": {
    "executive_summary": {
      "status": "pending",
      "content": "",
      "highlights": [],
      "concerns": []
    },
    "traffic": {
      "status": "pending",
      "sessions": null,
      "users": null,
      "new_users": null,
      "pageviews": null,
      "bounce_rate": null,
      "avg_session_duration": null,
      "top_channels": [],
      "period_comparison": {
        "sessions_delta_pct": null,
        "users_delta_pct": null,
        "conversions_delta_pct": null
      },
      "source": "ga4",
      "enriched_by": ""
    },
    "paid_media": {
      "status": "pending",
      "total_spend": null,
      "impressions": null,
      "clicks": null,
      "ctr": null,
      "conversions": null,
      "cost_per_conversion": null,
      "roas": null,
      "platforms": [],
      "source": "google_ads",
      "enriched_by": ""
    },
    "seo": {
      "status": "pending",
      "organic_sessions": null,
      "organic_conversions": null,
      "keywords_tracked": null,
      "keywords_top_10": null,
      "keywords_improved": null,
      "keywords_declined": null,
      "top_pages": [],
      "source": "ga4",
      "enriched_by": ""
    },
    "meetings": {
      "status": "pending",
      "total_meetings": null,
      "meeting_list": [],
      "source": "fathom",
      "enriched_by": ""
    },
    "recommendations": {
      "status": "pending",
      "items": [],
      "enriched_by": ""
    }
  },
  "evidence": [
    {
      "type": "github_file",
      "path": "config/clients.v1.json",
      "description": "Client configuration source"
    },
    {
      "type": "github_file",
      "path": "schemas/weekly_report_schema.v1.json",
      "description": "Report schema validation"
    }
  ],
  "enrichment_jobs": [
    {"task_type": "ga4_pull", "assigned_to": "prime", "status": "queued", "completed_at": null},
    {"task_type": "ads_pull", "assigned_to": "prime", "status": "queued", "completed_at": null},
    {"task_type": "fathom_sweep", "assigned_to": "codex", "status": "queued", "completed_at": null},
    {"task_type": "claude_analysis", "assigned_to": "claude", "status": "queued", "completed_at": null}
  ],
  "delivery": {
    "teamwork_message_id": null,
    "notion_block_id": null,
    "delivered_at": null
  }
}
ENDJSON
}

# --- Generate report Markdown ---
generate_report_md() {
  local client_slug="$1"
  local display_name="$2"
  local period_label="$3"
  local period_start="$4"
  local period_end="$5"

  cat <<ENDMD
# ${display_name} — ${period_label}

**Report Period:** ${period_start} to ${period_end}
**Generated:** $(date -u +"%Y-%m-%d %H:%M UTC")
**Status:** Draft (awaiting enrichment)

---

## Executive Summary

_Pending enrichment by Claude analysis agent._

### Highlights
- _(awaiting data)_

### Concerns
- _(awaiting data)_

---

## Traffic & Analytics

| Metric | Value | vs Previous |
|--------|-------|-------------|
| Sessions | — | — |
| Users | — | — |
| New Users | — | — |
| Pageviews | — | — |
| Bounce Rate | — | — |
| Avg Session Duration | — | — |

**Source:** GA4 (pending enrichment by Prime)

---

## Paid Media

| Metric | Value |
|--------|-------|
| Total Spend | — |
| Impressions | — |
| Clicks | — |
| CTR | — |
| Conversions | — |
| Cost/Conversion | — |
| ROAS | — |

**Source:** Google Ads / Meta Ads (pending enrichment by Prime)

---

## SEO Performance

| Metric | Value |
|--------|-------|
| Organic Sessions | — |
| Organic Conversions | — |
| Keywords Tracked | — |
| Keywords in Top 10 | — |
| Keywords Improved | — |
| Keywords Declined | — |

**Source:** GA4 / Search Console (pending enrichment by Prime)

---

## Meeting Activity

| Date | Title | Summary |
|------|-------|---------|
| — | — | — |

**Source:** Fathom (pending enrichment by Codex)

---

## Recommendations

_Pending Claude analysis of enriched data._

---

## Evidence

- \`config/clients.v1.json\` — Client configuration
- \`schemas/weekly_report_schema.v1.json\` — Report schema

---

_Generated by LMAOS Reporting Pipeline v1 | Orchestration spec: reporting_orchestration.v1_
ENDMD
}

# --- Main ---
echo "=== LMAOS Report Generation — Phase 1 ==="
echo "Timestamp: $TIMESTAMP"
echo "Full month: $FULL_MONTH"
echo "MTD period: $MTD_PERIOD"
echo "Config: $CONFIG_FILE"
echo ""

# Read client count
CLIENT_COUNT=$(json_query "$CONFIG_FILE" '.clients | length')
echo "Clients in config: $CLIENT_COUNT"

GENERATED=0
MANIFEST_ENTRIES=""

# Process each client
for i in $(seq 0 $((CLIENT_COUNT - 1))); do
  SLUG=$(json_query "$CONFIG_FILE" ".clients[$i].slug")
  NAME=$(json_query "$CONFIG_FILE" ".clients[$i].display_name")
  STATUS=$(json_query "$CONFIG_FILE" ".clients[$i].status")
  TW_ID=$(json_query "$CONFIG_FILE" ".clients[$i].teamwork_project_id")

  # Skip non-active clients
  if [ "$STATUS" != "active" ]; then
    echo "  SKIP: $NAME ($SLUG) — status: $STATUS"
    continue
  fi

  echo "  Generating reports for: $NAME ($SLUG)"

  # --- Full month report ---
  MONTH_YEAR=$(echo "$FULL_MONTH" | cut -d'-' -f1)
  MONTH_NUM=$(echo "$FULL_MONTH" | cut -d'-' -f2)
  MONTH_NAME=$(date -d "$FULL_MONTH-01" +"%B" 2>/dev/null || python3 -c "import datetime; print(datetime.date($MONTH_YEAR, $MONTH_NUM, 1).strftime('%B'))" 2>/dev/null || echo "Month $MONTH_NUM")
  PERIOD_LABEL="$MONTH_NAME $MONTH_YEAR"
  PERIOD_START="$FULL_MONTH-01"
  LAST_DAY=$(date -d "$FULL_MONTH-01 +1 month -1 day" +"%d" 2>/dev/null || python3 -c "import calendar; print(calendar.monthrange($MONTH_YEAR, $MONTH_NUM)[1])" 2>/dev/null || echo "31")
  PERIOD_END="$FULL_MONTH-$LAST_DAY"
  PERIOD_DIR="$REPORTS_DIR/$SLUG/$FULL_MONTH"

  mkdir -p "$PERIOD_DIR"
  generate_report_json "$SLUG" "$NAME" "$PERIOD_LABEL" "$PERIOD_START" "$PERIOD_END" "full_month" "$TW_ID" > "$PERIOD_DIR/draft_report.json"
  generate_report_md "$SLUG" "$NAME" "$PERIOD_LABEL" "$PERIOD_START" "$PERIOD_END" > "$PERIOD_DIR/draft_report.md"
  echo "    -> $PERIOD_DIR/draft_report.{json,md}"
  GENERATED=$((GENERATED + 1))

  MANIFEST_ENTRIES="${MANIFEST_ENTRIES}{\"client\":\"$SLUG\",\"period\":\"$FULL_MONTH\",\"type\":\"full_month\",\"path\":\"reports/monthly/$SLUG/$FULL_MONTH\"},"

  # --- MTD report ---
  if [ "$GENERATE_MTD" = true ]; then
    MTD_DIR="$REPORTS_DIR/$SLUG/$MTD_PERIOD"
    MTD_LABEL="$MONTH_NAME $CURRENT_YEAR MTD"
    MTD_START="$CURRENT_YEAR-$CURRENT_MONTH-01"
    MTD_END=$(date -u +"%Y-%m-%d")

    mkdir -p "$MTD_DIR"
    generate_report_json "$SLUG" "$NAME" "$MTD_LABEL" "$MTD_START" "$MTD_END" "mtd" "$TW_ID" > "$MTD_DIR/draft_report.json"
    generate_report_md "$SLUG" "$NAME" "$MTD_LABEL" "$MTD_START" "$MTD_END" > "$MTD_DIR/draft_report.md"
    echo "    -> $MTD_DIR/draft_report.{json,md}"
    GENERATED=$((GENERATED + 1))

    MANIFEST_ENTRIES="${MANIFEST_ENTRIES}{\"client\":\"$SLUG\",\"period\":\"$MTD_PERIOD\",\"type\":\"mtd\",\"path\":\"reports/monthly/$SLUG/$MTD_PERIOD\"},"
  fi
done

# --- Write manifest ---
MANIFEST_ENTRIES="${MANIFEST_ENTRIES%,}"  # Remove trailing comma
MANIFEST_FILE="$REPORTS_DIR/manifest_${TIMESTAMP}.json"

cat > "$MANIFEST_FILE" <<ENDMANIFEST
{
  "manifest_id": "manifest_${TIMESTAMP}",
  "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "pipeline_version": "1.0",
  "config_source": "config/clients.v1.json",
  "schema_version": "1.0",
  "reports_generated": $GENERATED,
  "periods": {
    "full_month": "$FULL_MONTH",
    "mtd": "$MTD_PERIOD"
  },
  "entries": [${MANIFEST_ENTRIES}]
}
ENDMANIFEST

echo ""
echo "=== Phase 1 Complete ==="
echo "Reports generated: $GENERATED"
echo "Manifest: $MANIFEST_FILE"
