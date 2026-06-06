# STORY-04-02-02: Implement Two-Column Results Endpoint

Feature → [FEATURE-04-02 — Search & Detail Endpoints](../FEATURE-04-02-search-and-detail-endpoints.md) · Epic → [EPIC-04 — Backend Application & API](../../EPIC-04-backend-application-and-api.md)

This is the **second** of the four stories in FEATURE-04-02 (Search & Detail Endpoints). It specifies the **digital | physical two-column results endpoint**: a **GET** handler, keyed on a card/character context (a `card_id`, or the character resolved by `STORY-04-02-01`), that returns the card's `variation` rows joined to `parallel_type`, each carrying its latest sold price, and partitions those rows into **exactly two groups keyed by `variation.format`** — `digital` and `physical` — so the EPIC-05 frontend can render the two-column comparison (PRD §4.2 FR-4). Built on the FEATURE-04-01 scaffolding, the handler opens a short-lived Neon connection through the **pooled** `DATABASE_URL` — never the unpooled `DATABASE_URL_UNPOOLED`, which EPIC-02 reserves for DDL and migrations — threads the operator `userId` from the `getUserId()` seam (v1 = the single seeded operator), validates the `format` filter value and returns HTTP **400** with a named `error` field on a value outside the allowed set, and reads official data sources only with zero LLM calls in the request path. Per the PRD §6.6 data partition, the catalog (`variation` / `parallel_type`) and `sale_observation` reads are **GLOBAL** shared data: rows are scoped by `card_id` (and the active filters), never filtered by `userId`.

The latest sold price per variation comes from the canonical **`LEFT JOIN LATERAL` … `ORDER BY sale_date DESC LIMIT 1`** pattern (schema Example Query 2): `variation v` joins `parallel_type pt` on `pt.id = v.parallel_type_id`, then a lateral subquery selects `sale_price`, `sale_date` from `sale_observation so` where `so.variation_id = v.id` ordered by `sale_date DESC` and limited to one row, and the application groups by `v.format` for the two columns. Each returned row carries the latest `sale_price` (NUMERIC(12,2)) and the latest `sale_date` (DATE) from that lateral row, the `grade` (via `grade_id`, NULL for digital) and `serial_number` (INTEGER, per-copy) when present, the **parallel badge** built from `parallel_type.name` plus `variation.print_run` (for example `Mojo /50`, with a NULL `print_run` rendered as unnumbered), and `variation.rep_image_url` (the hotlinked display image). To render the EPIC-05 row in a single fetch, the row also carries the `description_snippet`, the `asking_price` fallback (from `raw_listing.asking_price`, populated when there is no sale), the `price_label`/`confidence_label`, the `sample_size`, and the inline sparkline trend (`trend_pct`, `trend_dir`) — the trend and `sample_size` are read from the precomputed `valuation` cache at `window_days = 90` (PRD §4.2 FR-5), while the full multi-point price-history series and the 90-day/1-year toggle remain the responsibility of the price-history endpoint (`STORY-04-02-04`). The exact field list is the **API Contract** above. The combinable filters from PRD §4.1 FR-2 — the format toggle (Both / Digital-only / Physical-only), the variation filter by `parallel_type` + `print_run`, `grade`, `set`, `year`, and price range — constrain **both** columns at the same time (PRD §4.2 FR-6). A digital-only parallel — `parallel_type.format_availability = 'digital'`, for example Gilded (`family = 'gilded'`) — has no cross-format match (schema Example Query 4 returns no variation-level counterpart for it), so its row is flagged **`no physical counterpart`** and appears only in the `digital` group (PRD §3.3).

## User Story

> As a **Backend Engineer**, I want a digital|physical two-column results endpoint, so that the frontend can render a character's variations split by format with the latest sold price for each.

## API Contract

