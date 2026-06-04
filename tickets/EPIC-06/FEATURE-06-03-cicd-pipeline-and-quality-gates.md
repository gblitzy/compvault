# FEATURE-06-03: CI/CD Pipeline & Quality Gates

*Parent epic: [EPIC-06 — Testing & CI/CD Quality Gates](../EPIC-06-testing-and-cicd-quality-gates.md)*

## Feature Summary

This feature wires the CompVault test harness and suites into an automated GitHub Actions pipeline that gates every merge: a `ci.yml` workflow runs the TypeScript typecheck (`tsc --noEmit`), ESLint, and Vitest on every pull request, and merge-blocking gates reject any pull request whose line coverage falls below a named threshold, whose required secrets are absent, or that lacks an approving review — so regressions are caught before they reach `main`. The business value is a deterministic, automated quality bar that turns the harness and the suites into an enforced contract rather than an advisory checklist. Scope is limited to creating the CI workflow and the merge gates; it does **not** author the unit and integration suites (delivered by [FEATURE-06-02 — Unit & Integration Suites](FEATURE-06-02-unit-and-integration-suites.md)) or the Vitest harness, fixtures, and Neon-branch wiring (delivered by [FEATURE-06-01 — Test Harness & Environment Access](FEATURE-06-01-test-harness-and-environment-access.md)). Branch protection additionally requires a green `migrate.yml` status check, tying this gate to EPIC-02's migration-rehearsal workflow so no schema change merges into `main` without a successful migration run against a Neon branch.

## Environment Access & Configuration

The platform access this feature consumes is provisioned once in EPIC-06's environment-access feature and is documented per the canonical Blitzy environments reference <https://docs.blitzy.com/administration/environments>; the full step-by-step configuration is not duplicated here — see [FEATURE-06-01 — Test Harness & Environment Access](FEATURE-06-01-test-harness-and-environment-access.md). Two platforms are relevant to the pipeline and its gates:

- **GitHub Actions** — the CI runners that execute `ci.yml` on every pull request, plus the encrypted repository or organization secrets the workflow reads (for example the Neon test `DATABASE_URL`).
- **Blitzy** — the environment and secret-storage layer, where non-sensitive values are held as plaintext variables and credentials are held as encrypted secrets per <https://docs.blitzy.com/administration/environments>.

**Runtime floor:** the CI runner pins Node `>=18`, matching both the TypeScript application and the JavaScript Apify actor under test, so one runner toolchain exercises both targets.

## User Stories Index

This feature is delivered through three stories. Each link is relative to this file inside the `EPIC-06/` directory.

1. **[STORY-06-03-01 — Create CI Workflow](FEATURE-06-03/STORY-06-03-01-create-ci-workflow.md)** — create `ci.yml` running the TypeScript typecheck (`tsc --noEmit`), ESLint, and Vitest on every pull request.
2. **[STORY-06-03-02 — Enforce Coverage & Secret Checks](FEATURE-06-03/STORY-06-03-02-enforce-coverage-and-secret-checks.md)** — enforce coverage thresholds (parsers/validators/score **≥90%**, API/jobs **≥75%**, Apify helpers **≥90%**, UI **≥50%**) and secret-presence assertions that fail the run when a required secret is absent.
3. **[STORY-06-03-03 — Configure Branch Protection](FEATURE-06-03/STORY-06-03-03-configure-branch-protection.md)** — configure branch protection on `main` requiring a green `ci.yml` status check, a green `migrate.yml` status check, and at least 1 approving review.

## Dependencies

### Upstream (must be complete first)

- **EPIC-01 — Environment & Configuration Foundation:** supplies the GitHub Actions encrypted secrets and the environment baseline the pipeline reads.
- **[FEATURE-06-01 — Test Harness & Environment Access](FEATURE-06-01-test-harness-and-environment-access.md):** supplies the single Vitest configuration, the `__fixtures__`, the boundary mocks, and the per-CI Neon-branch wiring that `ci.yml` invokes.
- **[FEATURE-06-02 — Unit & Integration Suites](FEATURE-06-02-unit-and-integration-suites.md):** supplies the unit, integration, and Apify-helper suites whose line coverage the gates measure.
- **EPIC-02 — Database Platform & Schema (`STORY-02-02-03`):** supplies the `migrate.yml` migration-rehearsal workflow that branch protection requires to report a green status check before any merge to `main`.

### Validates (informational — not a build prerequisite of this feature)

By gating every merge into `main`, this feature protects the deliverables of **EPIC-02** (schema and migrations), **EPIC-03** (ingestion parsers, the confidence-gated matcher, and the Apify helpers), **EPIC-04** (backend API routes and batch jobs), and **EPIC-05** (frontend UI). A pull request that lowers line coverage below a named threshold, omits a required secret, or fails a required status check is blocked from merging.

## Definition of Done

- [ ] All 3 stories (STORY-06-03-01, STORY-06-03-02, STORY-06-03-03) are complete.
- [ ] `ci.yml` runs the TypeScript typecheck (`tsc --noEmit`), ESLint, and Vitest automatically on every pull request.
- [ ] Coverage thresholds are enforced exactly — parsers/validators/score **≥90%**, API/jobs **≥75%**, Apify helpers **≥90%**, UI **≥50%** — and the build fails when line coverage falls below any named threshold.
- [ ] Secret-presence assertions fail the run when a required secret (for example the Neon test `DATABASE_URL`) is absent.
- [ ] Branch protection on `main` requires a green `ci.yml` status check, a green `migrate.yml` status check, and at least 1 approving review before any merge.
- [ ] No prohibited vague quality term appears in any acceptance-criteria-like statement; every gate states a measurable pass/fail condition.
- [ ] **Testing:** the `ci.yml` pipeline reports a green result on a sample pull request that meets every gate, and blocks a deliberately failing pull request that drops line coverage below a named threshold or omits a required secret.
