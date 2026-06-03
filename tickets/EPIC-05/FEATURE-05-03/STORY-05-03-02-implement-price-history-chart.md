# STORY-05-03-02: Implement Price-History Chart

*Parent feature: [FEATURE-05-03 — Detail & Review Workbench UI](../FEATURE-05-03-detail-and-review-workbench-ui.md) · Parent epic: [EPIC-05 — Frontend User Interface](../../EPIC-05-frontend-user-interface.md)*

This is the **second of the three** stories in FEATURE-05-03 (Detail & Review Workbench UI). It describes the **price-history chart** hosted on the card/variation detail page ([STORY-05-03-01](STORY-05-03-01-implement-card-detail-page.md)): a sparkline drawn from the selected window's `valuation` distribution (`p25`/`median`/`p75`), a 90-day/1-year toggle mapped to `valuation.window_days` values 90 and 365, and a trend indicator that renders ▲ when `trend_dir = +1`, ▼ when `trend_dir = -1`, and a neutral marker when `trend_dir = 0`, paired with the percent change `trend_pct` over the selected window (for example `+18% / 90d`). The displayed value carries the confidence gate from PRD §6.5 — an `asking-price estimate` label at `sample_size = 0`, a `low-confidence` label at a sample size of 1 to 4, and a confident value at a sample size of 5 or more — so a confident number is never shown off a single sale, and a selected window with no `valuation` row renders a labeled `insufficient history` state rather than a blank chart. The chart **consumes — but does not implement —** the EPIC-04 price-history endpoint backed by the `valuation` cache and queries no database directly. It introduces no component library, design system, or charting library and is described with concrete, measurable states, per PRD §4.3 (FR-8/FR-9) and §6.5 and the `valuation` table in `docs/schema.sql`.

## User Story

**As a** Collector (end user), **I want** a price-history chart with a 90-day/1-year toggle and a trend indicator, **so that** I can see whether a variation's value is rising or falling.

## Environment Access

Environment access and preview deployment for this view are configured once in [FEATURE-05-01 — Frontend Foundation & Environment Access](../FEATURE-05-01-frontend-foundation-and-environment-access.md) per the canonical Blitzy environments reference <https://docs.blitzy.com/administration/environments>; this chart additionally requires the EPIC-04 price-history endpoint backed by the `valuation` cache to return the windowed `p25`/`median`/`p75` series and the `trend_dir`/`trend_pct` it renders. The full environment-configuration procedure is not duplicated here.

## Acceptance Criteria

1. **(valid-output — toggle re-renders series + trend)** Given `valuation` rows exist for `window_days = 90` and `window_days = 365`, When the toggle is switched from 90d to 1y, Then the sparkline re-renders from the 365-day row's `p25`/`median`/`p75` series and the trend indicator re-renders from that row's `trend_dir`/`trend_pct`.
2. **(valid-output — trend indicator)** Given a selected window's `valuation` row, When the trend indicator renders, Then it renders ▲ when `trend_dir = +1`, ▼ when `trend_dir = -1`, and a neutral marker when `trend_dir = 0`, each paired with the percent change from `trend_pct` (for example `+18% / 90d`).
3. **(input-validation — toggle accepts only two windows)** Given the window toggle, When a value is selected, Then it accepts only one of the two defined windows (`90d` or `1y`); any other value is rejected and the toggle keeps its prior selection.
4. **(error-handling — insufficient history)** Given no `valuation` row exists for the selected window, When the chart attempts to render, Then a labeled `insufficient history` state renders instead of an empty or blank chart.
5. **(edge-case — asking-price estimate at n = 0)** Given the selected window's `valuation.sample_size = 0`, When the chart renders, Then an `asking-price estimate` label renders instead of a confident sold-price value.
6. **(edge-case — low-confidence at 1 ≤ n ≤ 4)** Given the selected window's `valuation.sample_size` is between 1 and 4 inclusive, When the chart renders, Then a `low-confidence` label renders alongside the series, and no single-sale value is presented as a confident price.

## Sub-tasks

