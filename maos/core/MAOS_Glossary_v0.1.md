# MAOS Glossary

version: 0.1
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

## Canon Objects
- **Charter:** Top-level constraints and commitments that govern all agent behavior.
- **Codex:** Architectural and operational specs that define OS-wide patterns.
- **Session Log:** Timestamped operational log capturing multi-model comparisons, evaluations, transcripts, and decisions.

## Governance Objects
- **Validator:** Governance role responsible for checking correctness, safety, alignment.
- **Custodian:** Maintains Canon, stores, and portal structures; removes drift.
- **ACSE Controls:** STOP, RESET, REALIGN, LOCK AUTONOMY protective operations.
- **Status Signals (G/Y/R):** Governance signal for health, risk, or failure.

## Orchestration Objects
- **Agent Orchestration Hub:** Central command center where Prime, Claude, and MCP GitHub Relay coordinate execution.
- **Command Formats:** Structured tokens for predictable behaviors: `/ao`, `/msow`, `/handoff`, `/evidence`, `/summary`, `/codex-relay`, `/portal-update`, `/store-sync`, `/relay-status`, `/canon-sync`, `/agent-verify`, `/matrix-update`.
- **Relay:** Routing logic that hands off context, intent, and data between agents and workflows.

## Module Objects
- **Module:** Deterministic unit of work (e.g., evidence extractor, summary generator, Slack ID normalizer).
- **Evaluator (Multi-Model):** Compares outputs from multiple models and produces a judged output.
- **Codex Portal Relay:** Module that routes Codex-level updates into GitHub and portals via MCP.

## Flow Objects
- **Flow:** Multi-step process that chains modules with checkpoints and outputs.
- **Routing Flow:** Determines which agent or module receives the next step.
- **Decision Flow:** Transcript → summary → reasoning → decision → log → portal update.

## Data / Memory Objects
- **AI Inputs DB:** Canonical store for model inputs, evaluations, scoring, decisions, impact, and evidence with standardized timestamps.
- **Conversation Log:** Record of interactions integrated into operational decisions.
- **Audio Inbox:** Voice/audio ingestion system with transcript linkage and timestamp metadata.
- **Wiring Map:** Map of nodes and edges defining system topology (Mesh, Weave, Wiring, Heartbeat).
- **Portal:** UI surfaces for clients or operations, composed of synced blocks and canonical views.

## Interface Objects
- **Synced Charter Block:** Replicated block ensuring Charter visibility across critical surfaces.
- **Command Inbox:** Actionable intake for commands routed through the Agent Orchestration Hub.
- **Relay Widget:** Interactive element showing agent routing and handoff patterns.
