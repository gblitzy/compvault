# STORY-02-03-02: Implement the getUserId Seam

Feature: [FEATURE-02-03](../FEATURE-02-03-data-access-layer-and-seed-data.md) · Epic: [EPIC-02](../../EPIC-02-database-platform-and-schema.md)

## User Story

> As a Backend Engineer, I want a getUserId() seam that returns the seeded operator user id, so that handlers thread a real userId from day one while full authentication remains deferred.

## Connection & Environment Note

This story adds no new platform access: the seam reads the operator `app_user` row through the pooled runtime client from [STORY-02-03-01](STORY-02-03-01-implement-pooled-neon-client.md) on the pooled `DATABASE_URL`, and never the unpooled `DATABASE_URL_UNPOOLED` (which is reserved for DDL and migrations); the `app_user` table itself is defined by `FEATURE-02-02`, and its single operator row is created by the catalog seed in [STORY-02-03-03](STORY-02-03-03-author-catalog-seed-script.md). The full per-epic environment provisioning is documented in `FEATURE-02-01` per <https://docs.blitzy.com/administration/environments> and is not repeated here.

## Acceptance Criteria

1. **(valid-output)** **Given** the seeded operator `app_user` row exists, **When** `getUserId()` is called, **Then** it returns that row's non-null `BIGINT` id.
2. **(error-handling)** **Given** no operator `app_user` row exists, **When** `getUserId()` is called, **Then** it raises a named missing-seed error that identifies the absent operator row and returns no value (it does not return null).
3. **(input-validation)** **Given** an incoming request that carries no auth token, **When** `getUserId()` is called in v1, **Then** it reads no request token, runs no authentication check, and returns the seeded operator id.
4. **(edge-case)** **Given** repeated calls within a single request, **When** `getUserId()` is invoked more than once, **Then** every call returns the same `BIGINT` id (deterministic).
5. **(valid-output)** **Given** the function signature, **When** its return type is inspected, **Then** the return type is the `app_user.id` type (`BIGINT`), so wiring a per-request user id later changes no handler signature (non-breaking).
6. **(edge-case)** **Given** `owner_user_id` on `watchlist`, `collection_item`, and `saved_search`, **When** a v1 row is written through a handler that calls `getUserId()`, **Then** `owner_user_id` is left NULL on that row (the single-operator convention from `docs/schema.sql`).

## Sub-tasks

- Implement `getUserId()` to query the seeded operator `app_user` row and return its non-null `BIGINT` id — `@backend-engineer`
- Raise a named missing-seed error that identifies the absent operator row when no operator `app_user` row exists, returning no value instead of a silent null — `@backend-engineer`
- Apply a deterministic selection (the lowest `app_user.id`) so repeated calls within one request return the same id even when more than one operator row is present — `@backend-engineer`
- Type the return value as the `app_user.id` type (`BIGINT`) so a future per-request user id is a non-breaking substitution at this single call site — `@backend-engineer`
- Confirm the seam reads no request token and runs no authentication in v1, and that v1 handlers leave `owner_user_id` NULL on `watchlist`, `collection_item`, and `saved_search` — `@database-engineer`

## Edge Cases

- **Empty/Null:** no operator `app_user` row is seeded → `getUserId()` raises the named missing-seed error and returns no value (it does not return null).
- **Boundary:** more than one operator `app_user` row is present → the lowest `app_user.id` is selected so the returned id is stable across calls.
- **Invalid:** an operator row is present but its `id` resolves to null → `getUserId()` raises a named error rather than returning a null id.
- **Concurrent:** parallel handler calls read the same seeded operator row and return one consistent `BIGINT` id, so no race produces differing ids.

## Dependencies

### Upstream (must be complete first)

- **[STORY-02-03-03 — Author the Catalog Seed Script](STORY-02-03-03-author-catalog-seed-script.md):** the catalog seed creates the single operator `app_user` row that `getUserId()` returns; without it, the seam has no row to read and raises its missing-seed error.
- **`FEATURE-02-02`** (by identifier): the Drizzle schema and migrations define and create the `app_user` table this seam queries.
- **[STORY-02-03-01 — Implement the Pooled Neon Client](STORY-02-03-01-implement-pooled-neon-client.md):** the pooled client the seam reads through (the pooled `DATABASE_URL`, never the unpooled `DATABASE_URL_UNPOOLED`).

### Downstream (informational — not a build prerequisite of this story)

- **`EPIC-04`** (by identifier): the Backend Application & API threads the id from `getUserId()` as `userId` through its request handlers, so the seam is the single point future authentication replaces.

## Story Estimation Guidance

- **Effort: Low** — one function that issues a single read against the seeded operator `app_user` row and returns its id; no schema change and no new platform access.
- **Complexity: Low** — one indexed read, one deterministic-selection rule (lowest `app_user.id`), and one named-error guard, with no authentication branch and no request-token parsing.
- **Uncertainty: Low** — the return type (`BIGINT`), the source row (`app_user`), and the single-operator convention are all fixed by `docs/schema.sql`, so the target is known.
- **Fibonacci Story Points: 2** — Low effort, Low complexity, and Low uncertainty across a single read-and-return function place the estimate at 2; the named-error guard and the deterministic-selection rule keep it above a 1. Points measure relative size, not a duration.

## Definition of Done

- [ ] `getUserId()` returns the seeded operator `app_user` row's non-null `BIGINT` id.
- [ ] When no operator `app_user` row exists, `getUserId()` raises a named missing-seed error that identifies the absent operator row and returns no value (no silent null).
- [ ] The seam reads no request token and runs no authentication in v1.
- [ ] Repeated calls within a single request return the same id (deterministic), and when more than one operator row is present the lowest `app_user.id` is selected.
- [ ] An operator row whose `id` resolves to null raises a named error rather than returning a null id.
- [ ] The return type is the `app_user.id` type (`BIGINT`), so a future per-request user id is a non-breaking substitution at this call site.
- [ ] V1 handlers calling `getUserId()` leave `owner_user_id` NULL on `watchlist`, `collection_item`, and `saved_search`.
- [ ] No prohibited vague quality term appears in any acceptance criterion; every criterion names a measurable pass/fail condition (a non-null `BIGINT` id, a named error, or the same id).
- [ ] All relative links resolve: the parent feature index, the parent epic index, and the sibling stories `STORY-02-03-01` and `STORY-02-03-03`; `FEATURE-02-02` and `EPIC-04` are cited by plain identifier.
- [ ] **Testing:** a unit/integration test asserts `getUserId()` returns the seeded operator's non-null `BIGINT` id and raises the named missing-seed error when the operator `app_user` row is absent.
