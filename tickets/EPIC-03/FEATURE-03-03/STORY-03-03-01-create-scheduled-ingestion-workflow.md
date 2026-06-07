# STORY-03-03-01: Create Scheduled Ingestion Workflow

*Parent feature: [FEATURE-03-03 — Scheduled Ingestion Orchestration](../FEATURE-03-03-scheduled-ingestion-orchestration.md) · Parent epic: [EPIC-03 — Data Ingestion Pipeline](../../EPIC-03-data-ingestion-pipeline.md)*

This is the **first** of the three stories in FEATURE-03-03 (Scheduled Ingestion Orchestration). It creates the daily GitHub Actions workflow **`.github/workflows/ingest.yml`** that orchestrates the ingestion pipeline — invoking the Apify actor integration (FEATURE-03-01), running the two-stage extraction and confidence-gated matching (FEATURE-03-02), and finishing with the valuation recompute — so sold-listing data accumulates on a fixed schedule without manual intervention. This story delivers the schedule, the runner, the encrypted-secret wiring, and the keepalive step; the per-run heartbeat and the daily call-budget cap are layered on by **STORY-03-03-02**, and the deferred eBay API integration is tracked in **STORY-03-03-03**. This is a planning ticket and authors no application code and no workflow YAML file body; the `ingest.yml` workflow itself is authored when this story is executed.

The daily run is hosted on **GitHub Actions, not a Vercel function**, because Vercel serves request/response traffic only and is the wrong home for long-running or scraping work. The workflow declares the trigger pair `schedule: cron "0 8 * * *"` (UTC; scheduled Actions run UTC-only and the PRD records a 10–30 minute drift) plus `workflow_dispatch` for a manual run, and configures the `ingest` job with `runs-on: ubuntu-latest`, `timeout-minutes: 120`, and a Node `>=20.20.2` runtime — the TypeScript application's toolchain floor (root `package.json` `engines.node`) that the runner's `jobs/ingest.ts` pipeline and valuation recompute execute under; the `ebay-sold-listings` Apify actor keeps its own `engines.node` `>=18` floor (in `apify/package.json`, container image `apify/actor-node:20`), which the runner's `>=20.20.2` satisfies. A keepalive step runs on each scheduled execution to prevent GitHub's 60-day auto-disable of scheduled workflows after repository inactivity. The workflow reads its credentials from GitHub Actions encrypted secrets — `DATABASE_URL` (pooled, runtime), `APIFY_TOKEN` (actor invocation), and `LLM_API_KEY` (the batch LLM-fallback parser) — configured per the canonical Blitzy environments reference at <https://docs.blitzy.com/administration/environments> and never committed to the repository. The eBay credentials (`EBAY_CLIENT_ID` / `EBAY_CLIENT_SECRET`) are **deferred** to **STORY-03-03-03** and are not read by this workflow.

The pipeline is **idempotent and resumable**: the same `jobs/*` scripts run locally as a bounded dry-run/replay over the current saved queries for testing (with no historical backfill), and re-running over overlapping result sets writes no duplicate rows because persistence upserts idempotently on `(source, source_item_id)` (per **STORY-03-01-03**). Every data write the run performs targets the pooled `DATABASE_URL` on the relevant EPIC-02 Neon branch (`dev-qa` for non-production runs, `production` for production) — never the unpooled `DATABASE_URL_UNPOOLED` reserved for DDL and migrations — and depends on EPIC-02's Neon branching (`STORY-02-01-*`) — the two long-lived branches `production` and `dev-qa` — being provisioned first.

**Compliance posture:** the main application calls official data sources only; the `ebay-sold-listings` Apify actor is the single sanctioned out-of-band scraping exception; and 0 LLM calls run inside any request handler — the LLM-fallback parser runs inside this batch job only.

## User Story

> **As a** Platform Engineer, **I want** a daily GitHub Actions workflow that orchestrates the ingestion pipeline, **so that** sold-listing data accumulates on a fixed schedule without manual intervention.

## Acceptance Criteria

1. **(valid-output — triggers)** **Given** `.github/workflows/ingest.yml` declares `schedule: cron "0 8 * * *"` and `workflow_dispatch`, **When** the workflow is committed to the default branch, **Then** the Actions tab lists it as both schedule-triggered and manually runnable, and a manual run is startable from the Actions UI.

