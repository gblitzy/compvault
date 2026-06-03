# STORY-04-03-01: Implement Review-Queue Endpoints

*Parent feature: [FEATURE-04-03 — Operator Review-Queue API](../FEATURE-04-03-operator-review-queue-api.md) · Parent epic: [EPIC-04 — Backend Application & API](../../EPIC-04-backend-application-and-api.md)*

This is the **first of the two** stories in FEATURE-04-03 (Operator Review-Queue API). It specifies the **review-queue list and resolve endpoints** over the `review_queue` table — the surface through which the single seeded operator clears the items the EPIC-03 matcher routed out of the auto-commit path: low-confidence extractions and matches (the `n<5` matches surfaced per PRD §8.5), brand-new clusters, and duplicate-merge candidates (PRD §8.6 names this the core operator loop and the main defense against catalog fragmentation). Per `docs/schema.sql`, the `review_queue` row carries `id` (BIGINT identity primary key), `kind` (`review_kind`), `ref_table`, `ref_id`, `reason`, `payload` (JSONB), `state` (`review_state`, NOT NULL DEFAULT `open`), `created_at`, `resolved_at`, and `resolved_by`; that schema defines no UNIQUE constraint and no database-level state guard on this table, so the resolve transition is enforced as a single atomic conditional update keyed on `state = 'open'` in the application layer. The endpoints build on the FEATURE-04-01 API scaffolding: each handler opens a short-lived Neon connection through the **pooled** `DATABASE_URL` and never the unpooled `DATABASE_URL_UNPOOLED` (which EPIC-02 reserves for DDL and migrations), threads the operator `userId` from the `getUserId()` seam (v1 = the single seeded operator, `resolved_by` is backed by `app_user.id`), validates input and returns HTTP **400** with a named `error` field on malformed input, issues no LLM call in the request path, sources data through official APIs only, and is gated to the operator role (full role-based authentication is deferred).

## User Story

> **As an** Operator, **I want** to list and resolve `review_queue` items, **so that** I can approve/correct low-confidence extractions and matches, confirm new clusters, and clear merge candidates that the automated matcher routed for review.

## Acceptance Criteria

1. **(valid-output — LIST default state)** **Given** `review_queue` holds items in `state = open` and items in `state = resolved`, **When** the operator calls the list endpoint with no `state` query parameter, **Then** the response is HTTP **200** and every returned item has `state = open`, with no item in `state = resolved` or `state = dismissed` present.
2. **(valid-output — LIST explicit filter)** **Given** `review_queue` holds items across `state = open`, `state = resolved`, and `state = dismissed`, **When** the operator calls the list endpoint with `state=resolved`, **Then** the response is HTTP **200** and every returned item has `state = resolved`.
3. **(valid-output — RESOLVE transition and stamping)** **Given** an item with `state = open` and a known `id`, **When** the operator resolves that `id` with a target `state = resolved`, **Then** the response is HTTP **200**, the stored row has `state = resolved`, `resolved_at` holds the resolution timestamp (`now()`), and `resolved_by` equals the operator `userId` returned by `getUserId()`; a request whose target `state = dismissed` transitions the same `open` row to `state = dismissed` and stamps `resolved_at` and `resolved_by` identically.
4. **(input-validation — target state)** **Given** a resolve request whose target `state` is a value outside the set { `resolved`, `dismissed` } (for example `open` or `archived`), **When** the request is processed, **Then** the response is HTTP **400** with an `error` field that names `state`, and zero rows in `review_queue` are modified.
5. **(error-handling — unknown id)** **Given** an `id` that matches no row in `review_queue`, **When** the operator resolves that `id`, **Then** the response is HTTP **404** with a named `error` field, and zero rows in `review_queue` are created or modified.
6. **(error-handling and edge — already resolved and concurrency)** **Given** an item whose `state` is already `resolved` or `dismissed`, **When** a resolve request targets that `id`, **Then** the response is HTTP **409** and `resolved_at` and `resolved_by` are left unchanged; **and given** two operators submit resolve requests for the same `open` `id` at the same time, **Then** the atomic conditional update keyed on `state = 'open'` lets exactly one request transition the row and return HTTP **200**, while the losing request matches zero rows and returns HTTP **409**.
7. **(input-validation — unknown kind filter)** **Given** a list request whose `kind` query parameter is a value outside the set { `extraction`, `match`, `new_cluster`, `merge_candidate` }, **When** the request is processed, **Then** the response is HTTP **400** with an `error` field that names `kind`, and no rows are returned.

