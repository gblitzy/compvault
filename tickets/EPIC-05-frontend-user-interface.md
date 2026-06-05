# EPIC-05: Deliver the Frontend User Interface — character-first search, two-column digital|physical results, a card-detail price-history chart, and the operator review-queue workbench

## Epic Summary

EPIC-05 delivers the CompVault web interface: a character-first search experience, a two-column digital | physical results view, a card/variation detail page carrying a price-history chart and a recent-sales table, and the operator-only review-queue workbench. The business value is a single browsable surface where a collector compares digital and physical card values side by side, reads a sold-price trend over a selectable window, and where the operator resolves low-confidence matches that keep the catalog clean. Scope is limited to frontend screens that consume the EPIC-04 read and review-queue endpoints — this epic adds no backend logic, mandates no component library or design system, and excludes Phase 2 intelligence features (counterpart linking, deal scoring, pricing assistant) and Phase 3 multi-user and monetization features.

## Environment Access & Configuration

All environment provisioning for this epic follows the canonical Blitzy environments reference: <https://docs.blitzy.com/administration/environments>. Non-sensitive values are stored as plaintext environment variables and credentials are stored as encrypted secrets, after which the environment is attached to the project. This step-by-step configuration is completed in full **before** any UI implementation work begins.

The frontend is a Next.js App Router application deployed on Vercel. The Vercel GitHub integration produces one preview deployment per pull request and the production deployment on `main`, so each pull request renders the UI against a live, shareable URL before merge. Every screen reads from the EPIC-04 endpoints (character search and autocomplete, the two-column results, card/variation detail, the 90-day/1-year price-history and trend, and the review-queue), so those endpoints — or their published contracts — are reachable from each Vercel environment before the screens are wired to live data.

### Platforms and access required

| Platform | Access required | Purpose in EPIC-05 |
|----------|-----------------|--------------------|
| Blitzy | Dev/Staging/Prod environments; plaintext variables and encrypted secrets | Store the frontend build and runtime variables (including the EPIC-04 API base URL) per the Blitzy environments reference |
| Vercel | Project access; per-scope environment variables; per-PR preview deployments | Build and host the Next.js App Router frontend; expose one preview deployment per pull request and the production deployment on `main` |

### Step-by-step configuration (complete before UI work begins)

1. Create the Blitzy environments and store the frontend variables — the EPIC-04 API base URL and any public client configuration — as plaintext, with credentials stored as encrypted secrets, per <https://docs.blitzy.com/administration/environments>.
2. Connect the repository to Vercel and enable the GitHub integration so each pull request produces a preview deployment and `main` produces the production deployment.
3. Set the Vercel project environment variables for the Preview and Production scopes so the frontend resolves the EPIC-04 endpoint base URL in each scope.
4. Confirm the EPIC-04 read and review-queue endpoints (or their published contracts) respond from the Preview environment before any screen is wired to live data.
5. Validate the wiring with a minimal page that renders on a Vercel preview URL, confirming the environment is provisioned before the first UI screen is authored.

## Features Index

This epic is delivered through three features. Each link is relative to this file inside the `EPIC-05/` directory.

1. **[FEATURE-05-01 — Frontend Foundation & Environment Access](EPIC-05/FEATURE-05-01-frontend-foundation-and-environment-access.md)** — complete the Vercel preview-deployment and environment access above, then implement the application layout/shell (the shared page frame, the navigation, and the search entry point). This feature carries two stories.
2. **[FEATURE-05-02 — Search & Results Experience](EPIC-05/FEATURE-05-02-search-and-results-experience.md)** — implement the character search input with autocomplete, the digital | physical two-column results view, and the "last updated" freshness timestamp on each result. This feature carries three stories.
3. **[FEATURE-05-03 — Detail & Review Workbench UI](EPIC-05/FEATURE-05-03-detail-and-review-workbench-ui.md)** — implement the card/variation detail page with its recent-sales table, the price-history chart (a sparkline with a 90-day/1-year toggle and a trend indicator), and the operator-only review-queue workbench. This feature carries three stories.

## Dependencies

### Upstream (must be complete first)

- **EPIC-01 — Environment & Configuration Foundation:** supplies the Next.js + TypeScript scaffold, the Vercel project, and the secrets baseline that the frontend builds on.
- **EPIC-04 — Backend Application & API:** supplies the read endpoints the UI renders — character search and autocomplete, the two-column digital|physical results, card/variation detail with its sales table, the 90-day/1-year price-history and trend, and the operator review-queue list/resolve and counterpart-override endpoints. No screen renders live data until its backing endpoint exists.

### Downstream (informational — not a build prerequisite of this epic)

- **EPIC-06 — Testing & CI/CD Quality Gates:** authors UI test coverage against this epic's screens, targeting a UI coverage floor of **≥50%**.

## Definition of Done

- [ ] All 3 child features (FEATURE-05-01, FEATURE-05-02, FEATURE-05-03) are complete.
- [ ] Vercel preview deployments and environment access are configured per <https://docs.blitzy.com/administration/environments>, with one preview deployment produced per pull request.
- [ ] The application shell (shared page frame, navigation, and search entry point) is implemented and renders on a Vercel preview URL.
- [ ] The character search input with autocomplete is implemented and returns matching character names as the user types into the search box.
- [ ] The digital | physical two-column results view is implemented, rendering each result row with its latest sold price, sold date, grade or condition, serial number when present, and a sparkline.
- [ ] A "last updated" freshness timestamp is displayed on each card result.
- [ ] The card/variation detail page is implemented with a recent-sales table (price, sold date, grade, serial number, source link, and description snippet).
- [ ] The price-history chart is implemented as a sparkline with a 90-day/1-year toggle and a trend indicator that shows the direction (▲/▼) and the percent change over the selected window.
- [ ] The operator-only review-queue workbench UI is implemented, listing open review items and exposing the approve/correct (resolve) and counterpart-override actions backed by the EPIC-04 endpoints.
- [ ] Image tiles hotlink the source image and fall back to an "image expired" placeholder via an `onError` handler when the image is gone, so no broken tile renders.
- [ ] **Testing:** UI tests pass against the implemented screens and meet the **≥50%** UI coverage target tracked in EPIC-06.
