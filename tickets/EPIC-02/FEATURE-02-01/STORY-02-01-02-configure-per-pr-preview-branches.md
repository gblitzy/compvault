# STORY-02-01-02: Configure Preview Deployments Against the Shared Dev/QA Branch

*Parent feature: [FEATURE-02-01 — Neon Project & Branching Topology](../FEATURE-02-01-neon-project-and-branching-topology.md) · Parent epic: [EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md)*

This is the second story of FEATURE-02-01. It documents how every Vercel Preview (dev/qa) deployment connects to the shared long-lived `dev-qa` Neon branch: a single copy-on-write clone of the `production` branch that all non-production branches and pull requests share, with each preview deployment's pooled `DATABASE_URL` and unpooled `DATABASE_URL_UNPOOLED` pointed at the `dev-qa` branch so previews exercise a production-like database and never read `production` data. No separate Neon branch is created or deleted for each pull request. A Neon branch is a copy-on-write clone of its parent, so the `dev-qa` branch is cloned once from the `production` branch created in [STORY-02-01-01](STORY-02-01-01-provision-neon-project-and-production-branch.md) and then kept long-lived. This story documents the point-`DATABASE_URL`-at-the-`dev-qa`-branch mechanics that the Vercel preview deployments in `EPIC-05` consume; it does not provision the Neon project, the `production` branch, or the Neon secrets — those are sourced from [STORY-02-01-01](STORY-02-01-01-provision-neon-project-and-production-branch.md).

> **Lost-isolation note.** Because previews and CI now share the single `dev-qa` branch, per-run database isolation is lost — concurrent CI runs and open PRs share `dev-qa` state. This is the inherent consequence of the two-environment model.

## User Story

> As a **DevOps Engineer**, I want every preview deployment to run against the shared long-lived `dev-qa` Neon branch, so that each non-production deployment exercises a production-like database without provisioning a branch for each pull request.

## Environment Access & Configuration

- **Canonical reference.** All environment configuration for this story follows the Blitzy environments reference at <https://docs.blitzy.com/administration/environments> (informational — Blitzy cannot create environments). The single Blitzy environment is configured manually: build and run instructions are supplied in natural language, non-sensitive values are stored as **plaintext variables** and sensitive credentials are stored as **encrypted secrets**, and the environment is then **attached to the project**.
- **Platforms named.** Two platforms are wired together for this story:
  - **Neon** — holds the protected `production` branch (the parent) and one long-lived `dev-qa` branch cloned from it. The `dev-qa` branch is created once and shared by all previews; it is not created or deleted for each pull request.
  - **Vercel + GitHub** — the Vercel Preview scope applies to all non-production branches and pull requests, and supplies each preview deployment's pooled `DATABASE_URL` / unpooled `DATABASE_URL_UNPOOLED` from the `dev-qa` branch connection strings, so the preview app reads the shared `dev-qa` branch and never the `production` branch.
- **Encrypted secret.** The `dev-qa` branch's pooled `DATABASE_URL` and unpooled `DATABASE_URL_UNPOOLED` are stored as **encrypted secrets** per <https://docs.blitzy.com/administration/environments>; they are never stored as plaintext variables and never written into a workflow body.
- **Engine inheritance.** The `dev-qa` branch is a copy-on-write clone of the `production` branch, so it inherits **PostgreSQL 15+** from production — the floor required by the `valuation` table's `UNIQUE NULLS NOT DISTINCT (variation_id, grade_id, window_days, cost_basis)` constraint, which any Postgres server below 15 rejects.
- **Source of the parent and secrets.** The protected `production` parent branch, the Neon project API key, and the pooled and unpooled connection strings are provisioned and stored as encrypted secrets in [STORY-02-01-01](STORY-02-01-01-provision-neon-project-and-production-branch.md); this story reads them and documents how previews target the shared `dev-qa` branch rather than duplicating those provisioning steps.

### Platforms and access required

