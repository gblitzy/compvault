# FEATURE-04-01: Backend Foundation & Environment Access

*Parent epic: [EPIC-04 — Backend Application & API](../EPIC-04-backend-application-and-api.md)*

## Feature Summary

This feature configures the Vercel runtime and the backend environment access, then stands up the CompVault API foundation that every other EPIC-04 endpoint builds on: a Next.js App Router route scaffolding that threads `userId` from the `getUserId()` seam through every handler, and query-parameter input validation that rejects malformed input before any data read. The business value is one provisioned, multi-tenant-ready, validated entry point — a configured serverless runtime plus a shared request scaffold — so each later endpoint inherits the environment access, the `userId` threading, and the input validation instead of re-establishing them. Scope is limited to the environment access, the API route scaffolding, and the query-parameter validation: the search and detail endpoints live in [FEATURE-04-02 — Search & Detail Endpoints](FEATURE-04-02-search-and-detail-endpoints.md), the operator review-queue API lives in [FEATURE-04-03 — Operator Review-Queue API](FEATURE-04-03-operator-review-queue-api.md), and this feature builds no UI — that is EPIC-05. This feature is delivered through **3 stories**.

## Environment Access & Configuration

All environment provisioning for this feature follows the canonical Blitzy environments reference: <https://docs.blitzy.com/administration/environments>. Per that reference, an environment is created for each target, build and run instructions are supplied in natural language, non-sensitive values are stored as plaintext environment variables and credentials are stored as encrypted secrets, and the environment is then attached to the project. This step-by-step configuration is completed in full **before** the endpoints in [FEATURE-04-02 — Search & Detail Endpoints](FEATURE-04-02-search-and-detail-endpoints.md) and [FEATURE-04-03 — Operator Review-Queue API](FEATURE-04-03-operator-review-queue-api.md) are implemented.

The backend is a Next.js App Router application deployed on Vercel, where every API route runs as a stateless serverless request/response handler. At runtime each handler reads the **pooled** `DATABASE_URL` to open short-lived Neon connections — never the unpooled `DATABASE_URL_UNPOOLED`, which EPIC-02 reserves for DDL and migrations; many short-lived serverless invocations would otherwise exhaust raw Postgres connections, so the runtime path reads the pooled connection string only. The runtime toolchain floor is **Node `>=18`**, matching the rest of the project.

Every handler threads the operator `userId` from the `getUserId()` seam (EPIC-02 `STORY-02-03-02`, which returns the seeded operator user backed by the `app_user` table) from day one, so enabling real authentication later (Auth.js or Clerk) becomes a configuration change rather than a refactor; full authentication is deferred and is out of MVP scope. The handlers call official data sources only and issue no LLM call in the request path — LLM-assisted extraction stays in the EPIC-03 batch jobs. Because the endpoints read the Neon-backed catalog and the ingested sales, this feature depends on EPIC-02 (the pooled Neon access layer and the `getUserId()` seam) and EPIC-03 (the ingested sales data) being in place before the endpoints are implemented.

### Platforms and access required

| Platform | Access required | Purpose in FEATURE-04-01 |
|----------|-----------------|--------------------------|
| Blitzy | Environment per target; plaintext variables and encrypted secrets | Store the pooled `DATABASE_URL` and the API runtime credentials as encrypted secrets, with non-sensitive values stored as plaintext, per <https://docs.blitzy.com/administration/environments> |
| Vercel | Project access; per-scope environment variables; serverless runtime and deployments | Build and host the Next.js App Router API; expose the pooled `DATABASE_URL` to each route at runtime, with the production deployment on `main` |

### Step-by-step configuration (complete before endpoint work begins)

1. Create the Blitzy environment(s) and store the pooled `DATABASE_URL` plus the API runtime credentials as encrypted secrets, with non-sensitive values stored as plaintext, per <https://docs.blitzy.com/administration/environments>.
2. Connect the repository to Vercel so the Next.js App Router API builds and deploys, with the production deployment on `main`.
3. Set the Vercel project environment variables for each scope so every API route resolves the **pooled** `DATABASE_URL` at runtime and never the unpooled `DATABASE_URL_UNPOOLED`.
4. Pin the Vercel runtime to Node `>=18` so the API executes on the project's declared runtime floor.
5. Confirm the EPIC-02 access layer — the pooled Neon client and the `getUserId()` seam from `STORY-02-03-02` — and the EPIC-03 ingested sales are reachable before any endpoint is implemented.
6. Validate the wiring with a single health route that opens a pooled Neon connection on a Vercel deployment and returns HTTP 200, confirming the environment is provisioned before the first endpoint is authored.

