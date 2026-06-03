# FEATURE-05-02: Search & Results Experience

*Parent epic: [EPIC-05 — Frontend User Interface](../EPIC-05-frontend-user-interface.md)*

## Feature Summary

This feature delivers the CompVault discovery surface: a character-first search box with autocomplete on known character names, a digital | physical two-column results view in which each row renders a Card/Variation with its latest sold price, sold date, grade, serial number (when present), a short description snippet, and a sparkline trend, plus a per-card `last updated` freshness timestamp that states how recent the underlying sold data is. The business value is one scannable screen where a collector types a character name, reads digital and physical values side by side with parallel/grade/format badges, and sees how stale or fresh each price is before acting on it. Scope is limited to the search and results **views**, which consume the EPIC-04 character-search, autocomplete, and two-column-results endpoints — this feature adds no backend logic and introduces no component library or design system. The dedicated digital-vs-physical comparison view (FR-13) and deal scoring (§4.5) are Phase 2 work and are out of scope here.

## Environment Access & Configuration

The platform access these views require — Blitzy encrypted secrets for server-side credentials, and Vercel preview deployments with per-scope environment access — is provisioned once in [FEATURE-05-01 — Frontend Foundation & Environment Access](FEATURE-05-01-frontend-foundation-and-environment-access.md) and documented per the canonical Blitzy environments reference <https://docs.blitzy.com/administration/environments>; the full step-by-step environment configuration is not duplicated here.

These views render live data only after the EPIC-04 endpoints they read — character search with autocomplete, and the two-column digital | physical results — respond from the configured API base URL in the active Vercel scope. The browser receives only the client-safe public API base URL; server-side credentials such as `DATABASE_URL` remain in encrypted secrets and never enter the browser bundle.

## User Stories Index

This feature is delivered through three stories. Each link is relative to this file inside the `EPIC-05/` directory.

1. **[STORY-05-02-01 — Implement Search Input with Autocomplete](FEATURE-05-02/STORY-05-02-01-implement-search-input-with-autocomplete.md)** — a character-first search input whose autocomplete suggestions are sourced from the EPIC-04 character-search endpoint and rendered as character text is typed into the search box (for example, typing `Vader` returns matching character names from `character.name` and `character.aliases`).
2. **[STORY-05-02-02 — Implement Two-Column Results View](FEATURE-05-02/STORY-05-02-02-implement-two-column-results-view.md)** — a digital | physical two-column results view (columns derived from `variation.format`) where each row renders the latest sold price, sold date, grade, serial number, a description snippet, and a sparkline; each row carries parallel (`/25`, `1/1`), grade-tier, and format badges; a digital-only parallel (for example Gilded, `format_availability = 'digital'`) is labeled `no physical counterpart`.
3. **[STORY-05-02-03 — Implement "Last Updated" Timestamps](FEATURE-05-02/STORY-05-02-03-implement-last-updated-timestamps.md)** — a per-card `last updated` freshness timestamp on each result row and on the detail entry points, sourced from `valuation.computed_at`, `sale_observation` recency, or `raw_listing.last_seen`.

## Dependencies

### Upstream (must be complete first)

- **EPIC-01 — Environment & Configuration Foundation:** supplies the Next.js + TypeScript scaffold, the Vercel project, and the secrets baseline these views build on.
- **[FEATURE-05-01 — Frontend Foundation & Environment Access](FEATURE-05-01-frontend-foundation-and-environment-access.md):** supplies the provisioned environment access (per <https://docs.blitzy.com/administration/environments>) and the application shell — the shared page frame, the navigation, and the search entry point — within which the search input and the results view render.
- **EPIC-04 — Backend Application & API:** supplies the read endpoints these views consume — character search with autocomplete, and the two-column digital | physical results. No result row renders live data until its backing endpoint exists.

### Downstream (informational — not a build prerequisite of this feature)

- **[FEATURE-05-03 — Detail & Review Workbench UI](FEATURE-05-03-detail-and-review-workbench-ui.md):** the card/variation detail page is navigated to from a results row in this view.
- **EPIC-06 — Testing & CI/CD Quality Gates:** authors UI test coverage against these views, targeting a UI coverage floor of **≥50%**.

## Definition of Done

- [ ] All 3 stories (STORY-05-02-01, STORY-05-02-02, STORY-05-02-03) are complete.
- [ ] The character-first search input renders autocomplete suggestions sourced from the EPIC-04 character-search endpoint, returned as character text is typed into the search box.
- [ ] The digital | physical two-column results view renders, with columns derived from `variation.format`, and the active filters apply across both columns at the same time.
- [ ] Each result row renders its latest sold price, sold date, grade, serial number (when present), a description snippet, and a sparkline.
- [ ] Each result row renders parallel (`/25`, `1/1`), grade-tier, and format badges as chips, and a `no physical counterpart` label is shown on a digital-only parallel (for example Gilded, `format_availability = 'digital'`).
- [ ] Each price displays a visible sample-size label (`based on N sales`) that is greyed/labeled when the sample size is below 5.
- [ ] An empty result set renders a labeled message rather than a blank screen, and a row with no sold data renders an asking-price estimate carrying an `estimate` label rather than a sold price.
- [ ] A `last updated` freshness timestamp renders per card — sourced from `valuation.computed_at`, `sale_observation` recency, or `raw_listing.last_seen` — and a sold record ingested in the most recent daily ingestion cycle is reflected in the result row (FR-15).
- [ ] No component library or design system is introduced; the views are described and built with concrete, measurable states.
- [ ] No prohibited vague quality term appears in any acceptance-criteria-like statement; every such statement names a measurable pass/fail condition.
- [ ] **Testing:** UI tests pass for the search input and the two-column results view and meet the **≥50%** UI coverage target tracked in EPIC-06.
