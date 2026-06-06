# STORY-02-01-03: Configure CI Against the Shared Dev/QA Branch

*Parent feature: [FEATURE-02-01 — Neon Project & Branching Topology](../FEATURE-02-01-neon-project-and-branching-topology.md) · Parent epic: [EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md)*

This is the third story of FEATURE-02-01. It documents how CI runs against the shared long-lived `dev-qa` Neon branch: a single copy-on-write clone of the `production` branch that every CI run shares, with the CI job's pooled `DATABASE_URL` pointed at the `dev-qa` branch and migrations applied to it through the unpooled `DATABASE_URL_UNPOOLED`. No separate Neon branch is created or torn down for each run. A Neon branch is a copy-on-write clone of its parent, so the `dev-qa` branch is cloned once from the `production` branch created in [STORY-02-01-01](STORY-02-01-01-provision-neon-project-and-production-branch.md) and then kept long-lived. This story documents the connect-to-`dev-qa` mechanics that the EPIC-06 integration suite (`STORY-06-01-03`) consumes directly, and the branch that EPIC-02 `STORY-02-02-03`'s `migrate.yml` rehearses migrations against. It does not provision the project, the `production` branch, or the Neon secrets — those are sourced from [STORY-02-01-01](STORY-02-01-01-provision-neon-project-and-production-branch.md).

> **Lost-isolation note.** Because previews and CI now share the single `dev-qa` branch, per-run database isolation is lost — concurrent CI runs and open PRs share `dev-qa` state. This is the inherent consequence of the two-environment model.

## User Story

> As a **DevOps Engineer**, I want CI to run against the shared long-lived `dev-qa` Neon branch, so that integration tests exercise a production-like database without provisioning a branch for each run.

## Environment Access & Configuration

- **Canonical reference.** All environment configuration for this story follows the Blitzy environments reference at <https://docs.blitzy.com/administration/environments> (informational — Blitzy cannot create environments). The single Blitzy environment is configured manually: build and run instructions are supplied in natural language, non-sensitive values are stored as **plaintext variables** and sensitive credentials are stored as **encrypted secrets**, and the environment is then **attached to the project**.
- **Platforms named.** Two platforms are wired together for this story:
  - **Neon** — holds the protected `production` branch (the parent) and one long-lived `dev-qa` branch cloned from it. CI connects to the shared `dev-qa` branch; no branch is created or deleted for each run.
  - **GitHub Actions** — supplies the CI runners and the encrypted secrets. The runner reads the `dev-qa` branch connection strings (stored as **encrypted secrets** per the environments reference), exports the pooled `DATABASE_URL` to the test job, and applies migrations through the unpooled `DATABASE_URL_UNPOOLED`.
- **Encrypted secret.** The `dev-qa` branch's pooled `DATABASE_URL` and unpooled `DATABASE_URL_UNPOOLED` are stored as **encrypted secrets** per <https://docs.blitzy.com/administration/environments>; they are never stored as plaintext variables and never written into a workflow body.
- **Engine inheritance.** The `dev-qa` branch is a copy-on-write clone of the `production` branch, so it inherits **PostgreSQL 15+** from production — the floor required by the `valuation` table's `UNIQUE NULLS NOT DISTINCT (variation_id, grade_id, window_days, cost_basis)` constraint, which any Postgres server below 15 rejects.
- **Source of the parent and secrets.** The protected `production` parent branch, the Neon project API key, and the pooled and unpooled connection strings are provisioned and stored as encrypted secrets in [STORY-02-01-01](STORY-02-01-01-provision-neon-project-and-production-branch.md); this story reads them and documents how CI targets the shared `dev-qa` branch rather than duplicating those provisioning steps.

### Platforms and access required

| Platform | Access required | Purpose in STORY-02-01-03 |
|----------|-----------------|---------------------------|
| Neon | Project API key; the protected `production` parent branch and the long-lived `dev-qa` branch | Run CI against the shared `dev-qa` branch (no branch is created or torn down for each run) |
| GitHub Actions | CI runners; encrypted secrets holding the `dev-qa` branch pooled `DATABASE_URL` and unpooled `DATABASE_URL_UNPOOLED` | Export the `dev-qa` pooled `DATABASE_URL` to the test job, apply migrations through the unpooled `DATABASE_URL_UNPOOLED`, and run migrations and tests |

