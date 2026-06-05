# STORY-02-01-02: Configure Per-PR Preview Branches

*Parent feature: [FEATURE-02-01 — Neon Project & Branching Topology](../FEATURE-02-01-neon-project-and-branching-topology.md) · Parent epic: [EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md)*

This is the second story of FEATURE-02-01. It documents the per-PR Neon preview branch: one copy-on-write branch created from the production branch for each pull request, paired with that PR's Vercel preview deployment, with the preview deployment's `DATABASE_URL` pointed at its own isolated branch so the preview never reads production data, and the branch deleted when the pull request is closed or merged. A Neon branch is a copy-on-write clone of its parent, so each per-PR branch is cloned from the production branch created in [STORY-02-01-01](STORY-02-01-01-provision-neon-project-and-production-branch.md); the clone is near-instant and carries the parent's schema and data without a full physical copy. This story documents the create-from-production, point-`DATABASE_URL`-at-the-branch, and delete-on-close mechanics that the Vercel preview deployments in `EPIC-05` consume; it does not provision the Neon project, the production branch, or the Neon secrets — those are sourced from [STORY-02-01-01](STORY-02-01-01-provision-neon-project-and-production-branch.md).

## User Story

> As a **DevOps Engineer**, I want one Neon preview branch created per pull request, so that each PR / preview deployment runs against an isolated copy-on-write database.

## Environment Access & Configuration

- **Canonical reference.** All environment provisioning for this story follows the Blitzy environments reference at <https://docs.blitzy.com/administration/environments>. Per that reference, an environment is created for each target, build and run instructions are supplied in natural language, non-sensitive values are stored as **plaintext variables** and sensitive credentials are stored as **encrypted secrets**, and the environment is then **attached to the project**.
- **Platforms named.** Two platforms are wired together for this story:
  - **Neon** — holds the production branch (the parent) and exposes a branch create-and-delete API. The per-PR preview branch is created as a copy-on-write clone of the production branch when a pull request opens, and deleted when the pull request closes or merges.
  - **Vercel + GitHub** — the Vercel↔Neon integration triggers a preview deployment for each pull request and supplies that preview deployment's `DATABASE_URL` from the PR's own branch connection string, so the preview app reads its isolated branch and never the production branch.
- **Encrypted secret.** The Neon API key / integration token carrying branch create and delete permission is stored as an **encrypted secret** per <https://docs.blitzy.com/administration/environments>; it is never stored as a plaintext variable and never written into a workflow body.
- **Engine inheritance.** The preview branch is a copy-on-write clone of the production branch, so it inherits **PostgreSQL 15+** from production — the floor required by the `valuation` table's `UNIQUE NULLS NOT DISTINCT (variation_id, grade_id, window_days, cost_basis)` constraint, which any Postgres server below 15 rejects.
- **Source of the parent and secrets.** The production parent branch, the Neon API key / integration token, and the pooled and unpooled connection strings are provisioned and stored as encrypted secrets in [STORY-02-01-01](STORY-02-01-01-provision-neon-project-and-production-branch.md); this story reads them and documents the per-PR branch lifecycle rather than duplicating those provisioning steps.

### Platforms and access required

| Platform | Access required | Purpose in STORY-02-01-02 |
|----------|-----------------|---------------------------|
| Blitzy | Environment per target; plaintext variables and encrypted secrets | Confirm the Neon API key / integration token is stored as an encrypted secret per <https://docs.blitzy.com/administration/environments> |
| Neon | API key / integration token carrying branch create and delete permission; the production parent branch | Create one per-PR preview branch from production when a PR opens, and delete it when the PR closes or merges |
| Vercel + GitHub | The Vercel↔Neon integration; one preview deployment per pull request | Trigger a preview deployment per PR and set that preview deployment's `DATABASE_URL` to its branch connection string |

### Step-by-step configuration

1. Confirm in **Blitzy** that the Neon API key / integration token carrying branch create and delete permission is stored as an **encrypted secret** per <https://docs.blitzy.com/administration/environments>, sourced from STORY-02-01-01.
2. Enable the Vercel↔Neon integration so that opening a pull request creates one copy-on-write preview branch from the production branch and triggers that PR's preview deployment.
3. Point the preview deployment's `DATABASE_URL` at the PR branch's own connection string, so the preview app reads its isolated branch and never the production branch.
4. Configure cleanup so that closing or merging the pull request deletes that PR's preview branch, leaving 0 residual branches for the PR.
5. Surface a preview-branch-creation failure as a failed status check on the pull request, so the PR is not marked deploy-ready while its branch is absent.

## Acceptance Criteria

1. **(valid-output)** **Given** a new pull request, **When** the integration runs, **Then** exactly one Neon branch is created from the production branch for that PR and the preview deployment's `DATABASE_URL` points at that branch.
2. **(valid-output)** **Given** a pull request is closed or merged, **When** cleanup runs, **Then** that PR's preview branch is deleted and a post-cleanup branch list contains 0 residual branches for that PR.
3. **(error-handling)** **Given** preview-branch creation fails, **When** the PR pipeline runs, **Then** the failure is surfaced as a failed status check (not silently ignored) and the PR is not marked deploy-ready.
4. **(edge-case)** **Given** two open pull requests, **When** both integrations run, **Then** each PR has a distinct, isolated branch (2 branches, no shared state).
5. **(input-validation)** **Given** the Neon API key / integration token is absent, **When** the integration attempts a branch operation, **Then** it fails with a named authentication error and 0 preview branches are created.
6. **(edge-case)** **Given** a previously closed pull request is re-opened, **When** the integration runs, **Then** the branch is reused or recreated deterministically so that exactly one branch exists for that PR and never two.
7. **(valid-output)** **Given** a per-PR preview branch is in use, **When** the preview deployment queries its database, **Then** every read resolves against the PR's own branch and 0 reads resolve against the production branch.

