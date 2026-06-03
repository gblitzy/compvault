# STORY-03-02-01: Implement Regex-First Parser

*Parent feature: [FEATURE-03-02 — Extraction & Matching](../FEATURE-03-02-extraction-and-matching.md) · Parent epic: [EPIC-03 — Data Ingestion Pipeline](../../EPIC-03-data-ingestion-pipeline.md)*

This is the **first** of the four stories in FEATURE-03-02 (Extraction & Matching), implementing **Stage 1** of the two-stage extractor defined in PRD §7.6.2 (deterministic regex/rules first, LLM fallback second). The Stage-1 parser is the cheap, high-precision path: it reads one persisted `raw_listing` row — primarily its `title` (the identity-bearing field the current actor emits) and, **when present**, the optional `item_aspects` JSONB and `description` enrichment columns (which the current actor does **not** emit and which stay null until a future actor enrichment populates them; when present, `item_aspects` carries structured eBay aspects such as `Features: Digital`, Set, and Character) — and extracts card identity into a single `extraction` row. It pulls serial (`15/50` → `ex_serial_number=15`, `ex_serial_run=50`), print run (`/25`, `1/1` → `ex_print_run`), year (→ `ex_year`), grade (PSA/CGC/BGS/SGC + value → `ex_grade`), and format (→ `ex_format`) from the title, and tokenizes candidate parallel and character text. It assigns `confidence >= 0.85` for a clean title parse (an unambiguous serial-with-parallel token, or a parallel/print-run token with a grade and year) or when the optional structured aspect is present, so the majority of listings resolve here and never reach the LLM fallback (`STORY-03-02-02`), which runs only on the sub-threshold remainder (`confidence < 0.85`).

The write target is the `extraction` table created by EPIC-02 (columns `extractor_version`, `ex_character`, `ex_set`, `ex_year`, `ex_card_number`, `ex_parallel`, `ex_print_run`, `ex_serial_number`, `ex_serial_run`, `ex_grade`, `ex_format` of enum `format_t` = `physical`|`digital`, `is_lot`, `quality_flags`, `confidence`). The table keeps history: each parse writes a new row tagged with its `extractor_version`, so the parser can be re-run or versioned without overwriting prior rows. **Compliance posture:** Stage 1 is purely deterministic and issues **no LLM call**; it runs **inside the batch ingestion job only — never in a request handler**. The main application reads official data sources only, and the Apify actor is the single sanctioned out-of-band scraping exception. The write uses the pooled `DATABASE_URL`, never the unpooled `DATABASE_URL_UNPOOLED` that EPIC-02 reserves for DDL and migrations.

## User Story

> **As a** Data/Ingestion Engineer, **I want** a deterministic regex/rules parser that extracts card identity from listing titles (with eBay item aspects as optional enrichment when present), **so that** the cheap, high-precision path resolves the majority of listings without invoking the LLM.

## Acceptance Criteria

1. **(Valid-output / serial + grade + year)** **Given** a title `"Luke Skywalker 2023 Topps Chrome Refractor 15/50 PSA 10"`, **When** the regex-first parser runs, **Then** `ex_serial_number=15`, `ex_serial_run=50`, `ex_year=2023`, `ex_grade="PSA 10"`, and `confidence >= 0.85`, and exactly one `extraction` row is written with a non-null `extractor_version`.

2. **(Valid-output / digital via optional aspect)** **Given** a `raw_listing` whose **optional** `item_aspects` enrichment is present and contains `{"Features": "Digital"}` (a column the current actor does not emit; nullable until a future enrichment supplies it), **When** the parser runs, **Then** `ex_format='digital'` and `confidence >= 0.85` because the structured aspect is present.

3. **(Edge-case / digital via keyword)** **Given** a title containing `"SWCT"` (or `"Card Trader"` or `"digital"`) and NO `Features: Digital` aspect in `item_aspects`, **When** the parser runs, **Then** `ex_format='digital'` and `confidence < 0.85` (the keyword-only path is flagged lower-confidence).

4. **(Valid-output / print run + one-of-one)** **Given** a title containing a parallel token and `/25` (or `1/1`), **When** the parser runs, **Then** `ex_print_run=25` (or `ex_print_run=1` for the one-of-one) and `confidence >= 0.85`.