### Step-by-step configuration

1. Confirm in **Blitzy** that the `dev-qa` branch's pooled `DATABASE_URL` and unpooled `DATABASE_URL_UNPOOLED` are stored as **encrypted secrets** per <https://docs.blitzy.com/administration/environments>, sourced from STORY-02-01-01.
2. Confirm the single long-lived `dev-qa` branch exists as a copy-on-write clone of the `production` branch (created once, kept long-lived).
3. Export the `dev-qa` branch's pooled `DATABASE_URL` to the CI test job, and apply migrations through the unpooled `DATABASE_URL_UNPOOLED` on the PostgreSQL 15+ branch before the test suite reads the pooled `DATABASE_URL`.
4. Confirm no separate Neon branch is created or torn down for each CI run — all runs share the `dev-qa` branch.
5. Surface a missing or misconfigured `dev-qa` connection as a failed CI run, so the suite does not report green while its database connection is absent.

## Acceptance Criteria

1. **(valid-output)** **Given** a CI run starts, **When** the database step executes, **Then** the run connects to the shared `dev-qa` branch and its pooled `DATABASE_URL` is exported to the test job (no new branch is created for the run).
2. **(valid-output)** **Given** a CI run finishes (pass or fail), **When** the run ends, **Then** the shared `dev-qa` branch is left intact (no separate branch existed for that run to delete) and remains available for the next run.
3. **(error-handling)** **Given** the `dev-qa` connection is missing or misconfigured, **When** the CI run starts, **Then** it fails with a named error and 0 integration tests run.
4. **(edge-case)** **Given** two CI runs execute in parallel, **When** each connects to its database, **Then** both connect to the same shared `dev-qa` branch and therefore share its state — per-run isolation is intentionally traded away (see the lost-isolation note).
5. **(input-validation)** **Given** the Neon project API key is absent, **When** the database step runs, **Then** the job exits non-zero with a named authentication error and 0 connections are opened.
6. **(error-handling)** **Given** the `dev-qa` connection string is misconfigured, **When** the failure is detected, **Then** the run aborts with the named error, 0 integration tests run, and the test job's `DATABASE_URL` is never set to the `production`-branch connection string.
7. **(valid-output)** **Given** a CI run is in progress, **When** it applies migrations, **Then** they are applied to the shared `dev-qa` branch through the unpooled `DATABASE_URL_UNPOOLED`, and the test suite reads the pooled `DATABASE_URL`.
8. **(edge-case)** **Given** the `dev-qa` branch is a copy-on-write clone of the `production` branch, **When** migrations create the `valuation` table with its `UNIQUE NULLS NOT DISTINCT` constraint, **Then** the branch reports a PostgreSQL server version of 15 or higher and the constraint is created with exit code 0 — a server below 15 rejects the constraint.

## Sub-tasks

- Confirm the single long-lived `dev-qa` branch exists as a copy-on-write clone of `production` — `@devops-engineer`
- Export the `dev-qa` branch's pooled `DATABASE_URL` to the CI test job — `@devops-engineer`
- Apply migrations to the shared `dev-qa` branch through the unpooled `DATABASE_URL_UNPOOLED` before the suite runs — `@devops-engineer`
- Surface a missing or misconfigured `dev-qa` connection as a failed CI run — `@platform-engineer`
- Store the `dev-qa` branch connection strings as encrypted secrets per <https://docs.blitzy.com/administration/environments> — `@platform-engineer`

## Edge Cases

- **Empty/Null:** a CI run that performs no test-DB writes still connects cleanly to the shared `dev-qa` branch, which remains available for the next run.
- **Boundary:** many concurrent CI runs all share the single `dev-qa` branch, so the live branch count stays at one regardless of how many runs execute.
- **Invalid:** a misconfigured `dev-qa` connection aborts the run with a named error and 0 integration tests run, and no `production`-branch connection string is assigned to the test job's `DATABASE_URL`.
- **Concurrent:** parallel CI runs all connect to the same `dev-qa` branch and therefore share its state; per-run database isolation is lost (see the lost-isolation note).

