# STORY-03-02-02: Implement LLM-Fallback Parser

*Parent feature: [FEATURE-03-02 — Extraction & Matching](../FEATURE-03-02-extraction-and-matching.md) · Parent epic: [EPIC-03 — Data Ingestion Pipeline](../../EPIC-03-data-ingestion-pipeline.md)*

This is the **second** of the four stories in FEATURE-03-02 (Extraction & Matching), implementing **Stage 2** of the two-stage extractor defined in PRD §7.6.2 (deterministic regex first, LLM fallback second). The LLM fallback runs on **messy titles only** — the remainder that the Stage-1 regex-first parser (`STORY-03-02-01`) resolved with a per-row `extraction.confidence < 0.85`. A `raw_listing` whose Stage-1 `extraction.confidence >= 0.85` is treated as resolved and never reaches the model, so the costly model path stays bounded to the low-confidence tail.

The fallback sends the `raw_listing` `title` to the LLM (and the optional `item_aspects` and `description` enrichment columns when present — both are nullable and not emitted by the current actor, so the model receives the `title` as the primary input until a future actor enrichment supplies aspects/description) under a **strict JSON schema** carrying exactly nine fields — `character`, `set`, `year`, `card_number`, `parallel`, `print_run`, `serial`, `grade`, and `format` — each paired with a **per-field confidence**. Every response is **validated and clamped before any use**: a response that omits one of the nine fields or adds a tenth is rejected, and any per-field confidence outside the closed interval `[0, 1]` is rejected and clamped. A valid response writes one `extraction` row whose `extractor_version` identifies the LLM path, keeping LLM-derived rows auditable separately from the Stage-1 regex rows. Any failure — a timeout, an empty body, non-JSON text, or a schema-invalid object — routes the listing to `review_queue` with `kind='extraction'` and `state='open'`, increments `ingestion_run.error_count`, and lets the batch advance, so a single off-contract response never commits fabricated field values and never halts the run.

**Compliance posture:** the fallback executes inside the **batch ingestion job only — never in a request handler**. Per PRD §7.5, LLM-assisted extraction belongs in the worker/queue, never in a request/response path; the main application reads official data sources only, the Apify actor is the single sanctioned out-of-band scraping exception, and no request handler issues an LLM call. The `LLM_API_KEY` is read from encrypted secrets and is never hardcoded; the write uses the pooled `DATABASE_URL`, never the unpooled `DATABASE_URL_UNPOOLED` that EPIC-02 reserves for DDL and migrations.

## User Story

> **As an** ML/Extraction Engineer, **I want** an LLM fallback that runs on messy titles only, **so that** listings the regex parser cannot resolve are extracted with a strict, validated JSON contract.

## Acceptance Criteria

1. **(Edge-case / cost guard — not invoked)** **Given** a `raw_listing` whose Stage-1 `extraction.confidence >= 0.85`, **When** the batch extractor processes it, **Then** the LLM fallback is NOT invoked, zero requests are issued against `LLM_API_KEY`, and no second `extraction` row is written for that `raw_listing_id`.

2. **(Valid-output / schema-conformant)** **Given** a `raw_listing` whose Stage-1 `extraction.confidence < 0.85`, **When** the LLM fallback runs inside the batch ingestion job, **Then** the request body carries the `raw_listing` `title` (plus the optional `item_aspects` and `description` enrichment when present; both are nullable and not emitted by the current actor), the response is a JSON object whose keys are exactly `character`, `set`, `year`, `card_number`, `parallel`, `print_run`, `serial`, `grade`, and `format` — each paired with a per-field confidence in the closed interval `[0, 1]` — and one `extraction` row is written whose `extractor_version` identifies the LLM path (distinct from the Stage-1 regex tag).

