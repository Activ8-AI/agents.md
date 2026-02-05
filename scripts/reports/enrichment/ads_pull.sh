#!/usr/bin/env bash
# =============================================================================
# ads_pull.sh — Phase 3 Enrichment: Google Ads + Meta Ads Data Pull
# =============================================================================
# Pulls advertising performance data for a client/period.
# Google Ads: REST API v18 via access@theleverageway.com MCC
# Meta Ads: Marketing API v21.0 (if META_ACCESS_TOKEN set)
#
# Usage:
#   ./scripts/reports/enrichment/ads_pull.sh \
#     --client modern-office-furniture \
#     --period 2026-01 \
#     [--google-ads-id 123-456-7890] \
#     [--meta-ads-id 123456789] \
#     [--dry-run]
#
# Env vars (required unless --dry-run):
#   GOOGLE_ADS_DEVELOPER_TOKEN
#   GOOGLE_ADS_REFRESH_TOKEN (or GA4_REFRESH_TOKEN — same OAuth2 identity)
#   GOOGLE_ADS_CLIENT_ID + GOOGLE_ADS_CLIENT_SECRET
#   GOOGLE_ADS_LOGIN_CUSTOMER_ID (MCC ID, no dashes)
#   META_ACCESS_TOKEN (optional — for Meta/Facebook Ads)
#
# Outputs:
#   reports/monthly/{client}/{period}/enrichment/ads_data.json
#
# References:
#   - config/identity.v1.json (auth config)
#   - config/clients.v1.json (account IDs)
#   - orchestration_specs/reporting_orchestration.v1.md (Phase 3)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONFIG_FILE="$REPO_ROOT/config/clients.v1.json"

CLIENT_SLUG=""
PERIOD=""
GOOGLE_ADS_CID=""
META_ADS_ID=""
DRY_RUN=false

GADS_API="https://googleads.googleapis.com/v18"
META_API="https://graph.facebook.com/v21.0"

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --client) CLIENT_SLUG="$2"; shift 2 ;;
    --period) PERIOD="$2"; shift 2 ;;
    --google-ads-id) GOOGLE_ADS_CID="$2"; shift 2 ;;
    --meta-ads-id) META_ADS_ID="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

if [ -z "$CLIENT_SLUG" ] || [ -z "$PERIOD" ]; then
  echo "Usage: ads_pull.sh --client SLUG --period YYYY-MM [--google-ads-id ID] [--meta-ads-id ID] [--dry-run]"
  exit 1
fi

# --- Resolve account IDs from client config ---
resolve_ids() {
  python3 -c "
import json
with open('$CONFIG_FILE') as f:
    data = json.load(f)
for c in data['clients']:
    if c['slug'] == '$CLIENT_SLUG':
        integ = c.get('integrations', {})
        gads = integ.get('google_ads_id') or ''
        meta = integ.get('meta_ads_id') or ''
        print(f'{gads}|{meta}')
        break
else:
    print('|')
" 2>/dev/null
}

if [ -z "$GOOGLE_ADS_CID" ] || [ -z "$META_ADS_ID" ]; then
  IDS=$(resolve_ids)
  if [ -z "$GOOGLE_ADS_CID" ]; then
    GOOGLE_ADS_CID=$(echo "$IDS" | cut -d'|' -f1)
  fi
  if [ -z "$META_ADS_ID" ]; then
    META_ADS_ID=$(echo "$IDS" | cut -d'|' -f2)
  fi
fi

# Clean Google Ads CID (remove dashes for API)
GOOGLE_ADS_CID_CLEAN=$(echo "$GOOGLE_ADS_CID" | tr -d '-')

