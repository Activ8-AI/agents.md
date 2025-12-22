# MAOS Components Map

version: 0.2.0
status: Draft Canon

timestamp:
  created:
    date_ymd: 20251130
    day_of_week: Sunday
    time_local: 06:12 PM
    timezone: Central
  last_updated:
    date_ymd: 20251130
    day_of_week: Sunday
    time_local: 06:12 PM
    timezone: Central

---

## 0. Substrate Layer
- ChatGPT Workspace
- Claude Workspace
- Notion (UI + knowledge surface)
- Slack
- HubSpot
- Teamwork
- Google Drive
- BigQuery
- GCP AI (Doc AI, Gemini, Media AI)
- MCP GitHub Relay (write path)

## 1. Canon Layer
- Activ8 AI Operational Execution & Accountability Charter (v1.1)
- Meta Mega Codex for Activ8 AI
- LMAOS Meta Mega Codex
- Session-level Meta Codex Logs (e.g., 20251125 Morning)

## 2. Governance Layer
- **Governance Objects:** ACSE controls (STOP, RESET, REALIGN, LOCK AUTONOMY), Validator role, Custodian role, Choice log / decision log, Quarantine boundaries, status signals (G/Y/R)
- **Interface & Commands:** `/ao`, `/msow`, `/evidence`, `/handoff`, `/summary`, `/codex-relay`, `/portal-update`, `/store-sync`, `/relay-status`, `/canon-sync`, `/agent-verify`, `/matrix-update`
- **Governance Stores:** Session Logs, AI Inputs (impact scoring, model comparison), Preservation Vault
- **Governance Flows:** multi-model evaluation, release / impact cycle, secrets audit (cross-repo), verification kanban

## 3. Orchestration Layer
- **Core Object:** Agent Orchestration Hub (Prime ↔ Claude ↔ MCP GitHub Relay)
- **Functions:** command parsing, model routing, status signaling, relay handoffs, primary agent activation, evidence binding, MCP registry checks, system-to-system workflow coordination
- **Patterns:** transcript → summary → evaluation → decision → update; Prime-driven work assignment; divergence → convergence multi-agent flow

## 4. Module Layer
- `/ao` charter response generator
- `/msow` micro-SOW formatter
- `/handoff` inter-agent routing wrapper
- `/evidence` evidence block extractor
- `/summary` final-report formatter
- AI input normalizer
- status signal generator
- multi-model evaluator
- slack adjacency mapper
- notion ingestion/update modules (manual or via MCP)
- codex portal relay
- portal update module
- store sync module
- canon sync module
- relay status module
- agent verify module
- matrix update module

## 5. Flow Layer
- `flow.ai_input_classification`
- `flow.agent_orchestration`
- `flow.conversation_to_decision`
- `flow.release_impact_cycle`
- `flow.client_onboarding`
- `flow.lmaos_campaign_brief_to_launch`
- `flow.lmaos_weekly_review`

**Flow patterns:** command → orchestrator → module chain → store update; audio → transcript → command inbox → decision → matrix update; slack signal → orchestration hub → notion update → log & dashboard.

## 6. Data & Memory Layer
- AI Inputs Database (cross-model evaluation store)
- Conversation Log
- Audio Inbox
- Release Log
- Wiring Maps DB
- Client Operational Matrix
- LMAOS Client Portfolio Dashboard
- HubSpot–Notion orchestration log
- Preservation Vault

## 7. Interface Layer
- Agent Orchestration Hub
- CRM & Project Management Hub
- LMAOS Portal Architecture Hub
- Workspace Audio UI Kit
- Client Portals
- Synced Charter blocks
- Relay widgets
- Command inbox
- Looker Studio dashboards
