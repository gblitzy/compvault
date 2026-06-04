# STORY-06-03-03: Configure Branch Protection

**Parent feature:** [FEATURE-06-03 — CI/CD Pipeline & Quality Gates](../FEATURE-06-03-cicd-pipeline-and-quality-gates.md) · **Epic:** [EPIC-06 — Testing & CI/CD Quality Gates](../../EPIC-06-testing-and-cicd-quality-gates.md)

## User Story

> As a **Repository Administrator**, I want branch protection on `main` that requires a green `ci.yml`, a green `migrate.yml`, and at least one approving review before merge, so that no change reaches `main` without passing CI, rehearsing its database migrations, and receiving human review.

This story defines the final merge gate for the repository; it configures repository settings rather than authoring code. Branch protection on `main` is set so a pull request can merge only when three conditions hold at once: the `ci.yml` status check (the typecheck, ESLint, and Vitest workflow from `STORY-06-03-01`, carrying the coverage and secret-presence gates from `STORY-06-03-02`) reports green, the `migrate.yml` status check (EPIC-02's migration-rehearsal workflow from `STORY-02-02-03`, which applies the schema migrations on a Neon branch using the unpooled connection URL) reports green, and at least 1 approving review is recorded. Direct pushes to `main` are blocked, so every change arrives through a pull request. Dismiss-stale-approvals is enabled, so a new commit pushed to an open pull request invalidates a prior approval and a fresh approving review is required before merge. The required-check names registered in the rule match the job names emitted by `ci.yml` and `migrate.yml`, so a renamed or absent workflow job leaves its gate unmet rather than skipped. This is a planning ticket; the branch-protection rule is configured when this story is executed.

## Acceptance Criteria

1. **(input-validation — failing required check)** *Given* a pull request whose required status check `ci.yml` or `migrate.yml` reports a red failing status, *When* a merge is attempted, *Then* the merge control is disabled and the merge is blocked.

2. **(valid-output — happy path)** *Given* a pull request with a green `ci.yml` status check, a green `migrate.yml` status check, and at least 1 approving review, *When* a merge is attempted, *Then* the merge is permitted.

3. **(error-handling — zero approvals)** *Given* a pull request with green `ci.yml` and `migrate.yml` checks but 0 approving reviews, *When* a merge is attempted, *Then* the merge is blocked and the branch-protection rule reports the missing approving review.

4. **(edge-case — direct push)** *Given* branch protection is enabled on `main`, *When* a contributor attempts to push a commit straight to `main` outside a pull request, *Then* the push is rejected.

5. **(edge-case — pending check)** *Given* a required status check is in a pending or queued state, *When* a merge is attempted, *Then* the merge is blocked until that check resolves to a green status.

6. **(edge-case — re-approval on new commit)** *Given* a prior approving review exists and dismiss-stale-approvals is enabled, *When* a new commit is pushed to the pull request, *Then* the prior approval is dismissed and at least 1 fresh approving review is required before merge.

## Sub-tasks

- Enable branch protection on the `main` branch. `@repository-administrator`
- Add `ci.yml` and `migrate.yml` as required status checks that must report green before merge. `@repository-administrator`
- Require at least 1 approving review before merge. `@repository-administrator`
- Block direct pushes to `main` by requiring every change to arrive through a pull request. `@repository-administrator`
- Enable dismiss-stale-approvals so a new commit invalidates a prior approval. `@repository-administrator`
- Verify the required-check names match the workflow job names emitted by `ci.yml` and `migrate.yml`. `@release-engineer`

## Edge Cases

- **Boundary (0 approvals):** a pull request with green `ci.yml` and `migrate.yml` checks but 0 approving reviews — the merge is blocked.
- **Pending (required check not yet green):** a required status check still pending or queued — the merge is blocked until that check reports green.
- **Invalid (direct push):** a push straight to `main` outside a pull request — the push is rejected.
- **Concurrent (stale approval):** a new commit pushed after an approval, with dismiss-stale-approvals enabled — a fresh approving review is required before merge.

## Dependencies

- `STORY-06-03-01` — the `ci.yml` workflow must exist so it can be registered as a required status check.
- `STORY-06-03-02` — the coverage and secret-presence gates that run inside `ci.yml` and contribute to its green or red status.
- `STORY-02-02-03` — EPIC-02's `migrate.yml` migration-rehearsal workflow must exist so it can be registered as a required status check.

## Story Estimation Guidance

- **Effort:** Low — repository-settings configuration, not code authoring.
- **Complexity:** Low-to-Medium — the required-check names must match the workflow job names emitted by `ci.yml` and `migrate.yml`.
- **Uncertainty:** Low — the rule set (green `ci.yml`, green `migrate.yml`, at least 1 approving review, no direct push to `main`) is fully specified.
- **Fibonacci points:** **2** — the fully specified rule set and the settings-only scope hold this below a 3, while matching the required-check names to the workflow job names places it above a 1.

## Definition of Done

- [ ] Branch protection on `main` requires a green `ci.yml` status check and a green `migrate.yml` status check.
- [ ] At least 1 approving review is required before merge.
- [ ] Direct pushes to `main` are rejected; every change arrives through a pull request.
- [ ] Dismiss-stale-approvals is enabled so a new commit invalidates a prior approval.
- [ ] The required-check names match the `ci.yml` and `migrate.yml` workflow job names.
- [ ] **Testing:** a non-compliant pull request (a failing required check or 0 approving reviews) is blocked, and a compliant pull request (green `ci.yml`, green `migrate.yml`, 1 approving review) merges.