2. **(valid-output — runner)** **Given** the `ingest` job, **When** it starts, **Then** it runs on `ubuntu-latest` with `timeout-minutes: 120` and a Node `>=20.20.2` runtime, it executes the `jobs/ingest.ts` pipeline followed by the valuation recompute (`recompute-valuations.ts`), and it is hosted on GitHub Actions rather than a Vercel function.

3. **(input-validation — required secret)** **Given** the required encrypted secret `DATABASE_URL` is absent from GitHub Actions secrets, **When** the workflow starts, **Then** it exits with a non-zero code before the Apify actor is invoked and a log line names the missing `DATABASE_URL` secret.

4. **(edge-case — scheduled drift)** **Given** the scheduled trigger fires 10–30 minutes after 08:00 UTC, **When** the run proceeds, **Then** it completes the same pipeline as an on-time run and records exactly 1 `ingestion_run` row, so the drift neither duplicates nor skips the daily run.

5. **(edge-case — concurrency)** **Given** a manual `workflow_dispatch` run starts while a scheduled run is mid-flight, **When** both runs execute, **Then** 0 duplicate `raw_listing` rows are written because the persistence upsert is idempotent on `(source, source_item_id)` (per **STORY-03-01-03**).

6. **(error-handling — timeout)** **Given** a run exceeds the 120-minute `timeout-minutes`, **When** the limit is reached, **Then** GitHub Actions terminates the job, the run is marked failed, and the `ingestion_run.status` is set to `failed` (by **STORY-03-03-02**).

7. **(edge-case — 60-day keepalive)** **Given** 60 days elapse with no other repository activity, **When** the keepalive step has executed on each scheduled run, **Then** the scheduled workflow remains enabled and GitHub does not auto-disable it.

## Sub-tasks

