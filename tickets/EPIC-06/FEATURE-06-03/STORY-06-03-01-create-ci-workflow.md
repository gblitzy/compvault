# STORY-06-03-01: Create CI Workflow

**Parent feature:** [FEATURE-06-03 — CI/CD Pipeline & Quality Gates](../FEATURE-06-03-cicd-pipeline-and-quality-gates.md) · **Epic:** [EPIC-06 — Testing & CI/CD Quality Gates](../../EPIC-06-testing-and-cicd-quality-gates.md)

## User Story

> As a **Release Engineer**, I want a `ci.yml` GitHub Actions workflow that runs the TypeScript typecheck (`tsc --noEmit`), ESLint, and Vitest on every pull request using a Node `>=18` runner, so that type errors, lint violations, and failing tests are caught on each pull request before code reaches `main`.

This story describes the base continuous-integration workflow; it does not author the workflow file. The `ci.yml` file lives under `.github/workflows/` alongside `ingest.yml` and `migrate.yml`, and it is triggered by the `pull_request` event rather than on a schedule, so no cron expression is defined here. The workflow runs exactly three checks against the project — the TypeScript typecheck (`tsc --noEmit`), ESLint, and Vitest — on a hosted Node `>=18` runner, the toolchain floor set by both the TypeScript application and the JavaScript Apify actor. A non-zero exit from any step fails the GitHub Action and marks the job failed. This is the base workflow that `STORY-06-03-02` (coverage and secret gates) and `STORY-06-03-03` (branch protection) build on top of. This is a planning ticket; the `ci.yml` workflow file itself is authored when this story is executed.

## Acceptance Criteria

1. **(input-validation — trigger)** *Given* `ci.yml` is committed under `.github/workflows/`, *When* a pull request targeting `main` is opened or updated, *Then* the workflow is triggered by the `pull_request` event and starts its job on a Node `>=18` runner.

2. **(valid-output — happy path)** *Given* a pull request whose code passes all checks, *When* the workflow runs, *Then* the `tsc --noEmit` step, the ESLint step, and the Vitest step each exit zero and the job reports a green status.

3. **(error-handling — type error)** *Given* a pull request that introduces a TypeScript type error, *When* the `tsc --noEmit` step runs, *Then* the step exits non-zero and the job is marked failed.

4. **(error-handling — lint violation)** *Given* a pull request that introduces an ESLint rule violation, *When* the ESLint step runs, *Then* the step exits non-zero and the job is marked failed.

5. **(error-handling — failing test)** *Given* a pull request with a failing Vitest test, *When* the Vitest step runs, *Then* the step exits non-zero and the job is marked failed.

6. **(edge-case — subset of files)** *Given* a pull request that changes only a subset of files (for example a single file under `lib/`), *When* the workflow runs, *Then* all three checks still execute against the project and report a status.

7. **(edge-case — missing command)** *Given* a check command named in the workflow is absent from the project scripts, *When* that step runs, *Then* the step exits non-zero and the log names the missing command.

## Sub-tasks

- Define the `ci.yml` workflow triggered on `pull_request` events. `@release-engineer`
- Add a Node `>=18` setup step and a deterministic dependency-install step. `@release-engineer`
- Add a typecheck step that runs `tsc --noEmit`. `@release-engineer`
- Add an ESLint step. `@release-engineer`
- Add a Vitest step that runs the suites from `FEATURE-06-02`. `@release-engineer`
- Verify that a non-zero exit in any step fails the job. `@devops-engineer`
- Document the workflow's status-check name so branch protection (`STORY-06-03-03`) can require it. `@release-engineer`

## Edge Cases

- **Empty/Null:** a documentation-only pull request with no code changes still triggers the workflow and reports a status.
- **Boundary (cold cache):** the first run with no prior dependency cache builds from a clean state and still completes the three checks.
- **Invalid (missing command):** a check command named in the workflow is missing from the project scripts — the step exits non-zero and names the missing command.
- **Concurrent:** two pull requests run the workflow at the same time, each on an isolated runner, without cross-run interference.

## Dependencies

- `EPIC-01` — the GitHub Actions secrets and environment baseline the workflow runs within.
- `FEATURE-06-01` — the Vitest harness the Vitest step invokes.
- `FEATURE-06-02` — the unit, integration, and Apify-helper suites the workflow runs.

## Story Estimation Guidance

- **Effort:** Medium — author a multi-step workflow and validate it against passing and deliberately failing pull requests.
- **Complexity:** Medium — three coordinated checks on a hosted Node `>=18` runner.
- **Uncertainty:** Low — the workflow shape (typecheck, lint, and test on pull request) is fixed by the PRD.
- **Fibonacci points:** **3** — the bounded three-check shape on a single hosted runner holds this below a 5, while the multi-step authoring and the pass/fail validation place it above a 1.

## Definition of Done

- [ ] `ci.yml` exists under `.github/workflows/` and triggers on `pull_request` events.
- [ ] The workflow runs `tsc --noEmit`, ESLint, and Vitest on a Node `>=18` runner.
- [ ] Any step's non-zero exit fails the job.
- [ ] The workflow's status-check name is documented for branch protection.
- [ ] **Testing:** `ci.yml` runs green on a sample pull request with all three checks executing, and a pull request containing a deliberate type error, a lint violation, or a failing test is marked failed.
