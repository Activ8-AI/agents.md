#!/usr/bin/env bash
# =============================================================================
# ga4_pull.sh — Phase 3 Enrichment: Google Analytics 4 Data Pull
# =============================================================================
# Pulls GA4 analytics data for a client/period using the GA4 Data API (v1beta).
# Auth: OAuth2 via access@theleverageway.com (or service account)
#
# Usage:
#   ./scripts/reports/enrichment/ga4_pull.sh \
#     --client modern-office-furniture \
#     --period 2026-01 \
#     [--property 123456789] \
#     [--dry-run]
#
# Env vars (required unless --dry-run):
#   GA4_REFRESH_TOKEN or GOOGLE_APPLICATION_CREDENTIALS
#   GA4_OAUTH_CLIENT_ID + GA4_OAUTH_CLIENT_SECRET (if using refresh token)
#
# Outputs:
#   reports/monthly/{client}/{period}/enrichment/ga4_data.json
#
# References:
#   - config/identity.v1.json (auth config)
#   - config/clients.v1.json (property IDs)
#   - orchestration_specs/reporting_orchestration.v1.md (Phase 3)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONFIG_FILE="$REPO_ROOT/config/clients.v1.json"

CLIENT_SLUG=""
PERIOD=""
PROPERTY_ID=""
DRY_RUN=false
GA4_API="https://analyticsdata.googleapis.com/v1beta"

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --client) CLIENT_SLUG="$2"; shift 2 ;;
    --period) PERIOD="$2"; shift 2 ;;
    --property) PROPERTY_ID="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

if [ -z "$CLIENT_SLUG" ] || [ -z "$PERIOD" ]; then
  echo "Usage: ga4_pull.sh --client SLUG --period YYYY-MM [--property ID] [--dry-run]"
  exit 1
fi

# --- Resolve GA4 property from client config ---
if [ -z "$PROPERTY_ID" ]; then
  PROPERTY_ID=$(python3 -c "
import json
with open('$CONFIG_FILE') as f:
    data = json.load(f)
for c in data['clients']:
    if c['slug'] == '$CLIENT_SLUG':
        pid = c.get('integrations',{}).get('ga4_property_id')
        print(pid if pid else '')
        break
" 2>/dev/null)
fi

if [ -z "$PROPERTY_ID" ] || [ "$PROPERTY_ID" = "None" ] || [ "$PROPERTY_ID" = "null" ]; then
  echo "WARN: No GA4 property ID for $CLIENT_SLUG — needs configuration in config/clients.v1.json"
  if [ "$DRY_RUN" = false ]; then
    echo "  Set ga4_property_id in the client integrations block, or pass --property ID"
  fi
fi

# --- Compute date range ---
compute_date_range() {
  local period="$1"
  if [[ "$period" == *-MTD ]]; then
    local base="${period%-MTD}"
    local start_date="${base}-01"
    local end_date=$(date -u +"%Y-%m-%d")
    echo "$start_date" "$end_date"
  else
    local start_date="${period}-01"
    # Last day of month
    local end_date=$(date -u -d "${start_date} +1 month -1 day" +"%Y-%m-%d" 2>/dev/null || \
      python3 -c "
import datetime
d = datetime.date(int('${period}'.split('-')[0]), int('${period}'.split('-')[1]), 1)
import calendar
last = calendar.monthrange(d.year, d.month)[1]
print(datetime.date(d.year, d.month, last))
")
    echo "$start_date" "$end_date"
  fi
}

DATE_RANGE=($(compute_date_range "$PERIOD"))
START_DATE="${DATE_RANGE[0]}"
END_DATE="${DATE_RANGE[1]}"

OUTPUT_DIR="$REPO_ROOT/reports/monthly/$CLIENT_SLUG/$PERIOD/enrichment"
mkdir -p "$OUTPUT_DIR"

echo "=== GA4 Data Pull ==="
echo "Client:   $CLIENT_SLUG"
echo "Period:   $PERIOD ($START_DATE → $END_DATE)"
echo "Property: ${PROPERTY_ID:-NOT_SET}"
echo "Dry run:  $DRY_RUN"
echo ""

# --- Build GA4 request payload ---
GA4_REQUEST='{
  "dateRanges": [
    {
      "startDate": "'"$START_DATE"'",
      "endDate": "'"$END_DATE"'"
    }
  ],
  "metrics": [
    {"name": "sessions"},
    {"name": "totalUsers"},
    {"name": "newUsers"},
    {"name": "screenPageViews"},
    {"name": "bounceRate"},
    {"name": "averageSessionDuration"},
    {"name": "conversions"},
    {"name": "engagementRate"}
  ],
  "dimensions": [
    {"name": "sessionDefaultChannelGroup"}
  ]
}'

GA4_TRAFFIC_SOURCE_REQUEST='{
  "dateRanges": [
    {
      "startDate": "'"$START_DATE"'",
      "endDate": "'"$END_DATE"'"
    }
  ],
  "metrics": [
    {"name": "sessions"},
    {"name": "totalUsers"},
    {"name": "conversions"}
  ],
  "dimensions": [
    {"name": "sessionSource"},
    {"name": "sessionMedium"}
  ],
  "limit": 25
}'

