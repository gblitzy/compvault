# STORY-01-01-01: Create the Blitzy Environments

*Parent feature: [FEATURE-01-01 — Blitzy Environment Provisioning](../FEATURE-01-01-blitzy-environment-provisioning.md) · Parent epic: [EPIC-01 — Environment & Configuration Foundation](../../EPIC-01-environment-and-configuration-foundation.md)*

## User Story
**As a** Platform Engineer, **I want** to create the Dev, Staging, and Prod Blitzy environments, **so that** the project has three isolated, configured targets to build, run, and deploy in.

## Environment Access & Configuration
This story realizes part of EPIC-01's mandatory per-epic environment-access obligation. Follow the canonical reference: <https://docs.blitzy.com/administration/environments>.

- **Platform:** Blitzy. Create one environment per target: **Dev**, **Staging**, and **Prod**.
- **Doc essence applied here:** create an environment per target and supply natural-language build/run instructions. Defining variables/secrets is handled in [STORY-01-01-02](STORY-01-01-02-define-secrets-and-variables.md); attaching to the project and validating with a test build is handled in [STORY-01-01-03](STORY-01-01-03-attach-environments-and-validate-build.md).
- **Build/run target:** the application is a Next.js App Router project deployed on Vercel. Each environment's build instruction installs dependencies on **Node `>=18`** and runs the Next.js build; the run instruction starts the Next.js server.
- **Runtime floor:** Node `>=18` (sourced from `apify/package.json` `engines.node`; the Apify container image is Node 20).

### Step-by-step configuration (complete BEFORE dependent work)
1. Sign in to the Blitzy dashboard and open the environments administration page per <https://docs.blitzy.com/administration/environments>.
2. Create the **Dev** environment; author its build instruction (install on Node `>=18`, run the Next.js build) and run instruction (start the Next.js server).
3. Create the **Staging** environment using the same build/run instruction template.
4. Create the **Prod** environment using the same build/run instruction template.
5. Record each environment identifier in the team runbook for use by STORY-01-01-02 and STORY-01-01-03.

## Acceptance Criteria (Given/When/Then)
1. **(Valid output)** **Given** a Blitzy account with environment-creation access, **when** the Platform Engineer creates environments per <https://docs.blitzy.com/administration/environments>, **then** three environments named exactly `Dev`, `Staging`, and `Prod` exist in the Blitzy dashboard.
2. **(Valid output — build/run instructions)** **Given** each created environment, **when** its build/run instructions are authored, **then** each environment records a build instruction that installs dependencies on Node `>=18` and runs the Next.js App Router build, and a run instruction that starts the Next.js server.
3. **(Input validation)** **Given** an environment-name input, **when** a name is submitted, **then** the name matches one of the allowed set `{Dev, Staging, Prod}` and any name outside this set is rejected before the environment is saved.
4. **(Input validation — runtime floor)** **Given** the runtime configuration field, **when** a Node major version below 18 is entered, **then** the environment save is blocked and the message identifies Node `>=18` as the floor.
5. **(Error handling)** **Given** a second attempt to create an environment whose name already exists, **when** the create action is submitted, **then** the dashboard returns a duplicate-name error and the environment count stays at three.
6. **(Edge case — isolation)** **Given** the three environments exist, **when** the Dev environment configuration is changed, **then** the Staging and Prod environment configurations are unchanged.
7. **(Valid output)** **Given** the three environments exist, **when** the environments list is retrieved, **then** each environment shows a distinct identifier and a status of `created`/`ready`.

## Sub-Tasks
- [ ] Open the Blitzy environments administration page per <https://docs.blitzy.com/administration/environments>. `@platform-engineer`
- [ ] Create the Dev environment and author its build instruction (install on Node `>=18`; run the Next.js build) and run instruction (start the Next.js server). `@platform-engineer`
- [ ] Create the Staging environment from the same build/run template. `@platform-engineer`
- [ ] Create the Prod environment from the same build/run template. `@platform-engineer`
- [ ] Record each environment identifier in the team runbook. `@devops-engineer`
- [ ] Verify the three environments are listed and isolated from one another. `@devops-engineer`

## Edge Cases
- **Empty/Null:** an environment name is left blank — the create action is rejected and no environment is saved.
- **Boundary:** a Node major version of exactly 18 is accepted; 17 is rejected (the `>=18` floor).
- **Invalid:** a duplicate environment name (a second `Dev`) — rejected with a duplicate-name error; the count stays at three.
- **Concurrent:** two engineers submit the same environment name at the same time — one environment is saved and the other request returns a duplicate-name error.

## Dependencies
- **Upstream:** NONE — EPIC-01 is the root of the dependency graph, FEATURE-01-01 is its first feature, and this is its first story.
- **Downstream (informational):** [STORY-01-01-02](STORY-01-01-02-define-secrets-and-variables.md) and [STORY-01-01-03](STORY-01-01-03-attach-environments-and-validate-build.md) require these environments to exist. Parent feature: [FEATURE-01-01](../FEATURE-01-01-blitzy-environment-provisioning.md). Parent epic: [EPIC-01](../../EPIC-01-environment-and-configuration-foundation.md).

## Story Estimation Guidance
- **Effort:** Low–Medium (three environment records plus build/run instructions).
- **Complexity:** Low (dashboard configuration; no application code).
- **Uncertainty:** Low (the doc essence is known and fixed).
- **Fibonacci points:** 3

## Definition of Done
- [ ] Three environments (`Dev`, `Staging`, `Prod`) exist in the Blitzy dashboard, created per <https://docs.blitzy.com/administration/environments>.
- [ ] Each environment records build/run instructions targeting the Next.js App Router on Vercel with the Node `>=18` floor.
- [ ] Each environment identifier is recorded in the runbook.
- [ ] Duplicate-name and below-floor inputs are rejected.
- [ ] **Testing:** a smoke check confirms each of the three environments is reachable in the Blitzy dashboard and returns a `created`/`ready` status before STORY-01-01-02 defines variables and secrets.
