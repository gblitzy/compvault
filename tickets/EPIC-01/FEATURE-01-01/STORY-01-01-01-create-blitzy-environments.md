# STORY-01-01-01: Configure the Blitzy Environment

*Parent feature: [FEATURE-01-01 — Blitzy Environment Provisioning](../FEATURE-01-01-blitzy-environment-provisioning.md) · Parent epic: [EPIC-01 — Environment & Configuration Foundation](../../EPIC-01-environment-and-configuration-foundation.md)*

## User Story
**As a** Platform Engineer, **I want** to configure **the single Blitzy environment**, **so that** the project has **one** configured target to build, run, and deploy in.

## Environment Access & Configuration
This story realizes part of EPIC-01's mandatory per-epic environment-access obligation. Follow the canonical reference (informational only): <https://docs.blitzy.com/administration/environments>.

- **Platform:** Blitzy — **manually configure the single existing Blitzy environment**. Blitzy cannot create environments; the docs.blitzy.com reference is informational only.
- **Doc essence applied here:** manually configure the single environment with copy-paste build/run instructions. Defining variables/secrets is handled in [STORY-01-01-02](STORY-01-01-02-define-secrets-and-variables.md); attaching to the project and validating with a test build is handled in [STORY-01-01-03](STORY-01-01-03-attach-environments-and-validate-build.md).
- **Build/run target:** the application is a Next.js App Router project deployed on Vercel. The single environment's **Build** command is `npm install` then `npm run build` (must exit `0`) on **Node `>=20.20.2`**; the **Run** command is `npm run start` (starts the Next.js server).
- **Runtime floor:** Node `>=20.20.2` for the application runtime (from the root `package.json` `engines.node`); the Apify actor keeps its own `>=18` floor (from `apify/package.json`; the Apify container image is Node 20).

### Step-by-step configuration (complete BEFORE dependent work)
1. Open the single existing Blitzy environment per <https://docs.blitzy.com/administration/environments> (informational only — Blitzy cannot create environments).
2. Set the environment's Node version to `>=20.20.2`.
3. Set the **Build** command: `npm install` then `npm run build` (must exit `0`).
4. Set the **Run** command: `npm run start`.
5. Record the environment identifier in the team runbook for use by STORY-01-01-02 and STORY-01-01-03.

## Acceptance Criteria (Given/When/Then)
1. **(Valid output)** **Given** a Blitzy account with access to the single existing environment, **when** the Platform Engineer configures it per <https://docs.blitzy.com/administration/environments> (informational only), **then** **the single Blitzy environment** is configured in the Blitzy dashboard.
2. **(Valid output — build/run instructions)** **Given** the single environment, **when** its build/run instructions are authored, **then** it records a **Build** command `npm install` → `npm run build` that exits `0` on Node `>=20.20.2`, and a **Run** command `npm run start` that starts the Next.js server.
3. **(Input validation)** **Given** the single Blitzy environment's configuration, **when** it is saved, **then** the settings apply to the one existing environment and no second environment is created (Blitzy cannot create environments).
4. **(Input validation — runtime floor)** **Given** the runtime configuration field, **when** a Node version below `20.20.2` is entered, **then** the save is blocked and the message identifies Node `>=20.20.2` as the floor.
5. **(Error handling)** **Given** the single-environment model, **when** an attempt is made to add another Blitzy environment, **then** no new environment is created and **the environment count stays at one**.
6. **(Valid output)** **Given** the single environment, **when** the environments list is retrieved, **then** it shows an identifier and a status of `created`/`ready`.

## Sub-Tasks
- [ ] Open the single Blitzy environment per <https://docs.blitzy.com/administration/environments> (informational only). `@platform-engineer`
- [ ] Configure the single Blitzy environment: set Node `>=20.20.2`, Build `npm install` → `npm run build` (must exit `0`), Run `npm run start`. `@platform-engineer`
- [ ] Record the single environment identifier in the team runbook. `@devops-engineer`
- [ ] Verify the single environment is configured. `@devops-engineer`

## Edge Cases
- **Empty/Null:** the single environment's name/identifier is left blank — the configuration is rejected and not saved.
- **Boundary:** Node `20.20.2` is accepted; a version below `20.20.2` is rejected (the `>=20.20.2` floor).

## Dependencies
- **Upstream:** NONE — EPIC-01 is the root of the dependency graph, FEATURE-01-01 is its first feature, and this is its first story.
- **Downstream (informational):** [STORY-01-01-02](STORY-01-01-02-define-secrets-and-variables.md) and [STORY-01-01-03](STORY-01-01-03-attach-environments-and-validate-build.md) require the single environment to exist. Parent feature: [FEATURE-01-01](../FEATURE-01-01-blitzy-environment-provisioning.md). Parent epic: [EPIC-01](../../EPIC-01-environment-and-configuration-foundation.md).

## Story Estimation Guidance
- **Effort:** Low (single-environment manual configuration plus build/run instructions).
- **Complexity:** Low (dashboard configuration; no application code).
- **Uncertainty:** Low (the doc essence is known and fixed).
- **Fibonacci points:** 3

## Definition of Done
- [ ] The single Blitzy environment is configured in the Blitzy dashboard per <https://docs.blitzy.com/administration/environments> (informational only — Blitzy cannot create environments).
- [ ] The single environment records the **Build** command `npm install` → `npm run build` (exits `0`) and **Run** command `npm run start`, targeting the Next.js App Router on Vercel with the Node `>=20.20.2` floor (the Apify actor keeps its own separate, lower floor as noted in the Runtime floor bullet above).
- [ ] The single environment identifier is recorded in the runbook.
- [ ] Below-floor inputs are rejected.
- [ ] **Testing:** a smoke check confirms the single environment is reachable in the Blitzy dashboard and returns a `created`/`ready` status before STORY-01-01-02 defines variables and secrets.