GA4_LANDING_PAGES_REQUEST='{
  "dateRanges": [
    {
      "startDate": "'"$START_DATE"'",
      "endDate": "'"$END_DATE"'"
    }
  ],
  "metrics": [
    {"name": "sessions"},
    {"name": "conversions"},
    {"name": "bounceRate"}
  ],
  "dimensions": [
    {"name": "landingPage"}
  ],
  "orderBys": [
    {"metric": {"metricName": "sessions"}, "desc": true}
  ],
  "limit": 20
}'

# --- Get access token ---
get_access_token() {
  # Method 1: Service account (GOOGLE_APPLICATION_CREDENTIALS)
  if [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ] && [ -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
    python3 -c "
from google.oauth2 import service_account
from google.auth.transport.requests import Request
creds = service_account.Credentials.from_service_account_file(
    '$GOOGLE_APPLICATION_CREDENTIALS',
    scopes=['https://www.googleapis.com/auth/analytics.readonly']
)
creds.refresh(Request())
print(creds.token)
" 2>/dev/null
    return
  fi

  # Method 2: OAuth2 refresh token
  if [ -n "${GA4_REFRESH_TOKEN:-}" ] && [ -n "${GA4_OAUTH_CLIENT_ID:-}" ] && [ -n "${GA4_OAUTH_CLIENT_SECRET:-}" ]; then
    local response
    response=$(curl -s -X POST "https://oauth2.googleapis.com/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "grant_type=refresh_token" \
      -d "client_id=${GA4_OAUTH_CLIENT_ID}" \
      -d "client_secret=${GA4_OAUTH_CLIENT_SECRET}" \
      -d "refresh_token=${GA4_REFRESH_TOKEN}")
    echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null
    return
  fi

  echo ""
}

# --- Execute GA4 API call ---
ga4_report() {
  local token="$1"
  local request_body="$2"
  local report_name="$3"

  curl -s -X POST \
    "${GA4_API}/properties/${PROPERTY_ID}:runReport" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "$request_body"
}

# --- Main execution ---
if [ "$DRY_RUN" = true ]; then
  echo "DRY RUN — writing request payloads only"

  python3 -c "
import json, datetime

output = {
    'client_slug': '$CLIENT_SLUG',
    'period': '$PERIOD',
    'ga4_property_id': '${PROPERTY_ID:-NOT_SET}',
    'date_range': {'start': '$START_DATE', 'end': '$END_DATE'},
    'status': 'dry_run',
    'pulled_at': datetime.datetime.utcnow().isoformat() + 'Z',
    'auth_identity': 'access@theleverageway.com',
    'requests': {
        'channel_overview': json.loads('''$GA4_REQUEST'''),
        'traffic_sources': json.loads('''$GA4_TRAFFIC_SOURCE_REQUEST'''),
        'landing_pages': json.loads('''$GA4_LANDING_PAGES_REQUEST''')
    },
    'data': {
        'channel_overview': {'status': 'pending', 'note': 'Requires GA4 property ID and OAuth credentials'},
        'traffic_sources': {'status': 'pending'},
        'landing_pages': {'status': 'pending'}
    },
    'evidence': [
        {'type': 'api', 'source': 'GA4 Data API v1beta', 'identity': 'access@theleverageway.com'},
        {'type': 'github_file', 'path': 'config/clients.v1.json'}
    ]
}
with open('$OUTPUT_DIR/ga4_data.json', 'w') as f:
    json.dump(output, f, indent=2)
print('  Written: $OUTPUT_DIR/ga4_data.json')
"
else
  if [ -z "$PROPERTY_ID" ] || [ "$PROPERTY_ID" = "None" ] || [ "$PROPERTY_ID" = "null" ]; then
    echo "STOP: Cannot pull GA4 data without property ID."
    echo "  Set ga4_property_id in config/clients.v1.json for $CLIENT_SLUG"
    echo "  Or pass --property <GA4_PROPERTY_ID>"
    echo ""
    echo "  To find property IDs:"
    echo "    1. Sign in as access@theleverageway.com at analytics.google.com"
    echo "    2. Admin → Property → Property Details → Property ID"
    echo "    3. Update config/clients.v1.json integrations.ga4_property_id"
    exit 1
  fi

  ACCESS_TOKEN=$(get_access_token)
  if [ -z "$ACCESS_TOKEN" ]; then
    echo "STOP: No valid credentials found."
    echo "  Set one of:"
    echo "    GOOGLE_APPLICATION_CREDENTIALS (service account JSON)"
    echo "    GA4_REFRESH_TOKEN + GA4_OAUTH_CLIENT_ID + GA4_OAUTH_CLIENT_SECRET"
    echo ""
    echo "  Or run with --dry-run to generate request templates."
    exit 1
  fi

  echo "Pulling channel overview..."
  CHANNEL_DATA=$(ga4_report "$ACCESS_TOKEN" "$GA4_REQUEST" "channel_overview")

  echo "Pulling traffic sources..."
  SOURCE_DATA=$(ga4_report "$ACCESS_TOKEN" "$GA4_TRAFFIC_SOURCE_REQUEST" "traffic_sources")

  echo "Pulling landing pages..."
  LANDING_DATA=$(ga4_report "$ACCESS_TOKEN" "$GA4_LANDING_PAGES_REQUEST" "landing_pages")

  python3 -c "
import json, datetime

output = {
    'client_slug': '$CLIENT_SLUG',
    'period': '$PERIOD',
    'ga4_property_id': '$PROPERTY_ID',
    'date_range': {'start': '$START_DATE', 'end': '$END_DATE'},
    'status': 'complete',
    'pulled_at': datetime.datetime.utcnow().isoformat() + 'Z',
    'auth_identity': 'access@theleverageway.com',
    'data': {
        'channel_overview': json.loads('''$CHANNEL_DATA'''),
        'traffic_sources': json.loads('''$SOURCE_DATA'''),
        'landing_pages': json.loads('''$LANDING_DATA''')
    },
    'evidence': [
        {'type': 'api', 'source': 'GA4 Data API v1beta', 'property': '$PROPERTY_ID', 'identity': 'access@theleverageway.com'},
        {'type': 'github_file', 'path': 'config/clients.v1.json'}
    ]
}
with open('$OUTPUT_DIR/ga4_data.json', 'w') as f:
    json.dump(output, f, indent=2)
print('  Written: $OUTPUT_DIR/ga4_data.json')
"
fi

echo ""
echo "=== GA4 Pull Complete ==="
