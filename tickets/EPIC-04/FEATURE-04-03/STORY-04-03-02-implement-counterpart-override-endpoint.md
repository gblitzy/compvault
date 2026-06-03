# STORY-04-03-02: Implement Counterpart-Override Endpoint

*Parent feature: [FEATURE-04-03 — Operator Review-Queue API](../FEATURE-04-03-operator-review-queue-api.md) · Parent epic: [EPIC-04 — Backend Application & API](../../EPIC-04-backend-application-and-api.md)*

This is the **second of the two** stories in FEATURE-04-03 (Operator Review-Queue API). It specifies the **counterpart-override endpoint** — the server-side half of the PRD §8.6 counterpart-override editor — through which the single seeded operator pins a **manual** digital↔physical link in the `counterpart_override` table where the computed counterpart is wrong or missing. Cross-format counterparts are **computed by default, not stored**: the card-level counterpart is the same `card_id` expressed across formats, and the variation-level counterpart is the same `card_id` plus `parallel_type_id` across formats (PRD §3.3; `docs/schema.sql` example queries #4 and #5). This table records only the manual exceptions, so **every row this endpoint writes sets `is_manual = TRUE`**. The endpoint builds on the FEATURE-04-01 API scaffolding: it reads the pooled `DATABASE_URL` (never the unpooled `DATABASE_URL_UNPOOLED`, which EPIC-02 reserves for DDL and migrations), threads the operator `userId` from the `getUserId()` seam (v1 = the single seeded operator, `owner_user_id` is NULL), issues no LLM call in the request path, sources data through official APIs only, and is gated to the operator role (full role-based authentication is deferred). The catalog reference ids resolve against the `card` and `variation` tables in `docs/schema.sql`.

## User Story

**As an** Operator, **I want** a counterpart-override endpoint, **so that** I can create or edit a manual digital↔physical link where the computed counterpart is wrong or missing.

## Acceptance Criteria

1. **(valid-output — CREATE at variation level)** **Given** a POST body with `link_level = variation`, an existing `physical_ref_id` resolving to a physical `variation` row, and an existing `digital_ref_id` resolving to a digital `variation` row, **When** the request is processed, **Then** the response is HTTP **201** and the stored `counterpart_override` row has `is_manual = TRUE` and a `link_level`, `physical_ref_id`, and `digital_ref_id` equal to the supplied values.
2. **(valid-output — CREATE at card level)** **Given** a POST body with `link_level = card`, an existing `physical_ref_id` resolving to a `card` row, and an existing `digital_ref_id` resolving to a `card` row, **When** the request is processed, **Then** the response is HTTP **201** and the row records the card-level manual link with `is_manual = TRUE`.
3. **(input-validation — link_level)** **Given** a POST body whose `link_level` is a value outside the CHECK set `('card', 'variation')` (for example `set`), **When** the request is processed, **Then** the response is HTTP **400** with an `error` field named `link_level` and zero rows are inserted into `counterpart_override`.
4. **(input-validation — missing reference id)** **Given** a POST body missing `physical_ref_id` or missing `digital_ref_id`, **When** the request is processed, **Then** the response is HTTP **400** with an `error` field naming the missing field (`physical_ref_id` or `digital_ref_id`) and zero rows are inserted.
5. **(error-handling — unresolved reference)** **Given** a POST body whose `physical_ref_id` or `digital_ref_id` does not resolve to an existing `card` row (when `link_level = card`) or `variation` row (when `link_level = variation`), **When** the request is processed, **Then** the response is HTTP **404** for an id that matches no row, or HTTP **422** for an id of the wrong format for the `link_level`, with a named error field identifying the unresolved id, and zero rows are inserted.
6. **(valid-output — EDIT)** **Given** an existing override `id`, **When** the operator PATCHes it with a new `physical_ref_id`, `digital_ref_id`, and/or `notes`, **Then** the response is HTTP **200** and the stored row reflects the updated `physical_ref_id`, `digital_ref_id`, and `notes`; any changed reference id re-resolves against `card`/`variation` per the stored `link_level`.
7. **(edge-case — digital-only, no physical counterpart)** **Given** a `variation`-level POST whose digital side is a format-exclusive parallel with `parallel_type.format_availability = 'digital'` (for example Gilded) for which no physical `variation` shares its `(card_id, parallel_type_id)`, **When** the request is processed, **Then** the response is HTTP **422** labeled `no physical counterpart` and zero rows are inserted.

## Sub-tasks

- [ ] Implement the CREATE (POST) handler that inserts a `counterpart_override` row with `is_manual = TRUE` through the pooled `DATABASE_URL` and returns HTTP 201 with the created row (@backend-engineer)
- [ ] Validate `link_level` against the CHECK set `('card', 'variation')` and require both `physical_ref_id` and `digital_ref_id`, returning HTTP 400 with an `error` field that names the offending field (@backend-engineer)
- [ ] Resolve each reference id against `card` (for `link_level = card`) or `variation` (for `link_level = variation`), returning HTTP 404 for an id that matches no row and HTTP 422 for an id of the wrong format, with a named error field (@backend-engineer)
- [ ] Implement the EDIT (PATCH) handler on the override `id` that updates `physical_ref_id`, `digital_ref_id`, and/or `notes`, re-resolves any changed reference id, and returns HTTP 200 (@backend-engineer)
- [ ] Define and implement the duplicate-pair rule as HTTP 409: a pre-insert existence check on `(link_level, physical_ref_id, digital_ref_id)` runs inside a single serializable transaction so a repeat triple returns HTTP 409 and inserts no second row (@backend-engineer)
- [ ] Implement the digital-only rejection: a `variation`-level request whose digital side has `parallel_type.format_availability = 'digital'` with no physical `variation` sharing `(card_id, parallel_type_id)` returns HTTP 422 labeled `no physical counterpart` (@backend-engineer)
- [ ] Thread the operator `userId` from the `getUserId()` seam, gate the endpoint to the operator role, and read the pooled `DATABASE_URL` only — never the unpooled `DATABASE_URL_UNPOOLED` (@backend-engineer)
- [ ] Author API integration tests for CREATE, EDIT, the 400/404/422/409 paths, and the digital-only rejection against a per-CI Neon branch (@qa-engineer)
- [ ] Confirm the request handler issues zero LLM calls and sources data through official APIs only (@tech-lead)

## Edge Cases

- **Empty/Null — missing reference id:** a POST missing `physical_ref_id` or `digital_ref_id` returns HTTP 400 with an `error` field naming the missing field and inserts zero rows.
- **Invalid — digital-only (no physical counterpart):** a `variation`-level request for a digital-only parallel (`parallel_type.format_availability = 'digital'`, for example Gilded) that has no physical `variation` sharing its `(card_id, parallel_type_id)` returns HTTP 422 labeled `no physical counterpart` and inserts zero rows.
- **Boundary — duplicate pair:** a second override for the same `(link_level, physical_ref_id, digital_ref_id)` triple is rejected with HTTP 409 (the documented duplicate-pair rule); the first row is left unchanged and no second row is inserted. `docs/schema.sql` defines no UNIQUE constraint on this triple, so the rule is enforced at the application layer.
- **Concurrent — simultaneous identical POSTs:** two operators POST the same `(link_level, physical_ref_id, digital_ref_id)` triple at the same time; the pre-insert existence check and the insert run inside a single serializable transaction, so exactly one request commits the row (HTTP 201) and the other returns HTTP 409.

## Dependencies

### Upstream (must be complete first)

- **[FEATURE-04-01 — Backend Foundation & Environment Access](../FEATURE-04-01-backend-foundation-and-environment-access.md):** the API route scaffolding, the provisioned Vercel environment access (per <https://docs.blitzy.com/administration/environments>), the `getUserId()` threading, and the request-body validation this endpoint reuses.
- **[EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md):** the `counterpart_override`, `card`, and `variation` tables this endpoint reads and writes, the pooled Neon access layer, and the `getUserId()` seam (`STORY-02-03-02`, the seeded operator user).
- **[EPIC-03 — Data Ingestion Pipeline](../../EPIC-03-data-ingestion-pipeline.md):** the matched sales data that reveals which computed counterparts are wrong or missing and therefore need a manual override.

### Downstream (informational — not a build prerequisite of this story)

- **[EPIC-05 — Frontend User Interface](../../EPIC-05-frontend-user-interface.md):** the counterpart-override editor in the review-queue workbench (`STORY-05-03-03`) consumes this endpoint.
- **[EPIC-06 — Testing & CI/CD Quality Gates](../../EPIC-06-testing-and-cicd-quality-gates.md):** `STORY-06-02-02` integration-tests these API routes against a per-CI Neon branch at an API coverage floor of **≥75%**.

### Parent feature

- **[FEATURE-04-03 — Operator Review-Queue API](../FEATURE-04-03-operator-review-queue-api.md)**

## Story Estimation Guidance

- **Effort: Medium** — two handlers (CREATE and EDIT) over a single table, plus reference-id resolution and a conflict path, which exceeds a one-handler insert.
- **Complexity: Medium-High** — each reference id resolves against a different catalog table per `link_level`, the duplicate-pair rule is enforced at the application layer inside a serializable transaction (no DB UNIQUE constraint exists on the triple), and the digital-only case requires a `parallel_type.format_availability` lookup.
- **Uncertainty: Medium** — the request and response contract depends on the FEATURE-04-01 scaffolding, which is unbuilt, so the exact validation-error shape is settled once that foundation lands.
- **Fibonacci Story Points: 5.** The reference-resolution and conflict handling place this above a 3; a single table with a fixed schema holds it below an 8.

## Definition of Done

- [ ] A CREATE (POST) request with a valid `link_level` (`card` or `variation`) and existing reference ids inserts one `counterpart_override` row with `is_manual = TRUE` and returns HTTP 201 with the created row.
- [ ] A `link_level` outside the CHECK set `('card', 'variation')` returns HTTP 400 with an `error` field named `link_level` and inserts zero rows.
- [ ] A request missing `physical_ref_id` or `digital_ref_id` returns HTTP 400 with an `error` field naming the missing field and inserts zero rows.
- [ ] A `physical_ref_id` or `digital_ref_id` that does not resolve against `card`/`variation` per `link_level` returns HTTP 404 or HTTP 422 with a named error field and inserts zero rows.
- [ ] A `variation`-level request for a digital-only parallel (`parallel_type.format_availability = 'digital'`) with no physical counterpart returns HTTP 422 labeled `no physical counterpart` and inserts zero rows.
- [ ] The duplicate-pair rule is implemented as documented: a repeat `(link_level, physical_ref_id, digital_ref_id)` triple returns HTTP 409 inside a serializable transaction, and exactly one row exists after concurrent identical POSTs.
- [ ] An EDIT (PATCH) request on an existing override `id` updates `physical_ref_id`, `digital_ref_id`, and/or `notes`, re-resolves any changed reference id, and returns HTTP 200.
- [ ] The handler reads the pooled `DATABASE_URL` (never the unpooled `DATABASE_URL_UNPOOLED`), threads the operator `userId` from the `getUserId()` seam (v1 = the single seeded operator), gates the action to the operator role, and issues zero LLM calls.
- [ ] Computed counterparts (the same `card_id` across formats, or the same `card_id` plus `parallel_type_id` across formats) remain the default path; this endpoint writes only manual exceptions, every row carrying `is_manual = TRUE`.
- [ ] No prohibited vague quality term appears in any acceptance-criteria statement; every such statement names a measurable pass/fail condition.
- [ ] **Testing:** API integration tests against a per-CI Neon branch pass with a ≥75% coverage target.
