# FEATURE-04-03: Operator Review-Queue API

*Parent epic: [EPIC-04 — Backend Application & API](../EPIC-04-backend-application-and-api.md)*

## Feature Summary

FEATURE-04-03 delivers the operator-facing review-queue API for CompVault: the list and resolve endpoints over the `review_queue` table — which holds the low-confidence extractions and matches, the new clusters, and the duplicate-merge candidates that the EPIC-03 matcher routed out of the auto-commit path — plus the counterpart-override endpoint over the `counterpart_override` table that records a manual digital↔physical link where the computed counterpart is wrong or missing. The business value is the server-side half of the core operator loop (PRD §8.6): one API surface through which the single seeded operator resolves queued items, confirms new clusters, merges duplicate canonical cards (the primary defense against catalog fragmentation), and pins cross-format links the automated matcher cannot resolve, keeping low-confidence data out of the public price series. Scope is limited to these two endpoint groups; this feature does not build the API scaffolding ([FEATURE-04-01 — Backend Foundation & Environment Access](FEATURE-04-01-backend-foundation-and-environment-access.md)), the search and detail endpoints ([FEATURE-04-02 — Search & Detail Endpoints](FEATURE-04-02-search-and-detail-endpoints.md)), or the review-queue workbench UI (EPIC-05) that consumes these endpoints. Full role-based authentication is deferred — v1 gates every action to the single seeded operator returned by the `getUserId()` seam (`owner_user_id` is NULL in v1). This feature is delivered through **2 stories**.

## Environment Access & Configuration

The platform access these endpoints require — Blitzy encrypted secrets for the server-side database credential, and a Vercel serverless runtime with per-scope environment access that reads the pooled `DATABASE_URL` — is provisioned once in [FEATURE-04-01 — Backend Foundation & Environment Access](FEATURE-04-01-backend-foundation-and-environment-access.md) and documented per the canonical Blitzy environments reference <https://docs.blitzy.com/administration/environments>; the full step-by-step environment configuration is not repeated here.

Each handler opens a short-lived Neon connection through the **pooled** `DATABASE_URL` and never the unpooled `DATABASE_URL_UNPOOLED` (which EPIC-02 reserves for DDL and migrations), threads the operator `userId` from the `getUserId()` seam, and issues no LLM call in the request path. These endpoints therefore depend on the EPIC-02 access layer (the pooled Neon client and the `getUserId()` seam, `STORY-02-03-02`) and on EPIC-03 ingestion, which writes the low-confidence items into `review_queue` that the list and resolve endpoints act on.

## User Stories Index

This feature is delivered through two stories. Each link is relative to this file inside the `EPIC-04/` directory.

1. **[STORY-04-03-01 — Implement Review-Queue Endpoints](FEATURE-04-03/STORY-04-03-01-implement-review-queue-endpoints.md)** — the review-queue list endpoint that filters `review_queue` by `state` (defaulting to `open`) and exposes each item's `kind` (`extraction`, `match`, `new_cluster`, `merge_candidate`), `reason`, and `payload`, alongside the resolve endpoint that transitions an item from `open` to `resolved` or `dismissed` and stamps `resolved_at` and `resolved_by` with the operator `userId`; resolving an item whose `state` is already `resolved` or `dismissed` returns HTTP 409.
2. **[STORY-04-03-02 — Implement Counterpart-Override Endpoint](FEATURE-04-03/STORY-04-03-02-implement-counterpart-override-endpoint.md)** — the operator counterpart-override endpoint that creates or edits a row in `counterpart_override` (`link_level` `card` or `variation`, `physical_ref_id`, `digital_ref_id`, `is_manual` defaulting to true) to pin a manual digital↔physical link where the computed counterpart is wrong or missing; computed counterparts — the same `card_id` across formats, or the same `card_id` plus `parallel_type_id` for shared parallels — remain the default and this table records the manual exceptions only, and a request with a `link_level` outside the set (`card`, `variation`) returns HTTP 400 with an error field named `link_level`.

## Dependencies

### Upstream (must be complete first)

- **EPIC-01 — Environment & Configuration Foundation:** supplies the Next.js + TypeScript scaffold, the Vercel project, and the secrets baseline these endpoints build on.
- **[FEATURE-04-01 — Backend Foundation & Environment Access](FEATURE-04-01-backend-foundation-and-environment-access.md):** supplies the provisioned environment access (per <https://docs.blitzy.com/administration/environments>), the API route scaffolding that threads `userId` from the `getUserId()` seam, and the query-parameter validation these endpoints reuse.
- **EPIC-02 — Database Platform & Schema:** supplies the pooled Neon access layer, the `getUserId()` seam (`STORY-02-03-02`), and the `review_queue` and `counterpart_override` tables these endpoints read and write.
- **EPIC-03 — Data Ingestion Pipeline:** routes low-confidence extractions and matches, new clusters, and merge candidates into `review_queue`; the list and resolve endpoints have no open items to act on until ingestion has written them.

### Downstream (informational — not a build prerequisite of this feature)

- **EPIC-05 — Frontend User Interface:** the operator review-queue workbench (`STORY-05-03-03`) consumes the list, resolve, and counterpart-override endpoints this feature exposes.
- **EPIC-06 — Testing & CI/CD Quality Gates:** `STORY-06-02-02` integration-tests these API routes against a per-CI Neon branch, targeting an API coverage floor of **≥75%**.

## Definition of Done

- [ ] Both stories (STORY-04-03-01, STORY-04-03-02) are complete.
- [ ] The review-queue list endpoint returns `review_queue` items filtered by `state`, defaulting to `state = open` when no `state` filter is supplied, and exposes each item's `kind` (`extraction`, `match`, `new_cluster`, `merge_candidate`), `reason`, and `payload`.
- [ ] The resolve endpoint transitions an `open` item to `resolved` or `dismissed` and stamps `resolved_at` and `resolved_by` with the operator `userId` from `getUserId()`.
- [ ] Resolving an item whose `state` is already `resolved` or `dismissed` returns HTTP 409 and leaves `resolved_at` and `resolved_by` unchanged.
- [ ] The counterpart-override endpoint creates or edits a `counterpart_override` row with a `link_level` of `card` or `variation`, a `physical_ref_id`, a `digital_ref_id`, and `is_manual = true`, recording a manual exception to the computed counterpart.
- [ ] A counterpart-override request with a `link_level` outside the set (`card`, `variation`) returns HTTP 400 with an error field named `link_level` and writes no row.
- [ ] Every endpoint reads the pooled `DATABASE_URL`; no endpoint reads the unpooled `DATABASE_URL_UNPOOLED`.
- [ ] Every endpoint threads the operator `userId` from the `getUserId()` seam (v1 = the single seeded operator) and gates the review and override actions to that operator.
- [ ] No request handler issues an LLM call, and every external data source is an official API.
- [ ] No prohibited vague quality term appears in any acceptance-criteria-like statement; every such statement names a measurable pass/fail condition.
- [ ] **Testing:** API integration tests for the list, resolve, and counterpart-override routes pass against a per-CI Neon branch and meet the **≥75%** API coverage target tracked in EPIC-06 (`STORY-06-02-02`).
