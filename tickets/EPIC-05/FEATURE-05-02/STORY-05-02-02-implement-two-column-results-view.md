# STORY-05-02-02: Implement Two-Column Results View

*Parent feature: [FEATURE-05-02 — Search & Results Experience](../FEATURE-05-02-search-and-results-experience.md) · Parent epic: [EPIC-05 — Frontend User Interface](../../EPIC-05-frontend-user-interface.md)*

This is the **second of the three** stories in FEATURE-05-02 (Search & Results Experience). It describes the **digital | physical two-column results view** that a chosen character renders into: the two columns are derived from `variation.format` (`digital` vs `physical`), and each row presents one Card/Variation with its latest sold price, sold date, condition/grade, serial number (when present), a short description snippet, and a sparkline trend, fronted by scannable chip badges for the parallel/print run (`/25`, `1/1`), grade tier, and format. A format toggle (Both / Digital-only / Physical-only) and the variation/grade/set/year/price/date filters apply across both columns at the same time. Thin and empty data are surfaced, not hidden: a zero-sale variation shows an `asking-price estimate` label sourced from `raw_listing.asking_price`, a valuation with fewer than 5 sales (n<5) shows a greyed `based on N sales` label, and a digital-only parallel (for example a Gilded tier, `parallel_type.format_availability = 'digital'`) is labeled `no physical counterpart` in the Physical column. The view **consumes — but does not implement —** the EPIC-04 two-column-results endpoint and queries no database directly; the search input in [STORY-05-02-01](STORY-05-02-01-implement-search-input-with-autocomplete.md) drives which character is shown. It introduces no component library or design system and is described with concrete, measurable states, per PRD §4.2 (FR-4/FR-5/FR-6), §4.1 (FR-2), and §8.5.

## User Story

**As a** Collector (end user), **I want** digital and physical results shown in two columns, **so that** I can compare a character's variations across formats at a glance.

## Environment Access

Environment access and preview deployment for this view are configured once in [FEATURE-05-01 — Frontend Foundation & Environment Access](../FEATURE-05-01-frontend-foundation-and-environment-access.md) per the canonical Blitzy environments reference <https://docs.blitzy.com/administration/environments>; this view additionally requires the EPIC-04 two-column-results endpoint `GET /api/results` ([STORY-04-02-02](../../EPIC-04/FEATURE-04-02/STORY-04-02-02-implement-two-column-results-endpoint.md)) to return the digital and physical row fields it renders — `latest_sale_price`, `latest_sale_date`, `grade`, `serial_number`, `parallel_badge`, `rep_image_url`, `description_snippet`, `asking_price`, `price_label`, `sample_size`, `trend_pct`, `trend_dir`, `confidence_label`, `no_physical_counterpart`, and `last_updated`. The full environment-configuration procedure is not duplicated here.

## Acceptance Criteria

