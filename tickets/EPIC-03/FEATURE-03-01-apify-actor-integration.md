# FEATURE-03-01: Apify Actor Integration

*Parent epic: [EPIC-03 — Data Ingestion Pipeline](../EPIC-03-data-ingestion-pipeline.md)*

## Feature Summary

This feature configures Apify Platform access (the `APIFY_TOKEN` secret) and wires the existing `ebay-sold-listings` Apify actor as CompVault's primary live ingestion source: it invokes the actor per its input contract and persists each dataset record the actor produces into the `raw_listing` table through an idempotent upsert. The business value is a working ingestion path from day one — CompVault accumulates sold-eBay-listing data through the sanctioned Apify actor while the eBay API stays deferred — and the idempotent write guarantees that re-running the same dataset leaves exactly one `raw_listing` row per `source_item_id` rather than inserting duplicate rows. Scope is limited to the environment access, the actor invocation, and the idempotent raw-listing persistence: parsing and confidence-matching the persisted rows lives in [FEATURE-03-02 — Extraction & Matching](FEATURE-03-02-extraction-and-matching.md), and the recurring orchestration that invokes this integration lives in [FEATURE-03-03 — Scheduled Ingestion Orchestration](FEATURE-03-03-scheduled-ingestion-orchestration.md). This feature is delivered through **3 stories**.

## Environment Access & Configuration

This is EPIC-03's mandatory per-epic environment-access feature. All environment provisioning for this feature follows the canonical Blitzy environments reference: <https://docs.blitzy.com/administration/environments>. Per that reference (informational — Blitzy cannot create environments), the single Blitzy environment is configured manually: build and run instructions are supplied in natural language, non-sensitive values are stored as plaintext environment variables and credentials are stored as encrypted secrets, and the environment is attached to the project. This step-by-step configuration is completed in full **before** the actor is invoked.

The `ebay-sold-listings` actor runs on the Apify Platform and requires the **`APIFY_TOKEN`** secret to invoke it: a local run exports the token (`export APIFY_TOKEN=...`) and a CI or runtime invocation reads it from encrypted secrets. The actor runs on **Node `>=18`** — the floor declared by the `ebay-sold-listings` actor (`engines.node` `>=18` in `apify/package.json`), which the Apify container image pins at Node 20 (`apify/actor-node:20`). The actor uses the Apify `RESIDENTIAL` proxy group by default because eBay blocks datacenter and unproxied traffic.

The actor input contract is fixed by `apify/.actor/input_schema.json`: **`searchTerms` is required** and must be a non-empty array of keyword strings — an empty array or a non-array value is rejected before any request is issued (the actor raises `Input "searchTerms" must be a non-empty array of keyword strings.`). The remaining inputs carry defaults: `ebayDomain` defaults to `www.ebay.com` (one of 8 regional domains), `itemsPerPage` defaults to `240` (one of `60`/`120`/`240`), `maxPagesPerSearch` defaults to `3` (minimum `1`, maximum `100`), `maxItems` defaults to `0` (no cap), and `proxyConfiguration` defaults to the Apify `RESIDENTIAL` proxy group.

**Compliance posture:** the main application calls official data sources only; the `ebay-sold-listings` Apify actor is the single sanctioned out-of-band scraping exception, and no request handler issues an LLM call. Apify is the primary live ingestion source now — the eBay Browse/Marketplace-Insights API integration is deferred and tracked separately in FEATURE-03-03 (`STORY-03-03-03`).

Because every persisted record writes to the database, this feature depends on EPIC-02's Neon branching (`STORY-02-01-*`) — the two long-lived branches `production` and `dev-qa` — and the `raw_listing` schema being provisioned first; the write uses the pooled `DATABASE_URL`, never the unpooled `DATABASE_URL_UNPOOLED` reserved for DDL and migrations. (The recurring schedule, its call-budget cap, the GitHub Actions workflow that drives it, and the deferred eBay Developer API are introduced in FEATURE-03-03, not here.)

### Platforms and access required

| Platform | Access required | Purpose in FEATURE-03-01 |
|----------|-----------------|--------------------------|
| Blitzy | The single Blitzy environment; plaintext variables and encrypted secrets | Store the `APIFY_TOKEN` and the pooled `DATABASE_URL` as encrypted secrets, with non-sensitive values stored as plaintext, per <https://docs.blitzy.com/administration/environments> |
| Apify Platform | Account access; `APIFY_TOKEN`; execution rights for the `ebay-sold-listings` actor | Invoke the actor as the primary live ingestion source and read its default dataset for persistence into `raw_listing` |

### Step-by-step configuration (complete before the actor is invoked)

1. Configure the single Blitzy environment and store the `APIFY_TOKEN` and the pooled `DATABASE_URL` as encrypted secrets, with non-sensitive values stored as plaintext, per <https://docs.blitzy.com/administration/environments>.
2. Grant the ingestion job Apify Platform access and confirm the `APIFY_TOKEN` invokes the `ebay-sold-listings` actor and reads its default dataset.
3. Confirm the actor runtime is Node `>=18` — the floor set by the `ebay-sold-listings` actor in `apify/package.json` (the Apify container image pins Node 20) — and that the `RESIDENTIAL` proxy group is selected.
4. Confirm EPIC-02's Neon branching (`STORY-02-01-*`) and the `raw_listing` schema are provisioned and that the pooled `DATABASE_URL` reaches `raw_listing` before the first write.
5. Validate the wiring with one bounded invocation — a non-empty `searchTerms` array and a `maxItems` cap greater than `0` — that writes to `raw_listing` on the relevant Neon branch (`dev-qa` for non-production runs, `production` for production), confirming the environment is provisioned before any unbounded run.

