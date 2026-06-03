# STORY-05-03-01: Implement Card Detail Page

*Parent feature: [FEATURE-05-03 — Detail & Review Workbench UI](../FEATURE-05-03-detail-and-review-workbench-ui.md) · Parent epic: [EPIC-05 — Frontend User Interface](../../EPIC-05-frontend-user-interface.md)*

This is the **first of the three** stories in FEATURE-05-03 (Detail & Review Workbench UI). It describes the **card/variation detail page** — the surface where a collector judges one variation's value. The page renders a **recent-sales table** whose six columns are price (`sale_observation.sale_price`), date sold (`sale_observation.sale_date`), grade (`grade.label`, shown as `Raw` when `grade_id` is null), serial # (`serial_number`/`serial_run`, shown only when present), source link (`raw_listing.listing_url`), and a description snippet (from `raw_listing.description`), with `sale_observation` rows where `excluded_from_comps = TRUE` (lots/bundles/mislabels) held out of the table (PRD §4.3, FR-10). Alongside the table it renders the **digital↔physical counterpart panel** that states the counterpart's current value and the cross-format ratio (for example `physical is 3.2× the digital`) and resolves in both directions — physical→digital and digital→physical (PRD §4.3, FR-11; PRD §3.3) — and labels a format-exclusive variation `digital-exclusive / no physical counterpart` when `parallel_type.format_availability = 'digital'` (for example a Gilded tier). Image tiles **hotlink** the source URL only (no stored copies) and fall back to a placeholder through an `<img>` `onError` handler, rendering an `image expired` state when `raw_listing.image_status = 'gone'` so no broken tile renders (PRD §7, §8.5). The page **consumes — but does not implement —** the EPIC-04 card-detail endpoint and the counterpart-override endpoint, and queries no database directly; the price-history chart hosted on this page is built by the sibling [STORY-05-03-02](STORY-05-03-02-implement-price-history-chart.md). It introduces no component library or design system and is described with concrete, measurable states.

## User Story

**As a** Collector (end user), **I want** a card/variation detail page that shows a recent-sales table and the digital↔physical counterpart, **so that** I can judge a specific variation's value and compare formats.

## Environment Access

Environment access and preview deployment for this view are configured once in [FEATURE-05-01 — Frontend Foundation & Environment Access](../FEATURE-05-01-frontend-foundation-and-environment-access.md) per the canonical Blitzy environments reference <https://docs.blitzy.com/administration/environments>; this page additionally requires the EPIC-04 card-detail endpoint and the counterpart-override endpoint to return the recent-sales rows and the counterpart it renders. The full environment-configuration procedure is not duplicated here.

## Acceptance Criteria

1. **(valid-output — recent-sales table)** Given a variation with at least one `sale_observation` where `excluded_from_comps = FALSE`, When the detail page renders, Then the recent-sales table renders one row per non-excluded sale with all six columns: price (`sale_price`), date sold (`sale_date`), grade (`grade.label`, shown as `Raw` when `grade_id` is null), serial # (`serial_number`/`serial_run`, shown only when present), source link (`raw_listing.listing_url`), and a description snippet (from `raw_listing.description`).
2. **(valid-output — counterpart panel)** Given a variation that has a digital↔physical counterpart, When the counterpart panel renders, Then it displays the counterpart's current value and the cross-format ratio (for example `physical is 3.2× the digital`), and it renders the relationship in both directions (physical→digital and digital→physical).
3. **(input-validation — id parameter)** Given the card/variation id route parameter, When the page is requested, Then the id is validated as a positive integer before any fetch is issued, and a non-integer or non-positive id is rejected without issuing a fetch to the card-detail endpoint.
4. **(error-handling — not found)** Given a well-formed id that matches no card/variation, When the card-detail endpoint responds with no record (HTTP status code 404), Then a defined `not found` state renders with a link back to search, and the recent-sales table is not rendered as an empty grid.
5. **(edge-case — image expired)** Given a sale image whose `raw_listing.image_status = 'gone'`, When the row image renders, Then an `image expired` placeholder renders in place of a broken tile; AND given a hotlinked image URL that fails to load at view time, the `<img>` `onError` handler renders the same placeholder.
6. **(edge-case — digital-only variation)** Given a variation whose `parallel_type.format_availability = 'digital'` (for example a Gilded tier) with no physical counterpart, When the counterpart panel renders, Then a `digital-exclusive / no physical counterpart` label renders in place of a counterpart value.

## Sub-tasks

