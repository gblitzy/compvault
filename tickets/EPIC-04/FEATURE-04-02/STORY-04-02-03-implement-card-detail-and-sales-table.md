# STORY-04-02-03: Implement Card Detail & Sales Table

Feature → [FEATURE-04-02 — Search & Detail Endpoints](../FEATURE-04-02-search-and-detail-endpoints.md) · Epic → [EPIC-04 — Backend Application & API](../../EPIC-04-backend-application-and-api.md)

This is the **third** of the four stories in FEATURE-04-02 (Search & Detail Endpoints). It specifies the **card/variation detail + recent-sales-table endpoint**: a **GET** handler, keyed on a `variation_id` (with the denormalized `card_id` available as a fallback key), that returns one row per qualifying `sale_observation` joined to `raw_listing` for the source link and the description snippet, so the EPIC-05 detail page can show a variation's recent comps (PRD §4.3 FR-10). Built on the FEATURE-04-01 scaffolding, the handler opens a short-lived Neon connection through the **pooled** `DATABASE_URL` — never the unpooled `DATABASE_URL_UNPOOLED`, which EPIC-02 reserves for DDL and migrations — threads the operator `userId` from the `getUserId()` seam (v1 = the single seeded operator), validates the id path/query parameter and returns HTTP **400** with a named `error` field on a malformed (non-numeric / wrong-shape) value, and reads official data sources only with zero LLM calls in the request path. Per the PRD §6.6 data partition, `sale_observation` is **GLOBAL** shared data: the read is scoped by `variation_id`, never filtered by `userId`.

