# Conversation Meta Mega Codex

version: 0.2.0
status: Draft Canon (implementation-ready)

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

applies_to:
  - profile: activ8_ai
  - profile: lmaos
  - layer: orchestration
  - layer: governance
  - layer: memory
  - component: mcp_github_relay

---

## 1. Purpose

This Codex defines how conversations:

1. Turn into structured inputs
2. Produce evidence-backed actions
3. Flow through the MCP/GitHub Relay
4. Update files, portals, and matrices
5. Get recorded into logs and Canon

The goal is to make conversational work:

- deterministic
- auditable
- reversible
- governed by Charter and Canon

---

## 2. Conversation Pipeline

All conversations follow this high-level pipeline:

```
Input → Interpretation → Evidence → Relay → Action → Log → Canon
```

### 2.1 Input

Accepted input types:

- Text in ChatGPT, Claude, or other agents
- Transcripts from the Audio Inbox
- Slack messages
- External triggers (webhooks, CRM updates, etc.)

### 2.2 Interpretation

Interpretation must:

- Respect the active Profile
- Respect the Charter
- Respect existing Canon
- Use only surfaced evidence (Notion, GitHub, DBs, logs)

The agent:

- states assumptions explicitly
- avoids inventing state
- defers or asks for clarification when evidence is missing

### 2.3 Evidence

Every non-trivial operation must be backed by evidence.

Evidence block structure:

```
evidence:
  - type: notion_page
    id: <notion_page_id>
    description: <short description>
  - type: github_file
    path: <repo-relative-path>
    description: <short description>
  - type: url
    href: <https://...>
    description: <short description>
```

**Rule:** No major operation (matrix updates, Canon changes, profile edits, relay configuration) is allowed without at least one evidence target.

### 2.4 Relay

All persistent writes go through the MCP/GitHub Relay, not directly to Notion.

Relay responsibilities:

- Write or update files in the MAOS repo
- Emit diffs / PRs when appropriate
- Trigger automations that later update Notion, dashboards, etc.
- Maintain a clear mapping between conversational intent and repository changes

### 2.5 Action

Actions include:

Creating or updating:

- MAOS specs
- Profiles
- Modules
- Flows
- Glossary entries
- Integration configs (e.g., Slack channel maps)

Updating:

- Master Client Operational Matrix
- Client/ops portals (via GitHub Canon → Notion rendering)

Producing:

- SOWs, briefs, POAs, check-in docs

An action is only "complete" when:

- The file or record exists
- It is linked from the relevant hub/portal
- There is a log entry for the session

### 2.6 Log

Every meaningful session must be logged using the Meta Codex Session pattern:

- Problem
- Inputs (models, prompts)
- Evidence
- Drafts
- Evaluation
- Decision
- Impact score
- Artifacts produced
- Follow-ups

### 2.7 Canon

Patterns that are:

- stable
- repeated
- cross-client
- clearly beneficial

…are promoted to Canon and versioned (like this document).

## 3. Charter-Standard Commands

Commands define how agents structure their outputs and what the Relay should do.

### 3.1 Core Commands

These are already in use:

- `/ao` — charter-compliant structured action output
- `/msow` — micro-SOW (scope, assumptions, deliverables)
- `/evidence` — structured evidence listing and justification
- `/handoff` — packet for another agent or process
- `/summary` — compact summary of the session and changes

### 3.2 Relay-Integrated Commands

These are used to tie conversation into MCP/GitHub:

- `/codex-relay` — apply Codex-level changes via MCP/GitHub Relay
- `/portal-update` — generate or update portal structures based on Canon
- `/store-sync` — reconcile data across Notion DBs, HubSpot, Teamwork, BigQuery, etc.
- `/relay-status` — report MCP/GitHub Relay status and pending work
- `/canon-sync` — reconcile Canon between GitHub and Notion views
- `/agent-verify` — verify MCP-connected agents/repos configuration
- `/matrix-update` — update the Master Client Operational Matrix safely

Each command implies:

- an expected output schema
- relay behavior (what files or configs are touched)
- logging expectations

## 4. Conversation Objects

These are primitives referenced in other specs.

### 4.1 Message

A single natural-language input (human or agent).

### 4.2 Transcript

Audio → text record, stored in the Audio Inbox.

Required fields:

- `timestamp.date_ymd` (YYYYMMDD)
- `timestamp.day_of_week`
- `timestamp.time_local`
- `timestamp.timezone`
- `speaker`
- `audio_link`
- `session_log_link` (when applicable)

### 4.3 Evidence Block

Required for operations that affect:

- Canon
- Profiles
- Flows
- Matrices
- Portals
- Integrations

Structure defined in §2.3.

### 4.4 Decision

A specific choice made in the session.

A valid decision has:

- options considered
- chosen option
- evidence
- impact estimate
- links to artifacts created or updated

### 4.5 Artifact

Anything created by the flow:

- markdown specs
- YAML configs
- portal scaffolds
- matrix updates
- dashboard references
- SOPs, templates

Artifacts should be:

- written to GitHub (preferred)
- linked from hubs/portals
- referenced in logs

## 5. Conversation Patterns

Patterns describe standard conversational shapes.

### 5.1 Multi-Model Evaluation

