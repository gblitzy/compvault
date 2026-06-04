# STORY-01-01-02: Define Secrets & Variables

*Parent feature: [FEATURE-01-01 — Blitzy Environment Provisioning](../FEATURE-01-01-blitzy-environment-provisioning.md) · Parent epic: [EPIC-01 — Environment & Configuration Foundation](../../EPIC-01-environment-and-configuration-foundation.md)*

## User Story
**As a** DevOps Engineer, **I want** to define the plaintext variables and encrypted secrets in the Blitzy dashboard, **so that** each environment carries the configuration the application needs without exposing credentials.

## Environment Access & Configuration
This story realizes part of EPIC-01's mandatory per-epic environment-access obligation. Follow the canonical reference: <https://docs.blitzy.com/administration/environments>.

- **Platform:** Blitzy — the `Dev`, `Staging`, and `Prod` environments created in [STORY-01-01-01](STORY-01-01-01-create-blitzy-environments.md).
- **Doc essence applied here:** store non-sensitive values as **plaintext variables** and sensitive credentials as **encrypted secrets**; secrets are stored encrypted and never appear in plaintext. Blitzy holds the source-of-truth configuration that FEATURE-01-03 later mirrors to Vercel and GitHub Actions.
- **No real secret values:** every entry uses a placeholder; this ticket never records a live credential.

### Variable and secret set (define per environment)
- **Plaintext variable (non-sensitive):** `NODE_ENV` — non-empty value per environment.
- **Encrypted secrets (active credentials):**
  - `DATABASE_URL` — pooled, runtime connection.
  - `DATABASE_URL_UNPOOLED` — unpooled, DDL/migrations connection.
  - `APIFY_TOKEN` — Apify Platform token; the actor is the primary ingestion source.
  - `LLM_API_KEY` — key for the batch LLM fallback parser; consumed by batch jobs only, never in request handlers.
- **Deferred placeholders (documented, not active):** `EBAY_CLIENT_ID`, `EBAY_CLIENT_SECRET` — blocked on approved eBay Developer access; no active story consumes them.
- **Phase-3 placeholders (out of MVP scope):** `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`.
- **Connection-string discipline:** `DATABASE_URL` (pooled) is for application runtime; `DATABASE_URL_UNPOOLED` (unpooled) is for DDL/migrations — mixing the two breaks migrations.

### Step-by-step configuration (complete BEFORE dependent work)
1. Confirm the three environments from STORY-01-01-01 exist.
2. Classify each key as a plaintext variable or an encrypted secret using the set above.
3. Enter `NODE_ENV` as a plaintext variable in each environment.
4. Enter `DATABASE_URL`, `DATABASE_URL_UNPOOLED`, `APIFY_TOKEN`, and `LLM_API_KEY` as encrypted secrets (placeholder values) in each environment.
5. Enter the deferred eBay placeholders and the Phase-3 Stripe placeholders, labeled by status.
6. Run a review check asserting no sensitive key appears in any plaintext variable listing.

## Acceptance Criteria (Given/When/Then)
1. **(Valid output)** **Given** the three environments exist, **when** the DevOps Engineer defines configuration per <https://docs.blitzy.com/administration/environments>, **then** each environment lists the plaintext variable `NODE_ENV` with a non-empty value and the four encrypted secrets `DATABASE_URL`, `DATABASE_URL_UNPOOLED`, `APIFY_TOKEN`, and `LLM_API_KEY`.
2. **(Error handling — security)** **Given** a sensitive credential, **when** it is saved, **then** its value is stored as an encrypted secret and is absent from any plaintext variable listing and absent from build logs.
3. **(Input validation)** **Given** a secret entry, **when** the value field is empty, **then** the save is rejected and the secret is not created.
4. **(Input validation — connection discipline)** **Given** `DATABASE_URL` and `DATABASE_URL_UNPOOLED`, **when** both are entered, **then** `DATABASE_URL` is recorded as the pooled runtime connection and `DATABASE_URL_UNPOOLED` as the unpooled DDL/migrations connection, and the two values are distinct.
5. **(Edge case — deferred scope)** **Given** the deferred eBay integration, **when** `EBAY_CLIENT_ID` and `EBAY_CLIENT_SECRET` are entered, **then** both carry placeholder values labeled `deferred` and no active story consumes them.
6. **(Error handling)** **Given** a sensitive key entered into a plaintext variable field, **when** the review check runs, **then** it flags the key in the plaintext list and the entry is moved to encrypted secrets before the environment is marked configured.
7. **(Valid output — Phase 3)** **Given** the Phase-3 Stripe keys, **when** `STRIPE_SECRET_KEY` and `STRIPE_WEBHOOK_SECRET` are entered, **then** both are stored as encrypted-secret placeholders labeled `Phase 3 / out of MVP scope`.

