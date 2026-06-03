# STORY-03-01-03: Implement Idempotent Raw-Listing Upsert

*Parent feature: [FEATURE-03-01 — Apify Actor Integration](../FEATURE-03-01-apify-actor-integration.md) · Parent epic: [EPIC-03 — Data Ingestion Pipeline](../../EPIC-03-data-ingestion-pipeline.md)*

This is the **third** of the three stories in FEATURE-03-01 (Apify Actor Integration). It takes the `raw_listing` write path established in `STORY-03-01-02` — which persists each dataset record the `ebay-sold-listings` actor produces, mapping `itemId`→`source_item_id`, `title`→`title`, `priceMin`→`asking_price`, `currency`→`currency`, `url`→`listing_url`, and `imageUrl`→`primary_image_url` — and converts it into an **idempotent on-conflict upsert** keyed on the `raw_listing` constraint **`UNIQUE (source, source_item_id)`**. The measurable end-state is that re-running the same dataset twice leaves **exactly one** `raw_listing` row per `(source, source_item_id)`, with `last_seen` advanced to the later run time and `first_seen` preserved from the first insert.

On conflict the upsert overwrites the mutable columns from the incoming record (`title`, `asking_price`, `shipping_cost`, `currency`, `listing_url`, `primary_image_url`, `additional_image_urls`, `item_aspects`, `seller`, `marketplace`, `description`, `end_date`) and sets `last_seen = now()`, while `first_seen` (TIMESTAMPTZ NOT NULL DEFAULT `now()`) is written only on the initial insert and never overwritten thereafter. The state columns are mapped to their enum domains on every upsert: `status` to `listing_status` (`active` / `ended_unsold` / `sold` / `unknown`, default `active`) and `image_status` to `image_status_t` (`live` / `gone` / `unknown`, default `unknown`). A record whose `source_item_id` is null or empty cannot form the conflict key, so it is rejected and logged rather than written — restating, at the upsert level, the guard the actor already applies (`if (!itemId) return;`). The write uses the pooled `DATABASE_URL`, never the unpooled `DATABASE_URL_UNPOOLED` that EPIC-02 reserves for DDL and migrations.

**Compliance posture:** the main application reads official data sources only; the `ebay-sold-listings` Apify actor is the single sanctioned out-of-band scraping exception, and no request handler issues an LLM call. "Daily re-runs" below describes idempotency behavior over repeated runs; the recurring schedule itself lives in FEATURE-03-03 and is not part of this story.

## User Story

> **As a** Data/Ingestion Engineer, **I want** the raw-listing persistence to be an idempotent upsert keyed on `(source, source_item_id)`, **so that** daily re-runs over overlapping search results never create duplicate rows.

## Acceptance Criteria

1. **(valid-output — insert)** **Given** a `(source, source_item_id)` pair that matches 0 rows in `raw_listing`, **When** the upsert runs for that record, **Then** exactly 1 new row is inserted, and that row's `first_seen` and `last_seen` are both set to the current run time (`now()`).

2. **(idempotency — re-run)** **Given** the same dataset is persisted twice in succession, **When** the second upsert runs, **Then** the table holds exactly 1 `raw_listing` row per `(source, source_item_id)`, that row's `last_seen` equals the second (later) run time, and its `first_seen` retains the value written by the first run, unchanged.

3. **(valid-output — mutable update on conflict)** **Given** an existing row whose incoming record now carries a changed `title` or `asking_price`, **When** the upsert runs and hits the `UNIQUE (source, source_item_id)` conflict, **Then** the mutable columns (`title`, `asking_price`, `shipping_cost`, `currency`, `listing_url`, `primary_image_url`, `additional_image_urls`, `item_aspects`, `seller`, `marketplace`, `description`, `end_date`) are overwritten from the incoming record, `last_seen` is set to `now()`, and the row count for that key stays at exactly 1 (0 duplicate rows created).