- **Method and path:** `GET /api/results`
- **Scope (exactly one required):** `character_id` (the character resolved by [STORY-04-02-01](STORY-04-02-01-implement-character-search-autocomplete.md)) or `card_id`; supplying neither, or both, returns HTTP **400** with a named `error` field before any query runs.
- **Filters (all optional, applied across both columns at the same time):** `format` ∈ {`both`, `digital`, `physical`} (default `both`; the EPIC-05 toggle maps **Both → `both`**, **Digital-only → `digital`**, **Physical-only → `physical`**), `parallel`, `print_run`, `grade`, `set`, `year`, `price_min`, `price_max`, `date_from`, `date_to`, and `limit` ∈ [`1`, `100`]. These parameters and the safe error envelope are governed by the shared validator in [STORY-04-01-03](../FEATURE-04-01/STORY-04-01-03-implement-query-parameter-validation.md). The EPIC-05 two-column results view ([STORY-05-02-02](../../EPIC-05/FEATURE-05-02/STORY-05-02-02-implement-two-column-results-view.md)) calls this exact path.
- **Response** (HTTP **200**):

  ```json
  {
    "scope": { "character_id": 12 },
    "format": "both",
    "columns": {
      "digital":  [ { "variation_id": 501, "format": "digital", "...": "row" } ],
      "physical": [ { "variation_id": 502, "format": "physical", "...": "row" } ]
    },
    "last_updated": "2026-05-30T08:00:00Z"
  }
  ```

  Both `columns.digital` and `columns.physical` are always present; an empty column is `[]` (never omitted).
- **Result row fields:** `variation_id`, `card_id`, `format` (`digital`/`physical`), `parallel_badge` (`parallel_type.name` + `variation.print_run`, for example `Mojo /50`; a NULL `print_run` renders unnumbered), `print_run`, `rep_image_url`, `grade` (`grade.label`; `null`/`Raw` for digital or ungraded), `serial_number` (when present), `latest_sale_price` (`null` when the variation has no sale), `latest_sale_date` (`null` when no sale), `description_snippet` (the latest `sale_observation`'s `raw_listing.description`, or the active listing's `description` when there is no sale), `asking_price` (from `raw_listing.asking_price`, populated when `latest_sale_price` is `null`), `price_label` ∈ {`sold`, `based_on_n_sales`, `asking_price_estimate`}, `sample_size` (from the `window_days = 90` `valuation` row), `trend_pct`, `trend_dir` (`-1`/`0`/`+1`, from the `window_days = 90` `valuation` row), `confidence_label` ∈ {`confident`, `low_confidence`, `asking_price_estimate`}, `no_physical_counterpart` (`true` for a digital-only parallel), and `last_updated`.
- **Inline trend source:** the per-row sparkline trend (`trend_pct`, `trend_dir`) and `sample_size` are read from the precomputed `valuation` cache at `window_days = 90` (joined per variation); the full multi-point price-history series and the 90-day/1-year toggle are served separately by [STORY-04-02-04](STORY-04-02-04-implement-price-history-and-trend.md).
- **Freshness (`last_updated`):** the most recent of `valuation.computed_at`, the newest `sale_observation` date, and `raw_listing.last_seen`, present on each row and aggregated at the envelope level (the shared derived field defined in [FEATURE-04-02](../FEATURE-04-02-search-and-detail-endpoints.md)).
- **Errors:** a `format` outside {`physical`, `digital`, `both`} returns HTTP **400** `{ "error": "format" }`; a `card_id`/`character_id` that matches no row returns HTTP **404** with a named `error` field.

## Acceptance Criteria

1. **(valid-output — partition)** **Given** a card whose `variation` rows span both formats, **When** the endpoint is called, **Then** the response is HTTP **200** and the rows are partitioned into **exactly two groups keyed by `variation.format`** — `digital` and `physical`.
2. **(valid-output — row fields)** **Given** a `variation` that has at least one `sale_observation`, **When** the endpoint returns its row, **Then** the row carries `latest_sale_price` and `latest_sale_date` from the `LEFT JOIN LATERAL` (`ORDER BY sale_date DESC LIMIT 1`) subquery, the `grade` and `serial_number` when present, the `parallel_badge` (`parallel_type.name` + `print_run`, for example `Mojo /50`), `rep_image_url`, a `description_snippet`, the `sample_size`, `trend_pct`, and `trend_dir` (`-1`/`0`/`+1`) from the `window_days = 90` `valuation` row, a `confidence_label`, and a `last_updated` value.
3. **(valid-output — filters across both columns)** **Given** a variation/`print_run`, `grade`, `set`, `year`, or price-range filter, **When** the filter is applied, **Then** it constrains the rows in **both** the `digital` group and the `physical` group at the same time (PRD §4.2 FR-6).
4. **(edge-case — digital-only parallel)** **Given** a `variation` whose `parallel_type.format_availability = 'digital'` (for example Gilded), **When** the endpoint returns it, **Then** the row is flagged `no physical counterpart` and appears only in the `digital` group, never in the `physical` group (PRD §3.3).
5. **(input-validation — format filter value)** **Given** a `format` filter value outside the allowed set {`physical`, `digital`, `both`}, **When** the request is processed, **Then** the response is HTTP **400** with an `error` field that names `format`, and no database query is run.
6. **(error-handling — unknown card)** **Given** a `card_id` (or resolved character context) that matches no `card`, **When** the endpoint is called, **Then** the response is HTTP **404** with a named `error` field and no result groups.
7. **(edge-case — zero sales)** **Given** a `variation` with **zero** `sale_observation` rows, **When** the endpoint returns its row, **Then** `latest_sale_price` and `latest_sale_date` are `null` (the `LEFT JOIN LATERAL` subquery yields no row), `asking_price` is populated from `raw_listing.asking_price`, `price_label` is `asking_price_estimate`, and the row is retained in its `variation.format` group rather than dropped.
8. **(edge-case — thin sample n<5)** **Given** a `variation` whose `window_days = 90` `valuation` row has a `sample_size` of `1`–`4`, **When** the row is returned, **Then** `price_label` is `based_on_n_sales` and `confidence_label` is `low_confidence`, while a `sample_size` of `5` or more returns `price_label` `sold` and `confidence_label` `confident`.

