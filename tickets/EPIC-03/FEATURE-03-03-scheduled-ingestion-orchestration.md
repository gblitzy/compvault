# FEATURE-03-03: Scheduled Ingestion Orchestration

*Parent epic: [EPIC-03 — Data Ingestion Pipeline](../EPIC-03-data-ingestion-pipeline.md)*

## Feature Summary

This feature creates the recurring orchestration that drives CompVault's ingestion pipeline: a single GitHub Actions workflow (`ingest.yml`) runs once per day on cron `0 8 * * *` (UTC) plus an on-demand `workflow_dispatch` trigger, invoking the Apify integration (FEATURE-03-01), then the extraction and matching logic (FEATURE-03-02), and finishing by recomputing the `valuation` price cache from `sale_observation`. The business value is a live, idempotent, resumable, budget-aware pipeline whose health is observable: every run writes one `ingestion_run` heartbeat row (`status` transitions `running` → `ok` or `failed`) and tracks `calls_used` against a hard daily budget of ≤5,000 eBay Browse calls, halting at 4,500 and resuming the next cycle so a run never exceeds the free-tier cap, while a non-zero exit sets `ingestion_run.status = failed` and fails the Action so a missed or broken run is visible to the operator. Scope is limited to the schedule, the run heartbeat, the call-budget cap, and the documentation of the DEFERRED eBay API; this feature orchestrates — it does not implement — the Apify actor integration ([FEATURE-03-01 — Apify Actor Integration](FEATURE-03-01-apify-actor-integration.md)) or the two-stage extraction and confidence-gated matching ([FEATURE-03-02 — Extraction & Matching](FEATURE-03-02-extraction-and-matching.md)). This feature is delivered through **3 stories**.

## Environment Access & Configuration

The base platform access for ingestion — the Blitzy environments and the Apify `APIFY_TOKEN` secret — is provisioned in [FEATURE-03-01 — Apify Actor Integration](FEATURE-03-01-apify-actor-integration.md) and documented per the canonical Blitzy environments reference: <https://docs.blitzy.com/administration/environments>. This feature does not duplicate those steps; it ADDS the orchestration platform — **GitHub Actions** — and names the **DEFERRED eBay Developer API**.

The daily run is hosted on **GitHub Actions, not a Vercel function** (Vercel serves request/response traffic only and times out on long ingests). The `ingest.yml` workflow declares `runs-on: ubuntu-latest`, `timeout-minutes: 120`, and a Node `>=18` runtime, and is triggered by the cron schedule `0 8 * * *` (UTC; scheduled Actions run UTC-only and the spec records a 10–30 minute drift) plus the manual `workflow_dispatch` trigger. A keepalive step is included to prevent the 60-day scheduled-workflow auto-disable. The workflow reads its credentials from GitHub Actions encrypted secrets — `DATABASE_URL` (pooled, runtime), `APIFY_TOKEN` (actor invocation), and `LLM_API_KEY` (the batch LLM-fallback parser) — which are never committed to the repository.

The eBay Developer API credentials (`EBAY_CLIENT_ID` / `EBAY_CLIENT_SECRET`) are **DEFERRED and blocked on approved access**: they are configured only when the deferral is lifted, and no scheduled run requires them. The main application calls official data sources only; the Apify actor remains the single sanctioned out-of-band scraping exception, and no LLM call runs inside a request handler — the LLM-fallback parser runs inside this batch job only.

The daily run stays within a hard budget of **≤5,000 eBay Browse calls per day and halts at 4,500 calls**, tracked through `ingestion_run.calls_used`. This step-by-step configuration is completed in full **before** the scheduled job runs, and every data write the run performs depends on EPIC-02's Neon branching (`STORY-02-01-*`) and schema being provisioned first, using the pooled `DATABASE_URL` rather than the unpooled `DATABASE_URL_UNPOOLED` reserved for DDL and migrations.

### Platforms and access required

