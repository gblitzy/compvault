# EPIC-01: Establish the Environment & Configuration Foundation — provision the Blitzy/Vercel/GitHub environments, scaffold the Next.js + TypeScript application, and deliver a validated secrets baseline every later epic depends on

## Epic Summary

EPIC-01 establishes the CompVault foundation: it provisions the managed Blitzy, Vercel, and GitHub Actions environments, scaffolds the Next.js App Router + TypeScript application at the repository root, and authors the `.env.example` secrets baseline that every later epic consumes. The business value is a single configured foundation — three managed environments, one application scaffold, and one documented variable set — so the downstream database, ingestion, backend, frontend, and testing epics build on settled tooling instead of each provisioning its own. Scope is limited to provisioning the environments, initializing the scaffold and its directory layout, and authoring the `.env.example` template; this epic builds no database (EPIC-02), no ingestion (EPIC-03), no API (EPIC-04), and no UI (EPIC-05), and it does not execute `npm install` as part of this documentation backlog.

## Environment Access & Configuration

All environment provisioning for this epic follows the canonical Blitzy environments reference: <https://docs.blitzy.com/administration/environments>. Following that reference, an environment is created for each target, natural-language build and run instructions are supplied, non-sensitive values are stored as plaintext environment variables and credentials are stored as encrypted secrets, and the environment is then attached to the project. This step-by-step configuration is completed in full **before** any implementation work in the dependent epics (EPIC-02 through EPIC-06) proceeds.

This epic is the foundation, so it provisions the three managed platforms the application runs on — **Blitzy** (the Dev, Staging, and Prod environments), **Vercel** (application hosting and per-scope environment variables), and **GitHub Actions** (CI encrypted secrets) — and standardizes the variable set the rest of the backlog consumes. The application targets the Next.js App Router deployed on Vercel.

**Runtime floor:** Node `>=18` for the application toolchain. The existing Apify actor sets this floor through its `engines.node` field and its container image runs Node 20; the scaffold pins the project Node version at or above this floor so the application and the actor share one runtime.

### Platforms and access required

| Platform | Access required | Purpose in EPIC-01 |
|----------|-----------------|--------------------|
| Blitzy | Dev/Staging/Prod environments; plaintext variables and encrypted secrets | Create the three environments, store the variable set as plaintext and the credentials as encrypted secrets, and attach each environment to the project per the Blitzy environments reference |
| Vercel | Project access; per-scope environment variables; App Router builds and deployments | Host the Next.js App Router application and expose the active variable set to each deployment scope |
| GitHub Actions | Encrypted repository or organization secrets | Store the CI and ingestion secrets the later workflows consume |

### Environment variables standardized by this epic

This epic's `.env.example` enumerates the variable set for the whole backlog. The **pooled** `DATABASE_URL` (runtime reads) and the **unpooled** `DATABASE_URL_UNPOOLED` (DDL and migrations) are kept distinct, because mixing the two breaks migrations; EPIC-02 consumes both downstream.

| Variable | Role | Status |
|----------|------|--------|
| `DATABASE_URL` | Pooled Neon connection read at runtime by the application | Active (MVP) |
| `DATABASE_URL_UNPOOLED` | Unpooled Neon connection used for DDL and migrations | Active (MVP) |
| `APIFY_TOKEN` | Apify Platform token authorizing actor execution for ingestion | Active (MVP) |
| `LLM_API_KEY` | Key for the batch LLM-assisted extraction parser (batch jobs only, never in a request handler) | Active (MVP) |
| `EBAY_CLIENT_ID` / `EBAY_CLIENT_SECRET` | eBay Browse / Marketplace-Insights API credentials | Deferred — blocked on approved access |
| `STRIPE_SECRET_KEY` / `STRIPE_WEBHOOK_SECRET` | Stripe billing credentials | Phase 3 — out of MVP scope; documented placeholder only |

### Step-by-step configuration (complete before dependent epics proceed)

