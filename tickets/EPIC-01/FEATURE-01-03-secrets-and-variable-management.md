# FEATURE-01-03: Secrets & Variable Management

*Parent epic: [EPIC-01 — Environment & Configuration Foundation](../EPIC-01-environment-and-configuration-foundation.md)*

## Feature Summary

This feature authors the **`.env.example`** template — none exists in the repository today, so this creation is in scope — enumerating every variable the application reads, and configures the **Vercel project environment variables** (the **Production** scope and the **Preview** scope, where Preview = dev/qa) and the **GitHub Actions encrypted secrets** (CI and the scheduled ingestion). The business value is one committed `.env.example` documenting every variable name, plus configured Vercel variables and GitHub Actions secrets, giving the runtime, preview, and CI environments one consistent, auditable configuration that every later epic reads instead of guessing variable names. This is the **second realization of EPIC-01's Environment Access & Configuration obligation** — Vercel plus GitHub Actions — complementing [FEATURE-01-01 — Blitzy Environment Provisioning](FEATURE-01-01-blitzy-environment-provisioning.md). Scope is limited to authoring `.env.example` and configuring the Vercel and GitHub Actions variables and secrets; it does **not** provision the single Blitzy environment (that is [FEATURE-01-01 — Blitzy Environment Provisioning](FEATURE-01-01-blitzy-environment-provisioning.md)) and it does **not** scaffold the application (that is [FEATURE-01-02 — Application Scaffolding & Tooling](FEATURE-01-02-application-scaffolding-and-tooling.md)); it stores placeholder values only and never a real secret. This feature is delivered through **3 stories**.

## Environment Access & Configuration

All variable and secret configuration for this feature follows the canonical Blitzy environments reference: <https://docs.blitzy.com/administration/environments>. Per that reference, non-sensitive values are stored as **plaintext variables** and sensitive credentials are stored as **encrypted secrets**, and the environment is then attached to the project. **The single Blitzy environment holds the source-of-truth configuration**, which is mirrored out to **Vercel** — across its two scopes, **Production** (git `main` → Neon `production`) and **Preview = dev/qa** (all non-production branches/PRs → Neon `dev-qa`) — and to **GitHub Actions** (CI and the scheduled ingestion). Secrets are **never committed** to the repository — `.env`, `.env.local`, and `.env.*.local` are git-ignored, and `.env.example` carries placeholder values only.

### Platforms and access required

| Platform | Access required | Purpose in FEATURE-01-03 |
|----------|-----------------|--------------------------|
| Vercel | Project environment variables across the **Production** and **Preview** (= dev/qa) scopes | Expose the active variable set to the **Production** scope (deploys from `main`, pointed at the Neon `production` branch) and the **Preview** scope (= dev/qa, which applies to all non-production branches and pull requests, pointed at the Neon `dev-qa` branch) so each deployed scope resolves the variables the application reads; the Development scope is local-only via `vercel env pull` and is not a third deployed environment |
| GitHub Actions | Encrypted repository or environment secrets | Store the secrets the CI pipeline and the scheduled ingestion workflow read, held encrypted at rest and never committed |

### Variable set standardized by `.env.example` (with status)

`.env.example` enumerates the eight variable names below with placeholder values and zero real secrets. The **pooled** `DATABASE_URL` (application runtime) and the **unpooled** `DATABASE_URL_UNPOOLED` (DDL and migrations) are kept distinct, because mixing the two breaks migrations.

| Variable | Role | Status |
|----------|------|--------|
| `DATABASE_URL` | Pooled Neon connection read at application runtime | Active (MVP) |
| `DATABASE_URL_UNPOOLED` | Unpooled Neon connection used for DDL and migrations | Active (MVP) |
| `APIFY_TOKEN` | Apify Platform token authorizing actor execution; the Apify actor is the primary ingestion source in this MVP | Active (MVP) |
| `LLM_API_KEY` | Key for the batch LLM fallback parser; read in batch jobs only, never in a request handler | Active (MVP) |
| `EBAY_CLIENT_ID` / `EBAY_CLIENT_SECRET` | eBay Browse / Marketplace-Insights API credentials | Deferred — blocked on approved eBay Developer access; placeholder only |
| `STRIPE_SECRET_KEY` / `STRIPE_WEBHOOK_SECRET` | Stripe billing credentials | Phase 3 — out of MVP scope; placeholder only |

### Connection-string discipline

- The pooled `DATABASE_URL` is read at **application runtime** (the serverless read paths hosted on Vercel).
- The unpooled `DATABASE_URL_UNPOOLED` is read for **DDL and migrations** (`drizzle-kit`, run in a GitHub Actions step).
- Pointing migrations at the pooled URL, or runtime reads at the unpooled URL, breaks migrations; the two connection strings are stored as distinct values in every scope.

### Step-by-step configuration (complete before dependent epics consume these variables)