4. **(valid-output — state transition)** **Given** a listing previously stored with `status = 'active'` that the incoming record now reports as ended or sold, **When** the upsert runs, **Then** the existing row's `status` is updated to `ended_unsold` or `sold` (a value within the `listing_status` domain `active`/`ended_unsold`/`sold`/`unknown`), `last_seen` advances to `now()`, and 0 new rows are inserted.

5. **(input-validation — null/empty key)** **Given** an incoming record whose `source_item_id` is null or an empty string, **When** the upsert is attempted, **Then** 0 rows are written for that record because the `(source, source_item_id)` conflict key cannot be formed, and 1 rejection entry is logged that identifies the skipped record.

6. **(edge-case — image change)** **Given** an existing row whose incoming `primary_image_url` differs from the stored value, **When** the upsert runs, **Then** `primary_image_url` is overwritten with the incoming URL and `image_status` is re-evaluated to a single value within the `image_status_t` domain (`live`/`gone`/`unknown`), with the row count for that key remaining at exactly 1.

7. **(error-handling — retry-safe)** **Given** a transient database write error interrupts an upsert batch midway, **When** the same batch of records is retried, **Then** re-applying the records yields exactly 1 `raw_listing` row per `(source, source_item_id)` with 0 duplicates, because each record's write is an idempotent on-conflict upsert.

## Sub-tasks

- Implement the on-conflict upsert targeting the `UNIQUE (source, source_item_id)` constraint, so a new key inserts 1 row and a duplicate key updates the existing row in place. `@ingestion-engineer`
- On conflict, update the mutable columns (`title`, `asking_price`, `shipping_cost`, `currency`, `listing_url`, `primary_image_url`, `additional_image_urls`, `item_aspects`, `seller`, `marketplace`, `description`, `end_date`) from the incoming record and set `last_seen = now()`. `@ingestion-engineer`
- Preserve `first_seen` on conflict — set it only on the initial insert (default `now()`) and never overwrite it during an update. `@ingestion-engineer`
- Map and re-evaluate `status` (`listing_status`: `active`/`ended_unsold`/`sold`/`unknown`) and `image_status` (`image_status_t`: `live`/`gone`/`unknown`) on every upsert. `@ingestion-engineer`
- Guard against a null or empty `source_item_id` before issuing the upsert, skip the record, and log each rejected record. `@ingestion-engineer`
- Make the batch retry-safe so a partial-failure retry re-applies the same records without creating duplicate rows, routing the write through the pooled `DATABASE_URL` and never the unpooled `DATABASE_URL_UNPOOLED`. `@ingestion-engineer`
- Author a persistence/idempotency test that persists one dataset twice and asserts exactly 1 row per `(source, source_item_id)` with `last_seen` advanced and `first_seen` unchanged, plus a state-change fixture asserting an in-place `status` update with 0 new rows. `@qa-engineer`

## Edge Cases

- **Concurrent / idempotency:** the same `source_item_id` is persisted again on a re-run over overlapping search results → exactly 1 row remains for that key, `last_seen` advances to the later run time, and `first_seen` is unchanged.
- **State transition:** a previously-seen listing now reports ended or sold → the existing row's `status` moves to `ended_unsold` or `sold` within the `listing_status` domain, with 0 new rows inserted.
- **Empty/Null:** a null or empty `source_item_id` → the record is rejected and not written because the conflict key cannot be formed, and the rejection is logged.
- **Invalid / changed image:** the incoming `primary_image_url` differs from the stored value → `primary_image_url` is overwritten and `image_status` is re-evaluated against the `image_status_t` domain (`live`/`gone`/`unknown`).
- **Boundary — partial-failure retry:** a transient write error interrupts a batch → retrying the same records re-applies them as upserts, leaving exactly 1 row per key with 0 duplicates.

## Dependencies

### Upstream (must be complete first)

