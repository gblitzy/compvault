# FEATURE-05-03: Detail & Review Workbench UI

*Parent epic: [EPIC-05 — Frontend User Interface](../EPIC-05-frontend-user-interface.md)*

## Feature Summary

This feature delivers the CompVault valuation-detail surface: a card/variation detail page presenting a recent-sales table (price, date sold, grade, serial number, source link, and a description snippet), a price-history chart rendered as a sparkline with a 90-day/1-year toggle and a trend indicator (▲/▼ with the percent change over the selected window), a digital↔physical counterpart panel that states the counterpart's current value and the ratio between the two formats (for example, `physical is 3.2× the digital`), and the operator-only review-queue workbench where the seeded operator resolves low-confidence matches, confirms new clusters, and merges duplicate canonical cards. The business value is one screen where a collector reads a sold-price trend over a selectable window backed by the `valuation` cache, and where the operator keeps the catalog free of duplicates and mis-parses. Scope is limited to the detail and workbench **views**, which consume the EPIC-04 card-detail, price-history, and review-queue/counterpart-override endpoints — this feature adds no backend logic and introduces no component library or design system. Deal scoring (§4.5), the pricing assistant, forecasting, and the dedicated side-by-side digital-vs-physical view (FR-13) are Phase 2/3 work and are out of scope here. This feature carries **3 stories**.

## Environment Access & Configuration

The platform access these views require — Blitzy encrypted secrets for server-side credentials, and Vercel preview deployments with per-scope environment access — is provisioned once in [FEATURE-05-01 — Frontend Foundation & Environment Access](FEATURE-05-01-frontend-foundation-and-environment-access.md) and documented per the canonical Blitzy environments reference <https://docs.blitzy.com/administration/environments>; the full step-by-step environment configuration is not duplicated here.

These views render live data only after the EPIC-04 endpoints they read respond from the configured API base URL in the active Vercel scope — specifically the card/variation detail endpoint (with its recent-sales table), the 90-day/1-year price-history and trend endpoint backed by the `valuation` cache, and the operator review-queue list/resolve and counterpart-override endpoints. The browser receives only the client-safe public API base URL; server-side credentials such as `DATABASE_URL` remain in encrypted secrets and never enter the browser bundle.

## User Stories Index

This feature is delivered through three stories. Each link is relative to this file inside the `EPIC-05/` directory.

1. **[STORY-05-03-01 — Implement Card Detail Page](FEATURE-05-03/STORY-05-03-01-implement-card-detail-page.md)** — the card/variation detail page with a recent-sales table whose columns are price, date sold, grade, serial number, source link, and a description snippet (sourced from `sale_observation` joined to `raw_listing`), plus the digital↔physical counterpart panel that states the counterpart's current value and the format ratio (for example, `physical is 3.2× the digital`) and works in both directions; image tiles hotlink the source URL and fall back to a placeholder through an `<img>` `onError` handler, rendering an `image expired` state when `image_status = gone` so no broken tile renders.
2. **[STORY-05-03-02 — Implement Price-History Chart](FEATURE-05-03/STORY-05-03-02-implement-price-history-chart.md)** — the price-history chart rendered as a sparkline with a 90-day/1-year toggle (backed by `valuation.window_days` values 90 and 365) and a trend indicator that renders ▲ when `trend_dir = +1` and ▼ when `trend_dir = -1`, alongside the percent change (`trend_pct`) over the selected window; the value carries the confidence-gate label — an asking-price estimate label at `sample_size = 0`, a low-confidence label at `sample_size ≥ 1`, and a confident value at `sample_size ≥ 5` — and renders the distinct PSA/BGS 10, PSA/BGS 9, and Raw physical series with the long tail of grades grouped (FR-12).
3. **[STORY-05-03-03 — Implement Review-Queue Workbench UI](FEATURE-05-03/STORY-05-03-03-implement-review-queue-workbench-ui.md)** — the operator-only review-queue workbench listing open items by `kind` (`extraction`, `match`, `new_cluster`, `merge_candidate`) and `reason`, exposing approve/correct and dismiss actions plus a duplicate-canonical-card merge action; a resolved or dismissed item moves out of the open queue as its `state` transitions from `open` to `resolved` or `dismissed`. Access is gated to the operator role (v1 = the single seeded operator returned by `getUserId()`).

## Dependencies

### Upstream (must be complete first)

- **EPIC-01 — Environment & Configuration Foundation:** supplies the Next.js + TypeScript scaffold, the Vercel project, and the secrets baseline these views build on.
- **[FEATURE-05-01 — Frontend Foundation & Environment Access](FEATURE-05-01-frontend-foundation-and-environment-access.md):** supplies the provisioned environment access (per <https://docs.blitzy.com/administration/environments>) and the application shell — the shared page frame, the navigation, and the route entry points — within which the detail page, the price-history chart, and the review-queue workbench render.
- **EPIC-04 — Backend Application & API:** supplies the read and review endpoints these views consume — the card/variation detail endpoint with its recent-sales table, the 90-day/1-year price-history and trend endpoint backed by the `valuation` cache, and the operator review-queue list/resolve and counterpart-override endpoints. No screen renders live data until its backing endpoint exists.

### Downstream (informational — not a build prerequisite of this feature)

- **EPIC-06 — Testing & CI/CD Quality Gates:** authors UI test coverage against these views, targeting a UI coverage floor of **≥50%**.

## Definition of Done

- [ ] All 3 stories (STORY-05-03-01, STORY-05-03-02, STORY-05-03-03) are complete.
- [ ] The card/variation detail page renders the recent-sales table with the columns price, date sold, grade, serial number, source link, and a description snippet (sourced from `sale_observation` joined to `raw_listing`).
- [ ] The digital↔physical counterpart panel renders the counterpart's current value and the format ratio (for example, `physical is 3.2× the digital`) and resolves in both directions (physical→digital and digital→physical).
- [ ] Image tiles hotlink the source URL and fall back to a placeholder through an `<img>` `onError` handler; when `image_status = gone` the tile renders an `image expired` state and no broken tile is shown, with no stored image copy.
- [ ] The price-history chart renders as a sparkline with a 90-day/1-year toggle backed by `valuation.window_days` values 90 and 365, and switching the toggle re-renders the series for the selected window.
- [ ] The trend indicator renders ▲ when `trend_dir = +1` and ▼ when `trend_dir = -1`, and displays the percent change (`trend_pct`) over the selected window.
- [ ] The displayed value carries the confidence-gate label: an asking-price estimate label at `sample_size = 0`, a low-confidence label at `sample_size ≥ 1` and `< 5`, and a confident value at `sample_size ≥ 5`; a confident number is never shown off a single sale.
- [ ] The chart renders the distinct PSA/BGS 10, PSA/BGS 9, and Raw physical series, with the long tail of grades grouped (FR-12).
- [ ] The operator-only review-queue workbench lists open items by `kind` (`extraction`, `match`, `new_cluster`, `merge_candidate`) and `reason`, and supports approve/correct, dismiss, and a duplicate-canonical-card merge action; a resolved or dismissed item leaves the open queue as its `state` moves from `open` to `resolved` or `dismissed`.
- [ ] Workbench access is gated to the operator role (v1 = the single seeded operator returned by `getUserId()`).
- [ ] No component library or design system is introduced; the views are described and built with concrete, measurable states.
- [ ] No prohibited vague quality term appears in any acceptance-criteria-like statement; every such statement names a measurable pass/fail condition.
- [ ] **Testing:** UI tests pass for the detail page, the price-history chart, and the review-queue workbench, and meet the **≥50%** UI coverage target tracked in EPIC-06.
