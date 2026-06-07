# STORY-06-02-02: Author Integration Tests — API Routes

*Parent feature: [FEATURE-06-02 — Unit & Integration Suites](../FEATURE-06-02-unit-and-integration-suites.md) · Parent epic: [EPIC-06 — Testing & CI/CD Quality Gates](../../EPIC-06-testing-and-cicd-quality-gates.md)*

## User Story

As a **Backend Test Engineer**, I want API route integration tests that run against the shared `dev-qa` Neon branch with migrations applied, so that endpoint regressions are caught against a real schema and the ≥75% coverage bar is enforced.

These tests run on the shared `dev-qa` Neon branch wired by `STORY-06-01-03`: a long-lived copy-on-write clone of the `production` branch (provisioned once in EPIC-02, not created per run), migrated through the unpooled `DATABASE_URL_UNPOOLED` before the suite executes, and exposed to the suite as the pooled test `DATABASE_URL`; the branch is not torn down on completion. The branch runs PostgreSQL 15+ because the `valuation` table's `UNIQUE NULLS NOT DISTINCT (variation_id, grade_id, window_days, cost_basis)` constraint requires it; a server below 15 rejects that constraint at migration time. The suite seeds and asserts against the `docs/schema.sql` entities the `EPIC-04` routes read and write — `character`/`card_character`/`card` for search, `variation` joined to `parallel_type` for the two-column digital|physical results, `sale_observation` for the sales table, `valuation` for the 90-day and 365-day price history and the `trend_dir` signal, and `review_queue` for the operator queue. Every data-reading endpoint threads the `userId` from the `getUserId()` seam (the seeded operator user; `owner_user_id` is NULL in v1). This is a planning ticket; the test files themselves are authored when this story is executed.

> Because previews and CI now share the single `dev-qa` branch, per-run database isolation is lost — concurrent CI runs and open PRs share `dev-qa` state. This is the inherent consequence of the two-environment model.

## Acceptance Criteria

1. **(input-validation)** *Given* a request with a missing or malformed required query parameter, *When* the endpoint is called, *Then* it returns HTTP **400** and issues **0** database queries against the shared `dev-qa` Neon branch.

2. **(valid-output)** *Given* a seeded character whose card carries both a digital `variation` and a physical `variation`, *When* the two-column results endpoint is called, *Then* it returns HTTP **200** with results partitioned into exactly **2** columns — digital and physical — each sourced from `variation` joined to `parallel_type` on `parallel_type_id`.

3. **(error-handling — unknown input)** *Given* a character name that matches **0** rows in `character`, *When* the search endpoint is called, *Then* it returns either HTTP **200** with **0** result items or HTTP **404**, and emits **0** responses in the **5xx** range.

4. **(error-handling — failure path)** *Given* a simulated database error on the shared `dev-qa` Neon branch, *When* the endpoint handles the request, *Then* it returns an HTTP **5xx** status and the response body contains **0** stack traces, **0** connection strings, and **0** internal identifiers.

5. **(edge-case — pagination boundary)** *Given* a result set spanning more than **1** page at the configured page size, *When* the first page and the last page are requested at the page-size boundary, *Then* each response returns the exact expected row slice and the last page returns the remainder with **0** duplicate rows across pages.

6. **(multi-tenancy)** *Given* a request handled by any data-reading endpoint, *When* the handler resolves the caller, *Then* it threads the `userId` returned by the `getUserId()` seam (the seeded operator user, `owner_user_id` NULL in v1) into the query path on **100%** of data calls.

7. **(valid-output — price-history)** *Given* seeded `valuation` rows for `window_days` **90** and `window_days` **365** on one `variation`, *When* the price-history endpoint is called, *Then* it returns the 90-day series and the 365-day series, and the `trend_dir` value it returns is one of **-1**, **0**, or **+1** read from the `valuation` cache.

8. **(coverage gate)** *Given* the integration suite runs under `vitest run` with coverage instrumentation against the migrated shared `dev-qa` Neon branch, *When* line coverage for the exercised API routes falls below the **≥75%** bar, *Then* the test command exits with a non-zero status and the build fails.

## Sub-tasks

