# STORY-01-01-03: Attach Environment & Validate Build

*Parent feature: [FEATURE-01-01 — Blitzy Environment Provisioning](../FEATURE-01-01-blitzy-environment-provisioning.md) · Parent epic: [EPIC-01 — Environment & Configuration Foundation](../../EPIC-01-environment-and-configuration-foundation.md)*

## User Story
**As a** Platform Engineer, **I want** to attach **the single Blitzy environment** to the project and validate **it** with a test build, **so that** the foundation is confirmed working before dependent epics proceed.

## Environment Access & Configuration
This story completes EPIC-01's mandatory per-epic environment-access obligation for FEATURE-01-01. Follow the canonical reference: <https://docs.blitzy.com/administration/environments>.

- **Platform:** Blitzy — **the single Blitzy environment** created and configured in [STORY-01-01-01](STORY-01-01-01-create-blitzy-environments.md) and [STORY-01-01-02](STORY-01-01-02-define-secrets-and-variables.md).
- **Doc essence applied here:** attach the environment to the project (the final step in the reference), then validate the attachment with a build; the docs.blitzy.com reference is informational only.
- **Build/run target:** Next.js App Router on Vercel; the build runs `npm install` → `npm run build` on Node `>=20.20.2` (the Apify actor keeps its own `>=18` floor from `apify/package.json`).

### Step-by-step configuration (complete BEFORE dependent work)
1. Attach **the single Blitzy environment** to the project per <https://docs.blitzy.com/administration/environments> (informational only).
2. Trigger a test build on the single environment using the STORY-01-01-01 Build command (`npm install` → `npm run build`, which must exit `0`).
3. Capture the build's exit code and record the result in the runbook.
4. For any non-zero build, identify the missing variable or secret (defined in STORY-01-01-02) and re-trigger after the fix.
5. Record a validation summary recording the single environment's attached and validated status.

## Acceptance Criteria (Given/When/Then)
1. **(Valid output)** **Given** the single configured environment, **when** it is attached to the project per <https://docs.blitzy.com/administration/environments>, **then** the project lists **the single Blitzy environment** as attached.
2. **(Valid output — build)** **Given** the attached environment, **when** a test build is triggered, **then** the build runs `npm install` → `npm run build` on Node `>=20.20.2`, completes the Next.js App Router build, and the build process exits `0`.
3. **(Error handling)** **Given** the environment missing a required active secret (for example `DATABASE_URL`), **when** a test build is triggered, **then** the build halts with a non-zero exit code, the log names the missing key, and the environment is not marked validated.
4. **(Input validation)** **Given** the attach action, **when** an environment identifier that does not exist is supplied, **then** the attach is rejected and the project's attached-environment list is unchanged.
5. **(Valid output)** **Given** the single environment is attached and its test build exits `0`, **when** the validation summary is recorded, **then** the single environment shows a `validated` status.
6. **(Error handling — re-run)** **Given** a previously failed environment, **when** the missing secret is added and the test build is re-triggered, **then** the build exits `0` and the environment transitions to `validated`.

## Sub-Tasks
- [ ] Attach the single Blitzy environment to the project per <https://docs.blitzy.com/administration/environments> (informational only). `@platform-engineer`
- [ ] Trigger a test build on the single environment using the STORY-01-01-01 Build command (`npm install` → `npm run build`). `@platform-engineer`
- [ ] Capture the build's exit code and log the result in the runbook. `@platform-engineer`
- [ ] For any non-zero build, identify the missing variable/secret from STORY-01-01-02 and re-run after the fix. `@devops-engineer`
- [ ] Record a validation summary recording the single environment's attached and validated status. `@platform-engineer`

## Edge Cases
- **Empty/Null:** the attach action is submitted with an empty environment identifier — the action is rejected and the attached list is unchanged.
- **Boundary:** the single environment must be attached and its test build must exit `0`.
- **Invalid:** a non-existent environment identifier is supplied to the attach action — the action is rejected.
- **Concurrent:** two builds are triggered on one environment at the same time — each reports an exit code and the environment's `validated` state reflects the last completed exit-`0` build.

## Dependencies
- **Upstream:** [STORY-01-01-01](STORY-01-01-01-create-blitzy-environments.md) (the single environment exists) and [STORY-01-01-02](STORY-01-01-02-define-secrets-and-variables.md) (variables and secrets are defined).
- **Downstream (informational):** [FEATURE-01-02](../FEATURE-01-02-application-scaffolding-and-tooling.md) and [FEATURE-01-03](../FEATURE-01-03-secrets-and-variable-management.md) build within the single validated environment, and EPIC-02 through EPIC-06 depend on it. Parent feature: [FEATURE-01-01](../FEATURE-01-01-blitzy-environment-provisioning.md). Parent epic: [EPIC-01](../../EPIC-01-environment-and-configuration-foundation.md).

## Story Estimation Guidance
- **Effort:** Medium (attach the single environment and run a build on it).
- **Complexity:** Medium (build validation and failure diagnosis on the single environment).
- **Uncertainty:** Medium (a test build can surface configuration gaps from STORY-01-01-02).
- **Fibonacci points:** 5

## Definition of Done
- [ ] The single Blitzy environment is attached to the project per <https://docs.blitzy.com/administration/environments> (informational only).
- [ ] A test build on the single environment exits `0`.
- [ ] A validation summary records the single environment's attached and validated status.
- [ ] A build missing a required secret halts with a non-zero exit code and names the missing key.
- [ ] **Testing:** the test build on the single environment exits `0`, confirming the environment foundation before FEATURE-01-02, FEATURE-01-03, and EPIC-02 through EPIC-06 proceed.
