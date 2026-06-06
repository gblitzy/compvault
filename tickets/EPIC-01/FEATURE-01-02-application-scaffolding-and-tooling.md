# FEATURE-01-02: Application Scaffolding & Tooling

*Parent epic: [EPIC-01 — Environment & Configuration Foundation](../EPIC-01-environment-and-configuration-foundation.md)*

## Feature Summary

This feature initializes the **Next.js App Router + TypeScript** application at the repository root, configures **ESLint** and a strict **`tsc --noEmit` typecheck baseline**, and establishes the canonical directory layout — **`app/`, `db/`, `lib/`, `jobs/`, `scripts/`, and `.github/`** — drawn from the PRD repository scaffold (§7.6.1). The business value is one settled scaffold with one linting and typecheck baseline: with the project initialized, ESLint running with zero errors, `tsc --noEmit` exiting 0 with zero type errors, and the six directories present at the repository root, every later epic inherits one consistent place to add code instead of defining its own structure. Scope is limited to initializing the scaffold, configuring the ESLint and `tsc --noEmit` tooling, and creating the directory layout; it does **not** provision the managed environments (that is [FEATURE-01-01 — Blitzy Environment Provisioning](FEATURE-01-01-blitzy-environment-provisioning.md)), it does **not** author `.env.example` or configure the Vercel and GitHub Actions secrets (that is [FEATURE-01-03 — Secrets & Variable Management](FEATURE-01-03-secrets-and-variable-management.md)), and it does **not** implement the database (EPIC-02), ingestion (EPIC-03), API (EPIC-04), or UI (EPIC-05) — those epics populate the directories created here. This feature is delivered through **3 stories**.

## Environment Access & Configuration

The managed environments this scaffold builds and runs within come from [FEATURE-01-01 — Blitzy Environment Provisioning](FEATURE-01-01-blitzy-environment-provisioning.md), documented per the canonical Blitzy environments reference: <https://docs.blitzy.com/administration/environments>. This feature does not duplicate those environment steps; it consumes the single Blitzy environment that feature attaches to the project.

**Runtime floor:** the toolchain runs on Node `>=20.20.2` (the application floor, from the root `package.json` `engines.node`). The Apify actor keeps its own lower floor of Node `>=18` (set through its `engines.node` field in `apify/package.json`; its container image runs Node 20). The scaffold pins the project Node version at `>=20.20.2`, which satisfies both the application and the actor. The application targets the **Next.js App Router deployed on Vercel** (serverless request/response), so the scaffold's build and run configuration matches that stack.

This is a documentation backlog: this feature does **not** execute `npm install` or any scaffold command. The initialization, linting, typecheck, and directory-creation commands described in the child stories are executed when those stories are implemented.

## User Stories Index

This feature is delivered through three stories. Each link is relative to this file inside the `EPIC-01/` directory and resolves into the `FEATURE-01-02/` subfolder.

1. **[STORY-01-02-01 — Initialize the Next.js + TypeScript Project](FEATURE-01-02/STORY-01-02-01-initialize-nextjs-typescript-project.md)** — initialize the Next.js App Router + TypeScript project at the repository root.
2. **[STORY-01-02-02 — Configure ESLint & Strict Typecheck](FEATURE-01-02/STORY-01-02-02-configure-eslint-and-typecheck.md)** — configure ESLint and the `tsc --noEmit` strict typecheck baseline so that ESLint runs with zero errors and `tsc --noEmit` exits 0 with zero type errors on the scaffold.
3. **[STORY-01-02-03 — Establish the Directory Layout](FEATURE-01-02/STORY-01-02-03-establish-directory-layout.md)** — establish the `app/`, `db/`, `lib/`, `jobs/`, `scripts/`, and `.github/` directory layout at the repository root.

## Dependencies

### Upstream (must be complete first)

- **[FEATURE-01-01 — Blitzy Environment Provisioning](FEATURE-01-01-blitzy-environment-provisioning.md):** provides the single Blitzy environment the scaffold builds and runs within. The scaffold pins Node `>=20.20.2` (the application floor; the Apify actor keeps its own `>=18`) against the runtime that environment exposes.

### Downstream (informational — not a build prerequisite of this feature)

- **[FEATURE-01-03 — Secrets & Variable Management](FEATURE-01-03-secrets-and-variable-management.md):** authors `.env.example` and configures the Vercel and GitHub Actions secrets the scaffold consumes at build and run time.
- **EPIC-02 — Database Platform & Schema:** populates `db/` with the Drizzle `schema.ts`, the pooled Neon `client.ts`, and the `migrations/` output.
- **EPIC-03 — Data Ingestion Pipeline:** populates `jobs/` (the ingestion and valuation-recompute jobs) and `scripts/` (the local-only odds parser).
- **EPIC-04 — Backend Application & API:** populates `app/api` with the read endpoints.
- **EPIC-05 — Frontend User Interface:** populates `app/` with the UI routes (search, card detail, compare).
- **EPIC-06 — Testing & CI/CD Quality Gates:** populates `.github/workflows/` with `ci.yml`, `migrate.yml`, and `ingest.yml`.

## Definition of Done

- [ ] All 3 stories (STORY-01-02-01, STORY-01-02-02, STORY-01-02-03) are complete.
- [ ] The Next.js App Router + TypeScript project is initialized at the repository root.
- [ ] ESLint is configured and runs with zero errors on the scaffold.
- [ ] `tsc --noEmit` strict typecheck exits 0 with zero type errors on the scaffold.
- [ ] The directory layout `app/`, `db/`, `lib/`, `jobs/`, `scripts/`, and `.github/` is present at the repository root (six directories).
- [ ] The Node `>=20.20.2` runtime floor is recorded for the project (the application floor); the Apify actor keeps its own Node `>=18` floor, and `>=20.20.2` satisfies both.
- [ ] The scaffold is configured to target the Next.js App Router on Vercel, building on the environments from [FEATURE-01-01 — Blitzy Environment Provisioning](FEATURE-01-01-blitzy-environment-provisioning.md) per <https://docs.blitzy.com/administration/environments>.
- [ ] No prohibited vague quality term appears in any measurable statement; every such statement names a concrete pass/fail condition.
- [ ] **Testing:** `tsc --noEmit` exits 0 with zero type errors and ESLint runs with zero errors on the scaffold before any dependent epic (EPIC-02 through EPIC-06) adds code.
