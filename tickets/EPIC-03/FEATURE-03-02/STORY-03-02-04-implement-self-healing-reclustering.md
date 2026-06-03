# STORY-03-02-04: Implement Self-Healing Re-Clustering

*Parent feature: [FEATURE-03-02 — Extraction & Matching](../FEATURE-03-02-extraction-and-matching.md) · Parent epic: [EPIC-03 — Data Ingestion Pipeline](../../EPIC-03-data-ingestion-pipeline.md)*

This is the **fourth** of the four stories in FEATURE-03-02 (Extraction & Matching), implementing **step 5 — Self-healing** of the PRD §6 matching pipeline. It adds a **periodic re-clustering pass**, run inside the batch ingestion job, that detects **duplicate listing-derived digital variations** and surfaces them as **`merge_candidate`** items in `review_queue` for operator confirmation. The pass targets the rows where `source='listing_derived'` AND `format='digital'`, because that is where the fragmentation risk concentrates: the SWCT digital catalog is **auto-derived by clustering eBay listings** (no published checklist exists), whereas the physical catalog is seeded from authoritative odds sheets and checklist DBs and therefore carries a clean skeleton.

Fragmentation arises because the auto-derived digital catalog can mint **distinct `card`/`variation` rows for the same real-world collectible** — so two listing-derived digital variations can represent the same logical card and parallel even though the `UNIQUE (card_id, parallel_type_id, format)` constraint forbids identical key tuples. The re-clustering pass groups such rows and records each duplicate group as one `merge_candidate`. **Safety rule (binding):** the pass **never auto-deletes and never auto-merges** a catalog row; it writes a `merge_candidate` `review_queue` row only, and the operator confirms or dismisses the merge through the EPIC-04 review-queue API / EPIC-05 workbench. The pass runs in the batch ingestion job exclusively — never in a request handler — and the word "periodic" describes its recurring behavior only: the recurrence cadence and schedule are owned by [FEATURE-03-03 — Scheduled Ingestion Orchestration](../FEATURE-03-03-scheduled-ingestion-orchestration.md) and are not specified here.

## User Story

> **As a** Data/Ingestion Engineer, **I want** periodic re-clustering of listing-derived digital variations, **so that** duplicate auto-derived digital entries are detected and merged instead of fragmenting the catalog.

## Acceptance Criteria

1. **(Valid-output / merge candidate)** **Given** two `variation` rows with `source='listing_derived'` and `format='digital'` that the re-clustering heuristic resolves to the same logical `(card_id, parallel_type_id)` identity (matching `character`, set, and parallel signals) with an equal `print_run` (or both `NULL`), **When** the re-clustering pass runs, **Then** exactly one `review_queue` row is written with `ref_table='variation'`, `kind='merge_candidate'`, `state='open'`, and a `payload` JSONB array carrying the candidate `variation` IDs.

2. **(Valid-output / no duplicates → no-op)** **Given** a listing-derived digital catalog in which no two variations resolve to the same logical card and parallel, **When** the pass runs, **Then** zero `review_queue` rows are written and zero `variation` rows change.

3. **(Edge-case / print_run distinction)** **Given** two listing-derived digital variations that match on logical card and parallel but differ in `print_run` (for example `print_run=25` versus `print_run=50`), **When** the pass runs, **Then** they are NOT flagged as a merge candidate and zero `review_queue` rows are written for that pair, because a different `print_run` denotes a distinct variation.

4. **(Concurrent / idempotency guard)** **Given** a candidate pair already recorded in `review_queue` as `kind='merge_candidate'` with `state='open'`, **When** the pass runs again over the same pair, **Then** no second `merge_candidate` row is written for that pair and the `review_queue` row count for the pair stays at one.

5. **(Safety / no auto-delete)** **Given** a detected duplicate pair, **When** the pass runs, **Then** zero `variation` rows are deleted and zero `variation` rows are merged in the catalog — the pass writes one `merge_candidate` `review_queue` row for operator confirmation and makes no other catalog mutation.

6. **(Scope / digital-only)** **Given** seeded physical variations whose `source` is `topps_odds` or `checklist_db` (or any variation whose `format` is `physical`), **When** the pass runs, **Then** those rows are excluded from re-clustering and produce zero `merge_candidate` rows, because the pass selects only rows where `source='listing_derived'` AND `format='digital'`.

7. **(Input-validation / empty catalog)** **Given** zero listing-derived digital variations exist (an empty digital catalog), **When** the pass runs, **Then** it completes as a no-op, writes zero `review_queue` rows, mutates zero `variation` rows, and raises no error.

## Sub-tasks

- Select candidate variations where `source='listing_derived'` and `format='digital'` for comparison, and exclude every other `source` value and the `physical` format. `@data-eng`
- Implement the duplicate-similarity grouping over the selected variations that treats `print_run` as a distinguishing field, so a different print run yields a distinct group. `@data-eng`
- Write each detected duplicate group to `review_queue` with `ref_table='variation'`, `kind='merge_candidate'`, `state='open'`, and a `payload` JSONB array of the candidate `variation` IDs. `@data-eng`
- Add an idempotency guard that checks for an existing open `merge_candidate` for the same pair before writing, so a pair already queued is not re-queued. `@data-eng`
- Guarantee no catalog row is auto-deleted or auto-merged — zero `variation` rows change — surfacing candidates only. `@data-eng`
- Exclude seeded physical variations (`source` `topps_odds`/`checklist_db`) and any `physical`-format row from the pass. `@data-eng`
- Author re-clustering unit tests over digital-variation fixtures covering the no-duplicates no-op, the `print_run` distinction, and the already-open-candidate idempotency guard, targeting a ≥90% coverage floor. `@qa-engineer`

