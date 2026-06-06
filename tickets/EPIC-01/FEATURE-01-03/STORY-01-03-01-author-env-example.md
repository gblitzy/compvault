# STORY-01-03-01: Author the .env.example Template

*Parent feature: [FEATURE-01-03 — Secrets & Variable Management](../FEATURE-01-03-secrets-and-variable-management.md) · Parent epic: [EPIC-01 — Environment & Configuration Foundation](../../EPIC-01-environment-and-configuration-foundation.md)*

## User Story
**As a** Platform Engineer, **I want** to author a `.env.example` template enumerating every required variable, **so that** contributors and CI know exactly which variables to set without exposing real secrets.

## Environment Access & Configuration
This story realizes part of EPIC-01's mandatory per-epic environment-access obligation. Follow the canonical reference: <https://docs.blitzy.com/administration/environments>.

- **Platform:** the `.env.example` file authored here is the committed template that documents the variable set later configured on **Vercel** (in [STORY-01-03-02](STORY-01-03-02-configure-vercel-env-vars.md)) and **GitHub Actions** (in [STORY-01-03-03](STORY-01-03-03-configure-github-actions-secrets.md)). The single Blitzy environment holds the source-of-truth configuration that those stories mirror to Vercel and GitHub.
- **Doc essence applied here:** non-sensitive values are recorded as plaintext variables and sensitive credentials as encrypted secrets; `.env.example` records variable **names** and **placeholder** values only and never a live credential. The real `.env` file is git-ignored and never committed (PRD §7.6.3: "Secrets live in GitHub Actions secrets, never committed.").
- **Runtime floor:** Node `>=20.20.2` for the application runtime (from the root `package.json` `engines.node`); the Apify actor keeps its own `>=18` floor (from `apify/package.json`; the Apify container image is Node 20).

### Variable set to enumerate (the plaintext `NODE_ENV` plus eight secret names, with status)
- `NODE_ENV` — **plaintext** runtime-mode variable (non-sensitive); set to `production` for deployed runtimes (ACTIVE). Separate from the eight secret names below.
- `DATABASE_URL` — pooled, **runtime** connection (ACTIVE).
- `DATABASE_URL_UNPOOLED` — unpooled, **DDL/migrations** connection (ACTIVE).
- `APIFY_TOKEN` — Apify Platform token; the actor is the PRIMARY ingestion source (ACTIVE).
- `LLM_API_KEY` — key for the batch LLM fallback parser; consumed by batch jobs only, never in request handlers (ACTIVE).
- `EBAY_CLIENT_ID` / `EBAY_CLIENT_SECRET` — DEFERRED placeholders, blocked on approved eBay Developer access; documented, not active.
- `STRIPE_SECRET_KEY` / `STRIPE_WEBHOOK_SECRET` — Phase 3, out of MVP scope placeholders; documented, not active.
- **Connection-string discipline:** `DATABASE_URL` (pooled) is for application runtime; `DATABASE_URL_UNPOOLED` (unpooled) is for DDL/migrations — mixing the two breaks migrations.

### Step-by-step configuration (complete BEFORE dependent work)
1. Open the repository root scaffold from [FEATURE-01-02](../FEATURE-01-02-application-scaffolding-and-tooling.md) per <https://docs.blitzy.com/administration/environments>.
2. Create `.env.example` at the repository root listing the plaintext `NODE_ENV` variable and the eight secret names with placeholder values.
3. Annotate each variable with its status (ACTIVE / deferred / Phase 3) and its one-line purpose.
4. Record the pooled `DATABASE_URL` vs unpooled `DATABASE_URL_UNPOOLED` distinction and the note that mixing them breaks migrations.
5. Add a `.gitignore` entry that excludes the real `.env` file so a populated `.env` is never committed.
6. Run a secret-scan check asserting zero live credential values exist in `.env.example`.