## Sub-tasks

- Configure the Neon↔Vercel/GitHub integration to create one preview branch from production per PR — `@devops-engineer`
- Point each preview deployment's `DATABASE_URL` at its PR branch's connection string — `@devops-engineer`
- Configure cleanup to delete the preview branch on PR close/merge — `@devops-engineer`
- Surface a branch-creation failure as a failed status check — `@platform-engineer`
- Store the Neon API key / integration token as an encrypted secret per <https://docs.blitzy.com/administration/environments> — `@platform-engineer`

## Edge Cases

- **Empty/Null:** a pull request with no database changes still receives a usable preview branch — a connectable copy-on-write branch is created from production even when the PR touches 0 tables.
- **Boundary:** many concurrent open pull requests are bounded by the Neon branch quota — the number of live preview branches is a known count, and the delete-on-close cleanup keeps that count within quota.
- **Invalid:** a re-opened pull request resolves to exactly one branch for that PR — the branch is reused or recreated deterministically and is never duplicated into two.
- **Concurrent:** parallel pull-request opens each create a distinct branch with no shared state, so neither PR's preview reads the other PR's data.

## Dependencies

### Upstream (must be complete first)

- **[STORY-02-01-01 — Provision the Neon Project & Production Branch](STORY-02-01-01-provision-neon-project-and-production-branch.md):** supplies the production parent branch that every per-PR preview branch clones from, plus the Neon API key / integration token and connection strings stored as encrypted secrets that this story reads.
- **`EPIC-01` — Environment & Configuration Foundation:** supplies the Blitzy environments and the secrets baseline into which the Neon API key / integration token is stored as an encrypted secret. Cited cross-epic by identifier.

### Downstream / Related (informational — not a build prerequisite of this story)

- **`EPIC-05` — Frontend User Interface:** its Vercel preview deployments consume the per-PR preview branches documented here, reading each PR's isolated branch through the preview deployment's `DATABASE_URL`. Cited cross-epic by identifier.

### Sibling stories

- **[STORY-02-01-03 — Configure Per-CI Ephemeral Branches](STORY-02-01-03-configure-per-ci-ephemeral-branches.md)** and **[STORY-02-01-04 — Document Pooled & Unpooled Connections](STORY-02-01-04-document-pooled-and-unpooled-connections.md):** the per-branch connection strings each preview branch exposes follow the same pooled-versus-unpooled rule documented in STORY-02-01-04.

## Story Estimation Guidance

- **Effort: Medium** — the work documents the full per-PR branch lifecycle (create from production on open, point the preview `DATABASE_URL` at the branch, delete on close or merge) plus the failure-surfacing path, which exceeds a single-step edit but stays short of multi-system implementation.
- **Complexity: Medium** — it spans the Neon branch create-and-delete API and the Vercel↔GitHub preview-deployment lifecycle, and both must hold for each preview to stay isolated from the production branch.
- **Uncertainty: Medium** — integration wiring across Neon + Vercel/GitHub carries unknowns (the exact integration responses and the re-opened-PR and branch-quota paths) until a sample pull request exercises them.
- **Fibonacci Story Points: 5.** The multi-step branch lifecycle plus the failure-surfacing and re-opened-PR paths lift this above a 3; the fixed upstream production branch and the documentation-only scope hold it below an 8. Points measure relative size, not a duration.

## Definition of Done

- [ ] Per-PR preview branch automation is configured — one copy-on-write branch is created from the production branch per pull request.
- [ ] Each preview deployment's `DATABASE_URL` points at its own PR branch, and 0 preview reads resolve against the production branch.
- [ ] Branches are deleted on PR close or merge, leaving 0 residual branches for the PR.
- [ ] A re-opened pull request resolves to exactly one branch for that PR (reused or recreated deterministically), never two.
- [ ] A preview-branch-creation failure surfaces as a failed status check, and the PR is not marked deploy-ready.
- [ ] The preview branch inherits PostgreSQL 15+ from the production parent, anchored to the `valuation` table's `UNIQUE NULLS NOT DISTINCT` constraint.
- [ ] The Neon API key / integration token is stored as an encrypted secret per <https://docs.blitzy.com/administration/environments>.
- [ ] No prohibited vague quality term appears in any acceptance criterion; every criterion names a measurable pass/fail condition (an exact branch count, a named error, a failed check, or 0 residual branches).
- [ ] All relative links resolve: the parent feature index, the parent epic index, and the sibling stories STORY-02-01-01, STORY-02-01-03, and STORY-02-01-04.
- [ ] **Testing:** Opening a sample pull request creates exactly one Neon branch from production, and closing it deletes that branch, verified with 0 residual branches.