## User Stories Index

This feature is delivered through three stories. Each link is relative to this file inside the `EPIC-03/` directory.

1. **[STORY-03-01-01 — Configure Apify Access & Token](FEATURE-03-01/STORY-03-01-01-configure-apify-access-and-token.md)** — configure Apify Platform access and store the `APIFY_TOKEN` as an encrypted secret per <https://docs.blitzy.com/administration/environments>, so the `ebay-sold-listings` actor can be invoked on Node `>=18` (the actor floor declared in `apify/package.json`).
2. **[STORY-03-01-02 — Invoke Actor & Persist Raw Listings](FEATURE-03-01/STORY-03-01-02-invoke-actor-and-persist-raw-listings.md)** — invoke the `ebay-sold-listings` actor per its input contract (required `searchTerms`, plus the `ebayDomain`/`itemsPerPage`/`maxPagesPerSearch`/`maxItems`/`proxyConfiguration` defaults) and persist each dataset record into `raw_listing` with `source='ebay'` and the actor `itemId` mapped to `source_item_id`.
3. **[STORY-03-01-03 — Implement Idempotent Raw-Listing Upsert](FEATURE-03-01/STORY-03-01-03-implement-idempotent-raw-listing-upsert.md)** — implement the idempotent upsert keyed on `UNIQUE (source, source_item_id)` so re-running the same dataset updates `last_seen` and leaves exactly one `raw_listing` row per `source_item_id` instead of inserting duplicates.

## Dependencies

### Upstream (must be complete first)

- **EPIC-01 — Environment & Configuration Foundation:** supplies the single Blitzy environment and the secrets baseline that stores the `APIFY_TOKEN` and the pooled `DATABASE_URL`.
- **EPIC-02 — Database Platform & Schema:** supplies the Neon branching topology (`STORY-02-01-*`) and the `raw_listing` schema; every persisted record requires the database, and the write uses the pooled `DATABASE_URL`. The branching stories (`STORY-02-01-*`) are a hard prerequisite of every raw-listing write.

### Downstream (informational — not a build prerequisite of this feature)

- **[FEATURE-03-02 — Extraction & Matching](FEATURE-03-02-extraction-and-matching.md):** parses the `raw_listing` rows this feature persists through the two-stage extractor and confidence-matches them into the catalog.
- **[FEATURE-03-03 — Scheduled Ingestion Orchestration](FEATURE-03-03-scheduled-ingestion-orchestration.md):** invokes this integration on a recurring run with an `ingestion_run` heartbeat and a call-budget cap, and tracks the deferred eBay API integration (`STORY-03-03-03`).
- **EPIC-06 — Testing & CI/CD Quality Gates:** `STORY-06-02-03` tests the Apify helper functions (`extractItemId`, `parsePrice`, `parseSoldDate`) against HTML fixtures, targeting an Apify-helper coverage floor of **≥90%**.

## Definition of Done

- [ ] All 3 stories (STORY-03-01-01, STORY-03-01-02, STORY-03-01-03) are complete.
- [ ] The `APIFY_TOKEN` secret is configured per <https://docs.blitzy.com/administration/environments>, stored as an encrypted secret with non-sensitive values stored as plaintext, and the actor runs on Node `>=18` — the floor declared in `apify/package.json` (Apify container image Node 20).
- [ ] The platforms Blitzy (encrypted secret storage) and the Apify Platform (`APIFY_TOKEN` plus actor execution) are provisioned, and the environment configuration is completed before the actor is invoked.
- [ ] The `ebay-sold-listings` actor is invoked with a non-empty `searchTerms` array; an empty array or a non-array value is rejected before the actor is invoked.
- [ ] Each dataset record is persisted into `raw_listing` with `source='ebay'`, the actor `itemId` mapped to `source_item_id`, `title`→`title`, `priceMin`→`asking_price`, `currency`→`currency`, `url`→`listing_url`, and `imageUrl`→`primary_image_url`.
- [ ] The write is an idempotent upsert keyed on `UNIQUE (source, source_item_id)`: re-running the same dataset updates `last_seen` and leaves exactly one `raw_listing` row per `source_item_id`, inserting no duplicate rows.
- [ ] The data write targets the pooled `DATABASE_URL`; no write uses the unpooled `DATABASE_URL_UNPOOLED`, and EPIC-02's Neon branching (`STORY-02-01-*`) plus the `raw_listing` schema are confirmed reachable first.
- [ ] The main application calls official data sources only; the `ebay-sold-listings` Apify actor is the single sanctioned out-of-band scraping exception, and no request handler issues an LLM call.
- [ ] Apify is the primary live ingestion source; the eBay Browse/Marketplace-Insights API integration is deferred and tracked in FEATURE-03-03 (`STORY-03-03-03`) and is not a dependency of this feature.
- [ ] No prohibited vague quality term appears in any acceptance-criteria-like statement; every such statement names a measurable pass/fail condition.
- [ ] **Testing:** the Apify helper and raw-listing persistence tests pass against the dataset and HTML fixtures, and the upsert is verified idempotent by persisting a duplicate `source_item_id` twice and asserting exactly one `raw_listing` row remains with `last_seen` updated, meeting the **≥90%** Apify-helper coverage target tracked in EPIC-06 (`STORY-06-02-03`).