| Platform | Access required | Purpose in FEATURE-03-03 |
|----------|-----------------|--------------------------|
| GitHub Actions | CI runners; encrypted repository or organization secrets (`DATABASE_URL`, `APIFY_TOKEN`, `LLM_API_KEY`); scheduled cron | Run the daily `ingest.yml` workflow on cron `0 8 * * *` plus `workflow_dispatch`, with a keepalive step and a 120-minute timeout |
| Blitzy / Apify Platform | Provisioned in FEATURE-03-01 (`APIFY_TOKEN` encrypted secret; actor execution rights) | Reuse the base ingestion access per <https://docs.blitzy.com/administration/environments>; this feature invokes the FEATURE-03-01 integration on the schedule |
| eBay Developer API | `EBAY_CLIENT_ID` / `EBAY_CLIENT_SECRET` — **DEFERRED, blocked on approved access** | Documented future Browse/Marketplace-Insights source (`STORY-03-03-03`); not configured and not a dependency of any active story |

### Step-by-step configuration (complete before the scheduled job runs)

1. Confirm the base ingestion access from FEATURE-03-01 is in place — the `APIFY_TOKEN` encrypted secret and Apify actor execution rights — per <https://docs.blitzy.com/administration/environments>.
2. Configure the GitHub Actions encrypted secrets the `ingest.yml` workflow consumes (`DATABASE_URL`, `APIFY_TOKEN`, `LLM_API_KEY`) so both the cron `0 8 * * *` run and the `workflow_dispatch` run resolve them.
3. Define the `ingest.yml` workflow on `runs-on: ubuntu-latest` with `timeout-minutes: 120`, a Node `>=18` runtime, the cron `0 8 * * *` schedule, the `workflow_dispatch` trigger, and a keepalive step that prevents the 60-day auto-disable.
4. Confirm EPIC-02's Neon branching (`STORY-02-01-*`) and the `ingestion_run` and `ingestion_query` schema are provisioned and that the pooled `DATABASE_URL` reaches them before the first run.
5. Leave the eBay Developer API credentials (`EBAY_CLIENT_ID` / `EBAY_CLIENT_SECRET`) unconfigured: the eBay integration is deferred, blocked on approved access, and not required for any scheduled run.
6. Validate the wiring with a single `workflow_dispatch` dry-run that writes one `ingestion_run` heartbeat row and exercises the call-budget cap on a Neon branch, confirming the environment is provisioned before the first scheduled run.

## User Stories Index

This feature is delivered through three stories. Each link is relative to this file and resolves inside the `FEATURE-03-03/` subfolder.

1. **[STORY-03-03-01 — Create Scheduled Ingestion Workflow](FEATURE-03-03/STORY-03-03-01-create-scheduled-ingestion-workflow.md)** — create the `ingest.yml` GitHub Actions workflow on cron `0 8 * * *` plus `workflow_dispatch`, with a keepalive step and a 120-minute timeout on `runs-on: ubuntu-latest`; the workflow orchestrates the idempotent, resumable pipeline (invoke the Apify integration → extraction → matching) whose final stage recomputes the `valuation` price cache from `sale_observation`, writing one `valuation` row per `(variation_id, grade_id, window_days)` for `window_days` ∈ { `90`, `365` }.
2. **[STORY-03-03-02 — Implement Heartbeat & Call-Budget Cap](FEATURE-03-03/STORY-03-03-02-implement-heartbeat-and-call-budget-cap.md)** — write one `ingestion_run` heartbeat row per run (`status` `running` → `ok`/`failed`, with `items_seen`, `items_new`, `sales_recorded`, `queued_for_review`, `error_count`, and `calls_used`) and enforce the daily budget cap (≤5,000 Browse calls, halt at `calls_used` = 4,500, resume next cycle); a non-zero exit sets `ingestion_run.status = failed` and fails the Action.
3. **[STORY-03-03-03 — Document Deferred eBay API Integration](FEATURE-03-03/STORY-03-03-03-document-deferred-ebay-api-integration.md)** — document the future eBay Browse/Marketplace-Insights integration and its `EBAY_CLIENT_ID` / `EBAY_CLIENT_SECRET` access block (Marketplace Insights becomes an additive 90-day sold-history source if access is granted); **DEFERRED/BLOCKED — not scheduled and not a dependency of any active story**.

## Dependencies

### Upstream (must be complete first)