- [ ] Render the sparkline from the `valuation` series (`p25`/`median`/`p75`) for the selected window (@frontend-engineer)
- [ ] Implement the 90d/1y toggle mapping to `valuation.window_days` 90 and 365 (@frontend-engineer)
- [ ] Render the trend indicator from `trend_dir` (▲/▼/neutral) paired with `trend_pct` (@frontend-engineer)
- [ ] Render the confidence-gate labels (n = 0 asking-price estimate; 1–4 low-confidence; ≥5 confident) (@frontend-engineer)
- [ ] Handle the missing-window `insufficient history` and empty states (@frontend-engineer)

## Edge Cases

- **Empty — `sample_size = 0`:** the chart renders an `asking-price estimate` label instead of a confident value.
- **Boundary — 1 ≤ n ≤ 4:** the chart renders a `low-confidence` label alongside the series.
- **Boundary — toggle to a window with insufficient data points:** switching to a window whose row is absent or has `sample_size = 0` renders the labeled `insufficient history` / `asking-price estimate` state for that window.
- **Boundary — flat trend (`trend_dir = 0`):** a neutral marker renders (no ▲ and no ▼ arrow), paired with the `trend_pct` value.
- **Invalid/empty — missing valuation row:** no `valuation` row for the selected window renders the `insufficient history` state (not a blank chart).

## Dependencies

### Upstream (must be complete first)

- **[STORY-05-01-02 — Implement Application Shell](../FEATURE-05-01/STORY-05-01-02-implement-application-shell.md):** the application-shell layout within which this chart renders.
- **[STORY-05-03-01 — Implement Card Detail Page](STORY-05-03-01-implement-card-detail-page.md):** the card/variation detail page that hosts this chart.
- **[STORY-04-02-04 — Implement Price History and Trend](../../EPIC-04/FEATURE-04-02/STORY-04-02-04-implement-price-history-and-trend.md):** the EPIC-04 price-history and trend endpoint, backed by the `valuation` cache, that this chart consumes; epic context — **[EPIC-04 — Backend Application & API](../../EPIC-04-backend-application-and-api.md)**.
- **[EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md):** the data model behind the chart — the `valuation` cache fields `window_days`, `p25`/`median`/`p75`, `sample_size`, `trend_pct`, and `trend_dir`.

### Parent feature

- **[FEATURE-05-03 — Detail & Review Workbench UI](../FEATURE-05-03-detail-and-review-workbench-ui.md)**

## Story Estimation Guidance

- **Effort: moderate** — a sparkline, a two-value toggle, a three-state trend indicator, three confidence-gate labels, and an insufficient-history state.
- **Complexity: moderate** — mapping the toggle to `window_days` 90/365, deriving ▲/▼/neutral from `trend_dir`, and the n = 0 / 1–4 / ≥5 confidence gate.
- **Uncertainty: low-to-moderate** — the windows, series fields, trend rule, and confidence gate are fixed by PRD §4.3/§6.5 and the `valuation` schema; the exact endpoint shape is owned by EPIC-04.
- **Fibonacci Story Points: 5.**

## Definition of Done

- [ ] A sparkline renders from the `valuation` `p25`/`median`/`p75` series for the selected window.
- [ ] A 90d/1y toggle maps to `window_days` 90 and 365 and re-renders both the sparkline and the trend on switch.
- [ ] The trend indicator renders ▲ (`trend_dir = +1`), ▼ (`trend_dir = -1`), or a neutral marker (`trend_dir = 0`), paired with `trend_pct` (for example `+18% / 90d`).
- [ ] The confidence gate renders an `asking-price estimate` label at `sample_size = 0`, a `low-confidence` label at 1 ≤ n ≤ 4, and a confident value at n ≥ 5.
- [ ] A selected window with no `valuation` row renders a labeled `insufficient history` state.
- [ ] No design system or component library — including any charting library — is introduced; the sparkline, toggle, trend indicator, and confidence-gate labels are described and built with concrete, measurable states.
- [ ] No prohibited vague quality term appears in any acceptance-criteria statement; every such statement names a measurable pass/fail condition.
- [ ] **Testing:** UI tests pass for the toggle re-render, the trend rendering (▲/▼/neutral), the confidence-gate states (n = 0 / 1–4 / ≥5), and the insufficient-history state; the UI coverage target is **≥50%** where code applies.
