# STORY-06-01-03: Wire Integration Tests to the Shared dev-qa Neon Branch

*Parent feature: [FEATURE-06-01 — Test Harness & Environment Access](../FEATURE-06-01-test-harness-and-environment-access.md) · Parent epic: [EPIC-06 — Testing & CI/CD Quality Gates](../../EPIC-06-testing-and-cicd-quality-gates.md)*

This is the third and final story of FEATURE-06-01. It wires the integration test suite to the shared long-lived `dev-qa` Neon branch: a single long-lived branch — a copy-on-write clone of the `production` branch, provisioned once in EPIC-02 — that is migrated through the unpooled connection URL (`DATABASE_URL_UNPOOLED`) and exposed to the integration job as the pooled test `DATABASE_URL`. No per-run branch is created at pipeline start or deleted on completion; every CI run reuses the shared `dev-qa` branch. It builds on the single Vitest harness from [STORY-06-01-01](STORY-06-01-01-configure-vitest-and-env-access.md) and runs beside the fixtures and boundary mocks from [STORY-06-01-02](STORY-06-01-02-establish-fixtures-and-boundary-mocks.md); together they let EPIC-06's API integration tests run against a real, migration-fresh schema instead of mocks. A Neon branch is a copy-on-write clone of its parent, so `dev-qa` keeps every write off the protected `production` branch. The connection strings consumed here are the encrypted secrets configured by the environment-access work in [STORY-06-01-01](STORY-06-01-01-configure-vitest-and-env-access.md); this story reads them and does not re-provision them.

> Because previews and CI now share the single `dev-qa` branch, per-run database isolation is lost — concurrent CI runs and open PRs share `dev-qa` state. This is the inherent consequence of the two-environment model.

## User Story

As a **Platform Engineer**, I want integration tests to run against the shared long-lived `dev-qa` Neon branch, so that database-backed tests never touch the protected `production` branch while running against a real, migration-applied schema.

## Acceptance Criteria

1. **(input-validation)** Given the CI job starts without the `dev-qa` branch connection strings (the pooled `DATABASE_URL` and/or the unpooled `DATABASE_URL_UNPOOLED`), When the integration job's setup step runs, Then the job exits with a non-zero code, the log names the missing connection string, and 0 integration tests run.
2. **(valid-output)** Given the shared `dev-qa` branch connection strings are present, When the pipeline runs, Then migrations apply against the `dev-qa` branch's unpooled connection URL (`DATABASE_URL_UNPOOLED`) with exit code 0, the integration suite connects through the `dev-qa` pooled `DATABASE_URL` and reports 0 failed tests, and no per-run branch is created or deleted.
3. **(error-handling)** Given the connection to the `dev-qa` branch or the migration step fails, When the failure is detected, Then the job halts with a non-zero exit code, runs 0 integration tests, and opens 0 connections to the protected `production` branch — the `production` connection string is never assigned to the test `DATABASE_URL`.
4. **(edge-case)** Given the shared `dev-qa` branch already holds schema and data from prior runs, When a new CI run applies migrations idempotently and runs the suite, Then migrations converge with exit code 0 (with no destructive reset of `dev-qa`) and the suite passes against the persisted, migration-current schema.
5. **(connection-discipline)** Given the migration step and the test runtime both target the shared `dev-qa` branch, When each connects, Then migrations and DDL use the unpooled `DATABASE_URL_UNPOOLED` while the integration runtime uses the pooled `DATABASE_URL`, and the two connection strings hold distinct values — mixing the two breaks migrations.
6. **(concurrency)** Given two CI runs start at the same time, When each connects to the shared `dev-qa` branch, Then both runs operate against the same `dev-qa` database — per-run database isolation is not provided, and concurrent runs share `dev-qa` state (the inherent consequence of the two-environment model).
7. **(failure-handling)** Given the integration suite reports 1 or more failed tests, When the job reaches its completion step, Then the shared `dev-qa` branch is NOT deleted (it is long-lived and reused) and the job surfaces the failing tests with a non-zero exit code.
8. **(boundary)** Given the shared `dev-qa` branch is a copy-on-write clone of the `production` branch, When migrations create the `valuation` table with its `UNIQUE NULLS NOT DISTINCT (variation_id, grade_id, window_days, cost_basis)` constraint, Then the branch reports a PostgreSQL server version of 15 or higher and the constraint is created with exit code 0 — a server below 15 rejects the constraint.

## Sub-tasks

- Document that the integration job targets the shared long-lived `dev-qa` branch (provisioned once in EPIC-02 `STORY-02-01-*`), with no per-run branch creation or deletion — `@platform-engineer`
- Document applying schema migrations against the shared `dev-qa` branch through its unpooled connection URL (`DATABASE_URL_UNPOOLED`) on a PostgreSQL 15+ server — `@platform-engineer`
- Document setting the integration job's test `DATABASE_URL` to the shared `dev-qa` branch's pooled connection string so the suite reads the migrated branch at runtime — `@platform-engineer`
- Document that the `dev-qa` pooled and unpooled connection strings are read from the encrypted secrets configured by the environment access in `STORY-06-01-01`, not re-provisioned here — `@qa-engineer`
- Document the idempotency target the integration suite exercises on the shared `dev-qa` branch — the `raw_listing` `UNIQUE (source, source_item_id)` constraint, where a re-inserted listing updates one row rather than duplicating it — `@qa-engineer`

