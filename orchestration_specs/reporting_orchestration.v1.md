# Reporting Orchestration Specification

version: 1.0
status: Draft Canon (implementation-ready)
profile: lmaos
layer: orchestration

timestamp:
  created:
    date_ymd: 20260205
    day_of_week: Thursday
    time_local: 02:30 PM
    timezone: Central
  last_updated:
    date_ymd: 20260205
    day_of_week: Thursday
    time_local: 02:30 PM
    timezone: Central

applies_to:
  - profile: lmaos
  - layer: orchestration
  - component: mcp_github_relay
  - flow: flow.lmaos_weekly_review

---

## 1. Purpose

This spec defines the 4-phase reporting pipeline for LMAOS client reporting. It operationalizes the `flow.lmaos_weekly_review` pattern from the MAOS Profile, routing report generation through evidence gathering, enrichment, and delivery.

The pipeline ensures:

- Reports are generated from structured client configs (not invented state)
- Each report follows a versioned JSON schema
- Enrichment tasks are dispatched to the correct agent (Prime, Codex, Claude)
- All outputs are logged to the vault ledger
- Delivery is governed by Charter compliance checks

---

## 2. Pipeline Overview

```
Phase 1: Generate    → Draft reports from client config + period
Phase 2: Dispatch    → Queue enrichment jobs to agents via MCP
Phase 3: Enrich      → Agents pull GA4, Ads, Fathom, Claude analysis
Phase 4: Deliver     → Finalized reports pushed to portals + Teamwork
```

---

## 3. Phase 1 — Report Generation

### 3.1 Trigger

- Manual: `scripts/reports/run_monthly_reports.sh`
- GitHub Actions: `.github/workflows/reporting-pipeline.yml`
  - Scheduled: 1st of month 6 AM UTC (full prior month), 15th (MTD)
  - On-demand: `workflow_dispatch` with month, phase, dry_run inputs
- Fathom sync: `.github/workflows/fathom-sync.yml` (daily 6 AM UTC)

### 3.2 Inputs

- `config/clients.v1.json` — Client roster with slugs, statuses, Teamwork/Notion IDs
- `schemas/weekly_report_schema.v1.json` — Report structure validation
- Period parameters: `YYYY-MM` (full month) or `YYYY-MM-MTD` (month-to-date)

### 3.3 Process

For each active client in the config:

1. Read client metadata (slug, display name, services, contacts)
2. Initialize a draft report JSON conforming to the schema
3. Initialize a companion Markdown report for human review
4. Write both to `reports/monthly/{client_slug}/{period}/`
5. Record the generation event in a manifest

### 3.4 Outputs

```
reports/monthly/{client_slug}/{period}/draft_report.json
reports/monthly/{client_slug}/{period}/draft_report.md
reports/monthly/manifest_{timestamp}.json
```

### 3.5 Evidence

```yaml
evidence:
  - type: github_file
    path: config/clients.v1.json
    description: "Client roster driving report generation"
  - type: github_file
    path: schemas/weekly_report_schema.v1.json
    description: "Schema enforcing report structure"
```

---

## 4. Phase 2 — Job Dispatch

### 4.1 Trigger

- Automatically after Phase 1 completes
- Manual: `scripts/reports/dispatch_monthly_jobs.sh`

### 4.2 Process

For each generated draft report:

1. Create an enrichment job with 4 tasks:
   - `ga4_pull` → assigned to Prime (GA4 data extraction)
   - `ads_pull` → assigned to Prime (Google/Meta Ads data)
   - `fathom_sweep` → assigned to Codex (meeting transcript analysis)
   - `claude_analysis` → assigned to Claude (narrative + insights)
2. Dispatch jobs via MCP agent-comms (port 5060) or relay (port 5055)
3. Log dispatch results to `vault/ledger/report_jobs/`

### 4.3 Job Schema

```json
{
  "job_id": "uuid",
  "client_slug": "string",
  "period": "string",
  "tasks": [
    {
      "task_id": "string",
      "type": "ga4_pull|ads_pull|fathom_sweep|claude_analysis",
      "assigned_to": "prime|codex|claude",
      "status": "queued|in_progress|completed|failed",
      "created_at": "ISO8601"
    }
  ],
  "status": "dispatched|enriching|completed",
  "dispatched_at": "ISO8601"
}
```

### 4.4 Outputs

```
vault/ledger/report_jobs/dispatch_{timestamp}.json
vault/ledger/report_jobs/generation_{timestamp}.json
```

---

## 5. Phase 3 — Enrichment

### 5.1 Agent Responsibilities

| Task | Agent | Source | Output |
|------|-------|--------|--------|
| ga4_pull | Prime | GA4 API via BigQuery | Session, conversion, traffic data |
| ads_pull | Prime | Google Ads / Meta Ads API | Spend, impressions, ROAS |
| fathom_sweep | Codex | Fathom API transcripts | Meeting summaries, action items |
| claude_analysis | Claude | Draft report + enrichment data | Narrative insights, recommendations |