## User Stories Index

This feature is delivered through three stories. Each link is relative to this file inside the `EPIC-04/` directory.

1. **[STORY-04-01-01 — Configure Vercel Runtime & Environment Access](FEATURE-04-01/STORY-04-01-01-configure-vercel-runtime-and-env-access.md)** — configure the Vercel deployment runtime and the environment access so every API route resolves the pooled `DATABASE_URL` at runtime and never the unpooled `DATABASE_URL_UNPOOLED`; cite <https://docs.blitzy.com/administration/environments>.
2. **[STORY-04-01-02 — Implement API Scaffolding with getUserId](FEATURE-04-01/STORY-04-01-02-implement-api-scaffolding-with-getuserid.md)** — implement the Next.js App Router API route scaffolding that threads `userId` from the `getUserId()` seam (EPIC-02 `STORY-02-03-02`) through every handler, with no LLM call in the request path.
3. **[STORY-04-01-03 — Implement Query-Parameter Validation](FEATURE-04-01/STORY-04-01-03-implement-query-parameter-validation.md)** — implement query-parameter input validation that rejects malformed input with HTTP 400 and an `error` field naming the rejected parameter before any data read.

## Dependencies

### Upstream (must be complete first)

- **EPIC-01 — Environment & Configuration Foundation:** supplies the Blitzy environments, the Next.js + TypeScript scaffold, the Vercel project, and the secrets baseline the API builds on.
- **EPIC-02 — Database Platform & Schema:** supplies the pooled Neon access layer and the `getUserId()` seam (`STORY-02-03-02`) that every handler threads; the scaffolding reads the pooled `DATABASE_URL` this layer exposes, and `getUserId()` returns the seeded operator user backed by the `app_user` table.

### Downstream (informational — not a build prerequisite of this feature)

- **[FEATURE-04-02 — Search & Detail Endpoints](FEATURE-04-02-search-and-detail-endpoints.md):** builds the character search, the two-column results, the card-detail, and the price-history endpoints on this scaffolding and validation.
- **[FEATURE-04-03 — Operator Review-Queue API](FEATURE-04-03-operator-review-queue-api.md):** builds the review-queue and the operator counterpart-override endpoints on this scaffolding and validation.
- **EPIC-05 — Frontend User Interface:** consumes the resulting endpoints to render search, the two-column results, the detail price-history chart, and the operator review-queue workbench.
- **EPIC-06 — Testing & CI/CD Quality Gates:** `STORY-06-02-02` integration-tests these API routes against a per-CI Neon branch, targeting an API coverage floor of **≥75%**.

## Definition of Done

- [ ] All 3 stories (STORY-04-01-01, STORY-04-01-02, STORY-04-01-03) are complete.
- [ ] Vercel runtime and environment access are configured per <https://docs.blitzy.com/administration/environments>, with non-sensitive values stored as plaintext variables and credentials stored as encrypted secrets.
- [ ] The platforms Blitzy (encrypted secret storage) and Vercel (serverless API runtime and per-scope environment variables) are provisioned, and the API runtime floor is Node `>=18`.
- [ ] Every API route resolves the pooled `DATABASE_URL` at runtime; no route reads the unpooled `DATABASE_URL_UNPOOLED`.
- [ ] The API route scaffolding threads `userId` from the `getUserId()` seam (EPIC-02 `STORY-02-03-02`) through every handler from day one, with full authentication deferred (out of MVP scope).
- [ ] Query-parameter validation rejects malformed input with HTTP 400 and an `error` field naming the rejected parameter before any data read is issued.
- [ ] No request handler issues an LLM call (LLM-assisted extraction stays in the EPIC-03 batch jobs), and every external data source is an official API.
- [ ] The environment configuration is completed before the FEATURE-04-02 and FEATURE-04-03 endpoints are implemented, and the EPIC-02 (access layer + `getUserId()` seam) and EPIC-03 (ingested sales) dependencies are confirmed reachable.
- [ ] No prohibited vague quality term appears in any acceptance-criteria-like statement; every such statement names a measurable pass/fail condition.
- [ ] **Testing:** API integration tests for the scaffolded routes pass against a per-CI Neon branch and meet the **≥75%** API coverage target tracked in EPIC-06 (`STORY-06-02-02`).
