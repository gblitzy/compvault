# STORY-05-02-03: Implement "Last Updated" Timestamps

*Parent feature: [FEATURE-05-02 — Search & Results Experience](../FEATURE-05-02-search-and-results-experience.md) · Parent epic: [EPIC-05 — Frontend User Interface](../../EPIC-05-frontend-user-interface.md)*

This is the **third of the three** stories in FEATURE-05-02 (Search & Results Experience). It describes the per-card **"last updated" freshness timestamp** that renders on each result row and on the card-detail entry point, so a collector can read how recent the underlying price data is. The displayed value is the **most recent** of three source instants surfaced by the EPIC-04 payload — `valuation.computed_at`, the newest `sale_observation` date (`sale_date` / `created_at`), and `raw_listing.last_seen` — and is shown in both an absolute ISO-8601 UTC form and a relative form (for example "5 hours ago"). A `fresh` state renders when the most-recent update is within the last 24 hours and a distinct `stale` state renders when it is older than 24 hours, reflecting the one-daily-ingestion-cycle expectation. Thin and missing data are labeled, never blank: an all-null freshness value renders a `no data yet` label and a source error renders a `freshness unavailable` fallback. The view **consumes — but does not implement —** the EPIC-04 endpoints and queries no database directly. It introduces no component library or design system and is described with concrete, measurable states, per PRD §4.7 (FR-14/FR-15) and §8.5.

## User Story

**As a** Collector (end user), **I want** a "last updated" timestamp per card, **so that** I know how fresh the price data is.

## Environment Access

Environment access and preview deployment for this view are configured once in [FEATURE-05-01 — Frontend Foundation & Environment Access](../FEATURE-05-01-frontend-foundation-and-environment-access.md) per the canonical Blitzy environments reference <https://docs.blitzy.com/administration/environments>; the full environment-configuration procedure is not duplicated here.

## Acceptance Criteria

1. **(valid-output — absolute + relative render)** Given a card whose most-recent update timestamp is known (the latest of `valuation.computed_at`, the newest `sale_observation` date, and `raw_listing.last_seen`), When the card renders on a results row or the card-detail entry point, Then a "last updated" value displays in BOTH an absolute form (an ISO-8601 UTC datetime) and a relative form (for example "5 hours ago").
2. **(valid-output — most-recent source wins)** Given a card whose `valuation.computed_at` is one instant and whose newest `sale_observation` is a later instant, When the freshness value is derived from the endpoint payload, Then the displayed timestamp equals the MOST RECENT of the available source timestamps.
3. **(input-validation — null/missing timestamp)** Given a card whose freshness fields are all null, When the card renders, Then a "no data yet" label displays in place of a timestamp and no blank or empty value is shown.
4. **(error-handling — source unavailable)** Given the endpoint that supplies the freshness value returns an error status (HTTP status code 500 or higher) or omits the freshness field, When the card renders, Then a labeled fallback ("freshness unavailable") displays and the remainder of the card row stays interactive.
5. **(edge-case — fresh within one daily cycle)** Given a card whose most-recent update is within the last 24 hours, When the card renders, Then a "fresh" state displays (a labeled recent indicator) alongside the relative time.
6. **(edge-case — stale beyond one daily cycle)** Given a card whose most-recent update is older than 24 hours, When the card renders, Then a "stale" state that is visually distinct from the "fresh" state (a separate labeled indicator) displays, using the 24-hour threshold as the boundary.

## Sub-tasks

- [ ] Derive the freshness timestamp from the endpoint payload as the most-recent of `valuation.computed_at`, the newest `sale_observation` date, and `raw_listing.last_seen` (@frontend-engineer)
- [ ] Render the timestamp on result rows and the card-detail entry point in absolute (ISO-8601 UTC) and relative form (@frontend-engineer)
- [ ] Render the "no data yet" label when all freshness fields are null and the "freshness unavailable" fallback on a source error (@frontend-engineer)
- [ ] Distinguish "fresh" (within the last 24 hours) from "stale" (older than 24 hours) with separate labeled indicators (@frontend-engineer)
- [ ] Normalize all source timestamps to UTC before computing the absolute and relative forms (@frontend-engineer)

## Edge Cases

- **Empty/Null — all freshness fields null:** the card renders a "no data yet" label rather than a blank.
- **Empty — card never ingested:** a card with no `raw_listing`, no `sale_observation`, and no `valuation` renders "no data yet" (not an error).
- **Boundary — exactly at the 24-hour threshold:** a card whose most-recent update is at 24 hours is classified deterministically (fresh when 24 hours or newer; stale when older than 24 hours).
- **Boundary — timezone normalization:** source timestamps are TIMESTAMPTZ in UTC; the absolute and relative forms are computed from the UTC value so the displayed result does not shift with the viewer's local timezone.

## Dependencies

### Upstream (must be complete first)

- **[STORY-05-01-02 — Implement Application Shell](../FEATURE-05-01/STORY-05-01-02-implement-application-shell.md):** the application-shell layout this freshness timestamp renders within.
- **[STORY-05-02-02 — Implement Two-Column Results View](STORY-05-02-02-implement-two-column-results-view.md):** the result rows that host the per-card timestamp.
- **[EPIC-04 — Backend Application & API](../../EPIC-04-backend-application-and-api.md):** the endpoints that expose the derived freshness fields (`valuation.computed_at`, `sale_observation` recency, and `raw_listing.last_seen`) in their payload.
- **[EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md):** the data model behind the freshness sources — `valuation.computed_at`, `sale_observation.sale_date` / `created_at`, and `raw_listing.last_seen` (all TIMESTAMPTZ, stored in UTC).

### Parent feature

- **[FEATURE-05-02 — Search & Results Experience](../FEATURE-05-02-search-and-results-experience.md)**

## Story Estimation Guidance

- **Effort: low** — a single derived field rendered in two forms on rows already built by [STORY-05-02-02](STORY-05-02-02-implement-two-column-results-view.md).
- **Complexity: low-to-moderate** — selecting the most-recent of multiple source timestamps, the fresh/stale 24-hour threshold, and UTC normalization.
- **Uncertainty: low** — the freshness sources and the one-daily-cycle expectation are fixed by PRD §4.7 (FR-14/FR-15) and `docs/schema.sql`.
- **Fibonacci Story Points: 2.**

## Definition of Done

- [ ] A "last updated" value renders per card on result rows and the card-detail entry point in absolute (ISO-8601 UTC) and relative form.
- [ ] The displayed timestamp equals the most-recent of `valuation.computed_at`, the newest `sale_observation` date, and `raw_listing.last_seen`.
- [ ] A null/missing freshness value renders "no data yet"; a source error (HTTP status code 500 or higher) renders "freshness unavailable", and the remainder of the card row stays interactive.
- [ ] A card updated within the last 24 hours renders a "fresh" state; a card older than 24 hours renders a distinct "stale" state, using the 24-hour threshold as the boundary.
- [ ] All source timestamps are normalized to UTC before formatting.
- [ ] No component library or design system is introduced; the timestamp states are described and built as concrete, measurable labels.
- [ ] No prohibited vague quality term appears in any acceptance-criteria statement; every such statement names a measurable pass/fail condition.
- [ ] **Testing:** UI tests pass for the timestamp render (absolute + relative), the null/"no data yet" state, the source-error "freshness unavailable" fallback, the 24-hour fresh/stale threshold, and UTC timezone normalization; the UI coverage target is **≥50%** where code applies.
