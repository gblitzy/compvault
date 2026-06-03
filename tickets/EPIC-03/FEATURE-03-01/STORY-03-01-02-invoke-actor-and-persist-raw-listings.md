# STORY-03-01-02: Invoke Actor & Persist Raw Listings

*Parent feature: [FEATURE-03-01 — Apify Actor Integration](../FEATURE-03-01-apify-actor-integration.md) · Parent epic: [EPIC-03 — Data Ingestion Pipeline](../../EPIC-03-data-ingestion-pipeline.md)*

This is the **second** of the three stories in FEATURE-03-01 (Apify Actor Integration). It makes the existing `ebay-sold-listings` Apify actor CompVault's **primary live ingestion source now** — the eBay Browse/Marketplace-Insights API is deferred and tracked separately in [FEATURE-03-03 — Scheduled Ingestion Orchestration](../FEATURE-03-03-scheduled-ingestion-orchestration.md) (`STORY-03-03-03`). The story establishes three things: the **actor invocation** following the input contract fixed by `apify/.actor/input_schema.json`, the **field mapping** from each default-dataset record to the `raw_listing` columns, and the **write path** into `raw_listing` with the constant `source='ebay'`. The invocation is triggered by the ingestion job; this story does not define any schedule (the recurring run lives in FEATURE-03-03).

The actor input contract is fixed: **`searchTerms` is required** and must be a non-empty array of keyword strings — an empty array or a non-array value is rejected before any eBay request is issued, because the actor raises the exact error `Input "searchTerms" must be a non-empty array of keyword strings.`. The optional inputs carry defaults — `ebayDomain=www.ebay.com` (1 of 8 regional domains), `itemsPerPage=240` (1 of `60`/`120`/`240`), `maxPagesPerSearch=3` (minimum `1`, maximum `100`), `maxItems=0` (no cap), and `proxyConfiguration` set to the Apify `RESIDENTIAL` proxy group. Each default-dataset record carries 16 fields (`searchTerm`, `itemId`, `title`, `priceRaw`, `priceMin`, `priceMax`, `currency`, `soldDateRaw`, `soldDate`, `condition`, `shipping`, `bids`, `imageUrl`, `url`, `scrapedAt`), and a record with no extractable numeric `itemId` is skipped by the actor (the leading "Shop on eBay" placeholder and malformed rows carry no `itemId`).

The required record-to-column mapping is `itemId`→`source_item_id`, `title`→`title`, `priceMin`→`asking_price`, `currency`→`currency`, `url`→`listing_url`, `imageUrl`→`primary_image_url`, with the constant `source='ebay'`; `marketplace` is derived from `ebayDomain` (`www.ebay.com`→`EBAY_US`, `www.ebay.co.uk`→`EBAY_GB`) and `shipping` is parsed into `shipping_cost` when a number is present. The write targets the pooled `DATABASE_URL`, never the unpooled `DATABASE_URL_UNPOOLED` that EPIC-02 reserves for DDL and migrations. The **idempotency** of the write — the on-conflict upsert keyed on `UNIQUE (source, source_item_id)` — is the subject of `STORY-03-01-03`; this story describes the write as an upsert and forward-references `STORY-03-01-03` for the conflict semantics.

**Compliance posture:** the main application reads official data sources only; the `ebay-sold-listings` Apify actor is the single sanctioned out-of-band scraping exception, and no request handler issues an LLM call.

## User Story

> **As a** Data/Ingestion Engineer, **I want** to invoke the `ebay-sold-listings` actor following its input contract and persist its default-dataset records into `raw_listing`, **so that** sold-listing data is captured as the primary live feed.

## Acceptance Criteria

1. **(input-validation)** **Given** an empty array or a non-array value for `searchTerms`, **When** the actor invocation is attempted, **Then** the run is rejected before any eBay request is issued (0 pages crawled) and the exact error `Input "searchTerms" must be a non-empty array of keyword strings.` is logged.

2. **(valid-output — field mapping)** **Given** the actor returns N default-dataset records that each carry a numeric `itemId`, **When** persistence runs, **Then** N `raw_listing` rows exist with `source='ebay'`, `source_item_id` equal to the record `itemId`, `title` equal to the record `title`, `asking_price` equal to the record `priceMin`, `currency` equal to the record `currency`, `listing_url` equal to the record `url`, and `primary_image_url` equal to the record `imageUrl`.

