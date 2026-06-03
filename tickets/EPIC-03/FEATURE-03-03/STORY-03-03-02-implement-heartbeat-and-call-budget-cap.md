# STORY-03-03-02: Implement Heartbeat & Call-Budget Cap

*Parent feature: [FEATURE-03-03 — Scheduled Ingestion Orchestration](../FEATURE-03-03-scheduled-ingestion-orchestration.md) · Parent epic: [EPIC-03 — Data Ingestion Pipeline](../../EPIC-03-data-ingestion-pipeline.md)*

This is the **second** of the three stories in FEATURE-03-03 (Scheduled Ingestion Orchestration). It **instruments** the daily GitHub Actions workflow (`ingest.yml`) created by **STORY-03-03-01** with two controls: (1) an **ingestion-run heartbeat** — exactly 1 `ingestion_run` row per run that records the run lifecycle and its telemetry — and (2) a **hard daily call-budget cap** — at most **5,000 active source fetch requests per day with a HALT at 4,500**, tracked through `ingestion_run.calls_used`. On the active path that counter counts the Apify actor's fetched eBay result pages/requests (bounded per search term by the actor input `maxPagesPerSearch` and globally by `maxItems`); the deferred eBay Browse API contributes 0 to `calls_used` until **STORY-03-03-03** is unblocked. This is a planning ticket and authors no application code, no SQL body, and no workflow YAML file body; the run heartbeat and the budget-cap logic are authored when this story is executed.

The **heartbeat** is the mechanism that makes a missed or silently-failed run visible. On start, the run inserts 1 `ingestion_run` row with `started_at` and `status` = `running`; on completion it updates that same row with `finished_at`, a terminal `status` of `ok` or `failed`, and the run counters `items_seen`, `items_new`, `sales_recorded`, `queued_for_review`, `error_count`, and `calls_used`. A run that crashes never reaches its finalize step, so it remains in `status` = `running` with a null `finished_at`; a later run detects that stale row and the admin job monitor raises a freshness alert for the missed run.

The **budget cap** keeps source-fetch volume under the free-tier ceiling. On the active path the run increments `ingestion_run.calls_used` atomically on every Apify-fetched eBay result page/request (bounded per search term by the actor input `maxPagesPerSearch` and globally by `maxItems`) and **halts fetching once `calls_used` reaches 4,500** — the 90% safety threshold of the ≤5,000-per-day budget fixed by the PRD — then resumes on the next cycle; the deferred eBay Browse API contributes 0 to `calls_used` until **STORY-03-03-03** is unblocked, at which point Browse calls are counted in the same budget. The pipeline is **idempotent and resumable**: a halted run records its progress and the next run continues, and re-running over overlapping result sets writes no duplicate rows because persistence upserts on `(source, source_item_id)` (per **STORY-03-01-03**). Every database write this run performs targets the pooled `DATABASE_URL` on an EPIC-02 Neon branch — never the unpooled `DATABASE_URL_UNPOOLED` reserved for DDL and migrations — and depends on EPIC-02's Neon branching (`STORY-02-01-*`) being provisioned first. A fatal error that exits the process with a non-zero code sets `ingestion_run.status` = `failed`, fails the GitHub Action, and triggers GitHub's failure email to the operator.

**Compliance posture:** the main application calls official data sources only; the `ebay-sold-listings` Apify actor is the single sanctioned out-of-band scraping exception; and 0 LLM calls run inside any request handler — the LLM-fallback parser runs inside this batch job only. The `status` field is a TEXT column whose value set is `running`, `ok`, and `failed` (a fixed value set, not a Postgres enum).

## User Story

> **As a** Data/Ingestion Engineer, **I want** each run to write a heartbeat row and enforce a hard daily call budget, **so that** a missed or failed run is visible and the active source-fetch volume never exceeds the daily limit.

## Acceptance Criteria

1. **(input-validation — budget config)** **Given** the daily budget is configured to 5,000 with a halt threshold of 4,500, **When** the configuration is loaded at run start, **Then** a halt threshold greater than the 5,000 budget is rejected with a non-zero exit and a logged configuration error, so the halt threshold is never greater than the budget.