Used when stakes are above a defined threshold (governance, money, live systems).

Shape:

1. Define the problem clearly.
2. Run the prompt with 2+ models.
3. Capture raw outputs.
4. Evaluate comparatively (clarity, correctness, usefulness).
5. Assign impact and confidence scores.
6. Make a decision.
7. Log and optionally update Canon.

All runs are stored in the AI Inputs DB, with fields for:

- `source` (model)
- `systems` (which tools were used)
- `decision_applied`
- `impact_score`
- `confidence`
- `timestamp` (using the standardized format)

### 5.2 Relay Activation

Used whenever the GitHub Relay should change system state.

Shape:

1. Conversation produces a structured plan or spec.
2. A relay-aware command is used (e.g., `/codex-relay`, `/portal-update`).
3. Relay transforms the plan into file changes (specs, configs, etc.).
4. Changes are reviewed (human or automated checks).
5. Canon, Profiles, Portals pick up those changes.

### 5.3 Portal Update

Shape:

1. Identify change needed in a client or ops portal.
2. Generate/update portal spec in GitHub (e.g., `portals/<client>.md`).
3. Human or automation syncs spec into Notion.
4. The portal is linked from:
   - Master Client Operational Matrix
   - CRM/PM Hub
   - Portfolio dashboards

### 5.4 Matrix Update

Any change to the Master Client Operational Matrix must:

- be derived from evidence (Slack, Teamwork, HubSpot, Notion portals)
- use `/matrix-update`
- include:
  - client
  - field(s) changed
  - before/after
  - evidence references
  - timestamp (using standardized format)

### 5.5 Charter Compliance

For high-impact changes:

- Run a quick Charter check.
- If ambiguous, use STOP or REALIGN and clarify before proceeding.

## 6. Conversation Governance

### 6.1 Core Rules

- Do not invent client state, IDs, dashboards, or channels.
- Do not update Canon without evidence.
- Do not bypass or contradict the Charter.
- Do not assume tools that have been retired (e.g., Notion AI).
- All persistent changes go through the MCP/GitHub Relay or are clearly marked as "manual / pending-sync."

### 6.2 Safety Controls

- STOP — Halt the current flow or requested change.
- RESET — Rebuild understanding from ground truth (Matrix, Canon, Profiles).
- REALIGN — Re-anchor the work against Charter and Canon.
- LOCK AUTONOMY — Require human review for follow-up actions.

Use these when:

- evidence is conflicting
- user intent is unclear
- system configuration is uncertain
- stakes are high

## 7. Logging Standard

### 7.1 Session Log Schema

Session logs must include the standardized timestamp.

```
# Session Log — Conversation

timestamp:
  date_ymd: 20251130
  day_of_week: Sunday
  time_local: 06:12 PM
  timezone: Central

profile: activ8_ai
systems_in_scope:
  - slack
  - notion
  - github
  - hubspot

## Problem
...

## Context
...

## Evidence
- ...

## Drafts (per model, if multi-model)
- model: claude
  output: ...
- model: chatgpt
  output: ...

## Evaluation
...

## Decision
...

## Impact Score
(1–10, using AI Inputs rubric)

## Artifacts
- repo_changes:
  - path: ...
    description: ...
- portal_updates:
  - page: ...
    change: ...
- matrix_updates:
  - client: ...
    field: ...
    before: ...
    after: ...

## Follow-ups
- [ ] ...

### 7.2 AI Inputs DB

Each row:

- one model
- one situation
- one decision context

Timestamp fields stored as:

```
timestamp:
  date_ymd: 20251130
  day_of_week: Sunday
  time_local: 06:12 PM
  timezone: Central
```

## 8. Conversation → Canon Promotion

A rule or pattern may be promoted to Canon if:

- It has been used successfully more than once.
- It fits cleanly into Profiles and Flows.
- It respects the Charter.
- It is useful across clients/systems.
- It can be expressed as specs and/or code, not just prose.

When promoting:

1. Update the relevant Canon file (like this one).
2. Bump version (see below).
3. Add an entry to the Change Log.
4. Include a timestamp block using the standardized format.

## 9. Versioning & Change Log

This Codex uses **MAJOR.MINOR.PATCH**:

- **MAJOR** — conceptual or structural changes.
- **MINOR** — new commands, patterns, or behaviors.
- **PATCH** — clarifications with no behavioral change.

### 9.1 Current Version

0.2.0 — Standardized timestamp conventions and made them normative for logs and objects.

### 9.2 Change Log

- **v0.2.0** (timestamp follows the standard format introduced in this version)
  - Standardized timestamp format to:
    - `date_ymd` (YYYYMMDD)
    - `day_of_week`
    - `time_local` (HH:MM AM/PM)
    - `timezone`
  - Applied timestamp spec to:
    - this Codex header
    - transcript object definition
    - logging standard
    - session log template

- **v0.1.0** (superseded)
  - Initial compiled Conversation Meta Mega Codex
  - Normalized pipeline from Input → Canon
  - Added relay-aware commands (`/codex-relay`, `/portal-update`, `/store-sync`, `/relay-status`, `/canon-sync`, `/agent-verify`, `/matrix-update`)
  - Established logging standard and promotion rules