## Edge Cases

- **Empty/Null:** the `dev-qa` connection strings (`DATABASE_URL`/`DATABASE_URL_UNPOOLED`) are absent → the job fails fast with a non-zero exit code, names the missing connection string, and runs 0 integration tests.
- **Shared state:** the shared `dev-qa` branch retains schema and data from prior runs → migrations apply idempotently (no destructive reset) and the suite runs against the persisted, migration-current schema.
- **Concurrent:** two CI runs start at the same time → both operate against the shared `dev-qa` branch, so per-run database isolation is not provided and the runs share `dev-qa` state.
- **Invalid/Failure:** a migration is malformed and fails against the shared `dev-qa` branch → the migration step exits non-zero and 0 integration tests run; the long-lived `dev-qa` branch is not deleted.

## Dependencies

### Upstream (must be complete first)

- **`STORY-02-01-*` (EPIC-02 — Neon Project & Branching Topology — the HARD PREREQUISITE):** the shared `dev-qa` branch wiring documented here cannot run until EPIC-02 establishes Neon branching. Cited cross-epic by identifier:
  - **`STORY-02-01-03`** — the shared dev/qa branch as the CI target: the `dev-qa` branch this integration job connects to.
  - **`STORY-02-01-01`** — the Neon project and protected `production` branch the shared `dev-qa` branch is cloned from.
  - **`STORY-02-01-04`** — the pooled-versus-unpooled connection discipline; the unpooled `DATABASE_URL_UNPOOLED` is the variant used for migrations here.
- **`EPIC-01` — Environment & Configuration Foundation:** stores the connection strings as encrypted secrets. Cited cross-epic by identifier.
- **[STORY-06-01-01 — Configure Vitest & Environment Access](STORY-06-01-01-configure-vitest-and-env-access.md):** the single Vitest harness this integration job invokes, and the story that configures the environment access (the encrypted secrets) this branch wiring reads.

### Downstream (informational — not a build prerequisite of this story)

- **[STORY-06-01-02 — Establish Fixtures & Boundary Mocks](STORY-06-01-02-establish-fixtures-and-boundary-mocks.md):** the sibling story whose fixtures and boundary mocks run on the same harness; this story adds the database-backed branch the integration suite uses.
- **FEATURE-06-02 — Unit & Integration Suites (`STORY-06-02-02`):** the API integration tests authored there sit on top of this shared `dev-qa` branch wiring; referenced by identifier because they live in another feature folder.

## Story Estimation Guidance

- **Effort: Medium–High** — the work spans migrating the shared `dev-qa` branch through its unpooled connection URL and wiring the integration job to its two distinct connection strings (pooled runtime, unpooled migrations), plus the connection-discipline and PostgreSQL 15+ checks.
- **Complexity: Medium** — it spans migration ordering against the unpooled URL on the shared `dev-qa` branch and the pooled/unpooled connection-discipline split, each of which must hold for the suite to run against a real, migration-applied schema.
- **Uncertainty: Low–Medium** — the branching topology is fixed by EPIC-02 `STORY-02-01-*`; the remaining unknowns are the migration-apply behavior against the shared `dev-qa` branch and the connection-string wiring, which a sample PR run exercises.
- **Estimate: 8 points (Fibonacci).** The span across migrations (against the unpooled URL), the pooled-versus-unpooled connection-discipline split, and the CI wiring to the shared `dev-qa` branch places this above a 5; the fixed upstream branching topology (EPIC-02 `STORY-02-01-*`) holds it at an 8 rather than a 13.

## Definition of Done

- [ ] The integration suite is wired to the shared long-lived `dev-qa` Neon branch (provisioned once in EPIC-02), with migrations applied to it via the unpooled URL and no per-run branch created or deleted.
- [ ] The unpooled-for-migrations (`DATABASE_URL_UNPOOLED`) versus pooled-for-runtime (`DATABASE_URL`) discipline is stated, including that mixing the two breaks migrations.
- [ ] The PostgreSQL 15+ floor is stated, anchored to the `valuation` table's `UNIQUE NULLS NOT DISTINCT` constraint that the shared `dev-qa` branch inherits as a copy-on-write clone of `production`.
- [ ] Concurrent CI runs share the single `dev-qa` branch; the lost-per-run-isolation trade-off is stated explicitly.
- [ ] The `dev-qa` branch is long-lived and reused across runs (no orphan-branch detection or per-run cleanup).
- [ ] The shared `dev-qa` branch is never deleted on completion; it persists across passing and failing runs.
- [ ] The EPIC-02 `STORY-02-01-*` branching dependency (specifically `STORY-02-01-03`, `STORY-02-01-01`, and `STORY-02-01-04`) is recorded.
- [ ] No prohibited vague terms appear in the acceptance criteria.
- [ ] All relative links resolve: the parent feature index, the parent epic index, and the sibling stories STORY-06-01-01 and STORY-06-01-02.
- [ ] **Testing:** Integration tests pass against the shared `dev-qa` Neon branch in a sample PR run; the long-lived `dev-qa` branch is not torn down afterward.
