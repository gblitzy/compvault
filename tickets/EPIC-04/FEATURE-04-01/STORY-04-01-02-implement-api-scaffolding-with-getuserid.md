# STORY-04-01-02: Implement API Scaffolding with getUserId

Feature → [FEATURE-04-01 — Backend Foundation & Environment Access](../FEATURE-04-01-backend-foundation-and-environment-access.md) · Epic → [EPIC-04 — Backend Application & API](../../EPIC-04-backend-application-and-api.md)

This is the **second of the three stories** in FEATURE-04-01 and the API foundation the rest of EPIC-04 builds on. It specifies the **Next.js App Router** API route scaffolding that threads the operator `userId` from the `getUserId()` seam — implemented upstream in EPIC-02 `STORY-02-03-02`, which returns the single seeded operator backed by the `app_user` table — through every handler **before any data access**, so the catalog is multi-tenant-ready from day one while full authentication stays deferred (PRD §7.5, §7.6.1).

The data partition is the move that makes this work: catalog, `sale_observation`, and `valuation` are **GLOBAL** (one shared copy for every user, never filtered by `userId`), while only the personal tables — `watchlist`, `saved_search`, and `collection_item` — are scoped by `owner_user_id` (PRD §7.5; `docs/schema.sql`). The auth seam stays in **middleware** so that turning on real authentication later (Auth.js or Clerk) is a configuration change, not a refactor. Every handler runs as a stateless request/response function on Vercel, reads the pooled `DATABASE_URL` (never the unpooled `DATABASE_URL_UNPOOLED`, which EPIC-02 reserves for DDL and migrations), calls official APIs only, and issues no LLM call in the request path — LLM-assisted extraction stays in the EPIC-03 batch jobs (PRD §7.5, §7.6.1).

## User Story

> As a **Backend Engineer**, I want Next.js App Router API route scaffolding that threads `userId` from the `getUserId()` seam through every handler, so that the catalog is multi-tenant-ready from day one even though full authentication is deferred.

## Acceptance Criteria

1. **(valid-output — seam threading)** **Given** a scaffolded API route, **When** a request is handled, **Then** the handler obtains `userId` from `getUserId()` **before any data access** and returns HTTP **200** on the success path.
2. **(valid-output — data partition)** **Given** a request that reads personal data (`watchlist`, `saved_search`, or `collection_item`), **When** the query runs, **Then** it is filtered by `userId` (`owner_user_id`); and **Given** a request that reads GLOBAL data (catalog, `sale_observation`, or `valuation`), **When** the query runs, **Then** it is **NOT** filtered by `userId`.
3. **(input-validation — missing-thread scaffolding check)** **Given** a route added without the `userId` thread, **When** the shared scaffolding check (test/lint) runs, **Then** that check fails and the route does not pass CI, because `getUserId()` is not invoked before any data access.
4. **(edge-case — unauthenticated v1 boundary)** **Given** an unauthenticated request context in v1, **When** `getUserId()` is called, **Then** it resolves the single seeded operator `app_user` row (a non-null `userId`) and does not raise an error.
5. **(edge-case — concurrent resolution)** **Given** multiple concurrent requests, **When** each is handled, **Then** each handler resolves its own `userId` from `getUserId()` independently, with no shared mutable request state across handlers.
6. **(error-handling — no LLM in handler)** **Given** a request handler, **When** it is reviewed, **Then** it contains no LLM call (LLM-assisted work is batch-only); an attempt to add an LLM call inside a request handler fails review.

## Sub-tasks

- [ ] Scaffold the Next.js App Router `api/` read-endpoint structure per the PRD §7.6.1 repo layout (@backend-engineer)
- [ ] Thread `userId` from `getUserId()` (EPIC-02 `STORY-02-03-02`) at the entry of every handler before any data access (@backend-engineer)
- [ ] Enforce the data partition — filter the personal tables (`watchlist`, `saved_search`, `collection_item`) by `userId` (`owner_user_id`) and keep catalog, `sale_observation`, and `valuation` reads GLOBAL (@backend-engineer)
- [ ] Keep the auth seam in middleware so Auth.js or Clerk is a drop-in configuration change later, not a refactor (@backend-engineer)
- [ ] Add a shared test/lint check that fails any route missing the `userId` thread, so a non-threaded route does not pass CI (@qa-engineer)
- [ ] Document and enforce the no-LLM-in-handlers rule — LLM-assisted extraction stays in the EPIC-03 batch jobs (@tech-lead)
- [ ] Document the pooled-connection rule — every handler reads the pooled `DATABASE_URL` and never the unpooled `DATABASE_URL_UNPOOLED` (@backend-engineer)
- [ ] Author API integration tests against the `dev-qa` Neon branch covering seam resolution, the GLOBAL-vs-personal partition, and concurrent resolution (@qa-engineer)

## Edge Cases

