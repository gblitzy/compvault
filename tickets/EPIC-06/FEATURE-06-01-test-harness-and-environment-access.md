# FEATURE-06-01: Test Harness & Environment Access

*Parent epic: [EPIC-06 — Testing & CI/CD Quality Gates](../EPIC-06-testing-and-cicd-quality-gates.md)*

## Feature Summary

This feature stands up the CompVault test harness from zero: a single Vitest configuration that runs both the TypeScript application and the ES-module JavaScript Apify actor on one runtime, a shared `__fixtures__` and boundary-mock foundation, and integration tests wired to an isolated per-CI Neon branch. The business value is a deterministic, repeatable execution environment so every later suite has one known place to run, and so integration tests exercise real schema migrations against an isolated branch rather than against mocks. Scope is limited to standing up the harness, the fixtures, the boundary mocks, and the Neon-branch wiring, and to documenting EPIC-06's environment access; it does **not** author the unit and integration suites (FEATURE-06-02) or the CI/CD pipeline gates (FEATURE-06-03).

## Environment Access & Configuration

All environment provisioning for this feature follows the canonical Blitzy environments reference: <https://docs.blitzy.com/administration/environments>. Per that reference, an environment is created for each target, build and run instructions are supplied in natural language, non-sensitive values are stored as plaintext environment variables and credentials are stored as encrypted secrets, and the environment is then attached to the project. This step-by-step configuration is completed in full **before** the suites in FEATURE-06-02 and the pipeline gates in FEATURE-06-03 run.

**Runtime floor:** Node `>=18` for both the TypeScript application and the JavaScript Apify actor under test, matching the actor's `engines.node` declaration. The CI runner pins the project Node version at or above this floor so the harness exercises both targets on one runtime.

### Platforms and access required

| Platform | Access required | Purpose in FEATURE-06-01 |
|----------|-----------------|--------------------------|
| Blitzy | Environment per target; plaintext variables and encrypted secrets | Store the test `DATABASE_URL` and CI credentials as encrypted secrets per <https://docs.blitzy.com/administration/environments> |
| Neon | Project API key with branch create and delete permission | Provision the per-CI ephemeral test branch and expose its connection string as the integration-suite `DATABASE_URL` |
| GitHub Actions | CI runners; encrypted repository or organization secrets | Run the Vitest harness on every pull request and inject the secrets the harness consumes |

### Per-CI Neon branch lifecycle (upstream gate)

1. At pipeline start, a Neon branch is created as a copy-on-write clone of the production branch.
2. The branch connection string is injected as the integration-suite test `DATABASE_URL`; schema migrations run against it using the unpooled `DATABASE_URL_UNPOOLED` for DDL (the `valuation` table's `UNIQUE NULLS NOT DISTINCT` constraint requires PostgreSQL 15+).
3. The integration suite runs against the freshly migrated branch.
4. On pipeline completion — whether the run passes or fails — the branch is deleted, so no ephemeral branch outlives its pipeline.

This lifecycle depends on EPIC-02's branching topology; the branching stories (`STORY-02-01-*`) are a hard prerequisite of `STORY-06-01-03`.

### Step-by-step configuration (complete before suites run)

1. Create the Blitzy environment and store the test `DATABASE_URL` plus CI credentials as encrypted secrets per <https://docs.blitzy.com/administration/environments>.
2. Grant the CI workflow a Neon API key that carries branch create and delete permission.
3. Pin the GitHub Actions runner to Node `>=18` so both the TypeScript application and the JavaScript actor execute on one runtime.
4. Confirm the Vitest harness reads the injected test `DATABASE_URL` for the integration suite and resolves `__fixtures__` and boundary mocks from one shared path.
5. Run a no-op `vitest run` to prove the wiring before the suites are authored, so the environment is validated ahead of the first real test execution.

## User Stories Index

This feature is delivered through three stories. Each link is relative to this file inside the `EPIC-06/` directory.

1. **[STORY-06-01-01 — Configure Vitest & Environment Access](FEATURE-06-01/STORY-06-01-01-configure-vitest-and-env-access.md)** — configure Vitest for the TypeScript application and the ES-module JavaScript actor on Node `>=18`; configure the environment access above and cite <https://docs.blitzy.com/administration/environments>.
2. **[STORY-06-01-02 — Establish Fixtures & Boundary Mocks](FEATURE-06-01/STORY-06-01-02-establish-fixtures-and-boundary-mocks.md)** — establish `__fixtures__` (eBay and LLM JSON, plus Apify HTML mirroring the `li.s-item` and `li.s-card` cards the actor parses) and boundary mocks that stub the network/proxy boundary and the LLM.
3. **[STORY-06-01-03 — Wire Integration Tests to a Neon Branch](FEATURE-06-01/STORY-06-01-03-wire-integration-tests-to-neon-branch.md)** — wire integration tests to a per-CI Neon branch created from production at pipeline start and torn down on completion; depends on EPIC-02 branching (`STORY-02-01-*`).

## Dependencies

### Upstream (must be complete first)

- **EPIC-01 — Environment & Configuration Foundation:** supplies the Blitzy environment, the Next.js + TypeScript scaffold, and the secrets baseline the harness consumes.
- **EPIC-02 — Database Platform & Schema (`STORY-02-01-*`):** supplies the Neon branching topology. The branching stories are a hard prerequisite of the per-CI Neon test-branch story (`STORY-06-01-03`); no integration test runs until a branch can be created from production and deleted on completion.

### Downstream (informational — not a build prerequisite of this feature)

- **[FEATURE-06-02 — Unit & Integration Suites](FEATURE-06-02-unit-and-integration-suites.md):** runs its unit, integration, and Apify-helper suites on this harness and against this Neon-branch wiring.
- **[FEATURE-06-03 — CI/CD Pipeline & Quality Gates](FEATURE-06-03-cicd-pipeline-and-quality-gates.md):** invokes this harness from `ci.yml` and enforces coverage and secret-presence gates over it.

## Definition of Done

- [ ] All 3 stories (STORY-06-01-01, STORY-06-01-02, STORY-06-01-03) are complete.
- [ ] A single Vitest configuration runs both the TypeScript application and the ES-module JavaScript Apify actor on Node `>=18`.
- [ ] `__fixtures__` (eBay and LLM JSON, Apify HTML for `li.s-item` and `li.s-card` cards) and boundary mocks (network/proxy and LLM) are established and importable by the suites.
- [ ] Integration tests connect to a per-CI Neon branch that is created from the production branch at pipeline start and deleted on completion, configured per <https://docs.blitzy.com/administration/environments>.
- [ ] The EPIC-02 branching dependency (`STORY-02-01-*` as the hard prerequisite of `STORY-06-01-03`) is documented in the story.
- [ ] The environment access above is configured per <https://docs.blitzy.com/administration/environments>, with non-sensitive values stored as plaintext variables and credentials stored as encrypted secrets, before any suite runs.
- [ ] **Testing:** a sample `vitest run` executes against the harness and the per-CI Neon branch, resolves the `__fixtures__` and boundary mocks, and reports pass/fail results for at least one TypeScript test and one JavaScript actor test.