1. **(valid-output — two columns)** Given a character with at least one digital `variation` (`variation.format = 'digital'`) and at least one physical `variation` (`variation.format = 'physical'`), When the results view renders, Then a "Digital" column and a "Physical" column display, and each column lists one row per matching Card/Variation.
2. **(valid-output — row fields, sparkline, and badges)** Given a result row for a variation that has at least one matched `sale_observation`, When the row renders, Then it displays the latest sold price (`sale_observation.sale_price`), the sold date (`sale_observation.sale_date`), the condition/grade (`grade_id`, shown as "Raw" when null), the serial number (`serial_number`, shown only when present), a description snippet, and a sparkline trend; AND discrete chip-style badges display for the parallel/print run (for example `/25` or `1/1`), the grade tier, and the format — each rendered as a separate chip rather than inline prose.
3. **(input-validation + ui-state — format toggle, filters, and in-flight fetch)** Given the format toggle, When a value is selected, Then it accepts only one of "Both", "Digital-only", or "Physical-only" (any other value is rejected and the toggle keeps its prior value), and it sends the mapped `format` value to `GET /api/results` — `Both` → `both`, `Digital-only` → `digital`, `Physical-only` → `physical` — matching the `{both, digital, physical}` value set that [STORY-04-02-02](../../EPIC-04/FEATURE-04-02/STORY-04-02-02-implement-two-column-results-endpoint.md) validates; AND given any active filter (for example a grade or price-range filter), When the filter changes, Then it applies across BOTH the Digital and Physical columns at the same time; AND When a toggle or filter change triggers a results fetch, Then the changed control marks its active selection and enters a disabled/pending state that blocks a duplicate trigger until the fetch resolves or fails, after which the controls return to enabled.
4. **(error-handling — endpoint error)** Given the EPIC-04 two-column-results endpoint returns an error status (HTTP status code 500 or higher), When the view loads, Then a labeled "results unavailable" error state renders with a retry control, and neither column shows a partial or stale list.
5. **(edge-case — empty, thin, and format-exclusive data)** Given a query that returns no variations for the character, When the view renders, Then a "no results" state displays in place of two empty columns; AND given a variation with zero matched sales, Then its row shows an "asking-price estimate" label (sourced from `raw_listing.asking_price`) in place of a confident sold price; AND given a variation whose `valuation.sample_size` is below 5 (n<5), Then the price shows a greyed "based on N sales" label and no single-sale value is presented as a confident price; AND given a variation whose `parallel_type.format_availability = 'digital'` (for example a Gilded tier), Then a "no physical counterpart" label displays in the Physical column for that parallel.
6. **(security — escaped external text)** Given a `raw_listing.description` snippet that originates from external ingestion (Apify/eBay) and can contain HTML-like markup, When the snippet renders in a result row, Then it is output as escaped text through the framework's default text interpolation and is never injected as HTML (no `dangerouslySetInnerHTML` or direct `innerHTML`), so markup such as `<script>` or `<img onerror=...>` renders as literal characters and executes no script.
7. **(responsive — 375 CSS pixel viewport)** Given a viewport width of 375 CSS pixels, When the results view renders, Then the "Digital" and "Physical" columns stack into two vertically ordered labeled sections, each row's price, badges, and sparkline stay within the 375-pixel width, the format toggle and filter controls stay reachable with their labels visible and not truncated, and the page shows no page-level horizontal scrollbar.
8. **(accessibility — controls, rows, and sparkline)** Given the results view renders, When assistive technology inspects it, Then the format toggle, each filter control, and each status/format chip expose an accessible name and convey state through text or `aria-label` (not color alone); each result row is reachable by keyboard in DOM order with a visible focus indicator at a contrast ratio of at least 3:1; and each sparkline exposes a text alternative (`role="img"` with an `aria-label` stating the trend direction and percent change) so the trend is not conveyed by the graphic alone.

## Sub-tasks

- [ ] Build the two-column (Digital | Physical) results layout (@frontend-engineer)
- [ ] Render rows from the EPIC-04 two-column-results endpoint, mapping each `variation` into its format column by `variation.format` (@frontend-engineer)
- [ ] Render the parallel/print-run, grade-tier, and format badges as discrete chips (@frontend-engineer)
- [ ] Render the per-row sparkline trend backed by the `valuation` series (`trend_dir` -1/0/+1), exposing it as `role="img"` with an `aria-label` stating the trend direction and percent change (@frontend-engineer)
- [ ] Wire the format toggle (Both / Digital-only / Physical-only), sending the mapped `format` value (`both` / `digital` / `physical`) to `GET /api/results`, and the filters to apply across both columns simultaneously, marking the active selection and disabling the changed control while its fetch is in flight (@frontend-engineer)
- [ ] Render the `raw_listing.description` snippet as escaped text only (no `dangerouslySetInnerHTML`/`innerHTML`) so external HTML-like content cannot execute (@frontend-engineer)
- [ ] Stack the columns into labeled sections at a 375 CSS pixel viewport with no page-level horizontal scrollbar, keeping the toggle and filters reachable (@frontend-engineer)
- [ ] Add accessible names for the toggle, filters, and chips (state by text/`aria-label`, not color alone) and a visible keyboard focus indicator with keyboard row order (@frontend-engineer)
- [ ] Handle the empty ("no results"), zero-sale ("asking-price estimate"), digital-only ("no physical counterpart"), and endpoint-error states (@frontend-engineer)

## Edge Cases

- **Empty — no results:** a query returns no variations → a "no results" state renders in place of empty columns.
- **Boundary — zero-sale variation:** a variation with no matched sales → an "asking-price estimate" label (from `raw_listing.asking_price`) renders in place of a confident sold price.
- **Boundary — digital-only parallel:** `parallel_type.format_availability = 'digital'` (for example Gilded) → a "no physical counterpart" label renders in the Physical column.
- **Invalid/Error — endpoint failure:** the two-column-results endpoint returns an HTTP status code of 500 or higher → a labeled error state with a retry control renders, with no partial or stale list.
- **Boundary — filter empties one column:** a filter combination (for example "Physical-only") that empties one column → that column renders its own "no results in this column" state while the other column still lists its rows.

