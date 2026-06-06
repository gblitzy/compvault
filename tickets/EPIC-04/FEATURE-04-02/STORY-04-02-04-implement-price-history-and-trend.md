# STORY-04-02-04: Implement Price-History & Trend

Feature → [FEATURE-04-02 — Search & Detail Endpoints](../FEATURE-04-02-search-and-detail-endpoints.md) · Epic → [EPIC-04 — Backend Application & API](../../EPIC-04-backend-application-and-api.md)

This is the **fourth and last** of the four stories in FEATURE-04-02 (Search & Detail Endpoints). It specifies the **90-day / 1-year price-history and trend endpoint**, backed by the precomputed `valuation` cache defined in `docs/schema.sql`, that powers the EPIC-05 detail-page price-history chart (PRD §4.3 FR-8), the trend indicator (PRD §4.3 FR-9), and the per-card "last updated" timestamp (PRD §4.7 FR-14). The endpoint is a read-only consumer of the cache: the `valuation` rows are recomputed from `sale_observation` (PRD §6.5) by the final stage of the EPIC-03 daily scheduled ingestion run (`STORY-03-03-01`), so this handler computes no valuation in the request path and issues no LLM call. Built on the FEATURE-04-01 scaffolding, the handler opens a short-lived Neon connection through the **pooled** `DATABASE_URL` — never the unpooled `DATABASE_URL_UNPOOLED`, which EPIC-02 reserves for DDL and migrations — threads the operator `userId` from the `getUserId()` seam (v1 = the single seeded operator), validates the `window` query parameter and returns HTTP **400** with a named `error` field on a malformed value, and reads official data sources only. Per the PRD §6.6 data partition, `valuation` is **GLOBAL** shared data: the read is scoped by `variation_id` (and optional `grade_id`), never filtered by `userId`.

The `valuation` row carries `id`, `variation_id` (→ `variation(id)`, NOT NULL), `grade_id` (SMALLINT → `grade(id)`, NULL for digital or ungraded), `window_days` (SMALLINT NOT NULL — the set is `90` and `365`), `cost_basis` (TEXT NOT NULL DEFAULT `item_plus_shipping`), `p25` / `median` / `p75`, `price_min` / `price_max` (NUMERIC(12,2)), `sample_size` (INTEGER NOT NULL — drives the confidence gate), `trend_pct` (REAL — versus the prior window), `trend_dir` (SMALLINT — `-1` down / `0` flat / `+1` up), `confidence` (REAL, range `0..1`), `currency`, and `computed_at` (TIMESTAMPTZ NOT NULL DEFAULT now()). The `UNIQUE NULLS NOT DISTINCT (variation_id, grade_id, window_days, cost_basis)` constraint — which **requires PostgreSQL 15+** — keeps each digital (`grade_id` NULL) series unique; the `idx_valuation_variation` index on `valuation (variation_id, grade_id)` backs the read; and the schema rule is absolute: a series **never mixes grades or formats** (format is implied by the variation; grade is NULL for digital).

## User Story

> As a **Backend Engineer**, I want a 90-day / 1-year price-history + trend endpoint backed by the `valuation` cache, so that the frontend can render the price-history chart and a trend indicator with a visible confidence label.

## API Contract

- **Method and path:** `GET /api/variations/{variation_id}/price-history` (the `variation_id` is the path parameter).
- **Query parameters:** `window` ∈ {`90`, `365`} (required; a value outside the set returns HTTP **400** `{ "error": "window" }`), and `grade_id` (optional; omitted or empty selects the digital / ungraded `grade_id IS NULL` series). The parameter rules and safe error envelope are governed by the shared validator in [STORY-04-01-03](../FEATURE-04-01/STORY-04-01-03-implement-query-parameter-validation.md). The EPIC-05 price-history chart ([STORY-05-03-02](../../EPIC-05/FEATURE-05-03/STORY-05-03-02-implement-price-history-chart.md)) calls this exact path.
- **Response** (HTTP **200**):

  ```json
  {
    "variation_id": 502,
    "grade_id": null,
    "window_days": 90,
    "cost_basis": "item_plus_shipping",
    "p25": 88.00,
    "median": 134.50,
    "p75": 175.00,
    "price_min": 60.00,
    "price_max": 240.00,
    "sample_size": 23,
    "trend_pct": 18.0,
    "trend_dir": 1,
    "confidence": 0.86,
    "confidence_label": "confident",
    "currency": "USD",
    "computed_at": "2026-05-30T08:00:00Z",
    "last_updated": "2026-05-30T08:00:00Z"
  }
  ```