### 5.2 Authentication

All GA4 and Google Ads access flows through the primary identity:

```yaml
primary_identity: access@theleverageway.com
org: Leverage Marketing Agency
role: MCC admin / GA4 admin
config: config/identity.v1.json
```

Team identities: `lmaai@theleverageway.com`, `stan@theleverageway.com`
System identities: `codex@activ8ai.app`, `stan@activ8ai.app`

### 5.3 Implementation

```
scripts/reports/run_enrichment.sh              ← Phase 3 orchestrator
scripts/reports/enrichment/ga4_pull.sh         ← GA4 Data API v1beta
scripts/reports/enrichment/ads_pull.sh         ← Google Ads API v18 + Meta API v21.0
```

**GA4 Pull** (`ga4_pull.sh`):
- API: `analyticsdata.googleapis.com/v1beta`
- Reports: channel overview (sessions, users, bounce rate, engagement), traffic sources (source/medium), landing pages (top 20)
- Auth: OAuth2 refresh token or service account via `access@theleverageway.com`

**Ads Pull** (`ads_pull.sh`):
- Google Ads: `googleads.googleapis.com/v18` — GAQL queries for account overview, campaign performance, top 50 keywords
- Meta Ads: `graph.facebook.com/v21.0` — campaign-level spend, impressions, ROAS
- Auth: Developer token + OAuth2 (Google), long-lived access token (Meta)

### 5.4 Process

1. Orchestrator reads dispatch ledger for job list
2. For each job, runs ga4_pull → ads_pull → fathom_sweep → claude_analysis
3. Each task writes to `reports/monthly/{client}/{period}/enrichment/`
4. Fathom sweep checks `vault/meetings/by_client/` for period-matched transcripts
5. Claude analysis generates template referencing available enrichment data
6. Enrichment ledger written to `vault/ledger/report_jobs/enrichment_{timestamp}.json`

### 5.5 Outputs

```
reports/monthly/{client}/{period}/enrichment/
├── ga4_data.json          ← Sessions, traffic, conversions by channel
├── ads_data.json          ← Spend, ROAS, campaigns, keywords
├── fathom_data.json       ← Meeting matches for period
└── claude_analysis.json   ← Analysis template (pending human/agent review)
```

### 5.6 Governance

- All enrichment data must include evidence references
- Claude analysis must not invent metrics (use only data provided by Prime/Codex)
- If data is unavailable, the field is marked `"status": "pending"` not fabricated
- GA4/Ads property IDs must be set in `config/clients.v1.json` before live pulls

---

## 6. Phase 4 — Delivery

### 6.1 Process

1. Merge enrichment data into final report
2. Validate against `schemas/weekly_report_schema.v1.json`
3. Generate final Markdown for human review
4. Push summary to:
   - Teamwork project (as message or task)
   - Notion client portal (as callout block)
5. Log delivery to vault ledger

### 6.2 Delivery Channels

| Channel | Method | ID Source |
|---------|--------|-----------|
| Teamwork | POST /projects/{id}/messages | config/clients.v1.json → teamwork_project_id |
| Notion | PATCH /blocks/{id}/children | config/clients.v1.json → notion_portal_id |
| Email | SMTP via n8n workflow | config/clients.v1.json → contacts |

---

## 7. File Inventory

| File | Purpose | Version Lock |
|------|---------|--------------|
| `orchestration_specs/reporting_orchestration.v1.md` | This spec | v1 |
| `schemas/weekly_report_schema.v1.json` | Report structure validation | v1 |
| `config/clients.v1.json` | Client roster + integration IDs | v1 |
| `config/identity.v1.json` | Identity/auth mappings for GA4/Ads | v1 |
| `scripts/reports/run_monthly_reports.sh` | Phase 1 runner | v1 |
| `scripts/reports/dispatch_monthly_jobs.sh` | Phase 2 dispatcher | v1 |
| `scripts/reports/run_enrichment.sh` | Phase 3 orchestrator | v1 |
| `scripts/reports/enrichment/ga4_pull.sh` | GA4 Data API pull | v1 |
| `scripts/reports/enrichment/ads_pull.sh` | Google Ads + Meta Ads pull | v1 |
| `.github/workflows/reporting-pipeline.yml` | CI/CD: Phase 1+2+3 automation | v1 |
| `.github/workflows/fathom-sync.yml` | CI/CD: Daily Fathom transcript sync | v1 |

---

## 8. GitHub Actions & CI/CD

### 8.1 Workflows

| Workflow | Schedule | Trigger |
|----------|----------|---------|
| `reporting-pipeline.yml` | 1st + 15th of month, 6 AM UTC | schedule + workflow_dispatch |
| `fathom-sync.yml` | Daily 6 AM UTC | schedule + workflow_dispatch |

