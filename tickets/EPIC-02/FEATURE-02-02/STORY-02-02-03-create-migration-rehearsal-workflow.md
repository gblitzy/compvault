# STORY-02-02-03: Create the Migration Rehearsal Workflow

Feature: [FEATURE-02-02](../FEATURE-02-02-drizzle-schema-and-migrations.md) · Epic: [EPIC-02](../../EPIC-02-database-platform-and-schema.md)

## User Story

> As a Platform Engineer, I want a migrate.yml workflow that rehearses migrations on a Neon branch using the unpooled URL, so that schema changes are verified before they reach production and branch protection can require a green migration.

## Connection & Environment Note

The `migrate.yml` workflow applies migrations using the **unpooled** `DATABASE_URL_UNPOOLED` connection and never the pooled `DATABASE_URL` — mixing the pooled and unpooled connections breaks migrations, and that is the documented failure mode. The Neon branch the rehearsal runs against and the encrypted `DATABASE_URL_UNPOOLED` secret the workflow consumes are provisioned per [FEATURE-02-01 — Neon Project & Branching Topology](../FEATURE-02-01-neon-project-and-branching-topology.md) (documented per <https://docs.blitzy.com/administration/environments>); the target Neon database runs **PostgreSQL 15+** because `valuation`'s `UNIQUE NULLS NOT DISTINCT (variation_id, grade_id, window_days, cost_basis)` is rejected on any server below version 15.

## Acceptance Criteria

1. **(valid-output)** **Given** a pull request, **When** `migrate.yml` runs, **Then** it applies the migration set on a Neon branch using the unpooled `DATABASE_URL_UNPOOLED` and reports success with exit 0.
2. **(valid-output)** **Given** a manual `workflow_dispatch` invocation with no open pull request, **When** `migrate.yml` runs, **Then** it applies the migration set on a Neon branch using the unpooled `DATABASE_URL_UNPOOLED` with exit 0, and the workflow declares no cron trigger.
3. **(input-validation)** **Given** the unpooled connection secret `DATABASE_URL_UNPOOLED` is absent, **When** the workflow runs, **Then** it fails with a named missing-secret error and applies 0 migrations.
4. **(error-handling)** **Given** a migration that fails to apply, **When** `migrate.yml` runs, **Then** the job exits non-zero and is reported as a failed status check.
5. **(error-handling)** **Given** the pooled `DATABASE_URL` is supplied where the unpooled `DATABASE_URL_UNPOOLED` is required, **When** the workflow runs, **Then** the migration step fails and exits non-zero (mixing the pooled and unpooled connections breaks migrations).
6. **(edge-case)** **Given** the workflow completes, **When** teardown runs, **Then** any ephemeral Neon branch it created is deleted and a post-run branch list contains 0 residual branches for that run.
7. **(valid-output)** **Given** `migrate.yml` is the required status check, **When** it is green, **Then** `EPIC-06` `STORY-06-03-03` branch protection permits the merge.

## Sub-tasks

- Author `.github/workflows/migrate.yml` triggered on `pull_request` and `workflow_dispatch` with no cron schedule — `@platform-engineer`
- Wire the migration step to apply the generated migration set on a Neon branch using the unpooled `DATABASE_URL_UNPOOLED` secret — `@devops-engineer`
- Add a fail-fast guard that exits non-zero with a named missing-secret error when `DATABASE_URL_UNPOOLED` is absent — `@devops-engineer`
- Add a teardown step that deletes the ephemeral Neon branch on completion across both the success path and the failure path — `@devops-engineer`
- Surface a failed migration as a non-zero exit and a failed status check — `@platform-engineer`
- Add a verification step that diffs the applied schema against `docs/schema.sql` and confirms all 9 enums and all 20 tables exist — `@database-engineer`
- Record that `EPIC-06` `STORY-06-03-03` branch protection requires this workflow green — `@platform-engineer`

## Edge Cases

- **Empty/Null:** the `DATABASE_URL_UNPOOLED` secret is missing or empty → the workflow fails with a named missing-secret error and applies 0 migrations.
- **Invalid:** a deliberately broken migration is committed → the job exits non-zero and the status check is marked failed.
- **Concurrent:** two pull requests rehearse at the same time → each runs on its own isolated Neon branch (distinct per run) with no collision and no shared state.
- **Boundary:** an empty / no-op migration set → the workflow exits 0 (a no-change run is a pass, not a failure).

## Dependencies

### Upstream (must be complete first)

- **[`STORY-02-02-02` — Configure drizzle-kit & the Initial Migration](STORY-02-02-02-configure-drizzle-kit-and-initial-migration.md):** produces the generated migration set this workflow applies; the set must exist before a rehearsal can run.
- **[`STORY-02-02-01` — Author the Drizzle Schema](STORY-02-02-01-author-drizzle-schema.md):** provides the `db/schema.ts` the migration set is generated from.
- **[`STORY-02-01-02` — Configure Per-PR Preview Branches](../FEATURE-02-01/STORY-02-01-02-configure-per-pr-preview-branches.md):** provisions the per-PR Neon preview branch the rehearsal runs against.
- **[`STORY-02-01-03` — Configure Per-CI Ephemeral Branches](../FEATURE-02-01/STORY-02-01-03-configure-per-ci-ephemeral-branches.md):** provisions the per-CI ephemeral Neon branch create/teardown lifecycle the workflow relies on.
- `EPIC-01` provides the encrypted-secrets baseline that stores `DATABASE_URL_UNPOOLED` (cited by identifier).

### Downstream (informational — not a build prerequisite of this story)

- `EPIC-06` `STORY-06-03-03` (branch protection) requires `migrate.yml` to be green on `main` before a merge is permitted (cited by identifier).
- `EPIC-06` `STORY-06-02-02` (API integration tests) runs this migration set on a per-CI Neon branch using the unpooled `DATABASE_URL_UNPOOLED` (cited by identifier).

## Story Estimation Guidance

- **Effort: Medium** — one workflow file carrying a migration step, a fail-fast secret guard, a teardown step, and a schema-diff verification step, scoped to a fixed migration set and a fixed schema target (9 enums, 20 tables).
- **Complexity: Medium** — the unpooled-only connection discipline, the create-then-teardown Neon branch lifecycle across both the success path and the failure path, and the failed-check signalling each carry a defined pass/fail behavior the workflow must encode.
- **Uncertainty: Medium** — the CI runner plus the Neon branch lifecycle (branch creation at pipeline start, teardown on completion) is the open variable; the migration set and the schema target are fixed by the upstream stories.
- **Fibonacci Story Points: 5** — the Medium effort, Medium complexity, and Medium uncertainty (CI orchestration over a live Neon branch lifecycle) place this above the 3-point sibling `STORY-02-02-02`, which generates the migration against a fixed input with no branch lifecycle to manage. Points measure relative size, not a duration.

## Definition of Done

- [ ] `.github/workflows/migrate.yml` exists and is triggered on pull requests and `workflow_dispatch` with no cron schedule.
- [ ] The workflow applies the generated migration set on a Neon branch using the unpooled `DATABASE_URL_UNPOOLED` and never the pooled `DATABASE_URL` (mixing the pooled and unpooled connections breaks migrations).
- [ ] A migration that fails to apply exits non-zero and is reported as a failed status check.
- [ ] The ephemeral Neon branch the workflow created is torn down on completion across the success path and the failure path, leaving 0 residual branches for that run.
- [ ] An absent `DATABASE_URL_UNPOOLED` secret fails the workflow with a named missing-secret error and applies 0 migrations.
- [ ] The `EPIC-06` `STORY-06-03-03` branch-protection dependency (this workflow required green on `main`) is recorded.
- [ ] PostgreSQL 15+ is stated as the engine floor (required by `valuation`'s `UNIQUE NULLS NOT DISTINCT`).
- [ ] No prohibited vague quality term appears in any acceptance criterion; every criterion names a measurable pass/fail condition (an exit code, a state, a count, or a named error).
- [ ] All relative links resolve: the parent feature index, the parent epic index, the sibling stories `STORY-02-02-02` and `STORY-02-02-01`, and the `FEATURE-02-01` branch stories `STORY-02-01-02` and `STORY-02-01-03`.
- [ ] **Testing:** A sample pull request triggers `migrate.yml`, which applies migrations on a Neon branch via the unpooled `DATABASE_URL_UNPOOLED` (exit 0) and tears the branch down with 0 residual branches, while a deliberately broken migration fails the check.
