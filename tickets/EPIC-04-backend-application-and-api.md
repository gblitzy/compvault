# EPIC-04: Deliver the Backend Application & API — expose character search, two-column digital|physical results, card detail with a price-history chart, and the operator review-queue, threading userId from the getUserId seam

## Epic Summary

EPIC-04 delivers the CompVault backend: a Next.js App Router API on Vercel that serves character search and autocomplete, the two-column digital | physical results, card/variation detail with a recent-sales table, the 90-day/1-year price-history and trend backed by the `valuation` cache, and the operator review-queue and counterpart-override endpoints over the Neon-backed catalog. The business value is a single read-and-review API surface that turns the ingested sales data into the search, comparison, and price-history responses the frontend renders, plus the operator workflow that keeps low-confidence matches out of the price series. Scope is limited to the API endpoints, their input validation, and the review-queue/override actions; every handler threads `userId` from the `getUserId()` seam from the outset while full authentication is deferred (out of MVP scope), this epic depends on the ingested sales data and the Neon access layer, and it builds no UI — that is EPIC-05.

## Environment Access & Configuration

All environment provisioning for this epic follows the canonical Blitzy environments reference: <https://docs.blitzy.com/administration/environments>. Non-sensitive values are stored as plaintext environment variables and credentials are stored as encrypted secrets, after which the environment is attached to the project. This step-by-step configuration is completed in full **before** any endpoint implementation work begins.

The backend is a Next.js App Router application deployed on Vercel, where every API route runs as a stateless serverless request/response handler. At runtime each handler reads the **pooled** `DATABASE_URL` to open short-lived Neon connections — never the unpooled `DATABASE_URL_UNPOOLED`, which is reserved for DDL and migrations in EPIC-02. The handlers call official data sources only and issue no LLM calls in the request path; LLM-assisted extraction stays in the EPIC-03 batch jobs. Because the endpoints read the catalog and the ingested sales, this epic depends on EPIC-02 (the Neon access layer and the `getUserId()` seam) and EPIC-03 (the ingested sales data) being in place.

### Platforms and access required

| Platform | Access required | Purpose in EPIC-04 |
|----------|-----------------|--------------------|
| Blitzy | Dev/Staging/Prod environments; plaintext variables and encrypted secrets | Store the pooled `DATABASE_URL` and the API runtime secrets per the Blitzy environments reference |
| Vercel | Project access; per-scope environment variables; serverless runtime and deployments | Build and host the Next.js App Router API; expose the pooled `DATABASE_URL` to each route at runtime |

### Step-by-step configuration (complete before endpoint work begins)

1. Create the Blitzy environments and store the pooled `DATABASE_URL` plus the API runtime secrets as encrypted secrets, with non-sensitive values stored as plaintext, per <https://docs.blitzy.com/administration/environments>.
2. Connect the repository to Vercel so the Next.js App Router API builds and deploys, with the production deployment on `main`.
3. Set the Vercel project environment variables for each scope so every API route resolves the pooled `DATABASE_URL` at runtime and never the unpooled `DATABASE_URL_UNPOOLED`.
4. Confirm the EPIC-02 access layer — the pooled Neon client and the `getUserId()` seam from `STORY-02-03-02` — and the EPIC-03 ingested sales are reachable before any endpoint is implemented.
5. Validate the wiring with a single health route that opens a pooled Neon connection on a Vercel deployment, confirming the environment is provisioned before the first endpoint is authored.

## Features Index

This epic is delivered through three features. Each link is relative to this file inside the `EPIC-04/` directory.

1. **[FEATURE-04-01 — Backend Foundation & Environment Access](EPIC-04/FEATURE-04-01-backend-foundation-and-environment-access.md)** — complete the Vercel runtime and environment access above, then scaffold the API routes so each handler threads `userId` from the `getUserId()` seam and validates its query parameters before reading data. This feature carries three stories.
2. **[FEATURE-04-02 — Search & Detail Endpoints](EPIC-04/FEATURE-04-02-search-and-detail-endpoints.md)** — implement character search with autocomplete, the digital | physical two-column results, the card/variation detail with its recent-sales table, and the 90-day/1-year price-history and trend backed by the `valuation` cache. This feature carries four stories.
3. **[FEATURE-04-03 — Operator Review-Queue API](EPIC-04/FEATURE-04-03-operator-review-queue-api.md)** — implement the review-queue list and resolve endpoints and the operator counterpart-override endpoint that records manual cross-format links. This feature carries two stories.

## Dependencies

### Upstream (must be complete first)

- **EPIC-01 — Environment & Configuration Foundation:** supplies the Next.js + TypeScript scaffold, the Vercel project, and the secrets baseline the API builds on.
- **EPIC-02 — Database Platform & Schema:** supplies the pooled Neon access layer and the `getUserId()` seam (`STORY-02-03-02`) that every handler threads; the API reads the catalog tables (`character`, `card`, `card_character`, `variation`, `parallel_type`), the `sale_observation` time series, the `valuation` cache, and the `review_queue` and `counterpart_override` tables this layer exposes.
- **EPIC-03 — Data Ingestion Pipeline:** supplies the ingested `sale_observation` rows and the `valuation` cache the search, detail, and price-history endpoints read; no endpoint returns live sales data until ingestion has written it.

### Downstream (informational — not a build prerequisite of this epic)

- **EPIC-05 — Frontend User Interface:** consumes these endpoints to render search, the two-column results, the detail price-history chart, and the operator review-queue workbench.
- **EPIC-06 — Testing & CI/CD Quality Gates:** `STORY-06-02-02` integration-tests these API routes against a per-CI Neon branch, targeting an API coverage floor of **≥75%**.

## Definition of Done

- [ ] All 3 child features (FEATURE-04-01, FEATURE-04-02, FEATURE-04-03) are complete.
- [ ] Vercel runtime and environment access are configured per <https://docs.blitzy.com/administration/environments>, with each API route resolving the pooled `DATABASE_URL` at runtime.
- [ ] The API route scaffolding threads `userId` from the `getUserId()` seam on every handler and validates query parameters before any data read, rejecting malformed input with a `400` response.
- [ ] The character search and autocomplete endpoint returns matching characters drawn from the `character` and `card_character` tables.
- [ ] The digital | physical two-column results endpoint returns each variation's latest sold price split by `format` (`physical` and `digital`).
- [ ] The card/variation detail endpoint returns the recent-sales table from `sale_observation` (price, sold date, grade, serial number, source link, and description snippet).
- [ ] The price-history and trend endpoint reads the `valuation` cache for the 90-day (`window_days = 90`) and 1-year (`window_days = 365`) windows and returns the median, the percent change (`trend_pct`), and the trend direction (`trend_dir`, surfaced as ▲/▼).
- [ ] The review-queue list and resolve endpoints and the operator counterpart-override endpoint are implemented against the `review_queue` and `counterpart_override` tables.
- [ ] Every endpoint reads the pooled `DATABASE_URL`; no endpoint reads the unpooled `DATABASE_URL_UNPOOLED`.
- [ ] No request handler issues an LLM call (LLM-assisted extraction stays in the EPIC-03 batch jobs), and every external data source is an official API.
- [ ] **Testing:** API integration tests pass against a per-CI Neon branch and meet the **≥75%** API coverage target tracked in EPIC-06 (`STORY-06-02-02`).