## Sub-Tasks
- [ ] Enumerate the variable/secret set and classify each key as plaintext variable or encrypted secret. `@devops-engineer`
- [ ] Enter `NODE_ENV` as a plaintext variable per environment. `@devops-engineer`
- [ ] Enter `DATABASE_URL`, `DATABASE_URL_UNPOOLED`, `APIFY_TOKEN`, and `LLM_API_KEY` as encrypted secrets (placeholders) per environment. `@devops-engineer`
- [ ] Enter `EBAY_CLIENT_ID`/`EBAY_CLIENT_SECRET` (deferred) and `STRIPE_SECRET_KEY`/`STRIPE_WEBHOOK_SECRET` (Phase 3) placeholders. `@devops-engineer`
- [ ] Run a review check asserting no sensitive key appears in any plaintext list. `@platform-engineer`
- [ ] Record the pooled-vs-unpooled connection distinction in the runbook. `@devops-engineer`

## Edge Cases
- **Empty/Null:** a secret value left empty — the save is rejected and the secret is not created.
- **Boundary:** an environment is marked configured only when all four active secrets (`DATABASE_URL`, `DATABASE_URL_UNPOOLED`, `APIFY_TOKEN`, `LLM_API_KEY`) and `NODE_ENV` are present; a missing active key blocks the configured state.
- **Invalid:** a sensitive credential entered in a plaintext variable field — flagged by the review check and relocated to encrypted secrets.
- **Concurrent:** two engineers edit the same secret key at the same time — the dashboard stores one value and reports the conflict for the other edit.

## Dependencies
- **Upstream:** [STORY-01-01-01](STORY-01-01-01-create-blitzy-environments.md) — the environments must exist before variables and secrets are defined.
- **Downstream (informational):** [STORY-01-01-03](STORY-01-01-03-attach-environments-and-validate-build.md) reads these values during the test build; FEATURE-01-03 mirrors them to Vercel and GitHub Actions. Parent feature: [FEATURE-01-01](../FEATURE-01-01-blitzy-environment-provisioning.md). Parent epic: [EPIC-01](../../EPIC-01-environment-and-configuration-foundation.md).

## Story Estimation Guidance
- **Effort:** Medium (per-environment classification and entry of eight keys).
- **Complexity:** Medium (plaintext-vs-encrypted classification plus connection-string discipline).
- **Uncertainty:** Low–Medium (the variable set is known; secret sourcing depends on upstream accounts).
- **Fibonacci points:** 5

## Definition of Done
- [ ] Each environment lists `NODE_ENV` (plaintext) and the four active encrypted secrets with placeholder values.
- [ ] Deferred eBay placeholders and Phase-3 Stripe placeholders are present and labeled by status.
- [ ] No sensitive credential appears in any plaintext variable listing.
- [ ] The pooled-vs-unpooled distinction is documented (`DATABASE_URL` pooled/runtime; `DATABASE_URL_UNPOOLED` unpooled/migrations).
- [ ] **Testing:** a configuration check and a test build that reads the variables confirm each required active key is present and non-empty and that no secret value is printed to build logs, before STORY-01-01-03 validates the environments.
