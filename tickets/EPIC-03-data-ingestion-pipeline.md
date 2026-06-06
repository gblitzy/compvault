# EPIC-03: Build the Data Ingestion Pipeline — make the Apify actor the primary live source, extract and confidence-match sales into the catalog, and schedule daily ingestion while deferring the eBay API

## Epic Summary

EPIC-03 builds the CompVault data-ingestion pipeline: it makes the existing `ebay-sold-listings` Apify actor the primary live ingestion source, parses each scraped listing through a two-stage (regex-first, LLM-fallback) extractor, confidence-matches each sale into the catalog, and schedules a daily ingestion run that writes idempotently to the database and, as its final stage, recomputes the `valuation` price cache from the matched `sale_observation` rows. The business value is a live, idempotent, budget-capped pipeline that turns sold eBay listings into matched `sale_observation` rows and the precomputed `valuation` cache feeding the search, comparison, and price-history surfaces — with every low-confidence match routed to the operator review queue instead of polluting the price series. Scope is limited to Apify-primary ingestion, the two-stage extraction, the confidence-gated matcher, the self-healing re-clustering, and the scheduled orchestration with its run heartbeat, call budget, and daily `valuation`-cache recompute; the eBay Browse/Marketplace-Insights API integration is documented but deferred and blocked on approved access, and no LLM call runs inside a request handler (LLM-assisted extraction stays in the batch ingestion job).

## Environment Access & Configuration

All environment provisioning for this epic follows the canonical Blitzy environments reference: <https://docs.blitzy.com/administration/environments>. Non-sensitive values are stored as plaintext environment variables and credentials are stored as encrypted secrets, after which the environment is attached to the project. This step-by-step configuration is completed in full **before** any ingestion run executes.

Ingestion runs the existing `ebay-sold-listings` Apify actor as the single sanctioned out-of-band scraping exception; the main application calls official data sources only and issues no scraping itself. The actor is invoked from the Apify Platform with an `APIFY_TOKEN`, its dataset results are persisted to the `raw_listing` table, and a GitHub Actions cron workflow (`ingest.yml`) drives the daily run. Because every ingestion write targets the database, this epic depends on EPIC-02's Neon two-environment branching (the `production` and `dev-qa` branches) and schema being provisioned first; the writes use the pooled `DATABASE_URL`, never the unpooled `DATABASE_URL_UNPOOLED` reserved for DDL and migrations.

**Runtime floor:** Node `>=18` for the actor, which the Apify container pins at Node 20 (`apify/actor-node:20`).

**Ingestion budget and schedule:** the daily run stays within a budget of **≤5,000** eBay Browse calls per day and **halts at 4,500** calls so the run never exceeds the free-tier cap; the GitHub Actions workflow is scheduled on cron `0 8 * * *` (UTC) and also exposes `workflow_dispatch` for an on-demand run.

### Platforms and access required

| Platform | Access required | Purpose in EPIC-03 |
|----------|-----------------|--------------------|
| Blitzy | single environment (manual build/run + hand-entered secrets); plaintext variables and encrypted secrets | Store the ingestion secrets (`APIFY_TOKEN`, `LLM_API_KEY`, the pooled `DATABASE_URL`) in the single Blitzy environment per the Blitzy environments reference |
| Apify Platform | Account access; `APIFY_TOKEN`; actor execution rights for `ebay-sold-listings` | Invoke the actor as the primary live ingestion source and read its dataset results |
| GitHub Actions | CI runners; encrypted repository or organization secrets; scheduled cron | Run the daily `ingest.yml` workflow on cron `0 8 * * *` plus `workflow_dispatch`, injecting the ingestion secrets |
| eBay Developer API | `EBAY_CLIENT_ID` / `EBAY_CLIENT_SECRET` — **DEFERRED, blocked on approved access** | Documented future Browse/Marketplace-Insights source; not configured and not a dependency of any active story |

### Step-by-step configuration (complete before ingestion runs)

1. Configure the single Blitzy environment and store `APIFY_TOKEN`, `LLM_API_KEY`, and the pooled `DATABASE_URL` as encrypted secrets, with non-sensitive values stored as plaintext, per <https://docs.blitzy.com/administration/environments> (informational only — Blitzy cannot create environments).
2. Grant the ingestion job Apify Platform access and confirm the `APIFY_TOKEN` invokes the `ebay-sold-listings` actor and reads its dataset.
3. Confirm EPIC-02's Neon two-environment branching (the `production` and `dev-qa` branches) and schema are provisioned and that the pooled `DATABASE_URL` reaches the `raw_listing`, `extraction`, `sale_observation`, `valuation`, `ingestion_run`, and `review_queue` tables before the first write.
4. Configure the GitHub Actions secrets the `ingest.yml` workflow consumes (`APIFY_TOKEN`, `LLM_API_KEY`, `DATABASE_URL`) so the cron `0 8 * * *` run and the `workflow_dispatch` run resolve them.
5. Leave the eBay Developer API credentials (`EBAY_CLIENT_ID` / `EBAY_CLIENT_SECRET`) unconfigured: the eBay integration is deferred and blocked on approved access and is not required for any active ingestion run.
6. Validate the wiring with a single bounded actor invocation (a small `maxItems` cap) that writes to `raw_listing` on the relevant Neon branch (`dev-qa` for non-production runs, `production` for production), confirming the environment is provisioned before the first scheduled run.

## Features Index

This epic is delivered through three features. Each link is relative to this file inside the `EPIC-03/` directory.