- Author `.github/workflows/ingest.yml` with a `schedule: cron "0 8 * * *"` trigger and a `workflow_dispatch` trigger. `@platform-engineer`
- Configure the `ingest` job with `runs-on: ubuntu-latest`, `timeout-minutes: 120`, and a Node `>=20.20.2` setup step (which also satisfies the Apify actor's own `>=18` floor). `@devops-engineer`
- Add checkout, dependency-install, and a step that runs `jobs/ingest.ts` then the valuation recompute (`recompute-valuations.ts`). `@platform-engineer`
- Wire the GitHub Actions encrypted secrets `DATABASE_URL`, `APIFY_TOKEN`, and `LLM_API_KEY` into the run environment per <https://docs.blitzy.com/administration/environments>. `@devops-engineer`
- Add a keepalive step that runs on each scheduled execution to prevent the 60-day scheduled-workflow auto-disable. `@platform-engineer`
- Add a fail-fast startup assertion that exits non-zero and names any missing required secret before the actor is invoked. `@devops-engineer`
- Document that the same `jobs/*` scripts run locally as a bounded dry-run/replay over the current saved queries for testing (with no historical backfill) and that the pipeline is idempotent and resumable. `@platform-engineer`
- Validate the workflow with a `workflow_dispatch` dry-run that executes the pipeline end to end within the 120-minute timeout and records 1 `ingestion_run` row, plus a missing-secret run that exits non-zero before the actor is invoked. `@devops-engineer`

## Edge Cases

- **Boundary / drift:** the scheduled trigger is delayed 10–30 minutes past 08:00 UTC → the daily run still completes and exactly 1 `ingestion_run` row is recorded.
- **Concurrent:** a manual `workflow_dispatch` run overlaps a mid-flight scheduled run → 0 duplicate `raw_listing` rows are written because the upsert is idempotent on `(source, source_item_id)`.
- **Boundary / timeout:** a run exceeds 120 minutes → GitHub Actions terminates the job and the run is marked failed.
- **Empty/Null:** the required secret `DATABASE_URL` is absent → the run exits non-zero before the actor is invoked and a log line names the missing `DATABASE_URL`.

## Dependencies

### Upstream (must be complete first)

- **[EPIC-01 — Environment & Configuration Foundation](../../EPIC-01-environment-and-configuration-foundation.md):** supplies the single Blitzy environment and the GitHub Actions encrypted secrets (`DATABASE_URL`, `APIFY_TOKEN`, `LLM_API_KEY`) this workflow reads — specifically **FEATURE-01-01** (Blitzy Environment Provisioning), which manually configures and attaches the single environment, and **FEATURE-01-03** (Secrets & Variable Management), which establishes the encrypted-secret baseline.
- **[EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md) (`STORY-02-01-*`):** the Neon branching topology (the two long-lived branches `production` and `dev-qa`) — a hard prerequisite for every ingestion data write — and the EPIC-02 schema feature that creates the `ingestion_run` table this workflow's run heartbeat targets; every write uses the pooled `DATABASE_URL` on the relevant branch (`dev-qa` for non-production runs, `production` for production), never the unpooled `DATABASE_URL_UNPOOLED`.
- **[FEATURE-03-01 — Apify Actor Integration](../FEATURE-03-01-apify-actor-integration.md):** the Apify actor integration this workflow invokes on each run.
- **[FEATURE-03-02 — Extraction & Matching](../FEATURE-03-02-extraction-and-matching.md):** the two-stage extraction and confidence-gated matching this workflow runs in batch after persistence.

### Downstream (informational — not a build prerequisite of this story)

- **`STORY-03-03-02`:** instruments this workflow with the per-run `ingestion_run` heartbeat and the daily call-budget cap (≤5,000 eBay Browse calls per day, halting at `calls_used` = 4,500), and sets `ingestion_run.status = failed` on a non-zero exit.
- **`STORY-03-03-03`:** documents the deferred eBay Browse/Marketplace-Insights API integration (`EBAY_CLIENT_ID` / `EBAY_CLIENT_SECRET`) — **DEFERRED/BLOCKED** on approved access, not scheduled, and not a dependency of this story.
- **[EPIC-04 — Backend Application & API](../../EPIC-04-backend-application-and-api.md):** reads the `sale_observation` rows and the `valuation` cache this scheduled run produces.
- **[EPIC-06 — Testing & CI/CD Quality Gates](../../EPIC-06-testing-and-cicd-quality-gates.md):** validates this ingestion pipeline and its scheduled orchestration.

### Parent feature

- **[FEATURE-03-03 — Scheduled Ingestion Orchestration](../FEATURE-03-03-scheduled-ingestion-orchestration.md)**

## Story Estimation Guidance

- **Effort: Medium** — author a multi-step scheduled workflow, wire 3 encrypted secrets, add a keepalive step and a fail-fast secret assertion, and validate against a dry-run and a missing-secret run.
- **Complexity: Medium** — a cron schedule plus a manual `workflow_dispatch` trigger plus a keepalive plus encrypted-secret wiring plus idempotent-run concurrency keyed on `(source, source_item_id)`.
- **Uncertainty: Low–Medium** — the 10–30 minute scheduled-Action drift and the 60-day auto-disable are documented GitHub behaviors, and the cron, runner, and timeout are fixed by the PRD; the residual unknown is the keepalive mechanism choice.
- **Fibonacci Story Points: 5.** The schedule, manual trigger, keepalive, secret wiring, and concurrency handling place this above a 3, while the bounded single-workflow scope and the documented platform behaviors hold it below an 8. Points measure relative size, not a duration.

## Definition of Done

- [ ] `ingest.yml` declares `schedule: cron "0 8 * * *"` and `workflow_dispatch`, and is hosted on GitHub Actions, not a Vercel function.
- [ ] The `ingest` job runs on `ubuntu-latest` with `timeout-minutes: 120` and a Node `>=20.20.2` runtime, and it runs `jobs/ingest.ts` then the valuation recompute (`recompute-valuations.ts`).
- [ ] The encrypted secrets `DATABASE_URL`, `APIFY_TOKEN`, and `LLM_API_KEY` are wired into the run environment per <https://docs.blitzy.com/administration/environments>; a missing `DATABASE_URL` exits non-zero before the actor is invoked and a log line names the secret.
- [ ] A keepalive step prevents the 60-day scheduled-workflow auto-disable.
- [ ] The pipeline is idempotent and resumable, the same `jobs/*` scripts run locally as a bounded dry-run/replay over the current saved queries for testing (with no historical backfill), and all data writes use the pooled `DATABASE_URL` on the relevant EPIC-02 Neon branch (`dev-qa` for non-production runs, `production` for production), never the unpooled `DATABASE_URL_UNPOOLED`.
- [ ] The main application calls official data sources only, the `ebay-sold-listings` Apify actor is the single sanctioned out-of-band scraping exception, and 0 LLM calls run inside any request handler; the eBay credentials remain deferred to **STORY-03-03-03**.
- [ ] No prohibited vague quality term appears in any acceptance criterion, and every criterion names a measurable pass/fail condition (an exit code, a row count, or a named secret).
- [ ] **Testing:** a `workflow_dispatch` dry-run executes the pipeline end to end, completes within the 120-minute timeout, and records exactly 1 `ingestion_run` row; a run with a missing required secret exits non-zero before the actor is invoked.
