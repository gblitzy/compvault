# STORY-02-01-03: Configure Per-CI Ephemeral Branches

*Parent feature: [FEATURE-02-01 — Neon Project & Branching Topology](../FEATURE-02-01-neon-project-and-branching-topology.md) · Parent epic: [EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md)*

This is the third story of FEATURE-02-01. It documents the per-CI ephemeral Neon branch: a throwaway branch created from the production branch at CI pipeline start, with the CI job's `DATABASE_URL` pointed at that branch, used to run migrations and tests, then deleted on completion — whether the run passes or fails. A Neon branch is a copy-on-write clone of its parent, so the per-CI branch is cloned from the production branch created in [STORY-02-01-01](STORY-02-01-01-provision-neon-project-and-production-branch.md); creating one is near-instant and isolates every write from the production branch. This story documents the create-from-production and delete-on-completion mechanics that the EPIC-06 integration suite (`STORY-06-01-03`) consumes directly, and the kind of branch that EPIC-02 `STORY-02-02-03`'s `migrate.yml` rehearses migrations against. It does not provision the project, the production branch, or the Neon secrets — those are sourced from [STORY-02-01-01](STORY-02-01-01-provision-neon-project-and-production-branch.md).

## User Story

> As a **DevOps Engineer**, I want an ephemeral Neon branch created from production at CI pipeline start and torn down on completion, so that integration tests run against an isolated throwaway database.

## Environment Access & Configuration

- **Canonical reference.** All environment provisioning for this story follows the Blitzy environments reference at <https://docs.blitzy.com/administration/environments>. Per that reference, an environment is created for each target, build and run instructions are supplied in natural language, non-sensitive values are stored as **plaintext variables** and sensitive credentials are stored as **encrypted secrets**, and the environment is then **attached to the project**.
- **Platforms named.** Two platforms are wired together for this story:
  - **Neon** — holds the production branch (the parent) and exposes a branch create-and-delete API. The per-CI ephemeral branch is created as a copy-on-write clone of the production branch at pipeline start and deleted on completion.
  - **GitHub Actions** — supplies the CI runners and the encrypted secrets. The runner reads the Neon API key (an **encrypted secret** per the environments reference) to call the branch create-and-delete API, and the freshly created branch's connection string is exported to the test job as `DATABASE_URL`.
- **Encrypted secret.** The Neon API key carrying branch create and delete permission is stored as an **encrypted secret** per <https://docs.blitzy.com/administration/environments>; it is never stored as a plaintext variable and never written into a workflow body.
- **Engine inheritance.** The ephemeral branch is a copy-on-write clone of the production branch, so it inherits **PostgreSQL 15+** from production — the floor required by the `valuation` table's `UNIQUE NULLS NOT DISTINCT (variation_id, grade_id, window_days, cost_basis)` constraint, which any Postgres server below 15 rejects.
- **Source of the parent and secrets.** The production parent branch, the Neon API key, and the pooled and unpooled connection strings are provisioned and stored as encrypted secrets in [STORY-02-01-01](STORY-02-01-01-provision-neon-project-and-production-branch.md); this story reads them and documents the per-CI branch lifecycle rather than duplicating those provisioning steps.

### Platforms and access required

| Platform | Access required | Purpose in STORY-02-01-03 |
|----------|-----------------|---------------------------|
| Neon | API key carrying branch create and delete permission; the production parent branch | Create the per-CI ephemeral branch from production at pipeline start and delete it on completion |
| GitHub Actions | CI runners; encrypted secrets holding the Neon API key and the exported branch connection string | Run the create-branch step, export the branch connection string to the test job as `DATABASE_URL`, run migrations and tests, then run the delete-branch step |

### Step-by-step configuration

1. Confirm in **Blitzy** that the Neon API key carrying branch create and delete permission is stored as an **encrypted secret** per <https://docs.blitzy.com/administration/environments>, sourced from STORY-02-01-01.
2. Document the create-branch-from-production step that runs at pipeline start and derives the branch name from the CI run identifier (the CI run id, the commit SHA, or the pull-request number) so the name is distinct per run.
3. Document exporting the new branch's connection string to the test job as `DATABASE_URL`, and applying migrations through the unpooled `DATABASE_URL_UNPOOLED` on the PostgreSQL 15+ branch before the test suite reads the pooled `DATABASE_URL`.
4. Document the delete-branch-on-completion step that runs on a passing run AND on a failing run, so no ephemeral branch outlives its pipeline.
5. Document detection-and-reaping of orphaned branches carrying a run-scoped name left by a prior crashed run, executed before a new branch is created.

## Acceptance Criteria

1. **(valid-output)** **Given** a CI run starts, **When** the branch step executes, **Then** a new branch is created from the production branch and its connection string is exported to the test job as `DATABASE_URL`.
2. **(valid-output)** **Given** the CI run finishes (pass or fail), **When** teardown executes, **Then** the ephemeral branch is deleted and a post-run branch list contains 0 branches with that run's name.
3. **(error-handling)** **Given** teardown was skipped because a runner crashed, **When** the next CI run starts, **Then** stale ephemeral branches are identified and reaped before a new branch is created.
4. **(edge-case)** **Given** two CI runs execute in parallel, **When** each creates its branch, **Then** each run holds a distinct ephemeral branch (2 branches) with no shared state.
5. **(input-validation)** **Given** the Neon API key is absent, **When** the branch-creation step runs, **Then** the job exits non-zero with a named authentication error and 0 ephemeral branches are created.
6. **(error-handling)** **Given** the Neon API returns a non-2xx response to the create call, **When** the failure is detected, **Then** the run aborts with the named API error, 0 integration tests run, and the test job's `DATABASE_URL` is never set to the production-branch connection string.
7. **(input-validation)** **Given** the branch-creation step constructs the branch name, **When** the name is built, **Then** it embeds the CI run identifier (the run id, the commit SHA, or the pull-request number) so the name is unique per run and two runs never collide on one branch.
8. **(edge-case)** **Given** the ephemeral branch is a copy-on-write clone of the production branch, **When** migrations create the `valuation` table with its `UNIQUE NULLS NOT DISTINCT` constraint, **Then** the branch reports a PostgreSQL server version of 15 or higher and the constraint is created with exit code 0 — a server below 15 rejects the constraint.

