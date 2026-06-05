# STORY-04-01-01: Configure Vercel Runtime & Environment Access

Feature → [FEATURE-04-01 — Backend Foundation & Environment Access](../FEATURE-04-01-backend-foundation-and-environment-access.md) · Epic → [EPIC-04 — Backend Application & API](../../EPIC-04-backend-application-and-api.md)

This is the environment-access story of FEATURE-04-01 and the **first of its three stories**. It configures the Vercel deployment runtime and the managed environment access from which the CompVault backend reads its configuration, so that every endpoint authored later in the epic inherits one provisioned, serverless request/response runtime instead of re-establishing it. The sibling stories — API scaffolding with `getUserId()` ([STORY-04-01-02](STORY-04-01-02-implement-api-scaffolding-with-getuserid.md)) and query-parameter validation (`STORY-04-01-03`) — and every endpoint in [FEATURE-04-02 — Search & Detail Endpoints](../FEATURE-04-02-search-and-detail-endpoints.md) and [FEATURE-04-03 — Operator Review-Queue API](../FEATURE-04-03-operator-review-queue-api.md) build on the runtime configured here.

The backend is a Next.js (App Router) + TypeScript application deployed on Vercel, where every API route runs as a stateless serverless request/response handler (PRD §7.5). At runtime each handler opens a short-lived Neon connection through the **pooled** `DATABASE_URL` and never the unpooled `DATABASE_URL_UNPOOLED`, which EPIC-02 reserves for DDL and migrations; this story makes that connection-string discipline a configured, reviewed rule before the first endpoint is authored. This step-by-step environment configuration is completed in full **before** the FEATURE-04-02 and FEATURE-04-03 endpoints are implemented.

## User Story

> As a **Backend Engineer**, I want the Vercel deployment runtime and its environment access configured, so that API routes run on the Next.js App Router and read the pooled `DATABASE_URL` at runtime.

## Environment Access & Configuration

