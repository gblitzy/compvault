# FEATURE-04-02: Search & Detail Endpoints

*Parent epic: [EPIC-04 — Backend Application & API](../EPIC-04-backend-application-and-api.md)*

## Feature Summary

FEATURE-04-02 delivers the read-path API for CompVault: the character search and autocomplete endpoint over `character`/`card`/`card_character`, the digital | physical two-column results endpoint that returns each variation's latest sold price split by `variation.format`, the card/variation detail endpoint with its recent-sales table over `sale_observation`, and the 90-day/1-year price-history and trend endpoint backed by the `valuation` cache. The business value is the server-side half of the collector discovery loop — one endpoint surface that turns the ingested sales into the character-centric search results, the side-by-side digital and physical values, and the price-history series and trend signal the EPIC-05 frontend renders. Scope is limited to these four read endpoints over the Neon-backed catalog; this feature does not build the API scaffolding and query-parameter validation ([FEATURE-04-01 — Backend Foundation & Environment Access](FEATURE-04-01-backend-foundation-and-environment-access.md)), the operator review-queue API ([FEATURE-04-03 — Operator Review-Queue API](FEATURE-04-03-operator-review-queue-api.md)), or any UI (EPIC-05). Deal scoring and the pricing assistant are Phase 2 work and are out of scope here. This feature is delivered through **4 stories**.

## Environment Access & Configuration

The platform access these endpoints require — Blitzy encrypted secrets for the server-side database credential, and a Vercel serverless runtime with per-scope environment access that reads the pooled `DATABASE_URL` — is provisioned once in [FEATURE-04-01 — Backend Foundation & Environment Access](FEATURE-04-01-backend-foundation-and-environment-access.md) and documented per the canonical Blitzy environments reference <https://docs.blitzy.com/administration/environments>; the full step-by-step environment configuration is not repeated here.

Each handler opens a short-lived Neon connection through the **pooled** `DATABASE_URL` and never the unpooled `DATABASE_URL_UNPOOLED` (which EPIC-02 reserves for DDL and migrations), threads the operator `userId` from the `getUserId()` seam, reads official data sources only, and issues no LLM call in the request path (LLM-assisted extraction stays in the EPIC-03 batch jobs). These endpoints therefore depend on the EPIC-02 access layer — the pooled Neon client and the `getUserId()` seam (`STORY-02-03-02`) — and on the EPIC-03 ingested sales: the `sale_observation` rows and the computed `valuation` cache the detail and price-history endpoints read. The `valuation` cache is written by the EPIC-03 daily scheduled ingestion run (EPIC-03 `STORY-03-03-01` — Create Scheduled Ingestion Workflow), whose final stage recomputes the `valuation` rows from `sale_observation` for each `(variation_id, grade_id, window_days)`; no endpoint in this feature recomputes valuations in the request path.

## Shared Response Contract

These four endpoints share two cross-cutting contract elements, defined once here and referenced by each story so the EPIC-05 consumers bind to one set of names:

- **`format` filter values:** `format` ∈ {`both`, `digital`, `physical`}; an omitted `format` means `both`. The EPIC-05 two-column toggle maps **Both → `both`**, **Digital-only → `digital`**, **Physical-only → `physical`**. This set is enforced by the shared validator in [STORY-04-01-03 — Implement Query-Parameter Validation](FEATURE-04-01/STORY-04-01-03-implement-query-parameter-validation.md), and a value outside the set returns HTTP 400 with an `error` field named `format`.
- **Derived `last_updated` freshness field:** every per-card / per-variation payload (the two-column results rows and envelope, the card-detail response, and the price-history response) exposes a `last_updated` timestamp computed as the **most recent of** (1) `valuation.computed_at`, (2) the newest matched `sale_observation` `sale_date` for the variation, and (3) the variation's `raw_listing.last_seen`. The precedence is strictly "max of the three timestamps present"; when only one source is present that source's value is used, and when none is present `last_updated` is `null`.