| Platform | Access required | Purpose in STORY-02-01-02 |
|----------|-----------------|---------------------------|
| Blitzy | The single Blitzy environment; plaintext variables and encrypted secrets | Confirm the `dev-qa` branch connection strings are stored as encrypted secrets per <https://docs.blitzy.com/administration/environments> |
| Neon | Project API key; the protected `production` parent branch and the long-lived `dev-qa` branch | Point every preview deployment at the shared `dev-qa` branch (no branch is created or deleted for each pull request) |
| Vercel + GitHub | The Vercel Preview scope (all non-production branches and pull requests) | Set each preview deployment's `DATABASE_URL` / `DATABASE_URL_UNPOOLED` to the `dev-qa` branch connection strings |

### Step-by-step configuration

1. Confirm in **Blitzy** that the `dev-qa` branch's pooled `DATABASE_URL` and unpooled `DATABASE_URL_UNPOOLED` are stored as **encrypted secrets** per <https://docs.blitzy.com/administration/environments>, sourced from STORY-02-01-01.
2. Confirm the single long-lived `dev-qa` branch exists as a copy-on-write clone of the `production` branch (created once, kept long-lived).
3. Point every Vercel Preview (dev/qa) deployment's `DATABASE_URL` / `DATABASE_URL_UNPOOLED` at the `dev-qa` branch connection strings, so the preview app reads the shared `dev-qa` branch and never the `production` branch.
4. Confirm no separate Neon branch is created or deleted for each pull request — all previews share the `dev-qa` branch.
5. Surface a missing or misconfigured `dev-qa` connection as a failed status check on the pull request, so the PR is not marked deploy-ready while its database connection is absent.

## Acceptance Criteria

1. **(valid-output)** **Given** a new pull request, **When** the preview deployment runs, **Then** its `DATABASE_URL` / `DATABASE_URL_UNPOOLED` point at the shared `dev-qa` branch and no new Neon branch is created for that pull request.
2. **(valid-output)** **Given** a pull request is closed or merged, **When** cleanup runs, **Then** the shared `dev-qa` branch is left intact (no separate branch existed for that pull request to delete) and remains available for the next preview.
3. **(error-handling)** **Given** the `dev-qa` connection is missing or misconfigured, **When** the PR pipeline runs, **Then** the failure is surfaced as a failed status check (not silently ignored) and the PR is not marked deploy-ready.
4. **(edge-case)** **Given** two open pull requests, **When** both preview deployments run, **Then** both connect to the same shared `dev-qa` branch and therefore share its state — per-run isolation is intentionally traded away (see the lost-isolation note).
5. **(input-validation)** **Given** the Neon project API key is absent, **When** the integration attempts to read the `dev-qa` connection, **Then** it fails with a named authentication error and 0 connections are opened.
6. **(edge-case)** **Given** a previously closed pull request is re-opened, **When** its preview deployment runs, **Then** it connects to the same shared `dev-qa` branch deterministically (there is never a separate branch for that pull request to reuse or recreate).
7. **(valid-output)** **Given** a preview deployment is in use, **When** it queries its database, **Then** every read resolves against the shared `dev-qa` branch and 0 reads resolve against the `production` branch.

## Sub-tasks

- Confirm the single long-lived `dev-qa` branch exists as a copy-on-write clone of `production` — `@devops-engineer`
- Point each preview deployment's `DATABASE_URL` / `DATABASE_URL_UNPOOLED` at the `dev-qa` branch connection strings — `@devops-engineer`
- Confirm no Neon branch is created or deleted for each pull request (all previews share `dev-qa`) — `@devops-engineer`
- Surface a missing or misconfigured `dev-qa` connection as a failed status check — `@platform-engineer`
- Store the `dev-qa` branch connection strings as encrypted secrets per <https://docs.blitzy.com/administration/environments> — `@platform-engineer`

## Edge Cases