Each returned row carries the `sale_observation` fields the table renders: `sale_price` (NUMERIC(12,2), NOT NULL — the price), `sale_date` (DATE, NOT NULL — the date sold, the sort key), `serial_number` (INTEGER — the per-copy serial #, with `serial_run` available as the per-copy run), the grade via a join to `grade.label` (for example `PSA 10` or `Raw`; `grade_id` is a SMALLINT that is NULL for digital or ungraded sales), the source link `raw_listing.listing_url`, and the description snippet `raw_listing.description`. The cost basis is computed per row as `sale_price + shipping_cost` (item + shipping; `shipping_cost` is NUMERIC(12,2) and nullable, so a NULL is surfaced as an estimated basis, never a silent $0 — PRD §6). Rows flagged `excluded_from_comps = TRUE` (lots, bundles, raw-vs-graded mislabels — PRD §6.5) are **omitted** from the table; the canonical comps-only filter is the partial index `idx_sale_comps ON sale_observation (variation_id, sale_date) WHERE NOT excluded_from_comps`, which also backs the `sale_date DESC` ordering. The `match_status` enum (`pending` / `auto` / `reviewed` / `rejected`) and `match_confidence` (REAL) record how each sale was matched to its `variation_id`; because the read keys on a concrete `variation_id` (NULL until a sale is matched), only matched rows reach the table, while `currency` (TEXT NOT NULL DEFAULT `'USD'`) and `format` (`format_t` NOT NULL) travel with each row.

## User Story

> As a **Backend Engineer**, I want a card/variation detail + recent-sales-table endpoint, so that the frontend can show a variation's recent comps with their source links.

## Acceptance Criteria

1. **(valid-output — row fields)** **Given** a `variation_id` with one or more sales where `excluded_from_comps = FALSE`, **When** the detail endpoint is called, **Then** the response is HTTP **200** and each sales-table row returns `sale_price`, `sale_date`, the grade label (`grade.label`), `serial_number`, the source link (`raw_listing.listing_url`), and the description snippet (`raw_listing.description`), with the cost basis `sale_price + shipping_cost` available per row.
2. **(valid-output — ordering)** **Given** a `variation_id` with two or more qualifying sales, **When** the table is returned, **Then** the rows are ordered by **`sale_date DESC`** (the most recent `sale_date` first).
3. **(valid-output — comps exclusion)** **Given** a `variation_id` whose sales include rows with `excluded_from_comps = TRUE` (lots, bundles, or mislabels), **When** the table is returned, **Then** every `excluded_from_comps = TRUE` row is **omitted** and only `excluded_from_comps = FALSE` rows appear, matching the `idx_sale_comps` partial-index predicate `WHERE NOT excluded_from_comps`.
4. **(error-handling — not found)** **Given** a `variation_id` (or `card_id`) that matches no row, **When** the endpoint is called, **Then** the response is HTTP **404** with a named `error` field and no sales rows.
5. **(input-validation — malformed id)** **Given** a malformed id (non-numeric or wrong shape, for example `abc` or a negative value), **When** the request is processed, **Then** the response is HTTP **400** with an `error` field that names the id parameter, and no database read is issued.
6. **(edge-case — empty table)** **Given** a `variation_id` that exists in `variation` but has zero sales where `excluded_from_comps = FALSE`, **When** the endpoint is called, **Then** the response is HTTP **200** with an **empty sales array**, and the status is not HTTP 404.

## Sub-tasks

- [ ] Implement the GET handler that selects `sale_observation` joined to `raw_listing` (the source link `listing_url` and the `description` snippet), filters `excluded_from_comps = FALSE`, and orders by `sale_date DESC`, opening a short-lived connection through the pooled `DATABASE_URL` (@backend-engineer)
- [ ] Surface the per-row grade via the join to `grade.label` (rendered as ungraded / `Raw`-equivalent when `grade_id` is NULL) and compute the cost basis `sale_price + shipping_cost`, marking the basis estimated when `shipping_cost` is NULL (@backend-engineer)
- [ ] Validate the id path/query parameter and return HTTP 400 with an `error` field that names the id parameter on a non-numeric or wrong-shape value, issuing no database read (@backend-engineer)
- [ ] Map a `variation_id` (or `card_id`) that matches no row to HTTP 404 with a named `error` field and no sales rows (@backend-engineer)
- [ ] Thread the operator `userId` from the `getUserId()` seam and keep the `sale_observation` read GLOBAL — scoped by `variation_id`, never filtered by `userId` (@backend-engineer)
- [ ] Author API integration tests against a per-CI Neon branch covering the row fields, the `sale_date DESC` ordering, the `excluded_from_comps = TRUE` exclusion, the HTTP 404 no-row path, the HTTP 400 malformed-id path, and the empty-table HTTP 200 path (@qa-engineer)
- [ ] Confirm the request handler reads official data sources only, issues zero LLM calls, and reads the pooled `DATABASE_URL` rather than the unpooled `DATABASE_URL_UNPOOLED` (@tech-lead)

## Edge Cases

- **Empty/Null — variation with zero qualifying sales:** a `variation_id` that exists in `variation` but has no `excluded_from_comps = FALSE` sales → HTTP **200** with an empty sales array, and the status is not HTTP 404.
- **Invalid / excluded — lot or bundle row:** a sale flagged `excluded_from_comps = TRUE` carrying an `exclude_reason` (for example a lot, a bundle, or a raw-vs-graded mislabel) → omitted from the table; the row stays in `sale_observation` for audit (PRD §6.5) and is never returned as a comp.
- **Boundary — digital sale with NULL `grade_id`:** a digital sale whose `grade_id` is NULL → the row is returned with the grade shown as ungraded (`Raw`-equivalent, no `grade.label`), and the row is not dropped.
- **Not found — unknown id:** an unknown `variation_id` / `card_id` → HTTP **404** with a named `error` field and no sales rows.
- **Invalid — malformed id:** a non-numeric or wrong-shape id → HTTP **400** with an `error` field that names the id parameter, returned before any database read.

## Dependencies

### Upstream (must be complete first)

- **[FEATURE-04-01 — Backend Foundation & Environment Access](../FEATURE-04-01-backend-foundation-and-environment-access.md):** the API route scaffolding, the provisioned Vercel environment access (per <https://docs.blitzy.com/administration/environments>), the `getUserId()` threading, and the path/query-parameter validation this endpoint reuses.
- **[EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md):** the `sale_observation`, `raw_listing`, and `grade` tables and the `idx_sale_comps` partial index reached through the pooled Neon access layer, plus the `getUserId()` seam (`STORY-02-03-02`, the seeded operator user).
- **[EPIC-03 — Data Ingestion Pipeline](../../EPIC-03-data-ingestion-pipeline.md):** the matched `sale_observation` rows joined to `raw_listing` that populate the table; this endpoint returns no rows for a variation until ingestion and matching have written them.

### Downstream (informational — not a build prerequisite of this story)

- **[EPIC-05 — Frontend User Interface](../../EPIC-05-frontend-user-interface.md):** the card-detail page and its recent-sales table (`STORY-05-03-01`) consume this endpoint.
- **[EPIC-06 — Testing & CI/CD Quality Gates](../../EPIC-06-testing-and-cicd-quality-gates.md):** `STORY-06-02-02` integration-tests these API routes against a per-CI Neon branch at an API coverage floor of **≥75%**.

### Parent feature

- **[FEATURE-04-02 — Search & Detail Endpoints](../FEATURE-04-02-search-and-detail-endpoints.md)**

## Story Estimation Guidance

- **Effort: Low** — a single read handler over two joined tables (`sale_observation` ⋈ `raw_listing`, plus the `grade.label` lookup), with no write path.
- **Complexity: Medium** — the `excluded_from_comps = FALSE` filter and the `sale_date DESC` ordering are direct given `idx_sale_comps`, while the NULL-`grade_id` (ungraded / digital) handling and the `sale_price + shipping_cost` cost-basis branch (NULL `shipping_cost` → estimated) add light branching.
- **Uncertainty: Low** — the data model is fixed by `docs/schema.sql` and the row-field contract is fixed by PRD §4.3 FR-10; the response shape settles once the FEATURE-04-01 scaffolding lands.
- **Fibonacci Story Points: 3.** The two-table read sits above a 1–2; the comps-exclusion filter, the NULL-grade handling, and the cost-basis branch hold it below a 5. Points measure relative size, not a duration.

## Definition of Done

- [ ] Each sales-table row returns `sale_price`, `sale_date`, the grade label (`grade.label`), `serial_number`, the source link (`raw_listing.listing_url`), and the description snippet (`raw_listing.description`).
- [ ] The cost basis `sale_price + shipping_cost` is available per row, and a NULL `shipping_cost` is surfaced as an estimated basis rather than a silent $0.
- [ ] Every row where `excluded_from_comps = TRUE` is omitted; only `excluded_from_comps = FALSE` rows appear, matching the `idx_sale_comps` predicate `WHERE NOT excluded_from_comps`.
- [ ] The rows are ordered by `sale_date DESC`.
- [ ] An unknown `variation_id` / `card_id` returns HTTP 404 with a named `error` field, and a malformed (non-numeric / wrong-shape) id returns HTTP 400 with an `error` field that names the id parameter.
- [ ] A digital sale with a NULL `grade_id` is returned with the grade shown as ungraded (`Raw`-equivalent), and the row is not dropped.
- [ ] A `variation_id` that exists but has zero `excluded_from_comps = FALSE` sales returns HTTP 200 with an empty sales array.
- [ ] The handler reads the pooled `DATABASE_URL` (never `DATABASE_URL_UNPOOLED`), threads `userId` from `getUserId()`, keeps the `sale_observation` read GLOBAL (scoped by `variation_id`, not filtered by `userId`), and issues no LLM call in the request path.
- [ ] No prohibited vague quality term appears in any acceptance-criteria statement; every statement names a measurable pass/fail condition (an HTTP status code, an exact column or error-field name, the `sale_date DESC` ordering, or the `excluded_from_comps = TRUE` predicate).
- [ ] **Testing:** API integration tests against a per-CI Neon branch pass with a ≥75% coverage target.