## Acceptance Criteria (Given/When/Then)
1. **(Valid output)** **Given** the repository-root scaffold, **when** the Platform Engineer authors `.env.example` per <https://docs.blitzy.com/administration/environments>, **then** the file lists the plaintext `NODE_ENV` variable and all eight secret names (`DATABASE_URL`, `DATABASE_URL_UNPOOLED`, `APIFY_TOKEN`, `LLM_API_KEY`, `EBAY_CLIENT_ID`, `EBAY_CLIENT_SECRET`, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`) with placeholder values and zero real secret values.
2. **(Valid output — status labels)** **Given** the plaintext `NODE_ENV` variable and the eight secret names, **when** each is documented, **then** `NODE_ENV` is labeled a plaintext `ACTIVE` variable, the four active secrets (`DATABASE_URL`, `DATABASE_URL_UNPOOLED`, `APIFY_TOKEN`, `LLM_API_KEY`) are labeled `ACTIVE`, `EBAY_CLIENT_ID`/`EBAY_CLIENT_SECRET` are labeled `deferred`, and `STRIPE_SECRET_KEY`/`STRIPE_WEBHOOK_SECRET` are labeled `Phase 3`.
3. **(Input validation — connection discipline)** **Given** `DATABASE_URL` and `DATABASE_URL_UNPOOLED`, **when** both are documented, **then** `DATABASE_URL` is annotated as the pooled runtime connection, `DATABASE_URL_UNPOOLED` as the unpooled DDL/migrations connection, and the template states that mixing the two breaks migrations.
4. **(Error handling — no real secrets)** **Given** a secret-scan over `.env.example`, **when** any value matches a live-credential pattern (a token longer than 20 characters, a URL with an embedded password, or a value that is not a placeholder), **then** the scan exits non-zero and the commit is blocked.
5. **(Input validation — placeholder format)** **Given** each variable entry, **when** a value is set, **then** the value is a bracketed placeholder token and no entry has an empty value after its `=` sign.
6. **(Edge case — gitignore)** **Given** the repository root, **when** `.env.example` is committed, **then** a `.gitignore` rule excludes the real `.env` file and a populated `.env` cannot be committed.
7. **(Error handling — drift)** **Given** a later code change that reads a new variable, **when** `.env.example` omits that variable name, **then** a documentation check exits non-zero and names the missing variable before merge.

## Sub-Tasks
- [ ] Author `.env.example` at the repository root listing the plaintext `NODE_ENV` variable and all eight secret names with placeholder values. `@platform-engineer`
- [ ] Annotate each variable with its status (ACTIVE / deferred / Phase 3) and one-line purpose. `@platform-engineer`
- [ ] Document the pooled `DATABASE_URL` vs unpooled `DATABASE_URL_UNPOOLED` distinction and the note that mixing them breaks migrations. `@platform-engineer`
- [ ] Add a `.gitignore` entry excluding the real `.env` file. `@devops-engineer`
- [ ] Run a secret-scan check asserting zero live credential values in `.env.example`. `@devops-engineer`
- [ ] Record the variable set in the runbook for [STORY-01-03-02](STORY-01-03-02-configure-vercel-env-vars.md) and [STORY-01-03-03](STORY-01-03-03-configure-github-actions-secrets.md). `@platform-engineer`

## Edge Cases
- **Empty/Null:** a variable entry left with an empty value after `=` — the placeholder check exits non-zero and the entry is rejected.
- **Boundary:** `.env.example` must contain the plaintext `NODE_ENV` variable and all eight secret names; a missing required name blocks completion.
- **Invalid:** a live credential value present in `.env.example` — the secret-scan exits non-zero and blocks the commit.
- **Concurrent:** two engineers add the same variable name at the same time — the file keeps one entry and the duplicate is flagged for removal.

## Dependencies
- **Upstream:** [FEATURE-01-02 — Application Scaffolding & Tooling](../FEATURE-01-02-application-scaffolding-and-tooling.md) establishes the repository root where `.env.example` lives (STORY-01-02-01, STORY-01-02-03); [FEATURE-01-01 — Blitzy Environment Provisioning](../FEATURE-01-01-blitzy-environment-provisioning.md) holds the source-of-truth values this template documents (STORY-01-01-02).
- **Downstream (informational):** [STORY-01-03-02](STORY-01-03-02-configure-vercel-env-vars.md) and [STORY-01-03-03](STORY-01-03-03-configure-github-actions-secrets.md) mirror this variable set to Vercel and GitHub Actions; [EPIC-02](../../EPIC-02-database-platform-and-schema.md) consumes `DATABASE_URL`/`DATABASE_URL_UNPOOLED`; [EPIC-03](../../EPIC-03-data-ingestion-pipeline.md) consumes `APIFY_TOKEN`/`LLM_API_KEY`. Parent feature: [FEATURE-01-03](../FEATURE-01-03-secrets-and-variable-management.md). Parent epic: [EPIC-01](../../EPIC-01-environment-and-configuration-foundation.md).

## Story Estimation Guidance
- **Effort:** Low–Medium (one template file plus a `.gitignore` entry and a scan check).
- **Complexity:** Low (documentation; no application logic).
- **Uncertainty:** Low (the variable set is fixed by PRD §7.6.1 and this feature).
- **Fibonacci points:** 3

## Definition of Done
- [ ] `.env.example` is committed at the repository root with the plaintext `NODE_ENV` variable and all eight secret names and placeholder values.
- [ ] Each variable is labeled ACTIVE / deferred / Phase 3 with its one-line purpose.
- [ ] The pooled-vs-unpooled distinction is documented (mixing breaks migrations).
- [ ] A `.gitignore` rule excludes the real `.env` file.
- [ ] **Testing:** a secret-scan check and a documentation check confirm zero live credential values and that the plaintext `NODE_ENV` variable and all eight secret names are present before [STORY-01-03-02](STORY-01-03-02-configure-vercel-env-vars.md) and [STORY-01-03-03](STORY-01-03-03-configure-github-actions-secrets.md) mirror the set to Vercel and GitHub Actions.
