# FEATURE-03-02: Extraction & Matching

*Parent epic: [EPIC-03 — Data Ingestion Pipeline](../EPIC-03-data-ingestion-pipeline.md)*

## Feature Summary

FEATURE-03-02 builds the two-stage extractor and confidence-gated matcher that turn the `raw_listing` rows captured by [FEATURE-03-01 — Apify Actor Integration](FEATURE-03-01-apify-actor-integration.md) into structured `extraction` rows and matched `sale_observation` rows. A deterministic regex/rules parser runs first (cheap, high-precision); an LLM-fallback parser runs second on messy titles only; a confidence-gated matcher then auto-commits high-confidence sales onto the seeded catalog and routes low-confidence matches and brand-new clusters to the operator review queue, while a self-healing periodic re-clustering pass keeps the listing-derived digital catalog from fragmenting. The business value is a single-card price series that stays clean: lots, bundles, and raw-vs-graded mismatches are flagged out of comps, and every uncertain item is escalated for human review instead of being committed onto the catalog. Scope is limited to the parsing, matching, and re-clustering logic that writes `extraction`, `sale_observation`, and `review_queue` rows — it does not fetch or persist raw listings (FEATURE-03-01), does not schedule the batch job ([FEATURE-03-03 — Scheduled Ingestion Orchestration](FEATURE-03-03-scheduled-ingestion-orchestration.md)), and does not build the operator workbench UI that resolves the queue (EPIC-05). This feature is delivered through **4 stories**.

## Environment Access & Configuration

This feature performs no environment provisioning of its own. The platform access it relies on — Blitzy encrypted secrets and the Apify Platform `APIFY_TOKEN` — is realized by EPIC-03's mandatory per-epic environment-access feature, [FEATURE-03-01 — Apify Actor Integration](FEATURE-03-01-apify-actor-integration.md), and is documented per the canonical Blitzy environments reference: <https://docs.blitzy.com/administration/environments>. The full step-by-step environment configuration is not duplicated here — see FEATURE-03-01.

Two access facts are specific to this feature:

- The **LLM-fallback parser** (`STORY-03-02-02`) reads an **`LLM_API_KEY`** encrypted secret and runs in the **batch ingestion job only — never in a request handler**. Consistent with the platform compliance posture, the main application calls official data sources only, the Apify actor is the single sanctioned out-of-band scraping exception, and no request handler issues an LLM call.
- Every write story targets **EPIC-02's Neon access layer and schema** — the `extraction`, `sale_observation`, and `review_queue` tables — over the pooled `DATABASE_URL`, and the data write depends on EPIC-02's Neon branching (`STORY-02-01-*`). The unpooled `DATABASE_URL_UNPOOLED` is reserved for DDL and migrations and is not used by this feature.

## User Stories Index

This feature is delivered through four stories. Each link is relative to this file and resolves inside the `FEATURE-03-02/` subfolder.

1. **[STORY-03-02-01 — Implement Regex-First Parser](FEATURE-03-02/STORY-03-02-01-implement-regex-first-parser.md)** — the deterministic, high-precision regex/rules parser: it pulls serial (`15/50` → `ex_serial_number=15`, `ex_serial_run=50`), print run (`/25`, `1/1`), year, grade (PSA/CGC/BGS + value), and format (the title keywords `SWCT`/`Card Trader`/`digital`, or the optional `Features: Digital` item aspect when that enrichment is present), tokenizes candidate parallel/character from the title, and assigns high confidence from a clean title parse (or when the optional structured aspect is present).
2. **[STORY-03-02-02 — Implement LLM-Fallback Parser](FEATURE-03-02/STORY-03-02-02-implement-llm-fallback-parser.md)** — the LLM fallback for messy titles only: it sends the listing `title` (plus the optional `item_aspects`/`description` enrichment when present — both nullable and not emitted by the current actor) under a strict JSON schema (`character`, `set`, `year`, `card_number`, `parallel`, `print_run`, `serial`, `grade`, `format`) with a per-field confidence, validates and clamps the JSON before use, and issues no call from any request handler (batch ingestion job only, reading `LLM_API_KEY`).
3. **[STORY-03-02-03 — Implement Confidence-Gated Matcher](FEATURE-03-02/STORY-03-02-03-implement-confidence-gated-matcher.md)** — maps each `extraction` to a seeded `variation` (physical) or a digital cluster: high-confidence matches auto-commit as `sale_observation` rows with `match_status = auto`, while low-confidence matches (`review_queue.kind = match`) and brand-new clusters (`review_queue.kind = new_cluster`) are routed to `review_queue` with `state = open`; lots/bundles and raw-vs-graded mismatches set `excluded_from_comps = TRUE`.
4. **[STORY-03-02-04 — Implement Self-Healing Re-Clustering](FEATURE-03-02/STORY-03-02-04-implement-self-healing-reclustering.md)** — the periodic re-clustering pass that flags duplicate listing-derived digital variations as `review_queue.kind = merge_candidate` items, concentrated on the digital side where the SWCT catalog is auto-derived because no published checklist exists.

