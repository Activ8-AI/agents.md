# AGENTS.md

<p align="center">
  <img src="https://agents.md/og.png">
</p>

[AGENTS.md](https://agents.md) is a simple, open format for guiding coding agents.

Think of AGENTS.md as a README for agents: a dedicated, predictable place
to provide context and instructions to help AI coding agents work on your project.

Below is a minimal example of an AGENTS.md file:

```markdown
# Sample AGENTS.md file

## Dev environment tips
- Use `pnpm dlx turbo run where <project_name>` to jump to a package instead of scanning with `ls`.
- Run `pnpm install --filter <project_name>` to add the package to your workspace so Vite, ESLint, and TypeScript can see it.
- Use `pnpm create vite@latest <project_name> -- --template react-ts` to spin up a new React + Vite package with TypeScript checks ready.
- Check the name field inside each package's package.json to confirm the right name—skip the top-level one.

## Testing instructions
- Find the CI plan in the .github/workflows folder.
- Run `pnpm turbo run test --filter <project_name>` to run every check defined for that package.
- From the package root you can just call `pnpm test`. The commit should pass all tests before you merge.
- To focus on one step, add the Vitest pattern: `pnpm vitest run -t "<test name>"`.
- Fix any test or type errors until the whole suite is green.
- After moving files or changing imports, run `pnpm lint --filter <project_name>` to be sure ESLint and TypeScript rules still pass.
- Add or update tests for the code you change, even if nobody asked.

## PR instructions
- Title format: [<project_name>] <Title>
- Always run `pnpm lint` and `pnpm test` before committing.
```

## Website

This repository also includes a basic Next.js website hosted at https://agents.md/
that explains the project’s goals in a simple way, and featuring some examples.

### Running the app locally
1. Install dependencies:
   ```bash
   npm install
   ```
2. Start the development server:
   ```bash
   npm run dev
   ```
3. Open your browser and go to http://localhost:3000

## Meta Mega Codex — Charter Standard Execution

The repository now embeds the multi-layer Meta Mega Codex described in the charter. The stack is organized as follows:

- **Policies (Layer 2):** Domain-level guardrails live in `activ8_domain_policy.json`, `lma_domain_policy.json`, and `personal_domain_policy.json`, while copilot execution envelopes live in `activ8-ai-copilot.json`, `lma-copilot.json`, and `personal-copilot.json`. Every policy is version-locked (`2025.01.0`) to preserve zero drift.
- **Governors (Layer 3):** `activ8_governor.py`, `lma_governor.py`, and `personal_governor.py` share the base logic in `charter/governor_base.py` and emit append-only evidence to `charter_artifacts/*_evidence.json`.
- **Resilience + Logging (Layers 4-5):** `resilient_governor_runner.py`, `watchdog.py`, and `governor_evidence_aggregator.py` coordinate retries, stale detection, and dashboard aggregation. Append-only logs are handled via `custodian_log_binder.py` and `genesis_trace.py`.
- **Router (Layer 6):** `mcp_governor_router.py` exposes a lightweight router so that a single invocation can target `activ8`, `lma`, `personal`, or all governors.
- **Workflows (Layer 7):** Six GitHub Actions pipelines live in `.github/workflows/` with pinned `ubuntu-22.04`, `actions/checkout@v4.1.0`, and `actions/setup-python@v4.7.0`, plus pip caching for deterministic runs (see the individual `*-governor-sweep`, watchdog, aggregation, and failover YAML files).
- **Operations (Layer 8):** Runbooks map directly onto Python entry points, e.g. `PAT_ACTIV8_AI=<token> python activ8_governor.py`, `PAT_LMA=<token> python lma_governor.py`, `PAT_PERSONAL=<token> python personal_governor.py`, or the combined failover command `PAT_ACTIV8_AI=<token> PAT_LMA=<token> PAT_PERSONAL=<token> python resilient_governor_runner.py`.

To trigger the full suite locally, export the required tokens and run `python mcp_governor_router.py --target all`. The invocation phrases from the charter (“Charter On — Execute Meta Mega Codex.” / “Run Governors — Activ8 AI, LMAOS, PERSONAL — Charter Standard Execution.”) now align with runnable entry points, persistent evidence, and aggregated dashboards inside `charter_artifacts/`.