- **`STORY-03-01-02` — Invoke Actor & Persist Raw Listings:** the actor-invocation and `raw_listing` write path that this story converts into an idempotent on-conflict upsert; it supplies the record-to-column mapping (`itemId`→`source_item_id`, `title`→`title`, `priceMin`→`asking_price`, `currency`→`currency`, `url`→`listing_url`, `imageUrl`→`primary_image_url`).
- **[EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md) (`STORY-02-01-*`):** the Neon branching topology — a hard prerequisite for every raw-listing data write — and the schema feature that creates the `raw_listing` table with its `UNIQUE (source, source_item_id)` constraint, the `first_seen`/`last_seen` columns, and the `listing_status`/`image_status_t` enum domains this upsert targets.

### Downstream (informational — not a build prerequisite of this story)

- **[FEATURE-03-03 — Scheduled Ingestion Orchestration](../FEATURE-03-03-scheduled-ingestion-orchestration.md):** invokes this idempotent write on a recurring run, so overlapping result sets across runs collapse to 1 row per `(source, source_item_id)`.
- **[EPIC-06 — Testing & CI/CD Quality Gates](../../EPIC-06-testing-and-cicd-quality-gates.md) (`STORY-06-02-03`):** validates the Apify helper functions that build the records this upsert persists, against HTML fixtures.
- **[FEATURE-03-02 — Extraction & Matching](../FEATURE-03-02-extraction-and-matching.md):** parses the de-duplicated `raw_listing` rows this story guarantees, reading 1 canonical row per `(source, source_item_id)`.

### Parent feature

- **[FEATURE-03-01 — Apify Actor Integration](../FEATURE-03-01-apify-actor-integration.md)**

## Story Estimation Guidance

- **Effort: Medium** — a single on-conflict upsert path layered onto the existing `STORY-03-01-02` write, covering the mutable-column update set, the `first_seen`/`last_seen` split, and the enum re-evaluation.
- **Complexity: Medium** — the on-conflict semantics, the mutable-versus-immutable column handling (preserve `first_seen`, refresh `last_seen`), the `status`/`image_status` enum mapping, and the retry-safety guarantee.
- **Uncertainty: Low–Medium** — the `UNIQUE (source, source_item_id)` constraint, the column set, and both enum domains are fixed by `docs/schema.sql`; the residual unknown is the per-record `status`/`image_status` derivation rule.
- **Fibonacci Story Points: 3.** The fixed schema holds the upsert below a 5, while the enum re-evaluation and the retry-safety requirement raise it above a 1–2. Points measure relative size, not a duration.

## Definition of Done

- [ ] The upsert targets the `UNIQUE (source, source_item_id)` constraint; a new key inserts exactly 1 row, and a duplicate key updates the existing row in place (0 duplicate rows).
- [ ] On conflict, the mutable columns (`title`, `asking_price`, `shipping_cost`, `currency`, `listing_url`, `primary_image_url`, `additional_image_urls`, `item_aspects`, `seller`, `marketplace`, `description`, `end_date`) are updated from the incoming record and `last_seen = now()`; `first_seen` is preserved from the original row.
- [ ] `status` (`active`/`ended_unsold`/`sold`/`unknown`) and `image_status` (`live`/`gone`/`unknown`) are mapped and re-evaluated on each upsert against their enum domains.
- [ ] Records with a null or empty `source_item_id` are rejected and logged, and 0 such records are written.
- [ ] The batch is retry-safe — re-applying the same records after a partial-failure retry yields 0 duplicate rows — and the write uses the pooled `DATABASE_URL`, never the unpooled `DATABASE_URL_UNPOOLED`.
- [ ] The main application reads official data sources only, the Apify actor remains the single sanctioned out-of-band scraping exception, and 0 LLM calls are issued in any request handler; no prohibited vague quality term appears in any acceptance criterion, and every criterion names a measurable pass/fail condition (for example, "exactly 1 row").
- [ ] **Testing:** a persistence/idempotency test re-runs one dataset twice and asserts exactly 1 `raw_listing` row per `(source, source_item_id)` with `last_seen` advanced and `first_seen` unchanged; a state-change fixture verifies an in-place `status` update with 0 new rows.