- [ ] Build the `card/[id]` detail route within the application shell (@frontend-engineer)
- [ ] Render the recent-sales table from the EPIC-04 card-detail endpoint with all six columns, excluding `excluded_from_comps = TRUE` rows (@frontend-engineer)
- [ ] Render the digital↔physical counterpart panel with the counterpart value and the cross-format ratio, working in both directions (@frontend-engineer)
- [ ] Wire the `<img>` `onError` placeholder and the `image_status = gone` → `image expired` state (@frontend-engineer)
- [ ] Handle the not-found state and the zero-sales state (@frontend-engineer)

## Edge Cases

- **Empty — variation with zero non-excluded sales:** the recent-sales table renders a `no recorded sales` state instead of a blank grid.
- **Invalid — unknown/invalid id:** a malformed id is rejected before fetch; a well-formed id with no matching record renders the `not found` state.
- **Boundary — expired image (`image_status = 'gone'`):** the row renders the `image expired` placeholder (no broken tile, no stored copy).
- **Boundary — digital-only variation:** `parallel_type.format_availability = 'digital'` → the counterpart panel renders `digital-exclusive / no physical counterpart`.
- **Data-quality — excluded-from-comps sales:** `sale_observation` rows with `excluded_from_comps = TRUE` never appear in the recent-sales table.

## Dependencies

### Upstream (must be complete first)

- **[STORY-05-01-02 — Implement Application Shell](../FEATURE-05-01/STORY-05-01-02-implement-application-shell.md):** the application-shell layout (the shared page frame and route entry points) within which this detail page renders.
- **[STORY-04-02-03 — Implement Card Detail and Sales Table](../../EPIC-04/FEATURE-04-02/STORY-04-02-03-implement-card-detail-and-sales-table.md):** the EPIC-04 card/variation detail endpoint, with its recent-sales table, that this page consumes.
- **[STORY-04-03-02 — Implement Counterpart-Override Endpoint](../../EPIC-04/FEATURE-04-03/STORY-04-03-02-implement-counterpart-override-endpoint.md):** the EPIC-04 counterpart-override endpoint backing the digital↔physical counterpart panel where the computed match is overridden; epic context — **[EPIC-04 — Backend Application & API](../../EPIC-04-backend-application-and-api.md)**.
- **[EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md):** the data model behind the page — the `sale_observation` (`sale_price`, `sale_date`, `grade_id`, `serial_number`/`serial_run`, `excluded_from_comps`), `raw_listing` (`listing_url`, `primary_image_url`, `image_status`, `description`), `variation`, `parallel_type` (`format_availability`), and `counterpart_override` fields.

### Downstream (informational — not a build prerequisite of this story)

- **[STORY-05-03-02 — Implement Price-History Chart](STORY-05-03-02-implement-price-history-chart.md):** the price-history chart is hosted on this detail page and renders inside its layout.

### Parent feature

- **[FEATURE-05-03 — Detail & Review Workbench UI](../FEATURE-05-03-detail-and-review-workbench-ui.md)**

## Story Estimation Guidance

- **Effort: moderate** — a detail route, a six-column sales table, a bidirectional counterpart panel, image states, and two empty/error states.
- **Complexity: moderate** — joining sales to grade/listing data, the cross-format ratio in both directions, the `excluded_from_comps` filter, and the `image_status`/`onError` image states.
- **Uncertainty: low-to-moderate** — the table columns, counterpart panel, and image behavior are fixed by PRD §4.3/§3.3/§7 and `docs/schema.sql`; the exact endpoint shape is owned by EPIC-04.
- **Fibonacci Story Points: 5.**

## Definition of Done

- [ ] The `card/[id]` detail route renders within the application shell.
- [ ] The recent-sales table renders one row per non-excluded sale with all six columns (price, date sold, grade, serial #, source link, description snippet); `excluded_from_comps = TRUE` rows are absent.
- [ ] The digital↔physical counterpart panel renders the counterpart value and the cross-format ratio in both directions; a digital-only variation renders `digital-exclusive / no physical counterpart`.
- [ ] Images hotlink with an `onError` placeholder; `image_status = gone` renders the `image expired` state, and no broken tile and no stored copy is shown.
- [ ] A malformed id is rejected before fetch; a well-formed unknown id renders the `not found` state; a zero-sales variation renders the `no recorded sales` state.
- [ ] No component library or design system is introduced; the page, table, counterpart panel, and image states are described and built with concrete, measurable states.
- [ ] No prohibited vague quality term appears in any acceptance-criteria statement; every such statement names a measurable pass/fail condition.
- [ ] **Testing:** UI tests pass for the sales-table render, the not-found state, the image-expired state, and the digital-only counterpart label; the UI coverage target is **≥50%** where code applies.
