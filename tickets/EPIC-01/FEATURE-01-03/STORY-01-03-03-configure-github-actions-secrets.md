# STORY-01-03-03: Configure GitHub Actions Secrets

*Parent feature: [FEATURE-01-03 — Secrets & Variable Management](../FEATURE-01-03-secrets-and-variable-management.md) · Parent epic: [EPIC-01 — Environment & Configuration Foundation](../../EPIC-01-environment-and-configuration-foundation.md)*

## User Story
**As a** DevOps Engineer, **I want** to configure the GitHub Actions encrypted secrets, **so that** CI and the scheduled ingestion read credentials without committing them.

## Environment Access & Configuration
This story realizes part of EPIC-01's mandatory per-epic environment-access obligation. Follow the canonical reference: <https://docs.blitzy.com/administration/environments>.

- **Platform:** GitHub Actions — encrypted repository secrets consumed by the CI workflow and the scheduled ingestion workflow via `${{ secrets.NAME }}`. The single Blitzy environment holds the source-of-truth configuration; this story mirrors the values to GitHub Actions encrypted secrets.
- **Doc essence applied here:** sensitive credentials are stored as encrypted secrets and stay out of logs. Per PRD §7.6.3, "Secrets live in GitHub Actions secrets, never committed," so no secret value is placed in a tracked file.
- **Secret and variable set mirrored:** the four active **encrypted secrets** from [STORY-01-03-01](STORY-01-03-01-author-env-example.md) — `DATABASE_URL` (pooled, runtime), `DATABASE_URL_UNPOOLED` (unpooled, DDL/migrations), `APIFY_TOKEN`, `LLM_API_KEY` — plus the plaintext runtime-mode variable `NODE_ENV` (non-sensitive), mirrored as a GitHub Actions **Variable** (read via `${{ vars.NODE_ENV }}`), not as an encrypted secret. The deferred `EBAY_CLIENT_ID`/`EBAY_CLIENT_SECRET` and the Phase-3 `STRIPE_SECRET_KEY`/`STRIPE_WEBHOOK_SECRET` are not created as active CI secrets.

### Step-by-step configuration (complete BEFORE dependent work)
1. Open the repository Settings → Secrets and variables → Actions page per <https://docs.blitzy.com/administration/environments>.
2. Create the four active encrypted secrets (`DATABASE_URL`, `DATABASE_URL_UNPOOLED`, `APIFY_TOKEN`, `LLM_API_KEY`) using values mirrored from the single Blitzy environment; the CI/test and scheduled-ingestion `DATABASE_URL` (pooled) and `DATABASE_URL_UNPOOLED` (unpooled) resolve to the Neon `dev-qa` branch. Add `NODE_ENV` as a plaintext GitHub Actions **Variable** (not an encrypted secret), read via `${{ vars.NODE_ENV }}`.
3. Add a CI step that asserts each required secret is non-empty and exits non-zero when one is missing.
4. Run a tracked-file scan asserting no secret value is committed and that `.env` is excluded by `.gitignore`.
5. Document which workflow reads the unpooled `DATABASE_URL_UNPOOLED` (migrations) versus the pooled `DATABASE_URL` (runtime and ingestion); for CI and the scheduled-ingestion workflow both resolve to the Neon `dev-qa` branch.
6. Record the secret names in the runbook and confirm each matches `.env.example`.

## Acceptance Criteria (Given/When/Then)
1. **(Valid output)** **Given** the variable set from [STORY-01-03-01](STORY-01-03-01-author-env-example.md), **when** the DevOps Engineer configures GitHub Actions secrets per <https://docs.blitzy.com/administration/environments>, **then** the repository defines the four active encrypted secrets `DATABASE_URL`, `DATABASE_URL_UNPOOLED`, `APIFY_TOKEN`, and `LLM_API_KEY`, whose CI/test and ingestion `DATABASE_URL`/`DATABASE_URL_UNPOOLED` resolve to the Neon `dev-qa` branch, and the plaintext runtime-mode variable `NODE_ENV` is defined as a GitHub Actions Variable (read via `${{ vars.NODE_ENV }}`), not as an encrypted secret.
2. **(Error handling — never committed)** **Given** a scan over tracked files, **when** it runs, **then** no secret value is present in any committed file and `.env` is excluded by `.gitignore`.
3. **(Input validation — name match)** **Given** each GitHub Actions secret name, **when** it is created, **then** it matches a variable name in `.env.example` character-for-character.
4. **(Error handling — empty secret)** **Given** a CI step that asserts secret presence, **when** a required secret is empty or absent, **then** the step exits non-zero and the CI run fails with the missing secret named.
5. **(Valid output — migrations use unpooled)** **Given** the migration workflow, **when** it runs DDL against the Neon `dev-qa` branch, **then** it reads `DATABASE_URL_UNPOOLED` via `${{ secrets.DATABASE_URL_UNPOOLED }}`, while the runtime and ingestion steps read the pooled `DATABASE_URL` (also the `dev-qa` branch).
6. **(Edge case — deferred and Phase-3)** **Given** `EBAY_CLIENT_ID`/`EBAY_CLIENT_SECRET` (deferred) and `STRIPE_SECRET_KEY`/`STRIPE_WEBHOOK_SECRET` (Phase 3), **when** secrets are configured, **then** these are not created as active CI secrets and no active workflow references them.
7. **(Valid output — ingestion reads token)** **Given** the scheduled ingestion workflow, **when** it runs, **then** it reads `APIFY_TOKEN` and `LLM_API_KEY` from encrypted secrets, matching the Apify-primary ingestion path.