1. **[FEATURE-03-01 — Apify Actor Integration](EPIC-03/FEATURE-03-01-apify-actor-integration.md)** — configure Apify Platform access and the `APIFY_TOKEN`, invoke the `ebay-sold-listings` actor per its input contract (required `searchTerms`, plus `ebayDomain`, `itemsPerPage`, `maxPagesPerSearch`, `maxItems`, and the RESIDENTIAL proxy), persist its dataset results to `raw_listing`, and implement the idempotent upsert keyed on `(source, source_item_id)`. This feature carries three stories.
2. **[FEATURE-03-02 — Extraction & Matching](EPIC-03/FEATURE-03-02-extraction-and-matching.md)** — implement the cheap regex-first title parser, the LLM-fallback parser with a strict JSON schema (batch-only, never in a request handler), the confidence-gated matcher that auto-commits high-confidence sales and routes low-confidence matches to the review queue, and the self-healing re-clustering of duplicate digital variations. This feature carries four stories.
3. **[FEATURE-03-03 — Scheduled Ingestion Orchestration](EPIC-03/FEATURE-03-03-scheduled-ingestion-orchestration.md)** — create the `ingest.yml` GitHub Actions workflow on cron `0 8 * * *` plus `workflow_dispatch` (`STORY-03-03-01`), whose **final stage recomputes the `valuation` price cache from `sale_observation`** — writing one `valuation` row per `(variation_id, grade_id, window_days)` for `window_days` ∈ { `90`, `365` }, which the EPIC-04 price-history endpoint (`STORY-04-02-04`) reads; implement the `ingestion_run` heartbeat and the call budget cap (≤5,000 calls/day, halt at 4,500) (`STORY-03-03-02`); and document the deferred eBay Browse/Marketplace-Insights integration as a tracked, blocked story (`STORY-03-03-03`). This feature carries three stories.

## Dependencies

### Upstream (must be complete first)

- **EPIC-01 — Environment & Configuration Foundation:** supplies the Blitzy environments, the secrets baseline (`APIFY_TOKEN`, `LLM_API_KEY`, `DATABASE_URL`), and the GitHub Actions secrets the `ingest.yml` workflow consumes.
- **EPIC-02 — Database Platform & Schema:** supplies the Neon two-environment branching topology (the `production` and `dev-qa` branches) and the Drizzle schema and access layer; every data-write story in this epic requires the database, writing to `raw_listing`, `extraction`, `sale_observation`, `valuation`, `ingestion_run`, and `review_queue` through the pooled `DATABASE_URL`. The branching stories (`STORY-02-01-*`) are a hard prerequisite of every ingestion write.

### Downstream (informational — not a build prerequisite of this epic)

- **EPIC-04 — Backend Application & API:** consumes the ingested `sale_observation` rows, the matched catalog, and the `valuation` cache this pipeline produces; its search and detail endpoints read the matched sales, and its price-history endpoint (`STORY-04-02-04`) reads the `valuation` rows recomputed by the daily run's final stage (`STORY-03-03-01`).
- **EPIC-06 — Testing & CI/CD Quality Gates:** `STORY-06-02-03` tests the Apify helper functions (`extractItemId`, `parsePrice`, `parseSoldDate`) against HTML fixtures, targeting an Apify-helper coverage floor of **≥90%**.

### Deferred (blocked — not a prerequisite of any active story)

- **eBay Developer API integration (`STORY-03-03-03`):** the eBay Browse/Marketplace-Insights integration is documented and tracked but deferred and blocked on approved access (`EBAY_CLIENT_ID` / `EBAY_CLIENT_SECRET`). Apify is the primary live ingestion source now, so this story is **not** a dependency of any active story and gates no other work.

## Definition of Done

- [ ] All 3 child features (FEATURE-03-01, FEATURE-03-02, FEATURE-03-03) are complete.
- [ ] The Apify Platform access and `APIFY_TOKEN` are configured per <https://docs.blitzy.com/administration/environments>, with the credentials stored as encrypted secrets and non-sensitive values stored as plaintext before any ingestion run.
- [ ] The `ebay-sold-listings` actor is invoked per its input contract (required `searchTerms`) and its dataset results are persisted to `raw_listing`.
- [ ] The `raw_listing` write is idempotent, keyed on `(source, source_item_id)`, so a re-run updates rather than duplicates rows.
- [ ] The two-stage extraction is in place: a regex-first title parser handles structured titles and an LLM-fallback parser with a strict JSON schema handles the messy remainder.
- [ ] No request handler issues an LLM call; the LLM-fallback parser runs only inside the batch ingestion job.
- [ ] The confidence-gated matcher auto-commits high-confidence sales to `sale_observation` and routes every low-confidence match and new cluster to `review_queue`.
- [ ] The self-healing re-clustering merges duplicate listing-derived digital variations on a recurring basis.
- [ ] The `ingest.yml` workflow runs on cron `0 8 * * *` plus `workflow_dispatch` (`STORY-03-03-01`), records an `ingestion_run` heartbeat, and enforces the call budget cap (halt at 4,500 of the ≤5,000 daily Browse calls tracked in `ingestion_run.calls_used`).
- [ ] The daily run's final stage (`STORY-03-03-01`) recomputes the `valuation` price cache from `sale_observation`, writing one `valuation` row per `(variation_id, grade_id, window_days)` for `window_days` ∈ { `90`, `365` }; the EPIC-04 price-history endpoint (`STORY-04-02-04`) reads this precomputed cache and performs no recompute in the request path.
- [ ] The eBay Browse/Marketplace-Insights API integration is documented as deferred and blocked on approved access (`STORY-03-03-03`) and is not a dependency of any active story.
- [ ] The main application calls official data sources only; the Apify actor is the single sanctioned out-of-band scraping exception.
- [ ] **Testing:** the Apify helper and parsing tests pass against the HTML and JSON fixtures and meet the **≥90%** Apify-helper coverage target tracked in EPIC-06 (`STORY-06-02-03`).