## Dependencies

### Upstream (must be complete first)

- **EPIC-01 — Environment & Configuration Foundation:** supplies the single Blitzy environment and the secrets baseline, including the `LLM_API_KEY` encrypted secret the LLM-fallback parser reads.
- **EPIC-02 — Database Platform & Schema:** supplies the Neon access layer and the `extraction`, `sale_observation`, `review_queue`, `variation`, and `parallel_type` tables this feature writes to and matches against; every data write depends on EPIC-02's Neon branching (`STORY-02-01-*`), and the writes use the pooled `DATABASE_URL`.
- **[FEATURE-03-01 — Apify Actor Integration](FEATURE-03-01-apify-actor-integration.md):** produces the `raw_listing` rows this feature parses — the persisted listing `title` is the parser's reliable input (the identity-bearing field the current actor emits), while `item_aspects` and `description` are optional, nullable enrichment columns the current actor does **not** emit and that stay null until a future actor enrichment populates them; the parser relies on the emitted `title` and treats structured aspects/description as absent until that enrichment lands. Without persisted raw listings there is nothing to extract.

### Downstream (informational — not a build prerequisite of this feature)

- **[FEATURE-03-03 — Scheduled Ingestion Orchestration](FEATURE-03-03-scheduled-ingestion-orchestration.md):** runs this extraction-and-matching logic inside the scheduled batch ingestion job, where the LLM-fallback calls are batched.
- **EPIC-04 — Backend Application & API:** reads the `sale_observation` and `valuation` data this feature produces; its operator review-queue API (FEATURE-04-03) resolves the `review_queue` items this feature creates.
- **EPIC-06 — Testing & CI/CD Quality Gates:** `STORY-06-02-01` unit-tests the parsers, validators, and score against title/item-aspect fixtures, targeting a **≥90%** coverage floor.

## Definition of Done

- [ ] All 4 stories (STORY-03-02-01, STORY-03-02-02, STORY-03-02-03, STORY-03-02-04) are complete.
- [ ] The extractor runs in two stages, deterministic first: the regex/rules parser extracts serial, print run, year, grade, and format from listing titles (and from the optional `item_aspects` enrichment when present), and assigns high confidence from a clean title parse or when the optional structured aspect is present.
- [ ] A title `15/50` with a parallel or print-run token in context parses to `ex_serial_number=15` and `ex_serial_run=50`; with no parallel/print-run context it parses to a card number, lowers confidence, and writes a `review_queue` row with `state = open`.
- [ ] The format classifier uses the optional eBay item aspect `Features: Digital` when that enrichment is present and otherwise classifies from the title keywords `SWCT`/`Card Trader`/`digital`, flagging the keyword-only path as lower-confidence; the current actor emits no item aspects, so the title-keyword path is the active classifier until a future actor enrichment supplies aspects.
- [ ] The LLM-fallback parser runs on messy titles only, under a strict JSON schema (`character`, `set`, `year`, `card_number`, `parallel`, `print_run`, `serial`, `grade`, `format`) with per-field confidence, validates and clamps the JSON before use, and issues no call from any request handler.
- [ ] Extraction output is written to the `extraction` table; the matcher then maps each row to a seeded `variation` (physical) or a digital cluster.
- [ ] The confidence-gated matcher auto-commits high-confidence sales as `sale_observation` rows with `match_status = auto`, and routes low-confidence matches (`review_queue.kind = match`) and brand-new clusters (`review_queue.kind = new_cluster`) to `review_queue` with `state = open`.
- [ ] Lots/bundles (`set of N`, `lot of N`, multi-card listings) and raw-vs-graded mismatches set `excluded_from_comps = TRUE` so they never enter a single-card price series.
- [ ] Self-healing re-clustering flags duplicate listing-derived digital variations as `review_queue.kind = merge_candidate` items.
- [ ] A price series carries its sample size n: n=0 yields an asking-price estimate labeled as such, n>=1 carries a low-confidence label, and n>=5 is labeled confident; a series never mixes grades or formats.
- [ ] Extraction, matching, and every LLM call run in the batch ingestion job; the main application calls official data sources only, with the Apify actor as the single sanctioned out-of-band scraping exception, and no request handler issues an LLM call.
- [ ] No prohibited vague quality term appears in any acceptance-criteria-like statement; every such statement names a measurable pass/fail condition.
- [ ] **Testing:** parser and matcher unit tests run against title fixtures (and optional item-aspect enrichment fixtures) and pass, meeting the **≥90%** coverage target tracked in EPIC-06 (`STORY-06-02-01`).