3. **(valid-output — contract defaults)** **Given** an invocation that omits the optional inputs, **When** the actor starts, **Then** it runs with `ebayDomain=www.ebay.com`, `itemsPerPage=240`, `maxPagesPerSearch=3`, `maxItems=0` (no limit), and the Apify `RESIDENTIAL` proxy group.

4. **(edge-case — zero results)** **Given** the actor returns 0 dataset records, **When** persistence runs, **Then** 0 `raw_listing` rows are written and the ingestion run exits with status success (a 0-record run is not an error).

5. **(edge-case — missing item id)** **Given** a dataset record that carries no `itemId`, **When** persistence processes it, **Then** 0 rows are written for that record and the skip counter is incremented by 1 and logged, because `source_item_id` cannot be keyed without an `itemId`.

6. **(error-handling — anti-bot retry)** **Given** a fetched page yields 0 listing cards and its body contains a captcha or interstitial signal (`captcha`, `pardon our interruption`, `checking your browser`, or `access denied`), **When** the actor handles the page, **Then** it throws and the request is retried through a fresh proxy session up to 5 times (`maxRequestRetries = 5`) before the request is logged as failed.

7. **(boundary — no client-side cap)** **Given** `maxItems=0`, **When** the actor runs, **Then** no client-side item cap is applied and pagination is bounded only by `maxPagesPerSearch` (default 3 pages per term), with pagination stopping early on any page that yields 0 items.

## Sub-tasks

- Implement the actor invocation passing the input contract with a non-empty `searchTerms` array, where the saved ingestion queries supply the terms. `@ingestion-engineer`
- Read the actor's default-dataset records after the run completes. `@ingestion-engineer`
- Map each record to `raw_listing` columns per the mapping (`itemId`→`source_item_id`, `title`→`title`, `priceMin`→`asking_price`, `currency`→`currency`, `url`→`listing_url`, `imageUrl`→`primary_image_url`) with the constant `source='ebay'`. `@ingestion-engineer`
- Skip records that carry no `itemId` and increment a logged skip count. `@ingestion-engineer`
- Derive `marketplace` from `ebayDomain` (`www.ebay.com`→`EBAY_US`, `www.ebay.co.uk`→`EBAY_GB`) and parse `shipping` into `shipping_cost` when a number is present. `@ingestion-engineer`
- Route the write through the pooled `DATABASE_URL` (never the unpooled `DATABASE_URL_UNPOOLED`) and hand the write to the idempotent upsert defined in `STORY-03-01-03`. `@ingestion-engineer`
- Author a persistence test against dataset fixtures that asserts every mapped record field lands in its `raw_listing` column, that a missing-`itemId` fixture writes 0 rows, and that a 0-record fixture writes 0 rows. `@qa-engineer`

## Edge Cases

- **Empty/Null:** an empty array or a non-array value for `searchTerms` → the run is rejected before the actor crawls (input-validation), and the exact actor error string is logged.
- **Boundary:** the actor returns 0 dataset records → 0 rows are persisted and the run exits success; with `maxItems=0` no client-side cap is applied and pagination is bounded only by `maxPagesPerSearch`.
- **Invalid:** a dataset record carries no `itemId` → the record is skipped (0 rows) and the skip count is logged, because `source_item_id` cannot be keyed.
- **Resilience:** a fetched page yields 0 cards alongside a captcha/interstitial signal → the actor throws and retries through a fresh proxy session up to 5 times before the request is logged as failed (handled inside the actor).

## Dependencies

### Upstream (must be complete first)

- **`STORY-03-01-01` — Configure Apify Access & Token:** provides the `APIFY_TOKEN` encrypted secret and Apify Platform access required to invoke the `ebay-sold-listings` actor and read its default dataset.
- **[EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md) (`STORY-02-01-*`):** the Neon branching topology — a hard prerequisite for every raw-listing data write — and the EPIC-02 schema feature that creates the `raw_listing` table with its `source`/`source_item_id` columns, the `UNIQUE (source, source_item_id)` constraint, and the `listing_status`/`image_status_t` enum domains this write targets.