- **Valid:** `getUserId()` returns the seeded operator (`app_user` row; `owner_user_id` NULL in v1 = the single operator), and the handler threads that non-null `userId` before any data access.
- **Boundary:** an unauthenticated context in v1 still resolves the single seeded operator through `getUserId()` and does not raise an error, because v1 has no real authentication and the seam returns the seeded user.
- **Concurrent:** concurrent requests each resolve `userId` independently via `getUserId()`, with no shared mutable request state leaking one request's `userId` into another.
- **Empty/Null:** a personal-data read whose `userId` resolves to the seeded operator returns that operator's rows (`owner_user_id` NULL maps to the single operator), while a GLOBAL read (catalog, `sale_observation`, `valuation`) ignores `userId` and returns the shared rows.

## Dependencies

### Upstream (must be complete first)

- **[`STORY-04-01-01 — Configure Vercel Runtime & Environment Access`](STORY-04-01-01-configure-vercel-runtime-and-env-access.md):** supplies the configured Vercel request/response runtime and the pooled `DATABASE_URL` access this scaffolding runs on.
- **EPIC-02 `STORY-02-03-02`:** implements the `getUserId()` seam that returns the seeded operator `app_user`; this story consumes that seam and threads it through every handler — it does not re-implement the seam.
- **EPIC-02 `STORY-02-03-01`:** provides the pooled Neon client every handler reads through `DATABASE_URL`.

### Downstream (informational — not a build prerequisite of this story)

- **[`STORY-04-01-03 — Implement Query-Parameter Validation`](STORY-04-01-03-implement-query-parameter-validation.md):** wraps this scaffolding with query-parameter input validation that runs before any data read.
- **[FEATURE-04-02 — Search & Detail Endpoints](../FEATURE-04-02-search-and-detail-endpoints.md)** and **[FEATURE-04-03 — Operator Review-Queue API](../FEATURE-04-03-operator-review-queue-api.md):** build their handlers on this `userId`-threaded scaffolding.
- **[EPIC-05 — Frontend User Interface](../../EPIC-05-frontend-user-interface.md):** consumes the endpoints served by this scaffolding.
- **EPIC-06 `STORY-06-02-02`:** integration-tests these API routes against the `dev-qa` Neon branch at an API coverage floor of **≥75%**. Because these integration tests share the single `dev-qa` branch, concurrent runs share `dev-qa` state and per-run database isolation is not provided — see the lost-isolation note in `STORY-04-01-01` and EPIC-02.

### Parent feature

- **[FEATURE-04-01 — Backend Foundation & Environment Access](../FEATURE-04-01-backend-foundation-and-environment-access.md)**

## Story Estimation Guidance

- **Effort: Medium** — scaffold the App Router `api/` structure, thread `getUserId()` through every handler entry, partition personal versus GLOBAL reads, and add a shared missing-thread check, which exceeds a single-file edit.
- **Complexity: Medium** — the seam threading is mechanical, but the GLOBAL-vs-personal data partition (catalog, `sale_observation`, `valuation` stay GLOBAL while `watchlist`, `saved_search`, `collection_item` filter on `owner_user_id`) and the shared check that fails non-threaded routes add care.
- **Uncertainty: Low** — the seam is defined upstream in EPIC-02 `STORY-02-03-02`, and the partition rules and connection-string discipline are fixed by PRD §7.5/§7.6.1 and `docs/schema.sql`, leaving no open design question.
- **Fibonacci Story Points: 3.** The multi-handler threading plus the partition and the shared check place this above a 1; the upstream-defined seam and the fixed partition rules hold it below a 5. Points measure relative size, not a duration.

## Definition of Done

- [ ] Every scaffolded route obtains `userId` from `getUserId()` before any data access and returns HTTP 200 on the success path.
- [ ] Personal-table reads (`watchlist`, `saved_search`, `collection_item`) filter by `userId` (`owner_user_id`), while catalog, `sale_observation`, and `valuation` reads stay GLOBAL and are not filtered by `userId`.
- [ ] A route missing the `userId` thread fails the shared test/lint check and does not pass CI.
- [ ] An unauthenticated v1 context resolves the single seeded operator `app_user` row (a non-null `userId`) and does not raise an error.
- [ ] Concurrent requests each resolve `userId` independently via `getUserId()`, with no shared mutable request state.
- [ ] The auth seam stays in middleware so Auth.js or Clerk is a drop-in configuration change later; `getUserId()` is consumed from EPIC-02 `STORY-02-03-02` and not re-implemented here.
- [ ] No request handler contains an LLM call (LLM-assisted extraction stays in the EPIC-03 batch jobs), and every external data source is an official API.
- [ ] Every handler reads the pooled `DATABASE_URL` and never the unpooled `DATABASE_URL_UNPOOLED` (reserved for DDL and migrations).
- [ ] No prohibited vague quality term appears in any acceptance-criteria statement; every statement names a measurable pass/fail condition (the seam name `getUserId()`, "before any data access", exact table names, "GLOBAL reads are not filtered by `userId`", or an exact HTTP status).
- [ ] **Testing:** API integration tests against the `dev-qa` Neon branch pass with a ≥75% coverage target.