## Sub-tasks

- [ ] Implement the list (GET) handler that reads the pooled `DATABASE_URL`, filters `review_queue` by `state`, defaults to `state = open` when the parameter is omitted, and returns an HTTP 200 JSON array of items carrying `id`, `kind`, `ref_table`, `ref_id`, `reason`, `payload`, `state`, `created_at`, and (when set) `resolved_at` and `resolved_by` (@backend-engineer)
- [ ] Accept an optional `kind` filter on the list endpoint that admits only `extraction`, `match`, `new_cluster`, and `merge_candidate`, returning HTTP 400 with an `error` field that names `kind` for any other value (@backend-engineer)
- [ ] Implement the resolve (PATCH/POST on the item `id`) handler as a single atomic conditional update guarded on `state = 'open'`, transitioning the row to the target `state` (`resolved` or `dismissed`) and stamping `resolved_at = now()` and `resolved_by` with the operator `userId` from `getUserId()` (@backend-engineer)
- [ ] Validate the target `state` against the set { `resolved`, `dismissed` }, returning HTTP 400 with an `error` field that names `state` for any other value and leaving every row unmodified (@backend-engineer)
- [ ] Map an `id` that matches no `review_queue` row to HTTP 404 with a named `error` field, and a resolve whose conditional update matches zero rows because the row is already `resolved` or `dismissed` to HTTP 409 (@backend-engineer)
- [ ] Thread the operator `userId` from the `getUserId()` seam, gate both endpoints to the operator role, and read the pooled `DATABASE_URL` only — never the unpooled `DATABASE_URL_UNPOOLED` (@backend-engineer)
- [ ] Author API integration tests against a per-CI Neon branch covering the list default, the `state` and `kind` filters, the resolve transition and stamping, the 400/404/409 paths, and the concurrent-resolution path where exactly one request wins (@qa-engineer)
- [ ] Confirm the request handlers issue zero LLM calls and source data through official APIs only (@tech-lead)

## Edge Cases

- **Empty/Null — empty queue for the requested state:** `review_queue` holds zero items in the requested `state` (for example no `open` items remain) → the list endpoint returns HTTP **200** with an empty JSON array `[]`, not HTTP **404**.
- **Invalid — already-resolved item:** a resolve request targets an item whose `state` is already `resolved` or `dismissed` → HTTP **409**, and the stored `resolved_at` and `resolved_by` are left unchanged.
- **Concurrent — same item resolved at the same time:** two operators resolve the same `open` `id` at the same time → the atomic conditional update keyed on `state = 'open'` lets exactly one request transition the row and return HTTP **200**; the other matches zero rows and returns HTTP **409**.
- **Boundary/Invalid — unknown kind filter:** a list `kind` filter value outside the set { `extraction`, `match`, `new_cluster`, `merge_candidate` } → HTTP **400** with an `error` field that names `kind`, and no rows are returned.

## Dependencies

### Upstream (must be complete first)