3. **(Input-validation / strict schema)** **Given** an LLM response that omits one of the nine required fields or adds a key outside the nine, **When** the response is validated against the strict JSON schema, **Then** the response is rejected, zero `extraction` rows are written from it, and one `review_queue` row is written with `kind='extraction'` and `state='open'`.

4. **(Input-validation / clamp range)** **Given** an LLM response carrying a per-field confidence of `1.4` or `-0.2`, **When** validation runs, **Then** the value is rejected as out of range and every per-field confidence is constrained to the closed interval `[0, 1]` before any write to `extraction`.

5. **(Error-handling / timeout or empty)** **Given** the LLM call exceeds its timeout or returns an empty body, **When** the batch job handles the listing, **Then** one `review_queue` row is written with `kind='extraction'` and `state='open'`, `ingestion_run.error_count` is incremented by 1, and the batch advances to the next listing without raising an unhandled exception.

6. **(Error-handling / malformed JSON)** **Given** the LLM returns non-JSON or text that fails to parse, **When** parsing fails, **Then** the listing is routed to `review_queue` with `kind='extraction'`, and zero `extraction` rows carrying fabricated field values are committed for that `raw_listing_id`.

7. **(Batch-only constraint)** **Given** any HTTP request handler or API-route module, **When** the import graph is inspected, **Then** zero LLM client calls originate from a request handler — the fallback executes inside the batch ingestion job only, and the build fails when an LLM client is imported into a request-handler or API-route module.

## Sub-tasks

- Gate the LLM fallback on Stage-1 `extraction.confidence < 0.85`, skipping the model call when Stage-1 is at or above `0.85` (cost guard). `@ml-eng`
- Build the request payload from the `raw_listing` `title`, including the optional `item_aspects` and `description` enrichment columns when present (both nullable; not emitted by the current actor). `@ml-eng`
- Define the strict JSON schema covering `character`, `set`, `year`, `card_number`, `parallel`, `print_run`, `serial`, `grade`, and `format`, each with a per-field confidence. `@ml-eng`
- Validate every response against the schema; reject unknown or missing fields; reject or clamp any per-field confidence outside the closed interval `[0, 1]` before use. `@ml-eng`
- On a valid response, write the `extraction` row with an LLM-path `extractor_version`; on any failure, route the listing to `review_queue` (`kind='extraction'`, `state='open'`) and increment `ingestion_run.error_count`. `@ml-eng`
- Read `LLM_API_KEY` from encrypted secrets and confine the call to the batch ingestion job. `@ml-eng`
- Add a build-time guard that fails the build when an LLM client is imported into any request-handler or API-route module. `@platform-eng`

## Edge Cases

- **Empty/Null:** an empty model response or a null body routes the listing to `review_queue` (`kind='extraction'`, `state='open'`) and increments `ingestion_run.error_count`; zero `extraction` rows are written.
- **Invalid:** malformed or non-schema JSON is rejected and routed to `review_queue` (`kind='extraction'`); zero `extraction` rows carrying fabricated field values are committed.
- **Boundary:** a per-field confidence of exactly `0` or exactly `1` is accepted; a value of `1.0001` or `-0.0001` is rejected and clamped to the closed interval `[0, 1]`.
- **Concurrent/cost:** a title already resolved by Stage-1 (`extraction.confidence >= 0.85`) does not invoke the LLM — zero duplicate `extraction` rows and zero `LLM_API_KEY` spend for that listing.

## Dependencies

### Upstream (must be complete first)

- **`STORY-03-02-01` — Implement Regex-First Parser:** Stage 1 runs first and writes the per-row `extraction.confidence`; this fallback runs only on the sub-threshold remainder (`confidence < 0.85`). With no Stage-1 output there is no signal to gate on.
- **[EPIC-01 — Environment & Configuration Foundation](../../EPIC-01-environment-and-configuration-foundation.md) (`FEATURE-01-03`):** establishes the `LLM_API_KEY` encrypted secret this story reads from the batch job; the key is never hardcoded and is never read from a request handler.
- **[EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md) (`FEATURE-02-01` / `STORY-02-01-*`):** the Neon branching topology is a hard prerequisite for every data write, and the schema feature creates the `extraction` write target (including `extractor_version` and the per-row `confidence`) and the `review_queue` table (`kind`, `state`, `payload`); the write uses the pooled `DATABASE_URL`, never the unpooled `DATABASE_URL_UNPOOLED` reserved for DDL and migrations.