## Sub-tasks

- [ ] Implement the GET results handler that joins `variation` → `parallel_type` (on `parallel_type_id`) and performs the `LEFT JOIN LATERAL` latest-sale lookup on `sale_observation` (`ORDER BY sale_date DESC LIMIT 1`, schema Example Query 2), opening a short-lived connection through the pooled `DATABASE_URL` (@backend-engineer)
- [ ] Partition the result rows into **exactly two groups keyed by `variation.format`** — `digital` and `physical` — always returning both groups even when one is an empty array (@backend-engineer)
- [ ] Build each row's parallel badge from `parallel_type.name` + `variation.print_run` (a NULL `print_run` rendered as unnumbered) and attach `variation.rep_image_url`, the latest `sale_price` / `sale_date`, and the `grade` / `serial_number` when present (@backend-engineer)
- [ ] Apply the combinable filters — format toggle (Both / Digital-only / Physical-only), variation by `parallel_type` + `print_run`, `grade`, `set`, `year`, and price range — across both the `digital` and `physical` groups at the same time (PRD §4.2 FR-6) (@backend-engineer)
- [ ] Validate the `format` filter value against the allowed set {`physical`, `digital`, `both`} (omitted == `both`), returning HTTP 400 with an `error` field that names `format` and running no query for any other value (@backend-engineer)
- [ ] Flag a digital-only parallel (`parallel_type.format_availability = 'digital'`, for example Gilded) with `no physical counterpart` and emit it only in the `digital` group (@backend-engineer)
- [ ] Return a `null` latest-price field labeled as no recorded sale for a `variation` with zero `sale_observation` rows, and map a `card_id` that matches no `card` to HTTP 404 with a named `error` field (@backend-engineer)
- [ ] Thread the operator `userId` from the `getUserId()` seam, keep the catalog (`variation` / `parallel_type`) and `sale_observation` reads GLOBAL (scoped by `card_id`, never filtered by `userId`), and read the pooled `DATABASE_URL` only — never the unpooled `DATABASE_URL_UNPOOLED` (@backend-engineer)
- [ ] Author API integration tests against the `dev-qa` Neon branch covering the two-group partition, the latest-price LATERAL row, the zero-sale `null` path, the digital-only `no physical counterpart` flag, and the invalid-`format` HTTP 400 path (@qa-engineer)
- [ ] Confirm the request handler sources data through official APIs only and issues zero LLM calls (@tech-lead)

## Edge Cases

- **Empty/Null — variation with zero sales:** a `variation` with zero `sale_observation` rows → the latest-price field is `null` and the row is labeled `no recorded sale` (the `LEFT JOIN LATERAL` yields no row); the row is retained in its `variation.format` group, not omitted.
- **Boundary — card present in one format only:** a card whose `variation` rows are all one `format` → that format's group holds the rows and the other group is an **empty array**; the response still returns **both** groups.
- **Invalid — `format` filter outside the allowed set:** a `format` filter value outside {`physical`, `digital`, `both`} → HTTP **400** with an `error` field that names `format`, and no query is run.
- **Digital-only parallel — Gilded:** a `parallel_type.format_availability = 'digital'` parallel (for example Gilded, `family = 'gilded'`) → flagged `no physical counterpart`, emitted only in the `digital` group, with no variation-level cross-format counterpart (schema Example Query 4).

## Dependencies

### Upstream (must be complete first)