## Sub-tasks

- Document the create-branch-from-production step keyed on the CI run identifier (run id, commit SHA, or pull-request number) — `@devops-engineer`
- Export the branch connection string to the test job as `DATABASE_URL` — `@devops-engineer`
- Document the delete-branch-on-completion step that runs on success AND failure — `@devops-engineer`
- Document detection-and-reaping of orphaned branches from prior crashed runs — `@platform-engineer`
- Store the Neon API key as an encrypted secret per <https://docs.blitzy.com/administration/environments> — `@platform-engineer`

## Edge Cases

- **Empty/Null:** a CI run that performs no test-DB writes still tears its branch down cleanly, leaving 0 residual branches with that run's name.
- **Boundary:** a branch-name collision is avoided because the name embeds the CI run id, so each run name is unique and 2 concurrent runs hold 2 distinct names.
- **Invalid:** a failed branch-create aborts the run with a named error and 0 integration tests run, and no production-branch connection string is assigned to the test job's `DATABASE_URL`.
- **Concurrent:** parallel CI runs are isolated — each run gets a distinct branch and neither run sees the other run's writes.

## Dependencies

### Upstream (must be complete first)

- **[STORY-02-01-01 — Provision the Neon Project & Production Branch](STORY-02-01-01-provision-neon-project-and-production-branch.md):** supplies the production parent branch that every ephemeral branch clones from, plus the Neon API key and connection strings stored as encrypted secrets that this story reads.
- **`EPIC-01` — Environment & Configuration Foundation:** supplies the Blitzy environments and the secrets baseline into which the Neon API key is stored as an encrypted secret. Cited cross-epic by identifier.

### Downstream (informational — not a build prerequisite of this story)

- **`EPIC-06` `STORY-06-01-03` (wire integration tests to a per-CI Neon branch):** depends **directly** on this story — its integration suite consumes the create-from-production and delete-on-completion mechanics documented here. Cited cross-epic by identifier.
- **`EPIC-02` `STORY-02-02-03`:** its `migrate.yml` rehearses migrations against an ephemeral branch of the kind this story documents, running DDL on the unpooled `DATABASE_URL_UNPOOLED`. Cited by identifier.

### Sibling stories

- **[STORY-02-01-02 — Configure Per-PR Preview Branches](STORY-02-01-02-configure-per-pr-preview-branches.md)** and **[STORY-02-01-04 — Document Pooled & Unpooled Connections](STORY-02-01-04-document-pooled-and-unpooled-connections.md):** the per-branch connection strings the ephemeral branch exposes follow the same pooled-versus-unpooled rule documented in STORY-02-01-04.

## Story Estimation Guidance

- **Effort: Medium** — the work documents the full branch lifecycle (create from production, export the connection string, migrate, test, delete) plus the orphan-reaping path, which exceeds a single-step edit but stays short of multi-system implementation.
- **Complexity: Medium** — it spans the Neon branch create-and-delete API and the GitHub Actions job lifecycle (create at start, teardown on both success and failure, run-scoped naming for concurrency), each of which must hold for a run to stay isolated.
- **Uncertainty: Medium** — the branching topology is fixed by STORY-02-01-01, yet the exact Neon API responses and the teardown-on-failure and orphan-reaping paths carry integration unknowns until a sample CI run exercises them.
- **Fibonacci Story Points: 5.** The multi-step branch lifecycle plus the failure-teardown and orphan-reaping paths lift this above a 3; the fixed upstream production branch and the documentation-only scope hold it below an 8. Points measure relative size, not a duration.

## Definition of Done

- [ ] A per-CI ephemeral branch is created from the production branch at CI pipeline start.
- [ ] The test job's `DATABASE_URL` is set to that ephemeral branch's connection string.
- [ ] The branch is deleted on completion on a passing run AND on a failing run, leaving 0 residual branches with that run's name.
- [ ] Orphaned-branch detection and reaping (for branches left by a prior crashed run) is documented and runs before a new branch is created.
- [ ] The branch name embeds the CI run identifier (run id, commit SHA, or pull-request number) so two concurrent runs hold two distinct branch names.
- [ ] The ephemeral branch inherits PostgreSQL 15+ from production, anchored to the `valuation` table's `UNIQUE NULLS NOT DISTINCT` constraint.
- [ ] The Neon API key is stored as an encrypted secret per <https://docs.blitzy.com/administration/environments>.
- [ ] The downstream `EPIC-06` `STORY-06-01-03` dependency on this story is recorded.
- [ ] No prohibited vague quality term appears in any acceptance criterion; every criterion names a measurable pass/fail condition (an exact state, a named error, an exit code, or a branch count).
- [ ] All relative links resolve: the parent feature index, the parent epic index, and the sibling stories STORY-02-01-01, STORY-02-01-02, and STORY-02-01-04.
- [ ] **Testing:** A CI run creates an ephemeral branch from production, runs a query against it, and deletes it on completion with 0 residual branches.