## Dependencies

### Upstream (must be complete first)

- **[STORY-05-01-02 — Implement Application Shell](../FEATURE-05-01/STORY-05-01-02-implement-application-shell.md):** the application-shell layout this results view renders within.
- **[STORY-05-02-01 — Implement Search Input with Autocomplete](STORY-05-02-01-implement-search-input-with-autocomplete.md):** the search input that selects which character's results this view shows.
- **[STORY-04-02-02 — Implement Two-Column Results Endpoint](../../EPIC-04/FEATURE-04-02/STORY-04-02-02-implement-two-column-results-endpoint.md):** the EPIC-04 endpoint this view consumes for the digital and physical rows; epic context — **[EPIC-04 — Backend Application & API](../../EPIC-04-backend-application-and-api.md)**.
- **[EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md):** the data model behind the rows — `variation.format`, `variation.print_run`, `parallel_type` (`name`, `format_availability`), `sale_observation`, `valuation` (`sample_size`, `trend_dir`), and `raw_listing.asking_price`.

### Downstream (informational — not a build prerequisite of this story)

- **[STORY-05-02-03 — Implement Last-Updated Timestamps](STORY-05-02-03-implement-last-updated-timestamps.md):** the per-card freshness timestamp that renders alongside the rows produced by this view.

### Parent feature

- **[FEATURE-05-02 — Search & Results Experience](../FEATURE-05-02-search-and-results-experience.md)**

## Story Estimation Guidance

- **Effort: moderate** — a two-column layout, per-row fields, chip badges, a sparkline, a format toggle, and four labeled empty/error/thin states.
- **Complexity: moderate** — mapping variations into format columns, the confidence gate (n<5), the asking-price-estimate fallback, the digital-only "no physical counterpart" rule, and filters applied across both columns at once.
- **Uncertainty: low-to-moderate** — the row fields, badges, and states are fixed by PRD §4.2/§8.5 and `docs/schema.sql`; the exact endpoint response shape is owned by EPIC-04.
- **Fibonacci Story Points: 5.**

## Definition of Done

- [ ] A "Digital" column and a "Physical" column render, with each row mapped into its column by `variation.format`.
- [ ] Each row shows the latest sold price, sold date, grade ("Raw" when null), serial number (when present), a description snippet, and a sparkline trend.
- [ ] Parallel/print-run, grade-tier, and format badges render as discrete chips.
- [ ] The format toggle accepts only Both / Digital-only / Physical-only — sending the mapped `format` value (`both` / `digital` / `physical`) to `GET /api/results` — and, together with the filters, applies across both columns simultaneously; the changed control marks its active selection and is disabled/pending while its fetch is in flight, returning to enabled on resolve or failure.
- [ ] A no-results query renders a "no results" state; a zero-sale variation renders an "asking-price estimate" label; an n<5 valuation renders a greyed "based on N sales" label; a digital-only parallel renders "no physical counterpart".
- [ ] A two-column-results endpoint error (HTTP status code 500 or higher) renders a labeled error state with a retry control, with no partial or stale list.
- [ ] The `raw_listing.description` snippet renders as escaped text only (no `dangerouslySetInnerHTML`/`innerHTML`), so external HTML-like content renders as literal characters and executes no script.
- [ ] At a 375 CSS pixel viewport the columns stack into labeled sections, the toggle and filters stay reachable with labels visible, and the page shows no page-level horizontal scrollbar.
- [ ] The toggle, filters, and chips expose accessible names and convey state by text/`aria-label` (not color alone); each row is keyboard-reachable in DOM order with a visible focus indicator at a contrast ratio of at least 3:1; each sparkline exposes a `role="img"` text alternative naming the trend direction and percent change.
- [ ] No component library or design system is introduced; the layout, rows, chips, sparkline, and toggle are described and built with concrete, measurable states.
- [ ] No prohibited vague quality term appears in any acceptance-criteria statement; every such statement names a measurable pass/fail condition.
- [ ] **Testing:** UI tests pass for the two-column render, the row fields, the chip badges, the sparkline, the format-toggle/filter behavior across both columns, the in-flight disabled state, the escaped-text rendering of HTML-like description content, the 375 CSS pixel responsive stacking, the accessibility semantics (names, focus, sparkline text alternative), and the empty/zero-sale/digital-only/error states; the UI coverage target is **≥50%** where code applies.
