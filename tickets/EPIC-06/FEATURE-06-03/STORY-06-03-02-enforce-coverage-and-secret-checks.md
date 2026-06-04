# STORY-06-03-02: Enforce Coverage & Secret Checks

**Parent feature:** [FEATURE-06-03 — CI/CD Pipeline & Quality Gates](../FEATURE-06-03-cicd-pipeline-and-quality-gates.md) · **Epic:** [EPIC-06 — Testing & CI/CD Quality Gates](../../EPIC-06-testing-and-cicd-quality-gates.md)

## User Story

> As a **DevOps Engineer**, I want the CI pipeline to enforce per-area coverage thresholds and to assert that required secrets are present, so that a pull request that drops coverage below a named threshold or omits a required secret is blocked before merge.

This story extends the `ci.yml` workflow created by `STORY-06-03-01`: it adds a coverage gate and a secret-presence assertion that turn the unit, integration, and Apify-helper suites from `FEATURE-06-02` into a merge-blocking contract. The coverage gate reads the line-coverage report emitted by Vitest and fails the build when any per-area minimum is unmet — parsers/validators/score below 90%, API/jobs below 75%, Apify helpers below 90%, or UI below 50%. The secret-presence assertion fails the run when a required secret is absent from the CI environment, with the Neon test `DATABASE_URL` as the canonical example; secrets live in GitHub Actions encrypted secrets and are never committed to the repository. A non-zero exit from either step fails the GitHub Action and marks the job failed, which blocks the merge. This story is triggered by the `pull_request` event and defines no schedule. This is a planning ticket; the coverage gate and the secret-presence step are authored when this story is executed.

## Acceptance Criteria

1. **(input-validation — missing secret)** *Given* a required secret (for example the Neon test `DATABASE_URL`) is absent from the CI environment, *When* the secret-presence step runs, *Then* the step exits non-zero and the log names the missing secret.

2. **(valid-output — all thresholds met)** *Given* a test run whose line coverage meets or exceeds every threshold (parsers/validators/score >=90%, API/jobs >=75%, Apify helpers >=90%, UI >=50%) and every required secret is present, *When* the coverage gate evaluates the report, *Then* the gate exits zero and the job is marked passing.

3. **(error-handling — below a named threshold)** *Given* a test run whose parsers/validators/score line coverage is below 90%, *When* the coverage gate evaluates the report, *Then* the build exits non-zero and the log identifies the missed threshold (parsers/validators/score >=90%) and the measured value.

4. **(error-handling — a second area)** *Given* API/jobs line coverage below 75%, or Apify helpers line coverage below 90%, or UI line coverage below 50%, *When* the coverage gate runs, *Then* the build exits non-zero and the log names the specific area and the numeric threshold it missed.

5. **(edge-case — exact boundary passes)** *Given* line coverage exactly at a threshold boundary (for example API/jobs at 75.0%), *When* the coverage gate runs, *Then* the gate treats the boundary as passing and exits zero.

6. **(edge-case — one point below fails)** *Given* line coverage one point below a named threshold (for example parsers/validators/score at 89%), *When* the coverage gate runs, *Then* the build exits non-zero and the log names that threshold (parsers/validators/score >=90%).

7. **(edge-case — empty/absent report)** *Given* the coverage report is empty or absent, *When* the coverage gate runs, *Then* the build exits non-zero and the log states that no coverage report was produced.

## Sub-tasks

- Configure the test runner to emit a line-coverage report consumed by the CI coverage gate. `@devops-engineer`
- Encode the four per-area thresholds (parsers/validators/score >=90%, API/jobs >=75%, Apify helpers >=90%, UI >=50%) into the gate as line-coverage minimums. `@devops-engineer`
- Add a secret-presence assertion that fails the run and names any missing required secret (for example the Neon test `DATABASE_URL`). `@release-engineer`
- Make the gate exit non-zero and name the missed area when a per-area threshold is unmet. `@devops-engineer`
- Verify a line-coverage value exactly at a threshold is treated as passing. `@qa-engineer`

## Edge Cases

- **Empty/Null:** an empty or absent coverage report — the build exits non-zero and the log states that no report was produced.
- **Boundary:** line coverage exactly at a threshold passes; one point below the same threshold fails.
- **Invalid:** a required secret missing from the environment — the run exits non-zero and the log names the secret.
- **Invalid (malformed report):** a coverage report the gate cannot parse — the build exits non-zero and the log names the parse failure.

## Dependencies

- `STORY-06-03-01` — the `ci.yml` workflow that hosts the coverage gate and the secret-presence step.
- `FEATURE-06-02` — the unit, integration, and Apify-helper suites whose line coverage is measured.
- `EPIC-01` — the GitHub Actions encrypted secrets the secret-presence step asserts.

## Story Estimation Guidance

- **Effort:** Medium — wire coverage reporting and threshold/secret gating into CI and validate against passing and failing pull requests.
- **Complexity:** Medium — per-area coverage parsing and four distinct numeric thresholds.
- **Uncertainty:** Low-to-Medium — the four thresholds are fixed; the report-parsing wiring is the variable.
- **Fibonacci points:** **3** — the four fixed thresholds and the single secret-presence assertion hold this below a 5, while the coverage-report parsing and the pass/fail validation place it above a 1.

## Definition of Done

- [ ] The four thresholds are encoded exactly: parsers/validators/score >=90%, API/jobs >=75%, Apify helpers >=90%, UI >=50%.
- [ ] A missing required secret fails the run and names the missing secret.
- [ ] Coverage below any named threshold fails the build and identifies the area and the measured value.
- [ ] Coverage exactly at a threshold passes; one point below the same threshold fails.
- [ ] An empty, absent, or unparseable coverage report fails the build.
- [ ] **Testing:** a pull request below a threshold is blocked, and a compliant pull request (every threshold met, all required secrets present) passes.