1. Create the Blitzy Dev, Staging, and Prod environments, supply the natural-language build and run instructions, store non-sensitive values as plaintext variables and credentials as encrypted secrets, and attach each environment to the project per <https://docs.blitzy.com/administration/environments>.
2. Initialize the Next.js App Router + TypeScript scaffold at the repository root and establish the `app/`, `db/`, `lib/`, `jobs/`, `scripts/`, and `.github/` directory layout (FEATURE-01-02).
3. Author `.env.example` enumerating every variable in the table above, marking the deferred `EBAY_CLIENT_ID`/`EBAY_CLIENT_SECRET` and the Phase-3 `STRIPE_SECRET_KEY`/`STRIPE_WEBHOOK_SECRET` placeholders distinctly (FEATURE-01-03).
4. Configure the Vercel project environment variables for each scope so deployments resolve the active variable set.
5. Configure the GitHub Actions encrypted secrets the CI and ingestion workflows consume.
6. Confirm Node `>=18` is pinned for the project so the application and the Apify actor share one runtime.
7. Validate the foundation with a test/preview build before any dependent epic (EPIC-02 through EPIC-06) proceeds.

## Features Index

This epic is delivered through three features. Each link is relative to this file inside the `EPIC-01/` directory.

1. **[FEATURE-01-01 — Blitzy Environment Provisioning](EPIC-01/FEATURE-01-01-blitzy-environment-provisioning.md)** — create the Dev, Staging, and Prod Blitzy environments, define the plaintext variables and the encrypted secrets, attach the environments to the project, and validate them with a test build. This feature carries three stories.
2. **[FEATURE-01-02 — Application Scaffolding & Tooling](EPIC-01/FEATURE-01-02-application-scaffolding-and-tooling.md)** — initialize the Next.js App Router + TypeScript scaffold at the repository root, configure ESLint and the `tsc --noEmit` strict typecheck baseline, and establish the `app/`, `db/`, `lib/`, `jobs/`, `scripts/`, and `.github/` directory layout. This feature carries three stories.
3. **[FEATURE-01-03 — Secrets & Variable Management](EPIC-01/FEATURE-01-03-secrets-and-variable-management.md)** — author `.env.example` with every required variable, configure the Vercel project environment variables, and configure the GitHub Actions encrypted secrets. This feature carries three stories.

## Dependencies

### Upstream (must be complete first)

- **None.** EPIC-01 is the root of the dependency graph; it has no upstream epic and provisions the foundation every other epic builds on.

### Downstream (informational — not a build prerequisite of this epic)

- **EPIC-02 — Database Platform & Schema:** consumes the Blitzy environments and the secrets baseline into which the pooled `DATABASE_URL` and the unpooled `DATABASE_URL_UNPOOLED` are stored, and builds on the scaffold's `db/` directory.
- **EPIC-03 — Data Ingestion Pipeline:** consumes the `APIFY_TOKEN` and `LLM_API_KEY` secrets and the GitHub Actions environment this epic configures, and builds on the scaffold's `jobs/` directory.
- **EPIC-04 — Backend Application & API:** builds on the Next.js App Router scaffold and the Vercel project this epic provisions, reading the pooled `DATABASE_URL` exposed here.
- **EPIC-05 — Frontend User Interface:** builds on the same Next.js scaffold and the Vercel preview deployments this epic provisions.
- **EPIC-06 — Testing & CI/CD Quality Gates:** consumes the GitHub Actions encrypted secrets and the scaffold this epic delivers; its pipeline runs against the environments provisioned here.

## Definition of Done

- [ ] All 3 child features (FEATURE-01-01, FEATURE-01-02, FEATURE-01-03) are complete.
- [ ] The Blitzy Dev, Staging, and Prod environments are created and attached to the project per <https://docs.blitzy.com/administration/environments>.
- [ ] The Next.js App Router + TypeScript scaffold is initialized at the repository root and the `app/`, `db/`, `lib/`, `jobs/`, `scripts/`, and `.github/` directory layout is present.
- [ ] The ESLint and `tsc --noEmit` strict typecheck baseline runs with zero errors.
- [ ] `.env.example` is committed and enumerates every required variable — `DATABASE_URL`, `DATABASE_URL_UNPOOLED`, `APIFY_TOKEN`, `LLM_API_KEY`, the deferred `EBAY_CLIENT_ID`/`EBAY_CLIENT_SECRET`, and the Phase-3 `STRIPE_SECRET_KEY`/`STRIPE_WEBHOOK_SECRET` placeholders.
- [ ] The Vercel project environment variables and the GitHub Actions encrypted secrets are configured.
- [ ] Node `>=18` is pinned for the project so the application and the Apify actor share one runtime.
- [ ] **Testing:** a test/preview build validates the environment foundation end to end before any dependent epic (EPIC-02 through EPIC-06) proceeds.