### Downstream (informational — not a build prerequisite of this story)

- **[STORY-03-02-03 — Implement Confidence-Gated Matcher](STORY-03-02-03-implement-confidence-gated-matcher.md):** consumes the `extraction` rows this story writes, including the LLM-path rows, mapping each to a seeded `variation` or routing it to `review_queue`.
- **[EPIC-06 — `STORY-06-02-01` (unit tests for parsers/validators/score)](../../EPIC-06/FEATURE-06-02/STORY-06-02-01-author-unit-tests-parsers-validators-score.md):** unit-tests the JSON validators and the clamp logic against malformed and out-of-range fixtures, targeting a **≥90%** coverage floor.

### Parent feature

- **[FEATURE-03-02 — Extraction & Matching](../FEATURE-03-02-extraction-and-matching.md)**

## Story Estimation Guidance

- **Effort: Medium** — the fallback layers the gated LLM call, the strict-schema validator, the per-field clamp, the review-queue routing, and the request-handler isolation onto the Stage-1 extraction path.
- **Complexity: Medium–High** — strict-schema validation across the nine fields, per-field confidence clamping to `[0, 1]`, and the build-time request-handler isolation guard each add a distinct decision branch.
- **Uncertainty: Medium–High** — LLM output varies in shape and content, so the validator and clamp must reject every off-contract response without committing fabricated fields.
- **Fibonacci Story Points: 5.** The single gated call plus the validator, clamp, and dual routing lift it to a 5; the fixed nine-field schema and the single `0.85` gate threshold hold it below an 8. Points measure relative size, not a duration.

## Definition of Done

- [ ] The fallback runs only when Stage-1 `extraction.confidence < 0.85`; a listing at or above `0.85` triggers zero LLM calls (cost guard verified — no call for high-confidence listings).
- [ ] Requests carry the `raw_listing` `title` (plus the optional `item_aspects`/`description` enrichment when present; both nullable and not emitted by the current actor); the response must satisfy the strict JSON schema (`character`, `set`, `year`, `card_number`, `parallel`, `print_run`, `serial`, `grade`, `format`) with a per-field confidence.
- [ ] The returned JSON is validated and clamped before use; out-of-range per-field confidences and unknown or missing fields are rejected, and every accepted confidence lies in the closed interval `[0, 1]`.
- [ ] Failures (timeout, empty body, malformed JSON, schema-invalid response) route the listing to `review_queue` (`kind='extraction'`, `state='open'`) and increment `ingestion_run.error_count` without crashing the batch.
- [ ] No LLM call originates from any request handler or API route — the fallback executes in the batch ingestion job only; `LLM_API_KEY` is read from encrypted secrets; the main application reads official data sources only, with the Apify actor as the single sanctioned out-of-band scraping exception.
- [ ] A valid response writes one `extraction` row whose `extractor_version` identifies the LLM path, distinct from the Stage-1 regex tag.
- [ ] No prohibited vague quality term appears in any acceptance criterion, and every criterion names a measurable pass/fail condition (for example, `confidence < 0.85`, per-field confidence in `[0, 1]`, `kind='extraction'`, `state='open'`).
- [ ] **Testing:** validator and clamp unit tests against malformed and out-of-range JSON fixtures pass and meet a **≥90%** coverage target (EPIC-06 `STORY-06-02-01`); a fixture proves a Stage-1 high-confidence listing (`extraction.confidence >= 0.85`) does not invoke the LLM.
