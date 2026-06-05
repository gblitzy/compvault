# STORY-06-01-03: Wire Integration Tests to a Per-CI Neon Branch

*Parent feature: [FEATURE-06-01 — Test Harness & Environment Access](../FEATURE-06-01-test-harness-and-environment-access.md) · Parent epic: [EPIC-06 — Testing & CI/CD Quality Gates](../../EPIC-06-testing-and-cicd-quality-gates.md)*

This is the third and final story of FEATURE-06-01. It wires the integration test suite to an ephemeral per-CI Neon database branch: a throwaway branch created from the production branch at pipeline start, migrated through the unpooled connection URL, exposed to the integration job as the test `DATABASE_URL`, and deleted on completion. It builds on the single Vitest harness from [STORY-06-01-01](STORY-06-01-01-configure-vitest-and-env-access.md) and runs beside the fixtures and boundary mocks from [STORY-06-01-02](STORY-06-01-02-establish-fixtures-and-boundary-mocks.md); together they let EPIC-06's API integration tests run against a real, migration-fresh schema instead of mocks. A Neon branch is a copy-on-write clone of its parent, so creating one is near-instant and isolates every write from the production branch. The Neon API key and the connection strings consumed here are the encrypted secrets configured by the environment-access work in [STORY-06-01-01](STORY-06-01-01-configure-vitest-and-env-access.md); this story reads them and does not re-provision them.

## User Story

As a **Platform Engineer**, I want integration tests to run against an ephemeral per-CI Neon branch created from the production branch and torn down on completion, so that database-backed tests never touch the production branch and every CI run gets an isolated, migration-fresh database.

## Acceptance Criteria

1. **(input-validation)** Given the CI job starts without a Neon API key or without a parent-branch reference, When the branch-creation step runs, Then the job exits with a non-zero code and the log names the missing input — either the absent Neon API key or the absent parent-branch reference — and 0 branches are created.
2. **(valid-output)** Given a present Neon API key and the production branch named as parent, When the pipeline runs, Then a new branch is created from production as a copy-on-write clone, migrations apply against that branch's unpooled connection URL with exit code 0, the integration suite connects through the branch pooled `DATABASE_URL` and reports 0 failed tests, and the branch is deleted on completion so a post-run branch list does not contain the run's branch name.
3. **(error-handling)** Given branch creation fails because the Neon API returns a non-2xx response, When the failure is detected, Then the job halts with a non-zero exit code, runs 0 integration tests, and opens 0 connections to the production branch — the production-branch connection string is never assigned to the test `DATABASE_URL`.
4. **(edge-case)** Given a branch carrying the same run-scoped name remains from a prior failed run, When the pipeline starts, Then the leftover branch is detected and deleted before a new branch is created, and the new branch is created with exit code 0.
5. **(connection-discipline)** Given the migration step and the test runtime both target the per-CI branch, When each connects, Then migrations and DDL use the unpooled `DATABASE_URL_UNPOOLED` while the integration runtime uses the pooled `DATABASE_URL`, and the two connection strings hold distinct values — mixing the two breaks migrations.
6. **(concurrency)** Given two CI runs start at the same time, When each derives its branch name from its own CI run identifier (the run id, commit SHA, or pull-request number), Then the two runs hold two distinct branch names and 0 branches are shared between them.
7. **(failure-teardown)** Given the integration suite reports 1 or more failed tests, When the job reaches its completion step, Then the per-CI branch is still deleted and a post-run branch list contains 0 branches carrying the run's branch name — no orphan branch outlives a failing run.
8. **(boundary)** Given the per-CI branch is a copy-on-write clone of the production branch, When migrations create the `valuation` table with its `UNIQUE NULLS NOT DISTINCT (variation_id, grade_id, window_days, cost_basis)` constraint, Then the branch reports a PostgreSQL server version of 15 or higher and the constraint is created with exit code 0 — a server below 15 rejects the constraint.

## Sub-tasks

- Document the create-branch-from-production step that derives the branch name from the CI run identifier (run id, commit SHA, or pull-request number) — `@platform-engineer`
- Document applying schema migrations against the new branch through its unpooled connection URL (`DATABASE_URL_UNPOOLED`) on a PostgreSQL 15+ server — `@platform-engineer`
- Document setting the integration job's test `DATABASE_URL` to the branch's pooled connection string so the suite reads the migrated branch at runtime — `@platform-engineer`
- Document the delete-branch-on-completion step that runs on a passing run AND on a failing run, so no branch outlives its pipeline — `@devops-engineer`
- Document detection-and-cleanup of an orphaned branch carrying the run-scoped name from a prior failed run before a new branch is created — `@platform-engineer`
- Document that the Neon API key and the pooled and unpooled connection strings are read from the encrypted secrets configured by the environment access in `STORY-06-01-01`, not re-provisioned here — `@qa-engineer`
- Document the idempotency target the integration suite exercises on the fresh branch — the `raw_listing` `UNIQUE (source, source_item_id)` constraint, where a re-inserted listing updates one row rather than duplicating it — `@qa-engineer`