### Downstream (informational — not a build prerequisite of this story)

- **`STORY-03-01-03` — Implement Idempotent Raw-Listing Upsert:** consumes this write path and converts it into an idempotent on-conflict upsert keyed on `UNIQUE (source, source_item_id)`, so re-running the same dataset leaves exactly 1 `raw_listing` row per `(source, source_item_id)`.
- **[FEATURE-03-02 — Extraction & Matching](../FEATURE-03-02-extraction-and-matching.md):** parses the `raw_listing` rows this story persists through the two-stage extractor and confidence-matches them into the catalog.
- **[FEATURE-03-03 — Scheduled Ingestion Orchestration](../FEATURE-03-03-scheduled-ingestion-orchestration.md):** invokes this integration on a recurring run with an `ingestion_run` heartbeat and a call-budget cap, and tracks the deferred eBay API integration (`STORY-03-03-03`).
- **[EPIC-06 — Testing & CI/CD Quality Gates](../../EPIC-06-testing-and-cicd-quality-gates.md) (`STORY-06-02-03`):** tests the Apify helper functions (`extractItemId`, `parsePrice`, `parseSoldDate`) that build the records this story persists, against HTML fixtures, at an Apify-helper coverage floor of **≥90%**.

### Parent feature

- **[FEATURE-03-01 — Apify Actor Integration](../FEATURE-03-01-apify-actor-integration.md)**

## Story Estimation Guidance

- **Effort: Medium** — the actor invocation following the input contract, the default-dataset read, the record-to-column field mapping, and the skip logic for records that carry no `itemId`.
- **Complexity: Medium** — the invocation plus dataset read plus field mapping plus skip handling, with the on-conflict upsert semantics deferred to `STORY-03-01-03`.
- **Uncertainty: Medium** — the dataset record shape varies across eBay result-page layouts (`li.s-item` and the rolling-out `li.s-card`), so the parser-fed fields can shift between layouts.
- **Fibonacci Story Points: 5.** The fixed input contract and the fixed `raw_listing` column set hold the story at a 5 rather than higher, while the dataset-shape variability plus the field-mapping and skip logic raise it above a 1–3. Points measure relative size, not a duration.

## Definition of Done

- [ ] The `ebay-sold-listings` actor is invoked with a non-empty `searchTerms` array; an empty array or a non-array value is rejected before the crawl with the exact error `Input "searchTerms" must be a non-empty array of keyword strings.`.
- [ ] Optional inputs default to `ebayDomain=www.ebay.com`, `itemsPerPage=240`, `maxPagesPerSearch=3`, `maxItems=0` (no limit), and the `RESIDENTIAL` Apify proxy group.
- [ ] Each dataset record that carries a numeric `itemId` is persisted to `raw_listing` with `source='ebay'` and the full mapping applied (`itemId`→`source_item_id`, `title`→`title`, `priceMin`→`asking_price`, `currency`→`currency`, `url`→`listing_url`, `imageUrl`→`primary_image_url`), with `marketplace` derived from `ebayDomain` and `shipping` parsed into `shipping_cost` when a number is present.
- [ ] Records that carry no `itemId` are skipped with a logged skip count, and a 0-record run writes 0 rows and exits success.
- [ ] The write targets the pooled `DATABASE_URL` (never the unpooled `DATABASE_URL_UNPOOLED`), and the idempotent on-conflict upsert is delegated to `STORY-03-01-03`.
- [ ] The main application reads official data sources only, the `ebay-sold-listings` Apify actor remains the single sanctioned out-of-band scraping exception, and 0 LLM calls are issued in any request handler; no prohibited vague quality term appears in any acceptance criterion, and every criterion names a measurable pass/fail condition (for example, "N rows" or "0 rows").
- [ ] **Testing:** persistence tests against dataset fixtures assert every mapped record field lands in the correct `raw_listing` column, a fixture with a missing `itemId` writes 0 rows, and a 0-record fixture writes 0 rows; the Apify helper functions (`extractItemId`, `parsePrice`, `parseSoldDate`) are exercised by EPIC-06 (`STORY-06-02-03`) at the **≥90%** Apify-helper coverage floor.
