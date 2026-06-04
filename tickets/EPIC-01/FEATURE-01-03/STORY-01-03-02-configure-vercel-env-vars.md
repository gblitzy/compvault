# STORY-01-03-02: Configure Vercel Environment Variables

*Parent feature: [FEATURE-01-03 — Secrets & Variable Management](../FEATURE-01-03-secrets-and-variable-management.md) · Parent epic: [EPIC-01 — Environment & Configuration Foundation](../../EPIC-01-environment-and-configuration-foundation.md)*

## User Story
**As a** DevOps Engineer, **I want** to configure the Vercel project environment variables across preview and production, **so that** the deployed app and its previews read the correct configuration.

## Environment Access & Configuration
This story realizes part of EPIC-01's mandatory per-epic environment-access obligation. Follow the canonical reference: <https://docs.blitzy.com/administration/environments>.

- **Platform:** Vercel — the project environment variables, set in both the **Preview** and **Production** scopes. Blitzy holds the source-of-truth configuration; this story mirrors the values to Vercel.
- **Doc essence applied here:** non-sensitive values are stored as plaintext variables and sensitive credentials as encrypted (Sensitive) variables; secret values are stored encrypted and stay out of build logs. Each PR receives a Preview deployment; `main` deploys to Production (PRD §7.5).
- **Variable set mirrored:** the four active variables from [STORY-01-03-01](STORY-01-03-01-author-env-example.md) — `DATABASE_URL` (pooled, runtime), `DATABASE_URL_UNPOOLED` (unpooled, DDL/migrations), `APIFY_TOKEN`, `LLM_API_KEY`. The deferred `EBAY_CLIENT_ID`/`EBAY_CLIENT_SECRET` and the Phase-3 `STRIPE_SECRET_KEY`/`STRIPE_WEBHOOK_SECRET` are not set as active variables.

### Step-by-step configuration (complete BEFORE dependent work)
1. Open the Vercel project Settings → Environment Variables page per <https://docs.blitzy.com/administration/environments>.
2. Enter the four active variables for the **Preview** scope using values mirrored from the Blitzy source-of-truth.
3. Enter the four active variables for the **Production** scope.
4. Mark `DATABASE_URL`, `DATABASE_URL_UNPOOLED`, `APIFY_TOKEN`, and `LLM_API_KEY` as Sensitive so values stay out of build logs.
5. Run a name-match check asserting every Vercel variable name exists in `.env.example`.
6. Trigger a Preview deployment and confirm a non-zero exit when a required variable is removed.

## Acceptance Criteria (Given/When/Then)
1. **(Valid output)** **Given** the variable set from [STORY-01-03-01](STORY-01-03-01-author-env-example.md), **when** the DevOps Engineer configures Vercel per <https://docs.blitzy.com/administration/environments>, **then** the project lists the four active variables (`DATABASE_URL`, `DATABASE_URL_UNPOOLED`, `APIFY_TOKEN`, `LLM_API_KEY`) in both the Preview and Production scopes.
2. **(Valid output — pooled at runtime)** **Given** `DATABASE_URL`, **when** it is set in Vercel, **then** its value is the pooled connection string and `DATABASE_URL_UNPOOLED` is a separate variable used by migrations, not by the runtime app.
3. **(Error handling — encrypted)** **Given** a sensitive value such as `APIFY_TOKEN`, **when** it is stored in Vercel, **then** it is marked as a Sensitive variable and its value is absent from build logs and from the deployment output.
4. **(Input validation — name match)** **Given** each Vercel variable name, **when** it is created, **then** it matches a variable name in `.env.example` character-for-character, and any name absent from `.env.example` is rejected.
5. **(Error handling — missing required)** **Given** a Preview or Production deployment, **when** a required active variable is absent or empty, **then** the deployment check exits non-zero and the log names the missing variable.
6. **(Edge case — deferred and Phase-3 not active)** **Given** `EBAY_CLIENT_ID`/`EBAY_CLIENT_SECRET` (deferred) and `STRIPE_SECRET_KEY`/`STRIPE_WEBHOOK_SECRET` (Phase 3), **when** Vercel is configured, **then** these are not set as active runtime variables and their absence does not fail a deployment.
7. **(Valid output — preview isolation)** **Given** a per-PR Preview deployment, **when** it reads its variables, **then** it reads the Preview-scoped values and not the Production values.

## Sub-Tasks
- [ ] Open the Vercel project Settings → Environment Variables page per <https://docs.blitzy.com/administration/environments>. `@devops-engineer`
- [ ] Enter the four active variables for the Preview scope using values mirrored from the Blitzy source-of-truth. `@devops-engineer`
- [ ] Enter the four active variables for the Production scope. `@devops-engineer`
- [ ] Mark `DATABASE_URL`, `DATABASE_URL_UNPOOLED`, `APIFY_TOKEN`, and `LLM_API_KEY` as Sensitive so values stay out of build logs. `@devops-engineer`
- [ ] Run a name-match check asserting every Vercel variable name exists in `.env.example`. `@platform-engineer`
- [ ] Trigger a Preview deployment and confirm a non-zero exit when a required variable is removed. `@devops-engineer`

## Edge Cases
- **Empty/Null:** a required active variable left empty in Vercel — the deployment check exits non-zero and names it.
- **Boundary:** all four active variables must be present in both the Preview and Production scopes; three in either scope blocks completion.
- **Invalid:** a Vercel variable name with no match in `.env.example` — rejected by the name-match check.
- **Concurrent:** two deployments run while a variable is updated — each deployment reads one consistent snapshot of the variable set.

## Dependencies
- **Upstream:** [STORY-01-03-01](STORY-01-03-01-author-env-example.md) defines the variable set and names that Vercel mirrors; [FEATURE-01-01 — Blitzy Environment Provisioning](../FEATURE-01-01-blitzy-environment-provisioning.md) holds the source-of-truth values (STORY-01-01-02).
- **Downstream (informational):** [EPIC-04](../../EPIC-04-backend-application-and-api.md) (backend on Vercel) and [EPIC-05](../../EPIC-05-frontend-user-interface.md) (frontend previews) read these Vercel variables at runtime. Parent feature: [FEATURE-01-03](../FEATURE-01-03-secrets-and-variable-management.md). Parent epic: [EPIC-01](../../EPIC-01-environment-and-configuration-foundation.md).

## Story Estimation Guidance
- **Effort:** Medium (four entries across two scopes plus name-match and deployment checks).
- **Complexity:** Medium (Preview/Production scoping and Sensitive-flag handling).
- **Uncertainty:** Low–Medium (the variable set is fixed; values depend on upstream accounts).
- **Fibonacci points:** 5

## Definition of Done
- [ ] The four active variables are set in both the Vercel Preview and Production scopes.
- [ ] `DATABASE_URL` is the pooled connection; `DATABASE_URL_UNPOOLED` is the unpooled migrations connection.
- [ ] Active sensitive values are marked Sensitive and stay out of build logs.
- [ ] Every Vercel variable name matches `.env.example`; the deferred and Phase-3 keys are not active.
- [ ] **Testing:** a Preview deployment and a Production deployment read the configured variables, and a removed-required-variable case exits non-zero, confirmed before [EPIC-04](../../EPIC-04-backend-application-and-api.md) and [EPIC-05](../../EPIC-05-frontend-user-interface.md) consume them.