## Sub-Tasks
- [ ] Open the repository Settings → Secrets and variables → Actions page per <https://docs.blitzy.com/administration/environments>. `@devops-engineer`
- [ ] Create the four active encrypted secrets (`DATABASE_URL`, `DATABASE_URL_UNPOOLED`, `APIFY_TOKEN`, `LLM_API_KEY`) with values mirrored from the single Blitzy environment; CI/test and ingestion `DATABASE_URL`/`DATABASE_URL_UNPOOLED` resolve to the Neon `dev-qa` branch. Add `NODE_ENV` as a plaintext GitHub Actions Variable (read via `${{ vars.NODE_ENV }}`), not an encrypted secret. `@devops-engineer`
- [ ] Add a CI step that asserts each required secret is non-empty and exits non-zero when one is missing. `@devops-engineer`
- [ ] Run a tracked-file scan asserting no secret value is committed and `.env` is git-ignored. `@platform-engineer`
- [ ] Document which workflow reads the unpooled `DATABASE_URL_UNPOOLED` (migrations) versus the pooled `DATABASE_URL` (runtime and ingestion); for CI and ingestion both resolve to the Neon `dev-qa` branch. `@devops-engineer`
- [ ] Record the secret names in the runbook and confirm each matches `.env.example`. `@devops-engineer`

## Edge Cases
- **Empty/Null:** a required secret left empty — the CI presence-check step exits non-zero and names it.
- **Boundary:** all four active secrets must be present; three blocks the CI presence check from passing.
- **Invalid:** a secret name with no match in `.env.example` — flagged by the name-match check and renamed before use.
- **Concurrent:** two workflow runs read the same secret at the same time — each run reads the stored encrypted value and neither prints it to logs.

## Dependencies
- **Upstream:** [STORY-01-03-01](STORY-01-03-01-author-env-example.md) defines the secret names that GitHub Actions mirrors; [FEATURE-01-01 — Blitzy Environment Provisioning](../FEATURE-01-01-blitzy-environment-provisioning.md) holds the source-of-truth values (STORY-01-01-02).
- **Downstream (informational):** [EPIC-03](../../EPIC-03-data-ingestion-pipeline.md) scheduled ingestion reads `APIFY_TOKEN`/`LLM_API_KEY`/`DATABASE_URL`; [EPIC-06](../../EPIC-06-testing-and-cicd-quality-gates.md) `STORY-06-03-02` asserts secret presence in CI. Parent feature: [FEATURE-01-03](../FEATURE-01-03-secrets-and-variable-management.md). Parent epic: [EPIC-01](../../EPIC-01-environment-and-configuration-foundation.md).

## Story Estimation Guidance
- **Effort:** Medium (four secrets plus a presence-check step and a tracked-file scan).
- **Complexity:** Medium (CI integration and pooled-vs-unpooled routing across workflows).
- **Uncertainty:** Low–Medium (the secret set is fixed; values depend on upstream accounts).
- **Fibonacci points:** 5

## Definition of Done
- [ ] The four active encrypted secrets are defined in GitHub Actions, and `NODE_ENV` is defined as a plaintext GitHub Actions Variable (not an encrypted secret).
- [ ] No secret value is present in any committed file; `.env` is git-ignored.
- [ ] A CI step exits non-zero when a required secret is empty or absent.
- [ ] Migrations read `DATABASE_URL_UNPOOLED`; the runtime and ingestion steps read the pooled `DATABASE_URL`; for CI and the scheduled-ingestion workflow both resolve to the Neon `dev-qa` branch.
- [ ] **Testing:** a CI run executes the secret-presence assertion (failing on a removed secret and passing when all four are present) before [EPIC-03](../../EPIC-03-data-ingestion-pipeline.md) ingestion and [EPIC-06](../../EPIC-06-testing-and-cicd-quality-gates.md) `STORY-06-03-02` consume the secrets.