# --- Compute date range ---
compute_date_range() {
  local period="$1"
  if [[ "$period" == *-MTD ]]; then
    local base="${period%-MTD}"
    echo "${base}-01" "$(date -u +%Y-%m-%d)"
  else
    local start="${period}-01"
    local end
    end=$(python3 -c "
import datetime, calendar
y,m = map(int, '${period}'.split('-'))
last = calendar.monthrange(y,m)[1]
print(datetime.date(y,m,last))
")
    echo "$start" "$end"
  fi
}

DATE_RANGE=($(compute_date_range "$PERIOD"))
START_DATE="${DATE_RANGE[0]}"
END_DATE="${DATE_RANGE[1]}"

OUTPUT_DIR="$REPO_ROOT/reports/monthly/$CLIENT_SLUG/$PERIOD/enrichment"
mkdir -p "$OUTPUT_DIR"

echo "=== Ads Data Pull ==="
echo "Client:      $CLIENT_SLUG"
echo "Period:      $PERIOD ($START_DATE → $END_DATE)"
echo "Google Ads:  ${GOOGLE_ADS_CID:-NOT_SET}"
echo "Meta Ads:    ${META_ADS_ID:-NOT_SET}"
echo "Dry run:     $DRY_RUN"
echo ""

# --- Google Ads GAQL query ---
GADS_CAMPAIGN_QUERY="SELECT
  campaign.name,
  campaign.status,
  campaign.advertising_channel_type,
  metrics.impressions,
  metrics.clicks,
  metrics.cost_micros,
  metrics.conversions,
  metrics.conversions_value,
  metrics.cost_per_conversion,
  metrics.ctr,
  metrics.average_cpc,
  metrics.search_impression_share
FROM campaign
WHERE segments.date BETWEEN '${START_DATE}' AND '${END_DATE}'
  AND campaign.status != 'REMOVED'
ORDER BY metrics.cost_micros DESC"

GADS_KEYWORD_QUERY="SELECT
  ad_group.name,
  ad_group_criterion.keyword.text,
  ad_group_criterion.keyword.match_type,
  metrics.impressions,
  metrics.clicks,
  metrics.cost_micros,
  metrics.conversions,
  metrics.ctr,
  metrics.average_cpc,
  metrics.quality_score
FROM keyword_view
WHERE segments.date BETWEEN '${START_DATE}' AND '${END_DATE}'
ORDER BY metrics.cost_micros DESC
LIMIT 50"

GADS_ACCOUNT_QUERY="SELECT
  metrics.impressions,
  metrics.clicks,
  metrics.cost_micros,
  metrics.conversions,
  metrics.conversions_value,
  metrics.ctr,
  metrics.average_cpc,
  metrics.cost_per_conversion
FROM customer
WHERE segments.date BETWEEN '${START_DATE}' AND '${END_DATE}'"

# --- Meta Ads fields ---
META_FIELDS="campaign_name,impressions,clicks,spend,actions,cost_per_action_type,cpc,cpm,ctr,reach,frequency"

# --- Get Google Ads access token ---
get_gads_token() {
  local refresh="${GOOGLE_ADS_REFRESH_TOKEN:-${GA4_REFRESH_TOKEN:-}}"
  local client_id="${GOOGLE_ADS_CLIENT_ID:-${GA4_OAUTH_CLIENT_ID:-}}"
  local client_secret="${GOOGLE_ADS_CLIENT_SECRET:-${GA4_OAUTH_CLIENT_SECRET:-}}"

  if [ -n "$refresh" ] && [ -n "$client_id" ] && [ -n "$client_secret" ]; then
    curl -s -X POST "https://oauth2.googleapis.com/token" \
      -d "grant_type=refresh_token&client_id=${client_id}&client_secret=${client_secret}&refresh_token=${refresh}" | \
      python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null
    return
  fi
  echo ""
}

# --- Execute Google Ads query ---
gads_query() {
  local token="$1"
  local query="$2"

  curl -s -X POST \
    "${GADS_API}/customers/${GOOGLE_ADS_CID_CLEAN}/googleAds:searchStream" \
    -H "Authorization: Bearer $token" \
    -H "developer-token: ${GOOGLE_ADS_DEVELOPER_TOKEN}" \
    -H "login-customer-id: ${GOOGLE_ADS_LOGIN_CUSTOMER_ID}" \
    -H "Content-Type: application/json" \
    -d "{\"query\": \"$(echo "$query" | tr '\n' ' ' | sed 's/  */ /g')\"}"
}

# --- Execute Meta Ads query ---
meta_query() {
  local ad_account_id="$1"
  curl -s -G \
    "${META_API}/act_${ad_account_id}/insights" \
    -d "access_token=${META_ACCESS_TOKEN}" \
    -d "fields=${META_FIELDS}" \
    -d "time_range={\"since\":\"${START_DATE}\",\"until\":\"${END_DATE}\"}" \
    -d "level=campaign" \
    -d "limit=100"
}

# --- Main execution ---
if [ "$DRY_RUN" = true ]; then
  echo "DRY RUN — writing request templates only"

  python3 << 'PYEOF'
import json, datetime

output = {
    "client_slug": "$CLIENT_SLUG",
    "period": "$PERIOD",
    "date_range": {"start": "$START_DATE", "end": "$END_DATE"},
    "status": "dry_run",
    "pulled_at": datetime.datetime.utcnow().isoformat() + "Z",
    "auth_identity": "access@theleverageway.com",
    "google_ads": {
        "customer_id": "$GOOGLE_ADS_CID" or "NOT_SET",
        "status": "pending",
        "note": "Requires GOOGLE_ADS_DEVELOPER_TOKEN + OAuth credentials",
        "queries": {
            "account_overview": "SELECT metrics.* FROM customer WHERE segments.date BETWEEN ...",
            "campaign_performance": "SELECT campaign.name, metrics.* FROM campaign WHERE ...",
            "top_keywords": "SELECT keyword, metrics.* FROM keyword_view WHERE ... LIMIT 50"
        },
        "expected_metrics": {
            "total_spend": {"value": None, "currency": "USD"},
            "total_impressions": None,
            "total_clicks": None,
            "total_conversions": None,
            "avg_cpc": None,
            "avg_ctr": None,
            "roas": None,
            "campaigns": []
        }
    },
    "meta_ads": {
        "ad_account_id": "$META_ADS_ID" or "NOT_SET",
        "status": "pending" if "$META_ADS_ID" else "not_configured",
        "note": "Requires META_ACCESS_TOKEN",
        "expected_metrics": {
            "total_spend": {"value": None, "currency": "USD"},
            "total_impressions": None,
            "total_reach": None,
            "total_clicks": None,
            "total_conversions": None,
            "cpm": None,
            "ctr": None,
            "campaigns": []
        }
    },
    "evidence": [
        {"type": "api", "source": "Google Ads API v18", "identity": "access@theleverageway.com"},
        {"type": "api", "source": "Meta Marketing API v21.0"},
        {"type": "github_file", "path": "config/clients.v1.json"}
    ]
}

# Template substitution
import os
for k, v in [("$CLIENT_SLUG", os.environ.get("_CS", "")),
             ("$PERIOD", os.environ.get("_PD", "")),
             ("$START_DATE", os.environ.get("_SD", "")),
             ("$END_DATE", os.environ.get("_ED", "")),
             ("$GOOGLE_ADS_CID", os.environ.get("_GC", "")),
             ("$META_ADS_ID", os.environ.get("_MA", ""))]:
    pass

with open(os.environ.get("_OUT", "/dev/null"), "w") as f:
    json.dump(output, f, indent=2)
print(f"  Written: {os.environ.get('_OUT', 'ads_data.json')}")
PYEOF

  # Simpler approach for shell variable substitution
  python3 -c "
import json, datetime
output = {
    'client_slug': '$CLIENT_SLUG',
    'period': '$PERIOD',
    'date_range': {'start': '$START_DATE', 'end': '$END_DATE'},
    'status': 'dry_run',
    'pulled_at': datetime.datetime.utcnow().isoformat() + 'Z',
    'auth_identity': 'access@theleverageway.com',
    'google_ads': {
        'customer_id': '${GOOGLE_ADS_CID:-NOT_SET}',
        'status': 'pending',
        'note': 'Requires GOOGLE_ADS_DEVELOPER_TOKEN + OAuth credentials for access@theleverageway.com',
        'queries': {
            'account_overview': '''$(echo "$GADS_ACCOUNT_QUERY" | tr '\n' ' ')''',
            'campaign_performance': '''$(echo "$GADS_CAMPAIGN_QUERY" | tr '\n' ' ')''',
            'top_keywords': '''$(echo "$GADS_KEYWORD_QUERY" | tr '\n' ' ')'''
        },
        'expected_metrics': {
            'total_spend': {'value': None, 'currency': 'USD'},
            'total_impressions': None,
            'total_clicks': None,
            'total_conversions': None,
            'avg_cpc': None,
            'avg_ctr': None,
            'roas': None,
            'campaigns': []
        }
    },
    'meta_ads': {
        'ad_account_id': '${META_ADS_ID:-NOT_SET}',
        'status': 'pending' if '${META_ADS_ID}' else 'not_configured',
        'note': 'Requires META_ACCESS_TOKEN' if '${META_ADS_ID}' else 'No Meta Ads account configured for this client',
        'expected_metrics': {
            'total_spend': {'value': None, 'currency': 'USD'},
            'total_impressions': None,
            'total_reach': None,
            'total_clicks': None,
            'campaigns': []
        }
    },
    'evidence': [
        {'type': 'api', 'source': 'Google Ads API v18', 'identity': 'access@theleverageway.com'},
        {'type': 'api', 'source': 'Meta Marketing API v21.0'},
        {'type': 'github_file', 'path': 'config/clients.v1.json'}
    ]
}
with open('$OUTPUT_DIR/ads_data.json', 'w') as f:
    json.dump(output, f, indent=2)
print('  Written: $OUTPUT_DIR/ads_data.json')
"
else
  # --- Live pull ---
  GADS_RESULT="{}"
  META_RESULT="{}"

  # Google Ads
  if [ -n "$GOOGLE_ADS_CID_CLEAN" ] && [ "$GOOGLE_ADS_CID_CLEAN" != "None" ] && [ "$GOOGLE_ADS_CID_CLEAN" != "null" ]; then
    GADS_TOKEN=$(get_gads_token)
    if [ -n "$GADS_TOKEN" ]; then
      echo "Pulling Google Ads account overview..."
      GADS_ACCOUNT=$(gads_query "$GADS_TOKEN" "$GADS_ACCOUNT_QUERY")

      echo "Pulling Google Ads campaign performance..."
      GADS_CAMPAIGNS=$(gads_query "$GADS_TOKEN" "$GADS_CAMPAIGN_QUERY")

      echo "Pulling Google Ads top keywords..."
      GADS_KEYWORDS=$(gads_query "$GADS_TOKEN" "$GADS_KEYWORD_QUERY")

      GADS_RESULT=$(python3 -c "
import json
acct = json.loads('''$GADS_ACCOUNT''')
camps = json.loads('''$GADS_CAMPAIGNS''')
kws = json.loads('''$GADS_KEYWORDS''')
print(json.dumps({
    'customer_id': '$GOOGLE_ADS_CID',
    'status': 'complete',
    'account_overview': acct,
    'campaign_performance': camps,
    'top_keywords': kws
}))
" 2>/dev/null || echo '{"status": "error", "note": "Failed to parse Google Ads response"}')
    else
      echo "WARN: No Google Ads credentials — skipping"
      GADS_RESULT='{"status": "no_credentials", "note": "Set GOOGLE_ADS_DEVELOPER_TOKEN + OAuth credentials"}'
    fi
  else
    echo "WARN: No Google Ads customer ID for $CLIENT_SLUG"
    GADS_RESULT='{"status": "not_configured"}'
  fi

  # Meta Ads
  if [ -n "$META_ADS_ID" ] && [ "$META_ADS_ID" != "None" ] && [ -n "${META_ACCESS_TOKEN:-}" ]; then
    echo "Pulling Meta Ads campaign data..."
    META_RAW=$(meta_query "$META_ADS_ID")
    META_RESULT=$(python3 -c "
import json
data = json.loads('''$META_RAW''')
print(json.dumps({'ad_account_id': '$META_ADS_ID', 'status': 'complete', 'campaigns': data}))
" 2>/dev/null || echo '{"status": "error"}')
  else
    META_RESULT='{"status": "not_configured"}'
  fi

  # Write combined output
  python3 -c "
import json, datetime
output = {
    'client_slug': '$CLIENT_SLUG',
    'period': '$PERIOD',
    'date_range': {'start': '$START_DATE', 'end': '$END_DATE'},
    'status': 'complete',
    'pulled_at': datetime.datetime.utcnow().isoformat() + 'Z',
    'auth_identity': 'access@theleverageway.com',
    'google_ads': json.loads('''$GADS_RESULT'''),
    'meta_ads': json.loads('''$META_RESULT'''),
    'evidence': [
        {'type': 'api', 'source': 'Google Ads API v18', 'identity': 'access@theleverageway.com'},
        {'type': 'api', 'source': 'Meta Marketing API v21.0'},
        {'type': 'github_file', 'path': 'config/clients.v1.json'}
    ]
}
with open('$OUTPUT_DIR/ads_data.json', 'w') as f:
    json.dump(output, f, indent=2)
print('  Written: $OUTPUT_DIR/ads_data.json')
"
fi

echo ""
echo "=== Ads Pull Complete ==="