## Edge Cases

- **Empty/Null:** an empty listing-derived digital catalog (zero candidate rows) → the pass is a no-op, writes zero `review_queue` rows, and raises no error.
- **Boundary — print_run:** two digital variations that match on logical card and parallel but differ in `print_run` (for example `/25` versus `/50`) → NOT merged; zero `merge_candidate` rows for that pair.
- **Invalid / duplicate-guard:** a pair already open in `review_queue` as `kind='merge_candidate'` → no duplicate row is written and the row count for the pair stays at one (idempotent).
- **Concurrent:** two overlapping passes evaluate the same pair → still one `merge_candidate` row per pair, because the idempotency guard de-duplicates on the open candidate.
- **Safety:** a duplicate is detected → the pass never auto-deletes and never auto-merges a `variation`; the operator confirms the merge through the review-queue workbench.

## Dependencies

### Upstream (must be complete first)

- **`STORY-03-02-03` — Implement Confidence-Gated Matcher:** produces the committed listing-derived digital variations and clusters this pass re-clusters; without the matcher's auto-derived digital catalog there are no listing-derived rows to evaluate.
- **[EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md) (`STORY-02-01-*`):** the Neon branching topology — a hard prerequisite for every data write — and the schema feature that creates the `variation` table (with `source`, `format`, `print_run`, and the `UNIQUE (card_id, parallel_type_id, format)` constraint) and the `review_queue` table (`kind`, `state`, `payload` JSONB) this pass reads and writes; the write uses the pooled `DATABASE_URL`, never the unpooled `DATABASE_URL_UNPOOLED` reserved for DDL and migrations.

### Downstream (informational — not a build prerequisite of this story)

- **[EPIC-04 — Operator Review-Queue API (FEATURE-04-03)](../../EPIC-04/FEATURE-04-03-operator-review-queue-api.md):** resolves the `merge_candidate` items this pass creates, letting the operator confirm or dismiss each candidate merge and move the `review_queue` row from `state='open'` to `resolved` or `dismissed`.
- **[EPIC-06 — `STORY-06-02-01` (unit tests for parsers/validators/score)](../../EPIC-06/FEATURE-06-02/STORY-06-02-01-author-unit-tests-parsers-validators-score.md):** unit-tests the re-clustering logic against digital-variation fixtures, targeting a **≥90%** coverage floor.

### Parent feature

- **[FEATURE-03-02 — Extraction & Matching](../FEATURE-03-02-extraction-and-matching.md)**

## Story Estimation Guidance

- **Effort: Medium** — a single batch pass layered onto the committed listing-derived digital catalog, covering candidate selection, similarity grouping, the idempotency guard, and the `merge_candidate` write.
- **Complexity: Medium–High** — the similarity grouping, the idempotency guard against open candidates, and the digital-only scoping (`source='listing_derived'` AND `format='digital'`, with `print_run` distinguishing) raise it above a routine write.
- **Uncertainty: Medium–High** — the clustering heuristics run over auto-derived data with no published checklist, so the grouping thresholds carry residual unknowns.
- **Fibonacci Story Points: 5.** The heuristic grouping and the idempotency guard lift it above a 3, while the fixed schema targets and the surface-only safety rule hold it below an 8. Points measure relative size, not a duration.

## Definition of Done

- [ ] The pass selects only listing-derived digital variations (`source='listing_derived'`, `format='digital'`); seeded physical variations (`source` `topps_odds`/`checklist_db`) and every `physical`-format row are excluded.
- [ ] Duplicate candidates are written to `review_queue` with `kind='merge_candidate'`, `state='open'`, and a `payload` JSONB array of the candidate `variation` IDs.
- [ ] Two variations that match on logical card and parallel but differ in `print_run` are NOT flagged as duplicates (zero `merge_candidate` rows for that pair).
- [ ] No catalog row is auto-deleted or auto-merged — zero `variation` rows change; merge candidates are surfaced for operator confirmation only.
- [ ] The pass is idempotent: a pair already open as `kind='merge_candidate'` is not re-queued (row count stays at one), and an empty digital catalog is a no-op with zero `review_queue` rows.
- [ ] The pass runs inside the batch ingestion job only — no request handler executes it and no request handler issues an LLM call; the main application reads official data sources only, with the Apify actor as the single sanctioned out-of-band scraping exception.
- [ ] No prohibited vague quality term appears in any acceptance criterion, and every criterion names a measurable pass/fail condition (for example, `kind='merge_candidate'`, "exactly one row", "zero `review_queue` rows").
- [ ] **Testing:** re-clustering unit tests against digital-variation fixtures pass and meet a **≥90%** coverage target (EPIC-06 `STORY-06-02-01`), covering the no-duplicates no-op, the `print_run` distinction, and the already-open-candidate idempotency guard.