### 8.2 Required Repository Secrets

Set via GitHub Settings → Secrets and variables → Actions:

| Secret | Source | Used By |
|--------|--------|---------|
| `GA4_OAUTH_CLIENT_ID` | Google Cloud Console → OAuth 2.0 Client | ga4_pull.sh |
| `GA4_OAUTH_CLIENT_SECRET` | Google Cloud Console → OAuth 2.0 Client | ga4_pull.sh |
| `GA4_REFRESH_TOKEN` | OAuth2 flow for access@theleverageway.com | ga4_pull.sh |
| `GOOGLE_ADS_DEVELOPER_TOKEN` | Google Ads MCC → API Center | ads_pull.sh |
| `GOOGLE_ADS_CLIENT_ID` | Google Cloud Console (same as GA4 or separate) | ads_pull.sh |
| `GOOGLE_ADS_CLIENT_SECRET` | Google Cloud Console | ads_pull.sh |
| `GOOGLE_ADS_REFRESH_TOKEN` | OAuth2 flow for access@theleverageway.com | ads_pull.sh |
| `GOOGLE_ADS_LOGIN_CUSTOMER_ID` | MCC customer ID (no dashes) | ads_pull.sh |
| `META_ACCESS_TOKEN` | Meta Business → System User token | ads_pull.sh |
| `FATHOM_API_TOKEN` | Fathom → Settings → API | fathom-sync.yml |

All secrets sourced from Notion Secrets Registry (90f3336e8fda4a8f8517ffd9559eae36) or directly from platform dashboards.

### 8.3 Reporting Pipeline Jobs

```
reporting-pipeline.yml
├── generate     → Phase 1: Draft reports (commits to repo)
├── dispatch     → Phase 2: Enrichment job dispatch (depends on generate)
└── enrich       → Phase 3: GA4 + Ads + Fathom pulls (depends on dispatch)
```

Bot identity: `lmaos-pipeline[bot]` / `lmaai@theleverageway.com`

---

## 9. Integration Points

```yaml
integrations:
  google_analytics:
    api: "analyticsdata.googleapis.com/v1beta"
    identity: "access@theleverageway.com"
    role: "GA4 data pull for traffic, conversions, engagement"
  google_ads:
    api: "googleads.googleapis.com/v18"
    identity: "access@theleverageway.com"
    role: "Campaign performance, spend, ROAS, keywords"
  meta_ads:
    api: "graph.facebook.com/v21.0"
    role: "Meta/Facebook campaign performance (where applicable)"
  mcp_agent_comms:
    port: 5060
    role: "Dispatch enrichment jobs to registered agents"
  mcp_teamwork:
    port: 5059
    role: "Post report summaries to client projects"
  mcp_notion:
    port: 5064
    role: "Update client portal pages"
  relay:
    port: 5055
    role: "Fallback dispatch when agent-comms unavailable"
  fathom:
    api: "api.fathom.ai/external/v1"
    role: "Meeting transcript source for fathom_sweep tasks"
```

---

## 10. Governance & Safety

- **STOP**: Halt report generation if client config is invalid
- **REALIGN**: Re-check against Canon if report schema changes
- **LOCK AUTONOMY**: Require human review before delivering to client-facing portals
- No metrics are fabricated — missing data is marked pending
- All writes flow through MCP GitHub Relay per Canon §2.4

---

## 11. Versioning

### 11.1 Current Version

1.2 — GitHub Actions CI/CD wiring

### 11.2 Change Log

- **v1.2** (20260209)
  - Added GitHub Actions workflows (reporting-pipeline.yml, fathom-sync.yml)
  - Documented required repository secrets for GA4, Ads, Meta, Fathom
  - Bot identity: lmaos-pipeline[bot] / lmaai@theleverageway.com
  - Scheduled runs: 1st/15th monthly (reports), daily (Fathom sync)
- **v1.1** (20260205)
  - Implemented Phase 3 enrichment scripts (ga4_pull.sh, ads_pull.sh, run_enrichment.sh)
  - Added identity config (config/identity.v1.json) for access@theleverageway.com
  - GA4 Data API v1beta: channel overview, traffic sources, landing pages
  - Google Ads API v18: GAQL queries for campaigns, keywords, account totals
  - Meta Ads API v21.0: campaign-level performance (where applicable)
  - Fathom sweep pulls from vault/meetings/by_client/ transcript archive
  - Claude analysis generates evidence-backed templates for human review
  - Dry-run support across all enrichment tasks
- **v1.0** (20260205)
  - Defined 4-phase pipeline (Generate → Dispatch → Enrich → Deliver)
  - Established job schema for enrichment tasks
  - Mapped agent responsibilities (Prime, Codex, Claude)
  - Integrated with MCP agent-comms, Teamwork, Notion, Fathom
  - Aligned with LMAOS profile flow.lmaos_weekly_review