- **Canonical reference.** All environment provisioning for this story follows the Blitzy environments reference at <https://docs.blitzy.com/administration/environments>. Per that reference, an environment is created for each target, build and run instructions are supplied in natural language, non-sensitive values are stored as **plaintext variables** and sensitive credentials are stored as **encrypted secrets**, and the environment is then **attached to the project**.
- **Platforms.** **Blitzy** provides the managed environment and the encrypted secret storage for the pooled `DATABASE_URL` and the API runtime credentials. **Vercel** is the backend host: it builds and runs the Next.js App Router API as serverless functions and supplies the per-scope environment variables each route reads.
- **Deployment model.** The API runs on the **Next.js App Router on Vercel** as stateless request/response handlers (PRD §7.5); long-running scraping and LLM work do not run on Vercel — they stay in the EPIC-03 batch jobs. Each pull request produces a preview deployment, and the production deployment is produced from `main`.
- **Connection-string discipline (hard rule).** The runtime reads the **pooled `DATABASE_URL` only**. It **never** reads `DATABASE_URL_UNPOOLED` — that unpooled string is reserved for DDL and migrations (EPIC-02). The pooled driver is mandatory because many short-lived serverless invocations would otherwise exhaust raw Postgres connections (PRD §7.5).
- **Runtime toolchain floor.** The Vercel runtime executes on **Node `>=18`**, matching the rest of the project (including the Apify actor's `engines.node` declaration).
- **Identity seam.** Every handler threads the operator `userId` from the `getUserId()` seam (EPIC-02 `STORY-02-03-02`, the seeded operator user backed by the `app_user` table); full authentication is deferred and is wired in the sibling [STORY-04-01-02](STORY-04-01-02-implement-api-scaffolding-with-getuserid.md). The handlers read official APIs only and issue no LLM call in the request path.
- **Sequencing.** This step-by-step environment configuration completes **before** the endpoints in FEATURE-04-02 (search and detail) and FEATURE-04-03 (operator review-queue) are implemented.

### Platforms and access required

| Platform | Access required | Purpose in STORY-04-01-01 |
|----------|-----------------|---------------------------|
| Blitzy | Environment per target; plaintext variables and encrypted secrets | Store the pooled `DATABASE_URL` and the API runtime credentials as encrypted secrets, with non-sensitive values stored as plaintext, then attach the environment to the project per <https://docs.blitzy.com/administration/environments> |
| Vercel | Project access; GitHub integration; per-scope environment variables; serverless runtime and deployments | Build and host the Next.js App Router API; resolve the pooled `DATABASE_URL` to each route at runtime; expose one preview deployment per pull request and the production deployment on `main` |

### Step-by-step configuration (complete before endpoint implementation)

1. In **Blitzy**, create the backend environment(s) per <https://docs.blitzy.com/administration/environments>, store the pooled `DATABASE_URL` as an **encrypted secret** (non-sensitive config as plaintext variables), then **attach the environment to the project** so the runtime reads its variables.
2. In **Vercel**, connect the GitHub repository and enable the GitHub integration so each pull request produces a **preview deployment** and `main` produces the **production deployment**.
3. Set the Vercel environment variables for the **Preview** and **Production** scopes, each pointing at its own pooled Neon **branch** connection string, so the Preview scope never points at the production database.
4. Set and verify the Vercel runtime at **Node `>=18`** so the API executes on the project's declared runtime floor.
5. Verify the runtime resolves `DATABASE_URL` to the pooled Neon connection string and that a health route fails with a **named error identifying `DATABASE_URL`** (a non-200 response) when the secret is absent, confirming the environment is provisioned before the first endpoint is authored.

## Acceptance Criteria

1. **(input-validation — secret presence)** **Given** a deployment whose runtime is missing `DATABASE_URL`, **When** the health check runs, **Then** it fails with a named error that identifies `DATABASE_URL`, and the deployment is not marked healthy.
2. **(valid-output — runtime)** **Given** `DATABASE_URL` is configured as the pooled Neon connection string, **When** the runtime starts, **Then** the Next.js App Router serves a request/response on Vercel and the runtime resolves `DATABASE_URL` to that pooled connection string, returning HTTP **200** from the health route.
3. **(error-handling — unpooled URL in a handler)** **Given** a request handler that references `DATABASE_URL_UNPOOLED`, **When** the configuration is reviewed, **Then** it is rejected under the documented prohibition: `DATABASE_URL_UNPOOLED` is for DDL and migrations only, and the runtime reads the pooled `DATABASE_URL`.
4. **(edge-case — preview vs production boundary)** **Given** the Preview environment and the Production environment, **When** the environments are attached, **Then** Preview resolves a Neon **preview** branch connection string and Production resolves the **production** branch connection string; a configuration where Preview points at the production database fails the attach check.
5. **(valid-output — toolchain)** **Given** the configured Vercel runtime, **When** an API route executes, **Then** it runs on **Node `>=18`**.
6. **(input-validation — secret storage)** **Given** the environment setup follows <https://docs.blitzy.com/administration/environments>, **When** `DATABASE_URL` is stored, **Then** it is stored as an **encrypted secret** and not as a plaintext variable; storing `DATABASE_URL` as a plaintext variable fails review.

## Sub-tasks

- [ ] Create the Blitzy environment(s) per <https://docs.blitzy.com/administration/environments>, store the pooled `DATABASE_URL` as an encrypted secret with non-sensitive config as plaintext variables, then attach the environment to the project (@devops-engineer)
- [ ] Configure the Vercel project — GitHub integration, one preview deployment per pull request, production deployment on `main` (@devops-engineer)
- [ ] Set the Vercel Preview and Production environment variables, each pointing at its own pooled Neon branch connection string so Preview never points at the production database (@devops-engineer)
- [ ] Set and verify the Vercel runtime at Node `>=18` (@devops-engineer)
- [ ] Document the pooled-vs-unpooled rule as a reviewed prohibition: the runtime reads the pooled `DATABASE_URL`; `DATABASE_URL_UNPOOLED` is for DDL and migrations only (@backend-engineer)
- [ ] Add a runtime health route that returns HTTP 200 when `DATABASE_URL` resolves to the pooled Neon connection string and fails with a named error identifying `DATABASE_URL` when the secret is absent (@backend-engineer)
- [ ] Confirm the runtime reads official APIs only and issues no LLM call in any request handler — LLM-assisted extraction stays in the EPIC-03 batch jobs (@tech-lead)
- [ ] Author environment health-check smoke tests and API integration/smoke tests against a per-CI Neon branch (@qa-engineer)

## Edge Cases

- **Empty/Null — `DATABASE_URL` secret missing:** the runtime has no `DATABASE_URL` → the health check fails with a named error that identifies `DATABASE_URL`, and the deployment is not marked healthy.
- **Invalid — unpooled URL at runtime:** `DATABASE_URL_UNPOOLED` is configured for runtime request handling → rejected under the documented prohibition (the unpooled string is for DDL and migrations only; the runtime reads the pooled `DATABASE_URL`).
- **Boundary — preview-vs-production mismatch:** the Preview scope is pointed at the production database connection string → the environment-attach check fails, and Preview is reset to a Neon preview branch so previews never read production data.
- **Concurrent — shared pooled connection:** many concurrent serverless invocations open short-lived connections through the pooled `DATABASE_URL` → the pooled driver absorbs the concurrency so raw Postgres connections are not exhausted (the reason the pooled string is mandatory for the runtime).

## Dependencies

### Upstream (must be complete first)

- **[EPIC-01 — Environment & Configuration Foundation](../../EPIC-01-environment-and-configuration-foundation.md):** supplies the Blitzy environments, the Vercel project, and the secrets / `.env.example` baseline this story attaches the backend runtime to.
- **[EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md):** `STORY-02-03-01` provides the pooled Neon client the runtime reads through `DATABASE_URL`, and `STORY-02-01-04` documents the pooled-vs-unpooled connection split and tracks the open verification item — whether the existing local Neon setup is enough for local and test access.

### Downstream (informational — not a build prerequisite of this story)

- **[STORY-04-01-02 — Implement API Scaffolding with getUserId](STORY-04-01-02-implement-api-scaffolding-with-getuserid.md):** threads `userId` from the `getUserId()` seam through every handler on the runtime configured here; full authentication is deferred to this sibling.
- **[FEATURE-04-02 — Search & Detail Endpoints](../FEATURE-04-02-search-and-detail-endpoints.md)** and **[FEATURE-04-03 — Operator Review-Queue API](../FEATURE-04-03-operator-review-queue-api.md):** every endpoint requires this configured runtime and its pooled `DATABASE_URL` access.
- **[EPIC-05 — Frontend User Interface](../../EPIC-05-frontend-user-interface.md):** consumes the endpoints served by this runtime.
- **[EPIC-06 — Testing & CI/CD Quality Gates](../../EPIC-06-testing-and-cicd-quality-gates.md):** `STORY-06-02-02` integration-tests these API routes against a per-CI Neon branch at an API coverage floor of **≥75%**.

### Parent feature

- **[FEATURE-04-01 — Backend Foundation & Environment Access](../FEATURE-04-01-backend-foundation-and-environment-access.md)**

## Story Estimation Guidance

- **Effort: Medium** — multi-platform configuration spanning Blitzy (encrypted secrets), Vercel (GitHub integration, per-scope environment variables, runtime floor), and the per-scope Neon branch connection strings, which exceeds a single-file change.
- **Complexity: Medium** — wiring Blitzy + Vercel + per-scope Neon branch connection strings, encoding the pooled-vs-unpooled prohibition as a reviewed rule, and pinning the Node `>=18` runtime raises complexity above a single-platform setup.
- **Uncertainty: Medium** — the open verification item from `STORY-02-01-04` (whether the existing local Neon setup is enough for local and test access) is unresolved until the connection strings are confirmed against the runtime.
- **Fibonacci Story Points: 3.** The multi-platform wiring places this above a 1; the fixed platform behavior (PRD §7.5/§7.6.1 and the Blitzy environments doc) and the single resolved-runtime outcome hold it below a 5. Points measure relative size, not a duration.

## Definition of Done

- [ ] Blitzy and Vercel environment access is configured per <https://docs.blitzy.com/administration/environments>, with non-sensitive values stored as plaintext variables and credentials stored as encrypted secrets, and the environment attached to the project.
- [ ] `DATABASE_URL` is stored as an encrypted secret and resolves to the pooled Neon connection string at runtime; storing it as a plaintext variable fails review.
- [ ] The runtime reads the pooled `DATABASE_URL` only and never reads `DATABASE_URL_UNPOOLED` (reserved for DDL and migrations).
- [ ] A missing `DATABASE_URL` fails the health check with a named error that identifies `DATABASE_URL`, and the deployment is not marked healthy.
- [ ] Preview and Production point at separate Neon branches; the Preview scope never points at the production database, and a Preview-pointed-at-production configuration fails the attach check.
- [ ] The Vercel runtime executes on Node `>=18`.
- [ ] The API runs on the Next.js App Router on Vercel as stateless request/response handlers, threading `userId` from the `getUserId()` seam, reading official APIs only, with no LLM call in any request handler.
- [ ] No prohibited vague quality term appears in any acceptance-criteria statement; every statement names a measurable pass/fail condition (an exact env-var name, an HTTP status, "encrypted secret" versus "plaintext variable", Node `>=18`, or a named health-check error).
- [ ] **Testing:** Environment health-check smoke tests and API integration tests against a per-CI Neon branch pass with a ≥75% coverage target.