2. **(valid-output — heartbeat insert)** **Given** an ingestion run starts, **When** the run begins, **Then** exactly 1 `ingestion_run` row is inserted with `started_at` set to the start time and `status` = `running`.

3. **(valid-output — heartbeat finalize)** **Given** a run completes without a fatal error, **When** it finishes, **Then** the same `ingestion_run` row is updated with `finished_at` set, `status` = `ok`, and the counters `items_seen`, `items_new`, `sales_recorded`, `queued_for_review`, `error_count`, and `calls_used` written.

4. **(boundary — budget halt)** **Given** `ingestion_run.calls_used` reaches 4,500, **When** the next batch of active source fetches (Apify-fetched eBay result pages/requests) is requested, **Then** the job stops fetching before `calls_used` exceeds 5,000 and resumes on the next cycle, recording the run with a terminal `status` = `ok` rather than aborting it as `failed`.

5. **(error-handling — non-zero exit)** **Given** the pipeline raises a fatal error, **When** the process exits with a non-zero code, **Then** the `ingestion_run` row is set to `status` = `failed`, the GitHub Action fails, and GitHub emails the operator.

6. **(edge-case — stale running row)** **Given** a prior run crashed and left `status` = `running` with a null `finished_at`, **When** a later run executes, **Then** it flags the stale row so the admin job monitor raises a freshness alert for the missed run.

7. **(edge-case — zero enabled queries)** **Given** 0 `ingestion_query` rows have `enabled` = TRUE, **When** the run executes, **Then** `items_seen` = 0, `calls_used` = 0, and the run records `status` = `ok`, so an empty run is not recorded as a failure.

8. **(concurrent — atomic counter)** **Given** concurrent increments to `calls_used` within a single run, **When** 2 increments occur, **Then** each increment is applied atomically so `calls_used` equals the exact total count of active source fetch requests issued.

## Sub-tasks

- Insert 1 `ingestion_run` row at run start with `started_at` set and `status` = `running`. `@ingestion-engineer`
- On completion, set `finished_at`, set `status` to `ok` or `failed`, and write `items_seen`, `items_new`, `sales_recorded`, `queued_for_review`, `error_count`, and `calls_used`. `@ingestion-engineer`
- Increment `ingestion_run.calls_used` atomically on every active source fetch request — on the active path each Apify-fetched eBay result page/request, bounded per search term by `maxPagesPerSearch` and globally by `maxItems`; deferred eBay Browse calls contribute 0 until **STORY-03-03-03** is unblocked. `@ingestion-engineer`
- Halt fetching when `calls_used` reaches 4,500 (90% of the 5,000-per-day budget) and resume on the next cycle. `@ingestion-engineer`
- Map a non-zero process exit to `status` = `failed` so the GitHub Action fails and GitHub emails the operator. `@devops-engineer`
- Detect a prior run left in `status` = `running` with a null `finished_at` and flag it as a stale/missed run for the admin monitor's freshness alert. `@ingestion-engineer`
- Assert at startup that the halt threshold (4,500) is not greater than the configured daily budget (5,000) and exit with a non-zero code on misconfiguration. `@ingestion-engineer`
- Validate the heartbeat and budget cap with a `workflow_dispatch` dry-run that exercises insert → finalize, the halt at `calls_used` = 4,500, and a simulated non-zero exit that sets `status` = `failed`. `@devops-engineer`

## Edge Cases

- **(Boundary)** `calls_used` at exactly 4,500 → the job halts before `calls_used` exceeds 5,000 and resumes on the next cycle.
- **(Concurrent / crash)** a crash mid-run leaves `status` = `running` with a null `finished_at` → a later run flags the stale row and the monitor raises a freshness alert.
- **(Empty/Null)** 0 enabled `ingestion_query` rows → `items_seen` = 0, `calls_used` = 0, and the run records `status` = `ok`.
- **(Invalid / transient)** a transient fetch error increments `error_count` by 1 without aborting the run; the run aborts and sets `status` = `failed` only when `error_count` reaches its configured threshold.
- **(Concurrent)** concurrent `calls_used` increments are atomic → the counter equals the exact count of active source fetch requests issued.

## Dependencies

### Upstream (must be complete first)