All endpoints return errors through the shared safe error envelope defined in [STORY-04-01-03](FEATURE-04-01/STORY-04-01-03-implement-query-parameter-validation.md): a stable public `error` field only, with stack traces, SQL, connection strings, secrets, and internal exception messages never exposed to the client.

## User Stories Index

This feature is delivered through four stories. Each link is relative to this file inside the `EPIC-04/` directory.

1. **[STORY-04-02-01 — Implement Character Search & Autocomplete](FEATURE-04-02/STORY-04-02-01-implement-character-search-autocomplete.md)** — `GET /api/characters/search?q=&mode=` over `character`, `card`, and `card_character`, joining `card → card_character → character` on `character.name` (the `idx_cardchar_character` index backs the join) and matching `character.name` and `character.aliases` (for example, typing `Vader` returns matching character names); an empty search term returns HTTP 400 with an error field named `q`.
2. **[STORY-04-02-02 — Implement Two-Column Results Endpoint](FEATURE-04-02/STORY-04-02-02-implement-two-column-results-endpoint.md)** — `GET /api/results?character_id=|card_id=&format=` over `variation`, `parallel_type`, and the `format_t` enum, returning each variation's latest sold price via a `LATERAL` join on `sale_observation` ordered by `sale_date DESC LIMIT 1`, with rows split by `variation.format` (`digital` | `physical`) and the active filters applied across both columns at the same time; a digital-only parallel (`parallel_type.format_availability = 'digital'`, for example Gilded) carries a `no physical counterpart` marker.
3. **[STORY-04-02-03 — Implement Card Detail & Sales Table](FEATURE-04-02/STORY-04-02-03-implement-card-detail-and-sales-table.md)** — `GET /api/variations/{variation_id}` with its recent-sales table over `sale_observation` joined to `raw_listing`, returning price, sold date, grade, serial number, source link, and description snippet, excluding every row where `excluded_from_comps = TRUE` (the `idx_sale_comps` partial index backs this read), with cost basis computed as `sale_price + shipping_cost`, plus the digital↔physical `counterpart` read block (override-first then computed).
4. **[STORY-04-02-04 — Implement Price-History & Trend](FEATURE-04-02/STORY-04-02-04-implement-price-history-and-trend.md)** — `GET /api/variations/{variation_id}/price-history?window=&grade_id=` backed by the `valuation` cache, returning the `window_days` 90 and 365 series with `p25`/`median`/`p75`, `trend_pct`, and `trend_dir` (`-1` down / `0` flat / `+1` up, surfaced as ▲/▼ with a percent change such as `+18% / 90d`) keyed to one row per `(variation_id, grade_id, window_days, cost_basis)`, attaching a confidence label keyed to `sample_size`; a `window` value outside the set (`90`, `365`) returns HTTP 400.

## Dependencies

### Upstream (must be complete first)