- **Empty/Null:** a pull request with no database changes still connects to a usable database — the shared `dev-qa` branch is connectable even when the PR touches 0 tables.
- **Boundary:** many concurrent open pull requests all share the single `dev-qa` branch, so the live branch count stays at one regardless of how many pull requests are open.
- **Invalid:** a re-opened pull request connects to the same shared `dev-qa` branch deterministically — there is never a separate branch for that pull request to duplicate.
- **Concurrent:** parallel pull-request opens all connect to the same `dev-qa` branch and therefore share its state; per-run database isolation is lost (see the lost-isolation note).

## Dependencies

### Upstream (must be complete first)

- **[STORY-02-01-01 — Provision the Neon Project & Production Branch](STORY-02-01-01-provision-neon-project-and-production-branch.md):** supplies the protected `production` parent branch that the shared `dev-qa` branch clones from, plus the Neon project API key and connection strings stored as encrypted secrets that this story reads.
- **`EPIC-01` — Environment & Configuration Foundation:** supplies the single Blitzy environment and the secrets baseline into which the Neon connection strings are stored as encrypted secrets. Cited cross-epic by identifier.

### Downstream / Related (informational — not a build prerequisite of this story)

- **`EPIC-05` — Frontend User Interface:** its Vercel preview deployments consume the shared `dev-qa` branch documented here, reading it through the preview deployment's `DATABASE_URL`. Cited cross-epic by identifier.

### Sibling stories

- **[STORY-02-01-03 — Configure CI Against the Shared Dev/QA Branch](STORY-02-01-03-configure-per-ci-ephemeral-branches.md)** and **[STORY-02-01-04 — Document Pooled & Unpooled Connections](STORY-02-01-04-document-pooled-and-unpooled-connections.md):** the `dev-qa` branch connection strings the preview deployments expose follow the same pooled-versus-unpooled rule documented in STORY-02-01-04.

## Story Estimation Guidance

- **Effort: Low–Medium** — the work documents pointing previews at the shared `dev-qa` branch plus the failure-surfacing path, with no branch lifecycle to manage for each pull request.
- **Complexity: Low–Medium** — it spans the Vercel Preview scope and the shared `dev-qa` connection, both of which must hold for each preview to read `dev-qa` and never `production`.
- **Uncertainty: Low–Medium** — the Vercel Preview wiring against the shared `dev-qa` branch carries minor unknowns until a sample pull request exercises it.
- **Fibonacci Story Points: 3.** Removing the per-pull-request branch lifecycle lowers this from the former 5; the shared-`dev-qa` wiring and the failure-surfacing path hold it above a 2. Points measure relative size, not a duration.

## Definition of Done

- [ ] Every Vercel Preview (dev/qa) deployment points its `DATABASE_URL` / `DATABASE_URL_UNPOOLED` at the shared long-lived `dev-qa` branch, and no separate Neon branch is created for each pull request.
- [ ] 0 preview reads resolve against the `production` branch.
- [ ] The shared `dev-qa` branch is left intact on PR close or merge (no separate branch exists for that pull request to delete).
- [ ] A re-opened pull request connects to the same shared `dev-qa` branch deterministically.
- [ ] A missing or misconfigured `dev-qa` connection surfaces as a failed status check, and the PR is not marked deploy-ready.
- [ ] The `dev-qa` branch inherits PostgreSQL 15+ from the `production` parent, anchored to the `valuation` table's `UNIQUE NULLS NOT DISTINCT` constraint.
- [ ] The `dev-qa` branch connection strings are stored as encrypted secrets per <https://docs.blitzy.com/administration/environments>.
- [ ] The lost-isolation note is recorded: previews and CI share the single `dev-qa` branch, so per-run database isolation is lost.
- [ ] No prohibited vague quality term appears in any acceptance criterion; every criterion names a measurable pass/fail condition (an exact branch count, a named error, a failed check, or "0 reads against production").
- [ ] All relative links resolve: the parent feature index, the parent epic index, and the sibling stories STORY-02-01-01, STORY-02-01-03, and STORY-02-01-04.
- [ ] **Testing:** Opening a sample pull request connects its preview deployment to the shared `dev-qa` branch (no new branch created), and 0 preview reads resolve against the `production` branch.