- **[FEATURE-04-01 — Backend Foundation & Environment Access](../FEATURE-04-01-backend-foundation-and-environment-access.md):** the API route scaffolding, the provisioned environment access (per <https://docs.blitzy.com/administration/environments>), the `getUserId()` threading, and the query-parameter validation this endpoint reuses.
- **[EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md):** the catalog tables `variation` and `parallel_type`, the `format_t` / `format_availability` enums, and the pooled Neon access layer plus the `getUserId()` seam (`STORY-02-03-02`, the seeded operator user) this endpoint reads through.
- **[EPIC-03 — Data Ingestion Pipeline](../../EPIC-03-data-ingestion-pipeline.md):** the ingested `sale_observation` rows that supply the latest sold price per variation; the endpoint returns a `null` latest price for any variation until ingestion has written a sale for it.

### Downstream (informational — not a build prerequisite of this story)

- **[EPIC-05 — Frontend User Interface](../../EPIC-05-frontend-user-interface.md):** the digital | physical two-column results view (`STORY-05-02-02`) consumes this endpoint.
- **[EPIC-06 — Testing & CI/CD Quality Gates](../../EPIC-06-testing-and-cicd-quality-gates.md):** `STORY-06-02-02` integration-tests these API routes against the `dev-qa` Neon branch at an API coverage floor of **≥75%**. Because these integration tests share the single `dev-qa` branch, concurrent runs share `dev-qa` state and per-run database isolation is not provided — see the lost-isolation note in `STORY-04-01-01` and EPIC-02.

### Parent feature

- **[FEATURE-04-02 — Search & Detail Endpoints](../FEATURE-04-02-search-and-detail-endpoints.md)**

## Story Estimation Guidance

- **Effort: Medium** — one read handler over a two-table join plus the lateral latest-sale lookup, the two-group partition, and the combinable cross-column filter set.
- **Complexity: Medium** — the `LEFT JOIN LATERAL` latest-sale lookup and applying the combinable filters across both columns raise complexity; the partition into exactly two `variation.format` groups is deterministic.
- **Uncertainty: Low-Medium** — the data model is fixed by `docs/schema.sql` and the lateral pattern is given by Example Query 2, while the exact filter and validation-error shape settles once the FEATURE-04-01 scaffolding lands.
- **Fibonacci Story Points: 5.** The lateral latest-sale join and the cross-column filter application sit above a 3; the deterministic two-group partition and the fixed schema hold it below an 8. Points measure relative size, not a duration.

## Definition of Done

- [ ] The response partitions rows into exactly two groups keyed by `variation.format` — `digital` and `physical` — and returns both groups even when one is an empty array.
- [ ] Each row carries `latest_sale_price` and `latest_sale_date` from the `LEFT JOIN LATERAL` (`ORDER BY sale_date DESC LIMIT 1`) subquery, the `grade` and `serial_number` when present, the `parallel_badge` (`parallel_type.name` + `print_run`) and `rep_image_url`, the `description_snippet`, the `asking_price` fallback, `price_label`, `sample_size`, `trend_pct`, `trend_dir`, `confidence_label`, and `last_updated`.
- [ ] The combinable filters (format toggle, variation by `parallel_type` + `print_run`, `grade`, `set`, `year`, price range) constrain both the `digital` and `physical` columns at the same time.
- [ ] A digital-only parallel (`parallel_type.format_availability = 'digital'`, for example Gilded) is flagged `no physical counterpart` and appears only in the `digital` group.
- [ ] A `variation` with zero `sale_observation` rows returns `null` for `latest_sale_price`/`latest_sale_date`, populates `asking_price` from `raw_listing.asking_price` with `price_label` = `asking_price_estimate`, and the row is retained in its `variation.format` group.
- [ ] A `format` filter value outside the allowed set returns HTTP 400 with an `error` field that names `format`, and a `card_id` that matches no `card` returns HTTP 404 with a named `error` field.
- [ ] The handler reads the pooled `DATABASE_URL` (never `DATABASE_URL_UNPOOLED`), threads `userId` from `getUserId()`, keeps the catalog and `sale_observation` reads GLOBAL (not filtered by `userId`), and issues no LLM call in the request path.
- [ ] No prohibited vague quality term appears in any acceptance-criteria statement; every statement names a measurable pass/fail condition (an HTTP status code, an exact column or error-field name, or "exactly two groups").
- [ ] **Testing:** API integration tests against the `dev-qa` Neon branch pass with a ≥75% coverage target.