- **EPIC-01 — Environment & Configuration Foundation:** supplies the Blitzy environments and the GitHub Actions encrypted secrets (`DATABASE_URL`, `APIFY_TOKEN`, `LLM_API_KEY`) the `ingest.yml` workflow consumes.
- **EPIC-02 — Database Platform & Schema:** supplies the Neon branching topology (`STORY-02-01-*`) and the `ingestion_run` and `ingestion_query` schema; every data write the scheduled run performs requires the database through the pooled `DATABASE_URL`. The branching stories (`STORY-02-01-*`) are a hard prerequisite of every ingestion write.
- **[FEATURE-03-01 — Apify Actor Integration](FEATURE-03-01-apify-actor-integration.md):** the Apify actor integration the workflow invokes on each run.
- **[FEATURE-03-02 — Extraction & Matching](FEATURE-03-02-extraction-and-matching.md):** the two-stage extraction and confidence-gated matching the workflow runs in batch after persistence.

### Downstream (informational — not a build prerequisite of this feature)

- **EPIC-04 — Backend Application & API:** reads the `sale_observation` rows and the `valuation` cache this scheduled run produces; the price-history endpoint (`STORY-04-02-04`) reads the `valuation` rows recomputed by the daily run's final stage.
- **EPIC-06 — Testing & CI/CD Quality Gates:** validates the ingestion pipeline and its scheduled orchestration.

### Deferred (blocked — not a prerequisite of any active story)

- **`STORY-03-03-03` — eBay Developer API integration:** the eBay Browse/Marketplace-Insights integration (`EBAY_CLIENT_ID` / `EBAY_CLIENT_SECRET`) is documented and tracked but DEFERRED and blocked on approved access. Apify is the primary live ingestion source now, so this story is **not** a dependency of `STORY-03-03-01`, `STORY-03-03-02`, or any other active story, and it gates no other work.

## Definition of Done

- [ ] All 3 stories (STORY-03-03-01, STORY-03-03-02, STORY-03-03-03) are complete.
- [ ] The `ingest.yml` workflow runs on cron `0 8 * * *` (UTC) and on manual `workflow_dispatch`, declares `runs-on: ubuntu-latest`, `timeout-minutes: 120`, and a Node `>=18` runtime, and is hosted on GitHub Actions, not a Vercel function.
- [ ] A keepalive step is present in `ingest.yml` to prevent the 60-day scheduled-workflow auto-disable.
- [ ] The GitHub Actions encrypted secrets `DATABASE_URL`, `APIFY_TOKEN`, and `LLM_API_KEY` are configured per <https://docs.blitzy.com/administration/environments> and resolve in both the cron and `workflow_dispatch` runs; no secret value is committed to the repository.
- [ ] Each run writes one `ingestion_run` heartbeat row whose `status` transitions `running` → `ok` on success or `running` → `failed` on error, and increments `calls_used`, `items_seen`, `items_new`, `sales_recorded`, `queued_for_review`, and `error_count`.
- [ ] The run halts when `ingestion_run.calls_used` reaches 4,500 of the ≤5,000-per-day eBay Browse budget and resumes the next cycle; the pipeline is idempotent and resumable.
- [ ] A non-zero exit sets `ingestion_run.status = failed` and fails the Action (GitHub emails the operator).
- [ ] The daily run's final stage recomputes the `valuation` price cache from `sale_observation`, writing one `valuation` row per `(variation_id, grade_id, window_days)` for `window_days` ∈ { `90`, `365` }.
- [ ] The eBay Browse/Marketplace-Insights API integration is documented as DEFERRED/BLOCKED (`STORY-03-03-03`), is not scheduled, and is not a dependency of any active story; Apify is the primary live ingestion source.
- [ ] The main application calls official data sources only; the Apify actor is the single sanctioned out-of-band scraping exception, and no LLM call runs inside a request handler.
- [ ] All data writes target the pooled `DATABASE_URL` on an EPIC-02 Neon branch (`STORY-02-01-*`); no write uses the unpooled `DATABASE_URL_UNPOOLED` reserved for DDL and migrations.
- [ ] No prohibited vague quality term appears in any acceptance-criteria-like statement; every such statement names a measurable pass/fail condition.
- [ ] **Testing:** a `workflow_dispatch` dry-run exercises the heartbeat and call-budget-cap logic on a Neon branch and reports run telemetry — asserting one `ingestion_run` row is written, that `status` ends `ok` on a clean run and `failed` on a forced non-zero exit, and that the run halts at `ingestion_run.calls_used` = 4,500.
