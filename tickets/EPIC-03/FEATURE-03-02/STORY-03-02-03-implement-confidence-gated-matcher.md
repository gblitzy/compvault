# STORY-03-02-03: Implement Confidence-Gated Matcher

*Parent feature: [FEATURE-03-02 — Extraction & Matching](../FEATURE-03-02-extraction-and-matching.md) · Parent epic: [EPIC-03 — Data Ingestion Pipeline](../../EPIC-03-data-ingestion-pipeline.md)*

This is the **third** of the four stories in FEATURE-03-02 (Extraction & Matching), implementing **step 3 — Match** and **step 4 — Confidence score** of the PRD §6 matching pipeline (Seed → Extract → **Match** → **Confidence score** → Self-healing). It consumes the `extraction` rows produced by `STORY-03-02-01` (the regex-first parser) and `STORY-03-02-02` (the LLM-fallback parser) and maps each one to a seeded canonical `variation` by the key `(card_id, parallel_type_id, format)`; for a digital listing, and for any unseeded physical listing, it attempts assignment to a candidate digital cluster instead of a seeded `variation`. The matcher then **gates on confidence**: a `match_confidence >= 0.85` match to exactly one seeded `variation` **auto-commits** a `sale_observation` row with `match_status='auto'`, a best `match_confidence < 0.85` routes the listing to `review_queue` with `kind='match'`, and an `extraction` with zero candidate seeded `variation` rows routes to `review_queue` with `kind='new_cluster'`. Every queued row is written with `state='open'` for an operator to resolve.

Data-quality guardrails are enforced at commit time. Lots and bundles (`extraction.is_lot=TRUE` — "set of N", "lot of N", multi-card listings) and raw-vs-graded mismatches (`extraction.quality_flags` carrying `{"raw_vs_graded_mismatch": true}`) are written with `excluded_from_comps=TRUE` and an `exclude_reason`, so they never enter a single-card price series. The write columns `sale_price` (`NUMERIC(12,2)` NOT NULL) and `sale_date` (`DATE` NOT NULL) are mandatory: an `extraction` whose derived `sale_price` or `sale_date` is null is rejected before the write and logged or queued rather than committed with a null. A price series is keyed on `(variation, grade, format)` and never mixes grades or formats — `grade_id` is set for a physical sale and stays NULL for a digital sale — honoring the PRD §6.5/§8.5 sample-size rule: `n=0` yields an asking-price estimate labeled as such, `n>=1` carries a low-confidence label, `n>=5` is labeled confident, and a series never compares across grades or formats.

**Compliance posture:** the matcher runs inside the **batch ingestion job only — never in a request handler**; the main application reads official data sources only, the Apify actor is the single sanctioned out-of-band scraping exception, and no request handler issues an LLM call. The matcher is **idempotent per `raw_listing_id`** — a second pass over the same `raw_listing` updates the existing `sale_observation` in place rather than inserting a duplicate. The write uses the pooled `DATABASE_URL`, never the unpooled `DATABASE_URL_UNPOOLED` that EPIC-02 reserves for DDL and migrations.

## User Story

> **As a** Data/Ingestion Engineer, **I want** a matcher that maps extractions to a seeded `variation` and gates on confidence, **so that** high-confidence sales auto-commit and uncertain ones are queued for human review.

## Acceptance Criteria

1. **(Valid-output / auto-commit)** **Given** an `extraction` whose `match_confidence >= 0.85` maps to exactly one seeded `variation`, **When** the matcher runs, **Then** one `sale_observation` row is written with `variation_id` set, `card_id` denormalized, `format` equal to the extraction `ex_format`, `match_status='auto'`, and both `sale_price` and `sale_date` non-null.

2. **(Valid-output / low-confidence → review)** **Given** an `extraction` whose best candidate `match_confidence < 0.85`, **When** the matcher runs, **Then** one `review_queue` row is written with `kind='match'` and `state='open'`, and zero `sale_observation` rows with `match_status='auto'` are committed for that match.

3. **(Valid-output / new cluster)** **Given** an `extraction` with zero candidate seeded `variation` rows on the key `(card_id, parallel_type_id, format)`, **When** the matcher runs, **Then** one `review_queue` row is written with `kind='new_cluster'` and `state='open'`, and zero `variation` rows are auto-created in the catalog.

4. **(Input-validation / error-handling — NOT NULL)** **Given** an `extraction` whose derived `sale_price` or `sale_date` is null, **When** the matcher attempts to write `sale_observation`, **Then** zero `sale_observation` rows are written (both columns are NOT NULL) and one rejection entry is logged or one `review_queue` row is created — the matcher never writes a `sale_observation` carrying a null `sale_price` or a null `sale_date`.