- **EPIC-01 — Environment & Configuration Foundation:** supplies the Next.js + TypeScript scaffold, the Vercel project, and the secrets baseline these endpoints build on.
- **[FEATURE-04-01 — Backend Foundation & Environment Access](FEATURE-04-01-backend-foundation-and-environment-access.md):** supplies the provisioned environment access (per <https://docs.blitzy.com/administration/environments>), the API route scaffolding that threads `userId` from the `getUserId()` seam, and the query-parameter validation these endpoints reuse.
- **EPIC-02 — Database Platform & Schema:** supplies the pooled Neon access layer, the `getUserId()` seam (`STORY-02-03-02`), and the catalog tables these endpoints read — `character`, `card`, `card_character`, `variation`, `parallel_type`, `sale_observation`, and the `valuation` cache.
- **EPIC-03 — Data Ingestion Pipeline:** supplies the ingested `sale_observation` rows and the computed `valuation` cache the detail and price-history endpoints read; the `valuation` rows are written by the daily scheduled ingestion run (`STORY-03-03-01`), whose final stage recomputes the cache from `sale_observation`. No endpoint returns sold data until ingestion has written it.

### Downstream (informational — not a build prerequisite of this feature)

- **EPIC-05 — Frontend User Interface:** the search, two-column results, card-detail, and price-history-chart views consume these endpoints.
- **EPIC-06 — Testing & CI/CD Quality Gates:** `STORY-06-02-02` integration-tests these API routes against the `dev-qa` Neon branch, targeting an API coverage floor of **≥75%**. Because these integration tests share the single `dev-qa` branch, concurrent runs share `dev-qa` state and per-run database isolation is not provided — see the lost-isolation note in `STORY-04-01-01` and EPIC-02.

## Definition of Done

- [ ] All 4 stories (STORY-04-02-01, STORY-04-02-02, STORY-04-02-03, STORY-04-02-04) are complete.
- [ ] The character-search endpoint returns the cards matching a character name from `character` joined through `card_character` to `card`, and supplies autocomplete suggestions drawn from `character.name` and `character.aliases`.
- [ ] An empty or missing search term returns HTTP 400 with an error field named `q`, and no catalog read is issued.
- [ ] The two-column results endpoint returns each variation's latest sold price (via the `LATERAL` join on `sale_observation` ordered by `sale_date DESC LIMIT 1`) split by `variation.format` into the digital and physical columns, and the active filters apply across both columns at the same time.
- [ ] A digital-only parallel (`parallel_type.format_availability = 'digital'`, for example Gilded) returns with a `no physical counterpart` marker rather than an empty physical row.
- [ ] The card-detail endpoint returns the recent-sales table from `sale_observation` joined to `raw_listing` — price, sold date, grade, serial number, source link, and description snippet — and excludes every row where `excluded_from_comps = TRUE`.
- [ ] The card-detail endpoint computes cost basis as `sale_price + shipping_cost`.
- [ ] The price-history endpoint returns the `window_days` 90 and 365 series from the `valuation` cache with `p25`/`median`/`p75`, `trend_pct`, and `trend_dir` (`-1`/`0`/`+1`, surfaced as ▲/▼ with a percent change such as `+18% / 90d`).
- [ ] The price-history endpoint attaches a confidence label keyed to `sample_size`: `sample_size = 0` returns an asking-price-estimate marker, `1 ≤ sample_size < 5` returns a low-confidence label, and `sample_size ≥ 5` returns a confident label.
- [ ] No price-history series mixes grades or formats; each series is scoped to one `(variation_id, grade_id, window_days)` key, with `grade_id` NULL for digital or ungraded series.
- [ ] A `window` value outside the set (`90`, `365`) returns HTTP 400 with a named error field, and any other malformed query parameter returns HTTP 400 with a named error field.
- [ ] Each endpoint exposes the shared derived `last_updated` field (defined in the Shared Response Contract) computed as the most recent of `valuation.computed_at`, the newest matched `sale_observation` `sale_date`, and `raw_listing.last_seen`; the two-column endpoint exposes it on each row and at the envelope level, and the detail and price-history endpoints expose it on the payload.
- [ ] The `format` filter accepts only {`both`, `digital`, `physical`} (omitted == `both`) across the two-column endpoint and the shared validator, and the EPIC-05 toggle maps Both/Digital-only/Physical-only onto those exact values.
- [ ] Every endpoint reads the pooled `DATABASE_URL`; no endpoint reads the unpooled `DATABASE_URL_UNPOOLED`.
- [ ] Every endpoint threads the operator `userId` from the `getUserId()` seam, issues no LLM call in the request path, and reads official data sources only.
- [ ] No prohibited vague quality term appears in any acceptance-criteria-like statement; every such statement names a measurable pass/fail condition.
- [ ] **Testing:** API integration tests for the search, two-column results, card-detail, and price-history routes pass against the `dev-qa` Neon branch and meet the **≥75%** API coverage target tracked in EPIC-06 (`STORY-06-02-02`).