5. **(Edge-case / ambiguity → low confidence)** **Given** a title `"Grogu 15/50"` with NO parallel or print-run token in context, **When** the parser runs, **Then** `15/50` is treated as a card number, `ex_serial_number` and `ex_serial_run` are NULL, and `confidence < 0.85` so [`STORY-03-02-03`](STORY-03-02-03-implement-confidence-gated-matcher.md) routes the extraction to `review_queue`.

6. **(Input-validation / empty)** **Given** a null or empty `title` and an absent or empty `item_aspects` (the current-actor default, since the actor emits no aspects), **When** the parser runs, **Then** no identity tokens are extracted, `confidence` is set to a value below `0.85`, and one `extraction` row is still written (the parser does not throw).

7. **(Error-handling / unparseable)** **Given** a title with malformed tokens (for example `"###/@@ ???"`), **When** the parser runs, **Then** no numeric serial or print-run value is parsed, `confidence < 0.85`, and the row is written without raising an exception.

## Sub-tasks

- Implement the serial/print-run regex group (`15/50` → `ex_serial_number`/`ex_serial_run`; `/25` and `1/1` → `ex_print_run`). `@data-eng`
- Implement the year regex (4-digit year token → `ex_year` SMALLINT). `@data-eng`
- Implement the grade regex (`PSA`|`CGC`|`BGS`|`SGC` + numeric value → `ex_grade`, for example `"PSA 10"`). `@data-eng`
- Implement format detection: detect the title keywords `SWCT`/`Card Trader`/`digital` (→ `ex_format`, flagged lower-confidence) and use the optional `Features: Digital` item aspect (→ `ex_format` at high confidence) when that enrichment is present; the current actor emits no aspects, so the title-keyword path is the active classifier. `@data-eng`
- Implement lot/bundle detection (`"set of N"`/`"lot of N"`/multi-card) → `is_lot=TRUE`. `@data-eng`
- Implement the `15/50` ambiguity rule (serial when a parallel or print-run token is in context, else card number). `@data-eng`
- Normalize mixed-case and extra-whitespace titles before tokenizing. `@data-eng`
- Assign `confidence` (`>= 0.85` when structured aspects are present; below `0.85` for keyword-only or ambiguous parses) and write the `extraction` row (`extractor_version`, `ex_*`, `is_lot`, `quality_flags`, `confidence`). `@data-eng`

## Edge Cases

- **Empty/Null:** a null or empty `title` together with an absent or empty `item_aspects` (the current-actor default) → `confidence < 0.85`, one `extraction` row is still written, and the parser does not crash.
- **Boundary:** a `1/1` one-of-one → `ex_print_run=1`.
- **Invalid/Ambiguous:** `15/50` with a parallel/print-run token in context parses to `ex_serial_number=15` and `ex_serial_run=50`; the same `15/50` with no such context parses to a card number with `ex_serial_number`/`ex_serial_run` NULL and `confidence < 0.85`.
- **Concurrent/versioning:** re-running the parser on the same `raw_listing_id` writes a NEW `extraction` row with a bumped `extractor_version` (history preserved) rather than overwriting the prior row.

## Dependencies

### Upstream (must be complete first)

- **[EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md) (schema feature + `STORY-02-01-*`):** the schema feature creates the `extraction` write target (`extractor_version`, the `ex_*` columns, `ex_format` of enum `format_t`, `is_lot`, `quality_flags`, and the per-row `confidence`), and the Neon branching topology (`STORY-02-01-*`) is a hard prerequisite for every data write; the write uses the pooled `DATABASE_URL`, never the unpooled `DATABASE_URL_UNPOOLED` reserved for DDL and migrations.
- **[STORY-03-01-02 — Invoke Actor & Persist Raw Listings](../FEATURE-03-01/STORY-03-01-02-invoke-actor-and-persist-raw-listings.md):** persists the `raw_listing` rows this parser consumes; the parser's reliable input is the emitted `title`, while `item_aspects` and `description` are optional, nullable enrichment columns the current actor does not populate (absent until a future actor enrichment). With no persisted raw listings there is nothing to extract.
- **[STORY-03-01-03 — Implement Idempotent Raw-Listing Upsert](../FEATURE-03-01/STORY-03-01-03-implement-idempotent-raw-listing-upsert.md):** de-duplicates those rows on `UNIQUE (source, source_item_id)`, so the parser reads one stable `raw_listing` per source item.