5. **(Edge-case / lot exclusion)** **Given** an `extraction` with `is_lot=TRUE`, **When** the matcher runs, **Then** the resulting `sale_observation` has `excluded_from_comps=TRUE` and `exclude_reason` set (for example `'lot/bundle'`), so the row never enters a single-card price series.

6. **(Edge-case / raw-vs-graded mismatch)** **Given** an `extraction` whose `quality_flags` contains `{"raw_vs_graded_mismatch": true}`, **When** the matcher runs, **Then** the resulting `sale_observation` has `excluded_from_comps=TRUE` and `exclude_reason='raw_vs_graded_mismatch'`.

7. **(Boundary / inclusive gate)** **Given** an `extraction` whose `match_confidence` equals exactly `0.85` and maps to exactly one seeded `variation`, **When** the matcher runs, **Then** it is treated as high-confidence and auto-commits a `sale_observation` with `match_status='auto'` (the `>= 0.85` gate is inclusive).

8. **(Concurrent / idempotent + series isolation)** **Given** two matcher passes over the same `raw_listing_id`, **When** both passes run, **Then** exactly one `sale_observation` row exists for that `raw_listing` (the second pass updates the row in place rather than inserting a duplicate), and a price series keyed on `(variation, grade, format)` holds zero rows that mix a physical graded sale (`grade_id` set) with a digital sale (`grade_id` NULL).

## Sub-tasks

- Map each `extraction` to a seeded `variation` by `(card_id, parallel_type_id, format)`; for a digital or any unseeded physical listing, attempt candidate digital-cluster assignment instead. `@ingestion-eng`
- Implement the confidence gate: `match_confidence >= 0.85` auto-commits, and a value below `0.85` routes the match to `review_queue` (`kind='match'`, `state='open'`). `@ingestion-eng`
- Route extractions with zero candidate seeded `variation` rows to `review_queue` (`kind='new_cluster'`, `state='open'`), without auto-creating a catalog `variation`. `@ingestion-eng`
- Write the `sale_observation` columns `raw_listing_id`, `variation_id`, `card_id`, `grade_id` (physical only; NULL for digital), `format`, `sale_price`, `sale_date`, `serial_number`, `serial_run`, `match_confidence`, and `match_status='auto'`. `@ingestion-eng`
- Set `excluded_from_comps=TRUE` and an `exclude_reason` for `is_lot=TRUE` listings and for `quality_flags` raw-vs-graded mismatches. `@ingestion-eng`
- Reject a null `sale_price` or null `sale_date` before the write so the NOT NULL columns are never violated, logging or queuing the rejected listing. `@ingestion-eng`
- Make the matcher idempotent per `raw_listing_id` so a re-run updates the existing `sale_observation` in place and leaves exactly one row per `raw_listing`. `@ingestion-eng`
- Enforce series isolation so a price series keyed on `(variation, grade, format)` never groups two grades or two formats into one series. `@ingestion-eng`
- Author matcher unit/integration tests over `extraction` fixtures covering auto-commit, low-confidence routing, new-cluster routing, lot/mismatch exclusion, and per-`raw_listing_id` idempotency, targeting a ≥90% coverage floor. `@qa-engineer`

## Edge Cases

- **Empty/Null:** a null `sale_price` or null `sale_date` → the write is rejected (both columns are NOT NULL) and the listing is logged or queued, never committed with a null.
- **Boundary:** `match_confidence` exactly `0.85` → auto-commit (the `>= 0.85` gate is inclusive).
- **Invalid:** `is_lot=TRUE` or a `quality_flags` raw-vs-graded mismatch → `sale_observation` written with `excluded_from_comps=TRUE` and an `exclude_reason`, held out of every single-card price series.
- **New cluster:** an `extraction` with zero candidate seeded `variation` rows → one `review_queue` row with `kind='new_cluster'` and `state='open'`, and zero catalog `variation` rows auto-created.
- **Concurrent:** two matcher passes over the same `raw_listing_id` → exactly one `sale_observation` row for that `raw_listing` (the matcher is idempotent and updates in place).

## Dependencies

### Upstream (must be complete first)