- **Response fields:** the `valuation` columns `variation_id`, `grade_id` (`null` for the digital / ungraded series), `window_days`, `cost_basis`, `p25`, `median`, `p75`, `price_min`, `price_max`, `sample_size`, `trend_pct`, `trend_dir` (`-1`/`0`/`+1`), `confidence` (`0..1`), `currency`, and `computed_at`, plus a derived `confidence_label` ∈ {`asking_price_estimate`, `low_confidence`, `confident`} (`sample_size = 0` → `asking_price_estimate`; `1`–`4` → `low_confidence`; `≥ 5` → `confident`) and the shared `last_updated` derived field (most recent of `valuation.computed_at`, the newest `sale_observation` date, and `raw_listing.last_seen`, defined in [FEATURE-04-02](../FEATURE-04-02-search-and-detail-endpoints.md)).
- **Source of the cache:** the `valuation` rows this endpoint reads are written by the EPIC-03 daily scheduled ingestion run (EPIC-03 `STORY-03-03-01` — Create Scheduled Ingestion Workflow), whose final stage recomputes the cache from `sale_observation` for each `(variation_id, grade_id, window_days)`; this handler computes no valuation in the request path.
- **Errors:** a `window` outside {`90`, `365`} returns HTTP **400** `{ "error": "window" }` before any read; a `variation_id` + `grade_id` + `window` triple that matches no `valuation` row returns HTTP **404** with a named `error` field.

## Acceptance Criteria

1. **(input-validation — window not in the set)** **Given** a request whose `window` value is not one of `90` or `365` (for example `180`), **When** the request is processed, **Then** the response is HTTP **400** with an `error` field that names `window`, and no series is returned.
2. **(valid-output — series)** **Given** a `valuation` row exists for the variation at `window_days = 90`, **When** the endpoint is called with `window=90`, **Then** the response is HTTP **200** and returns the `p25` / `median` / `p75` series plus `price_min` / `price_max` for that window; the same contract holds for `window=365` against the `window_days = 365` row.
3. **(valid-output — trend)** **Given** the same valid request, **When** the response is returned, **Then** it includes `trend_pct` and `trend_dir` (one of `-1`, `0`, `+1`, surfaced as ▲/▼ with a percent change such as `+18% / 90d`) for the selected window, where the trend is the median sold price `90d` versus prior `90d`.
4. **(valid-output — confidence + freshness)** **Given** a valid request, **When** the response is returned, **Then** it includes `sample_size` and a confidence label derived from it (`sample_size = 0` → asking-price-estimate marker; `sample_size ≥ 1` → low-confidence; `sample_size ≥ 5` → confident) together with the `computed_at` "last updated" value (PRD §4.7 FR-14).
5. **(error-handling — no cached row)** **Given** a `variation_id` (with the requested `grade_id`) that matches no `valuation` row for the requested `window`, **When** the endpoint is called, **Then** the response is HTTP **404** with a named `error` field, and no series is returned.
6. **(edge-case — n=0 asking estimate)** **Given** a variation whose `valuation` row has `sample_size = 0`, **When** the endpoint is called, **Then** the response is HTTP **200** and the series is flagged as an **asking-price estimate** (labeled), not a confident value.
7. **(edge-case — n between 1 and 4)** **Given** a `valuation` row with `sample_size` of `1`, `2`, `3`, or `4`, **When** the endpoint is called, **Then** the response carries the **low-confidence** label (`sample_size ≥ 1` and `sample_size < 5`), and a `sample_size` of `5` crosses into the confident label.

## Sub-tasks

- [ ] Implement the GET handler that reads the `valuation` cache for the variation (and optional `grade_id`) at the requested `window_days`, opening a short-lived connection through the pooled `DATABASE_URL` (@backend-engineer)
- [ ] Validate the `window` query parameter against the set { `90`, `365` }, returning HTTP 400 with an `error` field that names `window` and returning no series for any other value (@backend-engineer)
- [ ] Map a `variation_id`/`grade_id`/`window` request that matches no `valuation` row to HTTP 404 with a named `error` field (@backend-engineer)
- [ ] Map `sample_size` to the confidence label — `sample_size = 0` → asking-price-estimate marker, `sample_size ≥ 1` → low-confidence, `sample_size ≥ 5` → confident (@backend-engineer)
- [ ] Return `p25` / `median` / `p75`, `price_min` / `price_max`, `trend_pct`, `trend_dir` (`-1`/`0`/`+1`), `sample_size`, `confidence`, and `computed_at` for the selected window (@backend-engineer)
- [ ] Key every series on `variation_id` + `grade_id` + `window_days` so a series is never mixed across grades or formats, relying on the `UNIQUE NULLS NOT DISTINCT` constraint and the `idx_valuation_variation` index (@backend-engineer)
- [ ] Thread the operator `userId` from the `getUserId()` seam, keep the `valuation` read GLOBAL (not filtered by `userId`), and read the pooled `DATABASE_URL` only — never the unpooled `DATABASE_URL_UNPOOLED` (@backend-engineer)
- [ ] Author API integration tests against the `dev-qa` Neon branch covering the invalid `window` (HTTP 400), the valid `90` and `365` series, the trend fields, the `sample_size = 0` / `1`–`4` / `≥ 5` labels, the HTTP 404 no-row path, and the NULL-`grade_id` digital series (@qa-engineer)
- [ ] Confirm the request handler computes no valuation and issues zero LLM calls, sourcing data through official APIs only (@tech-lead)

## Edge Cases