### Downstream (informational — not a build prerequisite of this story)

- **[STORY-03-02-02 — Implement LLM-Fallback Parser](STORY-03-02-02-implement-llm-fallback-parser.md):** runs only when this Stage-1 `confidence < 0.85`; a `raw_listing` resolved at `confidence >= 0.85` never reaches the model.
- **[STORY-03-02-03 — Implement Confidence-Gated Matcher](STORY-03-02-03-implement-confidence-gated-matcher.md):** consumes the `extraction` rows this parser writes, mapping each to a seeded `variation` or routing low-confidence rows to `review_queue`.
- **[EPIC-06 — `STORY-06-02-01` (unit tests for parsers/validators/score)](../../EPIC-06/FEATURE-06-02/STORY-06-02-01-author-unit-tests-parsers-validators-score.md):** unit-tests this parser against title and item-aspect fixtures, targeting a **≥90%** coverage floor.

### Parent feature

- **[FEATURE-03-02 — Extraction & Matching](../FEATURE-03-02-extraction-and-matching.md)**

## Story Estimation Guidance

- **Effort: Medium** — the parser layers the serial/print-run group, the year and grade regexes, the format-precedence rule, lot/bundle detection, the `15/50` ambiguity rule, title normalization, and the confidence assignment onto a single `extraction` write.
- **Complexity: Medium** — regex design, the format-precedence rule (structured aspect before keyword), and the `15/50` ambiguity rule each add a distinct decision branch, but Stage 1 is deterministic with no model call.
- **Uncertainty: Medium** — free-text title variability drives the residual unknown; the schema target and the `0.85` threshold are fixed by `docs/schema.sql` and the PRD.
- **Fibonacci Story Points: 5.** The serial/print-run/year/grade/format groups plus the ambiguity and format-precedence rules lift it to a 5; the fixed `extraction` schema, the single `0.85` threshold, and the absence of any model call hold it below an 8. Points measure relative size, not a duration.

## Definition of Done

- [ ] Regex extracts serial (`15/50` → `ex_serial_number`/`ex_serial_run`), print run (`/25`, `1/1` → `ex_print_run`), `ex_year`, `ex_grade` (PSA/CGC/BGS + value), and `ex_format`.
- [ ] Format detection uses the optional `item_aspects` `Features: Digital` aspect when that enrichment is present and otherwise classifies from the title keyword path (`SWCT`/`Card Trader`/`digital`) flagged with `confidence < 0.85`; the current actor emits no aspects, so the keyword path is the active classifier.
- [ ] `confidence >= 0.85` is assigned for a clean title parse (an unambiguous serial-with-parallel token, or a parallel/print-run token with grade and year) or when the optional structured aspect is present; below `0.85` for keyword-only or ambiguous parses.
- [ ] `is_lot=TRUE` for `"set of N"`/`"lot of N"`/multi-card titles.
- [ ] The `15/50` ambiguity rule is implemented (serial with a parallel/print-run token in context; else card number with `confidence < 0.85`).
- [ ] Each parse writes one `extraction` row (`extractor_version`, `ex_*`, `is_lot`, `quality_flags`, `confidence`) and makes no LLM call; it runs in the batch ingestion job only, with the Apify actor as the single sanctioned out-of-band scraping exception.
- [ ] Re-running the parser on the same `raw_listing_id` writes a NEW `extraction` row with a bumped `extractor_version`, preserving prior rows.
- [ ] No prohibited vague quality term appears in any acceptance criterion, and every criterion names a measurable pass/fail condition (for example `ex_serial_number=15 and ex_serial_run=50`, `confidence >= 0.85`).
- [ ] **Testing:** parser unit tests against title fixtures (and optional item-aspect enrichment fixtures) pass and meet a **≥90%** coverage target (exercised by EPIC-06 `STORY-06-02-01`), covering the `15/50` ambiguity, the `1/1` boundary, the empty/null title case, and a lot/bundle case.