- Seed deterministic catalog and sales fixtures (`character`, `card`, `card_character`, `parallel_type`, `variation`, `sale_observation`, `valuation`, `review_queue`) into the shared `dev-qa` Neon branch before the suite runs. `@backend-test-engineer`
- Author search and two-column-results integration tests asserting the exactly-2-column digital|physical partition sourced from `variation` joined to `parallel_type`. `@backend-test-engineer`
- Author card/variation detail and price-history tests asserting the `window_days` 90 and `window_days` 365 `valuation` windows and the `trend_dir` value (-1, 0, or +1) returned from the cache. `@backend-test-engineer`
- Author error-path tests asserting HTTP 400 on a missing or malformed required query parameter and HTTP 5xx with 0 leaked internals on a simulated database error. `@backend-test-engineer`
- Assert `getUserId()` threading on every data call and configure the ≥75% coverage gate as merge-blocking. `@qa-engineer`

## Edge Cases

- **Empty/Null:** a character query matching 0 rows in `character` returns an empty result set (HTTP 200 with 0 items) or HTTP 404, emitting 0 responses in the 5xx range.
- **Boundary:** pagination first-page and last-page slices at the page-size boundary, where the last page returns the remainder with 0 duplicate rows across pages.
- **Invalid:** a missing or malformed required query parameter returns HTTP 400 and issues 0 database queries.
- **Concurrent:** 2 or more simultaneous requests against the shared `dev-qa` Neon branch return consistent results with 0 cross-request data bleed.

## Dependencies

- `STORY-06-01-03` (shared `dev-qa` Neon branch wiring) — wires the suite to the long-lived `dev-qa` branch (a clone of `production`), applies migrations through the unpooled `DATABASE_URL_UNPOOLED`, and exposes the pooled `DATABASE_URL` to this suite; the branch is not torn down per run. It itself depends on `EPIC-02` `STORY-02-01-*` (the Neon branching topology hard prerequisite).
- `EPIC-02` — the `docs/schema.sql`-derived schema and migrations, the pooled Neon access layer, and the `getUserId()` seam (the seeded operator user) this suite threads through the query path.
- `EPIC-04` — the API route handlers under test: character search, two-column digital|physical results, card/variation detail with the sales table, the 90-day/365-day price-history endpoint, and the operator review-queue endpoints.
- Sibling suites `STORY-06-02-01` and `STORY-06-02-03` run on the same Vitest harness but carry no build-order dependency on this story; referenced by identifier only.

## Story Estimation Guidance

- **Effort: High** — the work spans deterministic seeding across 8 tables, multiple endpoint suites (search, two-column results, detail/sales, price-history, review queue), and the shared `dev-qa` Neon branch wiring, which exceeds a single-endpoint test pass.
- **Complexity: High** — the suite is schema-backed against a migrated branch on PostgreSQL 15+ (required by the `valuation` `UNIQUE NULLS NOT DISTINCT` constraint), exercises pagination boundaries, and asserts 0 cross-request data bleed under concurrent requests.
- **Uncertainty: Moderate** — the route response shapes are fixed by `EPIC-04` yet remain unbuilt, so the exact request and response contracts carry integration unknowns until those endpoints land.
- **Estimate: 8 points (Fibonacci).** The multi-endpoint span plus the branch-backed seeding and concurrency assertions place this above a 5; the fixed upstream branch wiring (`STORY-06-01-03`) holds it at an 8 rather than a 13.

## Definition of Done

- [ ] Migrations are applied to the shared `dev-qa` Neon branch before the suite runs; the branch is long-lived and not torn down on completion (the wiring owned by `STORY-06-01-03`).
- [ ] The shared `dev-qa` Neon branch reports a PostgreSQL server version of 15 or higher, so the `valuation` `UNIQUE NULLS NOT DISTINCT (variation_id, grade_id, window_days, cost_basis)` constraint is created with exit code 0.
- [ ] Tests cover character search, the exactly-2-column digital|physical results, card/variation detail with the sales table, price-history at `window_days` 90 and 365, and the review queue.
- [ ] `getUserId()` threading is asserted on data calls; HTTP 400 on invalid input and HTTP 5xx with 0 leaked internals on a simulated database error are asserted.
- [ ] At least one input-validation test, one valid-output test, one error-handling test, and one edge-case test are present; no prohibited vague quality term appears in any acceptance criterion.
- [ ] **Testing:** the integration suite runs green under `vitest run` against the shared `dev-qa` Neon branch and reports line coverage ≥75%; line coverage below 75% exits non-zero and fails the build.