- **Empty/Null — `sample_size = 0`:** a `valuation` row whose `sample_size` is `0` → HTTP **200** with an asking-price-estimate label (no confident value), backed by the active asking prices the recompute job recorded (PRD §8.5).
- **Boundary — `sample_size` crosses the gate:** a `sample_size` of `1`, `2`, `3`, or `4` → the low-confidence label (`sample_size ≥ 1` and `sample_size < 5`); a `sample_size` of `5` → the confident label.
- **Invalid — `window` outside the set:** a `window` value outside { `90`, `365` } → HTTP **400** with an `error` field that names `window`, and no series is returned.
- **NULL-grade series — digital variation:** a digital variation whose `grade_id` is NULL → a valid distinct series, kept unique by `UNIQUE NULLS NOT DISTINCT (variation_id, grade_id, window_days, cost_basis)`, never merged with a graded (`grade_id` non-NULL) series.

## Dependencies

### Upstream (must be complete first)

- **[FEATURE-04-01 — Backend Foundation & Environment Access](../FEATURE-04-01-backend-foundation-and-environment-access.md):** the API route scaffolding, the provisioned Vercel environment access (per <https://docs.blitzy.com/administration/environments>), the `getUserId()` threading, and the query-parameter validation this endpoint reuses.
- **[EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md):** the `valuation` table on PostgreSQL 15+ (for `UNIQUE NULLS NOT DISTINCT`) reached through the pooled Neon access layer, and the `getUserId()` seam (`STORY-02-03-02`, the seeded operator user).
- **[EPIC-03 — Data Ingestion Pipeline](../../EPIC-03-data-ingestion-pipeline.md), specifically `STORY-03-03-01` (Create Scheduled Ingestion Workflow):** the daily scheduled run whose final stage recomputes the `valuation` rows from `sale_observation` for each `(variation_id, grade_id, window_days)`; this endpoint reads that precomputed cache and never computes in the request path, so it returns no series until the recompute stage has run.

### Downstream (informational — not a build prerequisite of this story)

- **[EPIC-05 — Frontend User Interface](../../EPIC-05-frontend-user-interface.md):** the price-history chart, the trend indicator, and the "last updated" timestamp (`STORY-05-03-02`) consume this endpoint.
- **[EPIC-06 — Testing & CI/CD Quality Gates](../../EPIC-06-testing-and-cicd-quality-gates.md):** `STORY-06-02-02` integration-tests these API routes against the `dev-qa` Neon branch at an API coverage floor of **≥75%**.

### Parent feature

- **[FEATURE-04-02 — Search & Detail Endpoints](../FEATURE-04-02-search-and-detail-endpoints.md)**

## Story Estimation Guidance

- **Effort: Low** — a single read handler over one cache table, with no write path and no multi-table join.
- **Complexity: Medium** — the `sample_size` confidence-gate mapping (`0` → asking estimate, `≥ 1` → low-confidence, `≥ 5` → confident) and the never-mix-grades/formats rule (keying on `variation_id` + `grade_id` + `window_days`) add care beyond a flat select.
- **Uncertainty: Low-Medium** — the data model is fixed by `docs/schema.sql`, but the request and response contract depends on the FEATURE-04-01 scaffolding, so the exact validation-error shape settles once that foundation lands.
- **Fibonacci Story Points: 3.** The light read sits above a 1–2; the confidence-gate mapping and the grade/format keying hold it below a 5. Points measure relative size, not a duration.

## Definition of Done

- [ ] A `window` value outside the set { `90`, `365` } returns HTTP 400 with an `error` field that names `window`.
- [ ] A valid request returns the `p25` / `median` / `p75` series plus `price_min` / `price_max`, `trend_pct`, and `trend_dir` (`-1`/`0`/`+1`) for the selected window (`90` or `365`).
- [ ] The response includes `sample_size`, the confidence label per the `sample_size = 0` (asking-price estimate) / `≥ 1` (low-confidence) / `≥ 5` (confident) thresholds, and the `computed_at` "last updated" value (PRD §4.7 FR-14).
- [ ] A `variation_id`/`grade_id`/`window` request that matches no `valuation` row returns HTTP 404 with a named `error` field.
- [ ] A digital (NULL `grade_id`) series is returned distinct and is never mixed with a graded series; each series is keyed on `(variation_id, grade_id, window_days)` and held unique by `UNIQUE NULLS NOT DISTINCT` on PostgreSQL 15+.
- [ ] The endpoint reads the precomputed `valuation` cache only — it computes no valuation and issues no LLM call in the request path — through the pooled `DATABASE_URL` (never `DATABASE_URL_UNPOOLED`), threads `userId` from `getUserId()`, and keeps the read GLOBAL (not filtered by `userId`).
- [ ] No prohibited vague quality term appears in any acceptance-criteria statement; every statement names a measurable pass/fail condition (an HTTP status code, an exact column or error-field name, or an exact `sample_size` threshold).
- [ ] **Testing:** API integration tests against the `dev-qa` Neon branch pass with a ≥75% coverage target.