- **[FEATURE-04-01 — Backend Foundation & Environment Access](../FEATURE-04-01-backend-foundation-and-environment-access.md):** the API route scaffolding, the provisioned Vercel environment access (per <https://docs.blitzy.com/administration/environments>), the `getUserId()` threading, and the query-parameter validation these two endpoints reuse.
- **[EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md):** the `review_queue` table and the `app_user` row that backs `resolved_by`, the pooled Neon access layer, and the `getUserId()` seam (`STORY-02-03-02`, the seeded operator user).
- **[EPIC-03 — Data Ingestion Pipeline](../../EPIC-03-data-ingestion-pipeline.md):** the confidence-gated matcher in `FEATURE-03-02` writes the low-confidence extractions and matches, the new clusters, and the merge candidates into `review_queue`; the list and resolve endpoints have no `open` items to act on until that ingestion has run.

### Downstream (informational — not a build prerequisite of this story)

- **[EPIC-05 — Frontend User Interface](../../EPIC-05-frontend-user-interface.md):** the operator review-queue workbench (`STORY-05-03-03`) consumes the list and resolve endpoints this story exposes.
- **[EPIC-06 — Testing & CI/CD Quality Gates](../../EPIC-06-testing-and-cicd-quality-gates.md):** `STORY-06-02-02` integration-tests these API routes against a per-CI Neon branch at an API coverage floor of **≥75%**.

### Parent feature

- **[FEATURE-04-03 — Operator Review-Queue API](../FEATURE-04-03-operator-review-queue-api.md)**

## Story Estimation Guidance

- **Effort: Medium** — two handlers (a filtered list and a guarded resolve) over a single table, beyond a one-handler read but short of a multi-table contract.
- **Complexity: Medium-High** — the resolve transition must be a single atomic conditional update keyed on `state = 'open'` because `docs/schema.sql` defines no UNIQUE constraint and no database-level state guard, and the concurrent-resolution path must yield exactly one HTTP 200 winner with the loser receiving HTTP 409.
- **Uncertainty: Medium** — the request and response contract depends on the FEATURE-04-01 scaffolding, which is unbuilt, so the exact validation-error shape settles once that foundation lands.
- **Fibonacci Story Points: 5.** The concurrency-safe atomic transition and the multi-path validation place this above a 3; a single table with a fixed schema holds it below an 8. Points measure relative size, not a duration.

## Definition of Done

- [ ] The list endpoint filters `review_queue` by `state`, defaults to `state = open` when no `state` parameter is supplied, and returns an HTTP 200 JSON array exposing each item's `id`, `kind`, `ref_table`, `ref_id`, `reason`, `payload`, `state`, `created_at`, and (when set) `resolved_at` and `resolved_by`.
- [ ] The list endpoint returns an empty JSON array `[]` with HTTP 200 (not HTTP 404) when zero items match the requested `state`.
- [ ] A `kind` filter value outside the set { `extraction`, `match`, `new_cluster`, `merge_candidate` } returns HTTP 400 with an `error` field that names `kind`.
- [ ] The resolve endpoint performs the atomic `open` → `resolved` or `open` → `dismissed` transition as a single conditional update keyed on `state = 'open'`, and stamps `resolved_at` with `now()` and `resolved_by` with the operator `userId` from `getUserId()`.
- [ ] A resolve request with a target `state` outside the set { `resolved`, `dismissed` } returns HTTP 400 with an `error` field that names `state` and modifies zero rows.
- [ ] A resolve request against an `id` that matches no row returns HTTP 404 with a named `error` field, and a resolve against an item already `resolved` or `dismissed` — including the losing request in a concurrent pair — returns HTTP 409 with `resolved_at` and `resolved_by` left unchanged.
- [ ] The handlers read the pooled `DATABASE_URL` (never the unpooled `DATABASE_URL_UNPOOLED`), thread the operator `userId` from the `getUserId()` seam (v1 = the single seeded operator), gate both endpoints to the operator role, and issue zero LLM calls.
- [ ] No prohibited vague quality term appears in any acceptance-criteria statement; every such statement names a measurable pass/fail condition (an HTTP status code, an exact enum value, or an exact column or error-field name).
- [ ] **Testing:** API integration tests against a per-CI Neon branch pass, including the concurrent-resolution case, with a ≥75% coverage target.