## Edge Cases

- **Empty/Null:** the Neon API key or the parent-branch reference is absent → the job fails fast with a non-zero exit code, names the missing input, and creates 0 branches.
- **Boundary/Orphan:** a leftover branch carrying the run-scoped name from a prior failed run exists → it is detected and deleted before a new branch is created, leaving 0 duplicate branches.
- **Concurrent:** two CI runs start at the same time → each derives a distinct, run-scoped branch name from its CI run identifier, so the runs share 0 branches.
- **Invalid/Failure:** a migration is malformed and fails on the fresh branch → the migration step exits non-zero, 0 integration tests run, and the branch is still deleted on completion.

## Dependencies

### Upstream (must be complete first)

- **`STORY-02-01-*` (EPIC-02 — Neon Project & Branching Topology — the HARD PREREQUISITE):** the per-CI branch lifecycle documented here cannot run until EPIC-02 establishes Neon branching. Cited cross-epic by identifier:
  - **`STORY-02-01-03`** — per-CI ephemeral branch create and teardown: the create-from-production and delete-on-completion mechanics this story consumes.
  - **`STORY-02-01-01`** — the Neon project and production branch this story branches from.
  - **`STORY-02-01-04`** — the pooled-versus-unpooled connection discipline; the unpooled `DATABASE_URL_UNPOOLED` is the variant used for migrations here.
- **`EPIC-01` — Environment & Configuration Foundation:** stores the Neon API key and the connection strings as encrypted secrets. Cited cross-epic by identifier.
- **[STORY-06-01-01 — Configure Vitest & Environment Access](STORY-06-01-01-configure-vitest-and-env-access.md):** the single Vitest harness this integration job invokes, and the story that configures the environment access (the encrypted secrets) this branch wiring reads.

### Downstream (informational — not a build prerequisite of this story)

- **[STORY-06-01-02 — Establish Fixtures & Boundary Mocks](STORY-06-01-02-establish-fixtures-and-boundary-mocks.md):** the sibling story whose fixtures and boundary mocks run on the same harness; this story adds the database-backed branch the integration suite uses.
- **FEATURE-06-02 — Unit & Integration Suites (`STORY-06-02-02`):** the API integration tests authored there sit on top of this per-CI branch wiring; referenced by identifier because they live in another feature folder.

## Story Estimation Guidance

- **Effort: High** — the work spans the Neon branch lifecycle (create, migrate, test, delete), the orphan-detection cleanup path, and the CI wiring that injects two distinct connection strings, which exceeds a single-step change.
- **Complexity: High** — it spans the Neon API, migration ordering against the unpooled URL, and the CI job lifecycle (create-from-production, teardown on both success and failure, run-scoped naming for concurrency), each of which must hold for the suite to run in isolation.
- **Uncertainty: Medium** — the branching topology is fixed by EPIC-02 `STORY-02-01-*`, yet the exact Neon API responses, the teardown-on-failure path, and the orphan-detection step carry integration unknowns until a sample PR run exercises them.
- **Estimate: 8 points (Fibonacci).** The three-subsystem span (Neon API, migrations, CI lifecycle) plus the failure and orphan paths places this above a 5; the fixed upstream branching topology holds it at an 8 rather than a 13.

## Definition of Done

- [ ] The create → migrate → test → delete per-CI branch lifecycle is documented, with the branch created from the production branch at pipeline start and deleted on completion.
- [ ] The unpooled-for-migrations (`DATABASE_URL_UNPOOLED`) versus pooled-for-runtime (`DATABASE_URL`) discipline is stated, including that mixing the two breaks migrations.
- [ ] The PostgreSQL 15+ floor is stated, anchored to the `valuation` table's `UNIQUE NULLS NOT DISTINCT` constraint that the migrated branch inherits as a copy-on-write clone.
- [ ] The branch name embeds the CI run identifier so two concurrent runs hold two distinct branch names.
- [ ] Orphan-branch detection and cleanup before a new branch is created is documented.
- [ ] The branch is deleted on completion on a passing run AND on a failing run, leaving 0 orphan branches.
- [ ] The EPIC-02 `STORY-02-01-*` branching dependency (specifically `STORY-02-01-03`, `STORY-02-01-01`, and `STORY-02-01-04`) is recorded.
- [ ] No prohibited vague terms appear in the acceptance criteria.
- [ ] All relative links resolve: the parent feature index, the parent epic index, and the sibling stories STORY-06-01-01 and STORY-06-01-02.
- [ ] **Testing:** Integration tests pass against an ephemeral per-CI Neon branch in a sample PR run, and the branch is torn down afterward.