1. Author `.env.example` at the repository root enumerating all eight variable names — `DATABASE_URL`, `DATABASE_URL_UNPOOLED`, `APIFY_TOKEN`, `LLM_API_KEY`, `EBAY_CLIENT_ID`, `EBAY_CLIENT_SECRET`, `STRIPE_SECRET_KEY`, and `STRIPE_WEBHOOK_SECRET` — with placeholder values and zero real secrets, marking the deferred eBay credentials and the Phase-3 Stripe credentials distinctly from the active MVP variables (STORY-01-03-01).
2. Configure the Vercel project environment variables for the **Production** scope (`main` → Neon `production`) and the **Preview** scope (= dev/qa, all non-production branches/PRs → Neon `dev-qa`) so each deployment resolves the active variable set; the Development scope is local-only via `vercel env pull` (STORY-01-03-02).
3. Configure the GitHub Actions encrypted secrets the CI pipeline and the scheduled ingestion workflow read, mirrored from the single Blitzy environment's source-of-truth configuration per <https://docs.blitzy.com/administration/environments> (informational only — Blitzy cannot create environments) (STORY-01-03-03).
4. Confirm the pooled `DATABASE_URL` and the unpooled `DATABASE_URL_UNPOOLED` are stored as distinct values in every scope so migrations and runtime reads do not share one connection string.
5. Validate with a check or test/preview build that every active variable is present and non-empty before the dependent epics (EPIC-02 through EPIC-06) consume these variables.

## User Stories Index

This feature is delivered through three stories. Each link is relative to this file inside the `EPIC-01/` directory and resolves into the `FEATURE-01-03/` subfolder.

1. **[STORY-01-03-01 — Author the .env.example Template](FEATURE-01-03/STORY-01-03-01-author-env-example.md)** — author `.env.example` enumerating all eight required variables (the active set, the deferred eBay credentials, and the Phase-3 Stripe placeholders) with placeholder values and zero real secrets.
2. **[STORY-01-03-02 — Configure Vercel Environment Variables](FEATURE-01-03/STORY-01-03-02-configure-vercel-env-vars.md)** — configure the Vercel project environment variables across the **Production** and **Preview** (= dev/qa) scopes so each deployment resolves the active variable set.
3. **[STORY-01-03-03 — Configure GitHub Actions Secrets](FEATURE-01-03/STORY-01-03-03-configure-github-actions-secrets.md)** — configure the GitHub Actions encrypted secrets the CI pipeline and the scheduled ingestion workflow read, held encrypted at rest and never committed.

## Dependencies

### Upstream (must be complete first)

- **[FEATURE-01-01 — Blitzy Environment Provisioning](FEATURE-01-01-blitzy-environment-provisioning.md):** provisions and manually configures the single Blitzy environment that holds the source-of-truth secrets this feature mirrors out to Vercel and GitHub Actions.
- **[FEATURE-01-02 — Application Scaffolding & Tooling](FEATURE-01-02-application-scaffolding-and-tooling.md):** initializes the repository-root scaffold where `.env.example` lives alongside `drizzle.config.ts` and `vercel.json`.

### Downstream (informational — not a build prerequisite of this feature)

- **EPIC-02 — Database Platform & Schema:** consumes the pooled `DATABASE_URL` and the unpooled `DATABASE_URL_UNPOOLED` this feature standardizes.
- **EPIC-03 — Data Ingestion Pipeline:** consumes `APIFY_TOKEN` (the primary ingestion source) and `LLM_API_KEY` (the batch fallback parser) this feature standardizes.
- **EPIC-06 — Testing & CI/CD Quality Gates:** its `STORY-06-03-02` asserts each required secret is present and non-empty in CI.

## Definition of Done

- [ ] All 3 stories (STORY-01-03-01, STORY-01-03-02, STORY-01-03-03) are complete.
- [ ] `.env.example` is committed at the repository root and enumerates all eight variable names — `DATABASE_URL`, `DATABASE_URL_UNPOOLED`, `APIFY_TOKEN`, `LLM_API_KEY`, the deferred `EBAY_CLIENT_ID`/`EBAY_CLIENT_SECRET`, and the Phase-3 `STRIPE_SECRET_KEY`/`STRIPE_WEBHOOK_SECRET` — with placeholder values and zero real secrets.
- [ ] The deferred eBay credentials and the Phase-3 Stripe credentials are marked distinctly from the active MVP variables in `.env.example`.
- [ ] The Vercel project environment variables are configured across the **Production** and **Preview** (= dev/qa) scopes.
- [ ] The GitHub Actions encrypted secrets are configured and never committed; `.env`, `.env.local`, and `.env.*.local` remain git-ignored.
- [ ] The pooled `DATABASE_URL` (runtime) versus unpooled `DATABASE_URL_UNPOOLED` (DDL/migrations) discipline is documented, and the two are stored as distinct values in every scope.
- [ ] The single Blitzy environment holds the source-of-truth configuration mirrored to the Vercel two scopes (Production + Preview = dev/qa) and GitHub Actions, configured per <https://docs.blitzy.com/administration/environments>.
- [ ] No prohibited vague quality term appears in any measurable statement; every such statement names a concrete pass/fail condition.
- [ ] **Testing:** a check or test/preview build confirms every active variable (`DATABASE_URL`, `DATABASE_URL_UNPOOLED`, `APIFY_TOKEN`, `LLM_API_KEY`) is present and non-empty before any dependent epic (EPIC-02 through EPIC-06) consumes these variables.