- **`STORY-03-02-01` — Implement Regex-First Parser** and **`STORY-03-02-02` — Implement LLM-Fallback Parser:** produce the `extraction` rows (with `ex_format`, `ex_serial_number`, `ex_serial_run`, `is_lot`, `quality_flags`, and a per-row `confidence`) that this matcher consumes; with zero `extraction` rows there is nothing to match or gate.
- **[EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md) (`STORY-02-01-*`):** the Neon branching topology — a hard prerequisite for every data write — and the schema feature that creates the `sale_observation` write target (with `match_status`, `excluded_from_comps`/`exclude_reason`, and the NOT NULL `sale_price`/`sale_date` columns), the `review_queue` table (`kind`, `state`, `payload`), the `variation` match target (`UNIQUE (card_id, parallel_type_id, format)`), and the `parallel_type` and `grade` tables this story reads and writes; the write uses the pooled `DATABASE_URL`, never the unpooled `DATABASE_URL_UNPOOLED` reserved for DDL and migrations.

### Downstream (informational — not a build prerequisite of this story)

- **`STORY-03-02-04` — Implement Self-Healing Re-Clustering:** operates on the committed listing-derived digital variations and clusters this matcher produces, flagging duplicate auto-derived digital variations as `kind='merge_candidate'` `review_queue` items.
- **EPIC-04 — Backend Application & API:** reads the `sale_observation` rows this matcher commits; its operator review-queue API (**[FEATURE-04-03 — Operator Review-Queue API](../../EPIC-04/FEATURE-04-03-operator-review-queue-api.md)**) resolves the `kind='match'` and `kind='new_cluster'` `review_queue` items this story creates, moving each from `state='open'` to `resolved` or `dismissed`.
- **[EPIC-06 — `STORY-06-02-01` (unit tests for parsers/validators/score)](../../EPIC-06/FEATURE-06-02/STORY-06-02-01-author-unit-tests-parsers-validators-score.md):** unit-tests the matcher and the confidence score against `extraction` fixtures, targeting a **≥90%** coverage floor.

### Parent feature

- **[FEATURE-03-02 — Extraction & Matching](../FEATURE-03-02-extraction-and-matching.md)**

## Story Estimation Guidance

- **Effort: Medium–High** — the matcher layers candidate lookup, the confidence gate, the two review-queue routing paths, the exclusion rules, the NOT NULL guard, idempotency, and series isolation onto the `extraction` write path.
- **Complexity: High** — match scoring against `(card_id, parallel_type_id, format)`, the inclusive `>= 0.85` gate, the lot and raw-vs-graded exclusion logic, per-`raw_listing_id` idempotency, and the `(variation, grade, format)` series isolation each add a distinct decision branch.
- **Uncertainty: Medium** — the schema targets and the gate threshold are fixed by `docs/schema.sql` and the PRD; the residual unknown is the candidate-scoring heuristic that produces `match_confidence` for unseeded and digital listings.
- **Fibonacci Story Points: 8.** The match scoring, the dual routing paths, the exclusion rules, idempotency, and series isolation lift it to an 8; the fixed schema and the single explicit gate threshold hold it below a 13. Points measure relative size, not a duration.

## Definition of Done

- [ ] High-confidence (`match_confidence >= 0.85`) single-`variation` matches auto-commit a `sale_observation` with `match_status='auto'`, `variation_id` set, and `card_id` denormalized.
- [ ] Low-confidence matches (`match_confidence < 0.85`) write a `review_queue` row with `kind='match'`; extractions with zero candidate `variation` write a `review_queue` row with `kind='new_cluster'`; both carry `state='open'`.
- [ ] Every committed `sale_observation` has non-null `sale_price` and `sale_date`; an `extraction` with a null `sale_price` or `sale_date` is rejected and logged or queued, never written.
- [ ] Lots/bundles (`is_lot=TRUE`) and raw-vs-graded mismatches (`quality_flags` `{"raw_vs_graded_mismatch": true}`) set `excluded_from_comps=TRUE` with an `exclude_reason`.
- [ ] A price series keyed on `(variation, grade, format)` never mixes grades or formats (`grade_id` set for physical, NULL for digital); the matcher is idempotent — exactly one `sale_observation` per `raw_listing_id`.
- [ ] The matcher runs in the batch ingestion job only — no request handler executes it and no request handler issues an LLM call; the main application reads official data sources only, with the Apify actor as the single sanctioned out-of-band scraping exception.
- [ ] No prohibited vague quality term appears in any acceptance criterion, and every criterion names a measurable pass/fail condition (for example, `match_confidence >= 0.85`, `match_status='auto'`, `excluded_from_comps=TRUE`, "exactly one row").
- [ ] **Testing:** matcher unit/integration tests against `extraction` fixtures pass and meet a **≥90%** coverage target (EPIC-06 `STORY-06-02-01`), covering auto-commit, low-confidence routing, new-cluster routing, lot/mismatch exclusion, and per-`raw_listing_id` idempotency.