## Dependencies

### Upstream (must be complete first)

- **[STORY-02-01-01 — Provision the Neon Project & Production Branch](STORY-02-01-01-provision-neon-project-and-production-branch.md):** supplies the protected `production` parent branch that the shared `dev-qa` branch clones from, plus the Neon project API key and connection strings stored as encrypted secrets that this story reads.
- **`EPIC-01` — Environment & Configuration Foundation:** supplies the single Blitzy environment and the secrets baseline into which the Neon connection strings are stored as encrypted secrets. Cited cross-epic by identifier.

### Downstream (informational — not a build prerequisite of this story)

- **`EPIC-06` `STORY-06-01-03` (wire integration tests to the shared `dev-qa` Neon branch):** depends **directly** on this story — its integration suite consumes the connect-to-`dev-qa` mechanics documented here. Cited cross-epic by identifier.
- **`EPIC-02` `STORY-02-02-03`:** its `migrate.yml` rehearses migrations against the shared `dev-qa` branch this story documents, running DDL on the unpooled `DATABASE_URL_UNPOOLED`. Cited by identifier.

### Sibling stories

- **[STORY-02-01-02 — Configure Preview Deployments Against the Shared Dev/QA Branch](STORY-02-01-02-configure-per-pr-preview-branches.md)** and **[STORY-02-01-04 — Document Pooled & Unpooled Connections](STORY-02-01-04-document-pooled-and-unpooled-connections.md):** the `dev-qa` branch connection strings CI exposes follow the same pooled-versus-unpooled rule documented in STORY-02-01-04.

## Story Estimation Guidance

- **Effort: Low–Medium** — the work documents connecting CI to the shared `dev-qa` branch and applying migrations through the unpooled connection, with no branch lifecycle to manage for each run.
- **Complexity: Low–Medium** — it spans the shared `dev-qa` connection and the GitHub Actions job (export the pooled `DATABASE_URL`, apply migrations through the unpooled `DATABASE_URL_UNPOOLED`), both of which must hold for a run to read `dev-qa` and never `production`.
- **Uncertainty: Low–Medium** — the branching topology is fixed by STORY-02-01-01; the exact `dev-qa` connection wiring carries minor unknowns until a sample CI run exercises it.
- **Fibonacci Story Points: 3.** Removing the per-run branch lifecycle lowers this from the former 5; the shared-`dev-qa` connection and the migration-apply path hold it above a 2. Points measure relative size, not a duration.

## Definition of Done

- [ ] CI runs against the shared long-lived `dev-qa` branch, and no separate Neon branch is created for each run.
- [ ] The test job's `DATABASE_URL` is set to the `dev-qa` branch's pooled connection string, and migrations are applied through the unpooled `DATABASE_URL_UNPOOLED`.
- [ ] The shared `dev-qa` branch is left intact when a run finishes (no separate branch existed for that run to delete).
- [ ] A missing or misconfigured `dev-qa` connection fails the run with a named error, and 0 integration tests run.
- [ ] The test job's `DATABASE_URL` is never set to the `production`-branch connection string.
- [ ] The `dev-qa` branch inherits PostgreSQL 15+ from the `production` parent, anchored to the `valuation` table's `UNIQUE NULLS NOT DISTINCT` constraint.
- [ ] The `dev-qa` branch connection strings are stored as encrypted secrets per <https://docs.blitzy.com/administration/environments>.
- [ ] The downstream `EPIC-06` `STORY-06-01-03` dependency on this story is recorded.
- [ ] The lost-isolation note is recorded: previews and CI share the single `dev-qa` branch, so per-run database isolation is lost.
- [ ] No prohibited vague quality term appears in any acceptance criterion; every criterion names a measurable pass/fail condition (an exact state, a named error, an exit code, or a branch count).
- [ ] All relative links resolve: the parent feature index, the parent epic index, and the sibling stories STORY-02-01-01, STORY-02-01-02, and STORY-02-01-04.
- [ ] **Testing:** A CI run connects to the shared `dev-qa` branch, applies migrations through the unpooled `DATABASE_URL_UNPOOLED`, runs a query against it, and reports green, with the `dev-qa` branch left intact for the next run.