- **[STORY-03-03-01 — Create Scheduled Ingestion Workflow](./STORY-03-03-01-create-scheduled-ingestion-workflow.md):** the daily GitHub Actions workflow (`ingest.yml`) this story instruments with the per-run `ingestion_run` heartbeat and the daily call-budget cap.
- **[EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md):** the schema feature that creates the `ingestion_run` and `ingestion_query` tables this heartbeat reads and writes, and the Neon branching topology (`STORY-02-01-*`) — a hard prerequisite for every database write. Every write uses the pooled `DATABASE_URL`, never the unpooled `DATABASE_URL_UNPOOLED` reserved for DDL and migrations.

### Downstream (informational — not a build prerequisite of this story)

- **[EPIC-04 — Backend Application & API](../../EPIC-04-backend-application-and-api.md):** the admin job monitor reads the `ingestion_run` rows this story writes — the last successful run, the per-run telemetry, and the freshness alert for a missed run.
- **[EPIC-06 — Testing & CI/CD Quality Gates](../../EPIC-06-testing-and-cicd-quality-gates.md):** validates the run telemetry and the budget-cap halt behavior.

### Parent feature

- **[FEATURE-03-03 — Scheduled Ingestion Orchestration](../FEATURE-03-03-scheduled-ingestion-orchestration.md)**

## Story Estimation Guidance

- **Effort: Medium** — instrument the workflow with a heartbeat row, an atomic call counter, a halt gate at 4,500, a stale-run detector on a null `finished_at`, and a non-zero-exit-to-`failed` mapping, then validate against a dry-run.
- **Complexity: Medium** — an atomic `calls_used` counter, the `running` → `ok`/`failed` state machine, stale-run detection, and the non-zero-exit-to-`failed` mapping.
- **Uncertainty: Low** — the `ingestion_run` columns are fixed by `docs/schema.sql` and the 4,500-of-5,000 halt threshold is fixed by the PRD; the residual unknown is the atomic-increment mechanism.
- **Fibonacci Story Points: 5.** The atomic counter, the state machine, the stale-run detection, and the exit mapping place this above a 3, while the bounded single-instrumentation scope and the schema-fixed columns hold it below an 8. Points measure relative size, not a duration.

## Definition of Done

- [ ] Each run inserts 1 `ingestion_run` row (`started_at` set, `status` = `running`) and finalizes it (`finished_at` set, `status` = `ok` or `failed`, and `items_seen`, `items_new`, `sales_recorded`, `queued_for_review`, `error_count`, and `calls_used` written).
- [ ] `calls_used` is incremented atomically per active source fetch request (on the active path each Apify-fetched eBay result page/request, bounded by `maxPagesPerSearch`/`maxItems`; deferred eBay Browse calls contribute 0 until **STORY-03-03-03** is unblocked); the job halts at `calls_used` = 4,500 of the ≤5,000-per-day budget and resumes the next cycle; the pipeline is idempotent and resumable.
- [ ] A non-zero process exit sets `status` = `failed`, fails the GitHub Action, and triggers the GitHub failure email.
- [ ] A prior run left in `status` = `running` with a null `finished_at` is flagged as stale so the monitor raises a freshness alert.
- [ ] A run with 0 enabled `ingestion_query` rows records `status` = `ok` with `items_seen` = 0 and `calls_used` = 0.
- [ ] The main application calls official data sources only, the `ebay-sold-listings` Apify actor is the single sanctioned out-of-band scraping exception, and 0 LLM calls run inside any request handler; all writes use the pooled `DATABASE_URL` on an EPIC-02 Neon branch, never the unpooled `DATABASE_URL_UNPOOLED`.
- [ ] No prohibited vague quality term appears in any acceptance criterion, and every criterion names a measurable pass/fail condition (a row count, a counter value, a `status` value, or an exit code).
- [ ] **Testing:** a `workflow_dispatch` dry-run exercises the heartbeat (insert → finalize) and the budget-cap halt at `calls_used` = 4,500, and reports run telemetry (`items_seen`, `items_new`, `sales_recorded`, `queued_for_review`, `error_count`, `calls_used`); a simulated non-zero exit sets `status` = `failed`.
