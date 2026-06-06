# EPIC-06: Establish Testing & CI/CD Quality Gates — build a Vitest harness, unit and integration suites on the shared `dev-qa` Neon branch, and a GitHub Actions pipeline enforcing coverage thresholds and branch protection

## Epic Summary

EPIC-06 builds the CompVault quality layer from zero: a Vitest harness covering the TypeScript application and the JavaScript Apify actor, unit and integration suites backed by the shared `dev-qa` Neon branch, and a GitHub Actions pipeline that gates every merge on typecheck, ESLint, Vitest, coverage thresholds, and secret-presence checks. The business value is an automated, deterministic quality bar that blocks regressions before they reach `main` and that exercises real migrations against the shared `dev-qa` Neon branch rather than against mocks. Scope is limited to the test harness, the unit and integration suites, and the CI/CD pipeline with its gates; this epic depends on EPIC-01 for the environment baseline and on the `dev-qa` Neon branch from EPIC-02, and it validates the deliverables of EPIC-02, EPIC-03, EPIC-04, and EPIC-05.

## Environment Access & Configuration

All environment provisioning for this epic follows the canonical Blitzy environments reference: <https://docs.blitzy.com/administration/environments>. Non-sensitive values are stored as plaintext environment variables and credentials are stored as encrypted secrets, after which the environment is attached to the project. This step-by-step configuration is completed in full **before** any test suite runs.

**Runtime floor:** Node `>=20.20.2` for the TypeScript application (root `package.json` `engines.node`); the JavaScript Apify actor under test keeps its own floor of Node `>=18` (from `apify/package.json`). The CI runner pins Node `>=20.20.2`, which satisfies both.

### Platforms and access required

| Platform | Access required | Purpose in EPIC-06 |
|----------|-----------------|--------------------|
| Blitzy | single environment (manual build/run + hand-entered secrets); plaintext variables and encrypted secrets | Store the test `DATABASE_URL` and other CI credentials in the single Blitzy environment per the Blitzy environments reference |
| Neon | Project API key; access to the `production` (protected) and `dev-qa` branches | Use the shared long-lived `dev-qa` branch (alongside the protected `production` branch) and expose its connection string as the test `DATABASE_URL` |
| GitHub Actions | CI runners; encrypted repository or organization secrets | Run typecheck, ESLint, and Vitest on every pull request and inject the secrets the workflow consumes |

### Shared `dev-qa` Neon branch (upstream gate)

1. CI runs target the shared, long-lived `dev-qa` branch (alongside the protected `production` branch) rather than creating a branch per run.
2. The `dev-qa` branch connection string is injected as the integration suite test `DATABASE_URL`; migrations run against it using the unpooled `DATABASE_URL_UNPOOLED` for DDL.
3. The integration suite runs against the migrated `dev-qa` branch.
4. No per-run branch is created or deleted; the `dev-qa` branch persists across pipeline runs.

Because previews and CI now share the single `dev-qa` branch, per-run database isolation is lost — concurrent CI runs and open PRs share `dev-qa` state. This is the inherent consequence of the two-environment model.

This shared branch depends on EPIC-02's branching topology; the branching stories (`STORY-02-01-*`) are a hard prerequisite of `STORY-06-01-03`.

### Step-by-step configuration (complete before suites run)

1. Create the Blitzy environments and store the test `DATABASE_URL` plus the CI credentials as encrypted secrets per <https://docs.blitzy.com/administration/environments>.
2. Grant the CI workflow a Neon API key with access to the `production` (protected) and `dev-qa` branches.
3. Confirm the GitHub Actions runner pins Node `>=20.20.2` for the TypeScript application; the Apify actor's own floor is Node `>=18`.
4. Confirm the Vitest harness reads the injected test `DATABASE_URL` for the integration suite.
5. Validate the wiring with a no-op pipeline run before the suites are authored, so the environment is proven ahead of the first real test execution.

## Features Index

This epic is delivered through three features. Each link is relative to this file inside the `EPIC-06/` directory.

1. **[FEATURE-06-01 — Test Harness & Environment Access](EPIC-06/FEATURE-06-01-test-harness-and-environment-access.md)** — configure Vitest for the TypeScript application and the JavaScript actor and complete the environment access above; establish `__fixtures__` (eBay/LLM JSON, Apify HTML) and boundary mocks; wire integration tests to the shared `dev-qa` Neon branch (depends on EPIC-02 branching).
2. **[FEATURE-06-02 — Unit & Integration Suites](EPIC-06/FEATURE-06-02-unit-and-integration-suites.md)** — author unit tests for parsers/validators/score (coverage ≥90%); author API integration tests against the `dev-qa` Neon branch (coverage ≥75%); author Apify helper tests (`extractItemId`, `parsePrice`, `parseSoldDate`) against HTML fixtures (coverage ≥90%).
3. **[FEATURE-06-03 — CI/CD Pipeline & Quality Gates](EPIC-06/FEATURE-06-03-cicd-pipeline-and-quality-gates.md)** — create `ci.yml` (typecheck + ESLint + Vitest) on every pull request; enforce coverage thresholds and secret-presence assertions; configure branch protection on `main` (green `ci.yml` and `migrate.yml`, ≥1 approval).

## Dependencies

### Upstream (must be complete first)

- **EPIC-01 — Environment & Configuration Foundation:** supplies the Blitzy environments, the Next.js + TypeScript scaffold, and the secrets baseline that the harness and the pipeline consume.
- **EPIC-02 — Database Platform & Schema:** supplies the Neon branching topology. The branching stories (`STORY-02-01-*`) are a hard prerequisite of the shared `dev-qa` Neon branch story (`STORY-06-01-03`); no integration test runs until the `dev-qa` branch is reachable and migrated.

### Validates (informational — not a build prerequisite of this epic)

- **EPIC-02** — schema and migrations executed against a Neon branch.
- **EPIC-03** — ingestion parsers, the confidence-gated matcher, and the Apify helpers.
- **EPIC-04** — backend API routes and batch jobs.
- **EPIC-05** — frontend UI components.

## Definition of Done

- [ ] All 3 child features (FEATURE-06-01, FEATURE-06-02, FEATURE-06-03) are complete.
- [ ] The environment access above is configured per <https://docs.blitzy.com/administration/environments> before any suite runs.
- [ ] The Vitest harness covers both the TypeScript application and the JavaScript Apify actor on Node `>=20.20.2` (the application floor); the Apify actor's own floor is Node `>=18`.
- [ ] `__fixtures__` (eBay/LLM JSON, Apify HTML) and boundary mocks are established.
- [ ] Integration tests run on the shared `dev-qa` Neon branch (alongside the protected `production` branch) (depends on EPIC-02 `STORY-02-01-*`, per <https://docs.blitzy.com/administration/environments>).
- [ ] Coverage thresholds are met: parsers/validators/score **≥90%**; API/jobs **≥75%**; Apify helpers **≥90%**; UI **≥50%**.
- [ ] `ci.yml` runs typecheck + ESLint + Vitest on every pull request, with coverage-threshold gates and secret-presence assertions enforced.
- [ ] Branch protection on `main` requires green `ci.yml` and `migrate.yml` status checks plus ≥1 approval before any merge.
- [ ] **Testing:** the `ci.yml` pipeline is green on a sample pull request, demonstrating that the harness, the unit and integration suites, the coverage gates, and the secret-presence gates run end to end.
