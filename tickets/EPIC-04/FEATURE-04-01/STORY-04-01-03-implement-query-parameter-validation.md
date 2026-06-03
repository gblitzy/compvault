# STORY-04-01-03: Implement Query-Parameter Validation

Feature → [FEATURE-04-01 — Backend Foundation & Environment Access](../FEATURE-04-01-backend-foundation-and-environment-access.md) · Epic → [EPIC-04 — Backend Application & API](../../EPIC-04-backend-application-and-api.md)

This is the **third of the three stories** in FEATURE-04-01 and the input-validation layer that wraps the API route scaffolding from [STORY-04-01-02](STORY-04-01-02-implement-api-scaffolding-with-getuserid.md). It specifies a **shared query-parameter validation contract** that rejects malformed requests with **HTTP 400** — a structured body whose `error` field names the offending parameter — **before any database access**, so every downstream endpoint inherits one deterministic guard instead of re-checking input per route. The combinable search filters defined in the PRD (§4.1 FR-2: format toggle, variation by parallel + print run, grade, set, year, price range, date-sold range) are exactly the query parameters this contract governs, and the search and detail endpoints in [FEATURE-04-02](../FEATURE-04-02-search-and-detail-endpoints.md) reuse it unchanged (PRD §7.5).

Validation runs first and short-circuits invalid input, so it issues no query of its own. On the success path the request reaches a handler that reads the **pooled `DATABASE_URL`** (never the unpooled `DATABASE_URL_UNPOOLED`, which EPIC-02 reserves for DDL and migrations), threads the operator `userId` from the `getUserId()` seam, and makes **no LLM call** — LLM-assisted extraction stays in the EPIC-03 batch jobs (PRD §7, §7.5). The concrete value domains come from `docs/schema.sql` and the PRD: a `format` parameter accepts only `physical` or `digital` (`format_t`); a price-history `window` accepts only `90` or `365` (`valuation.window_days`); a history `granularity` accepts only `day`, `week`, `month`, or `year` (FR-2 / FR-8); numeric ids are positive `BIGINT` identity keys; and a `limit` is a bounded numeric page size.

## User Story

> As an **API Engineer**, I want query-parameter input validation, so that malformed requests are rejected with **HTTP 400** before any database access.

## Acceptance Criteria

1. **(input-validation — malformed parameter)** **Given** a request with a malformed query parameter, **When** the request is processed, **Then** the response is **HTTP 400** with a structured body whose `error` field names the offending parameter, and **no database query is executed**.
2. **(valid-output — schema-conformant request)** **Given** a request whose query parameters satisfy the validation schema (for example `format=digital&limit=20`), **When** the request is processed, **Then** validation passes and the request reaches the handler, which returns **HTTP 200** on the success path.
3. **(error-handling — numeric out of range)** **Given** a numeric parameter whose value is below the documented minimum or above the documented maximum (for example `limit` above its maximum of `100`, or below its minimum of `1`), **When** the request is processed, **Then** the response is **HTTP 400** with an `error` field naming that parameter, and **no database query is executed**.
4. **(edge-case — empty or missing required parameter)** **Given** a required parameter that is empty or absent (for example a search request with no `character` value), **When** the request is processed, **Then** the response is **HTTP 400** with an `error` field naming the missing parameter.
5. **(edge-case — unknown or extra parameter)** **Given** a request that includes an unknown query parameter not declared in the validation schema, **When** the request is processed, **Then** the response is **HTTP 400** with an `error` field naming that unknown parameter; the validator rejects an undeclared parameter rather than forwarding it to the query, and this reject-and-name rule is the single rule applied across every route.
6. **(invalid — wrong type)** **Given** a non-numeric value where a numeric parameter is expected (for example `limit=abc` or `window=ninety`), **When** the request is processed, **Then** the response is **HTTP 400** with an `error` field naming the parameter, and validation occurs **before any database access**.
7. **(input-validation — value outside allowed domain)** **Given** a parameter whose value falls outside its allowed-value set (for example `format=both`, `window=180`, or `granularity=hour`), **When** the request is processed, **Then** the response is **HTTP 400** with an `error` field naming the parameter, because `format` accepts only `physical` or `digital`, `window` accepts only `90` or `365`, and `granularity` accepts only `day`, `week`, `month`, or `year`.

## Sub-tasks

- [ ] Define a shared query-parameter validation schema/utility — per-parameter name, type, required flag, min/max bound, and allowed-value set (`format` ∈ {`physical`, `digital`}; `window` ∈ {`90`, `365`}; `granularity` ∈ {`day`, `week`, `month`, `year`}) — reused by every EPIC-04 route (@api-engineer)
- [ ] Return **HTTP 400** with a structured body whose `error` field names the failing parameter on any validation failure (@api-engineer)
- [ ] Enforce numeric range bounds and reject non-numeric values where a numeric parameter is expected — for example `limit` ∈ [`1`, `100`] and a four-digit numeric `year` (@api-engineer)
- [ ] Implement the unknown/extra-parameter rule deterministically — reject any undeclared parameter with **HTTP 400** and an `error` field naming it, and do not forward it to the query (@api-engineer)
- [ ] Guarantee validation runs **before any database access** — no query is issued on invalid input, and the validator short-circuits the request (@backend-engineer)
- [ ] Author API integration tests against a per-CI Neon branch covering malformed, out-of-range, empty/missing, wrong-type, unknown-parameter, and valid pass-through cases (@qa-engineer)
- [ ] Confirm the validation path makes no LLM call and that downstream handlers read only the pooled `DATABASE_URL` (never `DATABASE_URL_UNPOOLED`) and thread `userId` from `getUserId()` (@tech-lead)

