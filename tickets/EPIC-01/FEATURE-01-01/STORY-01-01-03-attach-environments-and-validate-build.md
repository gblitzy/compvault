# STORY-01-01-03: Attach Environments & Validate Build

## User Story
**As a** Platform Engineer, **I want** to attach the environments to the project and validate each with a test build, **so that** the foundation is confirmed working before dependent epics proceed.

## Environment Access & Configuration
This story completes EPIC-01's mandatory per-epic environment-access obligation for FEATURE-01-01. Follow the canonical reference: <https://docs.blitzy.com/administration/environments>.

- **Platform:** Blitzy — the `Dev`, `Staging`, and `Prod` environments created in [STORY-01-01-01](STORY-01-01-01-create-blitzy-environments.md) and configured in [STORY-01-01-02](STORY-01-01-02-define-secrets-and-variables.md).
- **Doc essence applied here:** attach the environment to the project (the final step in the reference), then validate the attachment with a build.
- **Build/run target:** Next.js App Router on Vercel; the build runs on Node `>=18`.

### Step-by-step configuration (complete BEFORE dependent work)
1. Attach the `Dev`, `Staging`, and `Prod` environments to the project per <https://docs.blitzy.com/administration/environments>.
2. Trigger a test/preview build on each environment using the build instruction from STORY-01-01-01.
3. Capture each build's exit code and record the result in the runbook.
4. For any non-zero build, identify the missing variable or secret (defined in STORY-01-01-02) and re-trigger after the fix.
5. Record a validation summary listing each environment's attached and validated status.

## Acceptance Criteria (Given/When/Then)
1. **(Valid output)** **Given** the three configured environments, **when** each is attached to the project per <https://docs.blitzy.com/administration/environments>, **then** the project lists `Dev`, `Staging`, and `Prod` as attached environments.
2. **(Valid output — build)** **Given** an attached environment, **when** a test build is triggered, **then** the build runs on Node `>=18`, completes the Next.js App Router build, and the build process exits `0`.
3. **(Error handling)** **Given** an environment missing a required active secret (for example `DATABASE_URL`), **when** a test build is triggered, **then** the build halts with a non-zero exit code, the log names the missing key, and the environment is not marked validated.
4. **(Input validation)** **Given** the attach action, **when** an environment identifier that does not exist is supplied, **then** the attach is rejected and the project's attached-environment list is unchanged.
5. **(Edge case — isolation)** **Given** the Prod environment, **when** a test build runs against Dev, **then** the Prod environment is not invoked and its status is unchanged.
6. **(Valid output)** **Given** all three environments are attached and each test build exits `0`, **when** the validation summary is recorded, **then** all three environments show a `validated` status.
7. **(Error handling — re-run)** **Given** a previously failed environment, **when** the missing secret is added and the test build is re-triggered, **then** the build exits `0` and the environment transitions to `validated`.

## Sub-Tasks
- [ ] Attach the `Dev`, `Staging`, and `Prod` environments to the project per <https://docs.blitzy.com/administration/environments>. `@platform-engineer`
- [ ] Trigger a test/preview build on each environment using the STORY-01-01-01 build instruction. `@platform-engineer`
- [ ] Capture each build's exit code and log the result in the runbook. `@platform-engineer`
- [ ] For any non-zero build, identify the missing variable/secret from STORY-01-01-02 and re-run after the fix. `@devops-engineer`
- [ ] Record a validation summary listing each environment's attached and validated status. `@platform-engineer`

## Edge Cases
- **Empty/Null:** the attach action is submitted with an empty environment identifier — the action is rejected and the attached list is unchanged.
- **Boundary:** all three environments must be attached and each test build must exit `0`; if two of the three pass, the feature is not marked done.
- **Invalid:** a non-existent environment identifier is supplied to the attach action — the action is rejected.
- **Concurrent:** two builds are triggered on one environment at the same time — each reports an exit code and the environment's `validated` state reflects the last completed exit-`0` build.

## Dependencies
- **Upstream:** [STORY-01-01-01](STORY-01-01-01-create-blitzy-environments.md) (the environments exist) and [STORY-01-01-02](STORY-01-01-02-define-secrets-and-variables.md) (variables and secrets are defined).
- **Downstream (informational):** [FEATURE-01-02](../FEATURE-01-02-application-scaffolding-and-tooling.md) and [FEATURE-01-03](../FEATURE-01-03-secrets-and-variable-management.md) build within these validated environments, and EPIC-02 through EPIC-06 depend on them. Parent feature: [FEATURE-01-01](../FEATURE-01-01-blitzy-environment-provisioning.md). Parent epic: [EPIC-01](../../EPIC-01-environment-and-configuration-foundation.md).

## Story Estimation Guidance
- **Effort:** Medium (attach three environments and run a build on each).
- **Complexity:** Medium (build validation and failure diagnosis across three targets).
- **Uncertainty:** Medium (a test build can surface configuration gaps from STORY-01-01-02).
- **Fibonacci points:** 5

## Definition of Done
- [ ] `Dev`, `Staging`, and `Prod` are attached to the project per <https://docs.blitzy.com/administration/environments>.
- [ ] A test build on each environment exits `0`.
- [ ] A validation summary records each environment's attached and validated status.
- [ ] A build missing a required secret halts with a non-zero exit code and names the missing key.
- [ ] **Testing:** the test/preview build on each of the three environments exits `0`, confirming the environment foundation before FEATURE-01-02, FEATURE-01-03, and EPIC-02 through EPIC-06 proceed.