## Edge Cases

- **Empty/Null:** a required parameter that is empty or missing (for example `character=` or an absent `character`) → **HTTP 400** with an `error` field naming it, and no database query is executed.
- **Boundary:** a value exactly at the documented minimum or maximum is accepted (for example `limit=1` and `limit=100`); one unit beyond the bound (`limit=0` or `limit=101`) → **HTTP 400** with an `error` field naming `limit`.
- **Invalid:** a non-numeric value where a numeric parameter is expected (for example `limit=abc`) → **HTTP 400** with an `error` field naming the parameter, and validation occurs before any database access.
- **Concurrent:** concurrent malformed and valid requests each receive an independent, deterministic outcome, because the validator holds no shared mutable state — one request's rejection never alters another request's result.

## Dependencies

### Upstream (must be complete first)

- **[`STORY-04-01-02 — Implement API Scaffolding with getUserId`](STORY-04-01-02-implement-api-scaffolding-with-getuserid.md):** supplies the `getUserId()`-threaded Next.js App Router handlers this validation layer wraps; the validator runs at the entry of those handlers before any data access and does not re-implement the seam.
- **[FEATURE-04-01 — Backend Foundation & Environment Access](../FEATURE-04-01-backend-foundation-and-environment-access.md):** the parent feature whose configured Vercel runtime and pooled `DATABASE_URL` access the validated handlers run on.
- **[EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md):** supplies the pooled Neon access layer the validated handlers read through `DATABASE_URL`, and the value domains (`format_t`, `valuation.window_days`) the validator enforces as allowed-value sets.

### Downstream (informational — not a build prerequisite of this story)

- **[FEATURE-04-02 — Search & Detail Endpoints](../FEATURE-04-02-search-and-detail-endpoints.md):** the character-search, two-column results, card-detail, and price-history endpoints reuse this validation contract for their combinable filters.
- **[FEATURE-04-03 — Operator Review-Queue API](../FEATURE-04-03-operator-review-queue-api.md):** the review-queue and counterpart-override endpoints reuse this validation contract for their query parameters.
- **[EPIC-06 — Testing & CI/CD Quality Gates](../../EPIC-06-testing-and-cicd-quality-gates.md):** `STORY-06-02-02` integration-tests these API routes against a per-CI Neon branch at an API coverage floor of **≥75%**.

### Parent feature

- **[FEATURE-04-01 — Backend Foundation & Environment Access](../FEATURE-04-01-backend-foundation-and-environment-access.md)**

## Story Estimation Guidance

- **Effort: Low** — one shared, schema-driven validation utility plus its per-route wiring, a bounded change rather than a multi-file build.
- **Complexity: Low** — the validator is deterministic and stateless: declared parameters, type checks, min/max bounds, and allowed-value sets, with one reject-and-name rule for unknown parameters and no branching beyond the schema.
- **Uncertainty: Low** — the parameter domains are fixed by `docs/schema.sql` (`format_t`, `valuation.window_days`) and the PRD §4.1 FR-2 filter list, and the scaffolding it wraps is defined upstream in STORY-04-01-02, leaving no open design question; the cross-route reuse adds minor care, not risk.
- **Fibonacci Story Points: 2.** The deterministic, schema-driven validator is light, and the cross-route reuse holds it above a 1 while the fixed domains and the upstream-defined scaffolding keep it below a 3. Points measure relative size, not a duration.

## Definition of Done

- [ ] A malformed query parameter returns **HTTP 400** with a structured body whose `error` field names the offending parameter, and no database query is executed.
- [ ] An out-of-range numeric parameter (below the documented minimum or above the documented maximum, for example `limit` outside [`1`, `100`]) returns **HTTP 400** with an `error` field naming that parameter.
- [ ] An empty or missing required parameter returns **HTTP 400** with an `error` field naming the missing parameter.
- [ ] A non-numeric value where a numeric parameter is expected returns **HTTP 400** with an `error` field naming the parameter.
- [ ] A value outside its allowed-value domain (`format` other than `physical`/`digital`; `window` other than `90`/`365`; `granularity` other than `day`/`week`/`month`/`year`) returns **HTTP 400** with an `error` field naming the parameter.
- [ ] A request whose parameters satisfy the validation schema passes validation and reaches the handler, which returns **HTTP 200** on the success path.
- [ ] The unknown/extra-parameter rule is documented and applied deterministically — an undeclared parameter returns **HTTP 400** with an `error` field naming it and is not forwarded to the query.
- [ ] Validation runs **before any database access**, holds no shared mutable state, and yields an independent, deterministic outcome for each concurrent request.
- [ ] Downstream handlers read the pooled `DATABASE_URL` (never `DATABASE_URL_UNPOOLED`), thread `userId` from `getUserId()`, and make no LLM call in the request path.
- [ ] No prohibited vague quality term appears in any acceptance-criteria statement; every statement names a measurable pass/fail condition (an exact HTTP status, the `error` field name, an exact parameter name, a min/max bound, an allowed-value set, or "before any database access").
- [ ] **Testing:** API integration tests against a per-CI Neon branch pass with a ≥75% coverage target.
