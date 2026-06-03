# FEATURE-05-01: Frontend Foundation & Environment Access

*Parent epic: [EPIC-05 — Frontend User Interface](../EPIC-05-frontend-user-interface.md)*

## Feature Summary

This feature establishes the frontend foundation for CompVault: it completes the Vercel preview-deployment and environment access for the web application, then implements the Next.js App Router application shell — the shared page frame, the navigation, and the search entry point — within which every other EPIC-05 view renders. The business value is one provisioned, deployable surface that produces a shareable preview URL on every pull request, so each later screen is built and reviewed against a live environment rather than against a local-only build. Scope is limited to the environment access and the shell: the character search and the two-column results live in FEATURE-05-02, and the card-detail price-history chart and the operator review-queue workbench live in FEATURE-05-03. This feature adds no backend logic — it consumes the EPIC-04 endpoints — and introduces no component library or design system.

## Environment Access & Configuration

All environment provisioning for this feature follows the canonical Blitzy environments reference: <https://docs.blitzy.com/administration/environments>. Per that reference, an environment is created for each target, build and run instructions are supplied in natural language, non-sensitive values are stored as plaintext environment variables and credentials are stored as encrypted secrets, and the environment is then attached to the project. This step-by-step configuration is completed in full **before** the search and results views (FEATURE-05-02) and the detail and review-queue workbench views (FEATURE-05-03) are implemented.

The frontend is a Next.js App Router application deployed on Vercel. The Vercel GitHub integration produces one preview deployment per pull request and the production deployment on `main`, so each pull request renders the shell against a live, shareable URL before merge. Preview deployments read a preview-scoped configuration and never point at production data, keeping the preview database isolated from the production database.

Every screen that renders within the shell reads from the EPIC-04 endpoints — character search and autocomplete, the two-column digital | physical results, card/variation detail, the 90-day/1-year price-history and trend, and the operator review-queue — through one configured API base URL. The browser receives only client-safe configuration (the public API base URL); server-side credentials such as `DATABASE_URL` and any API tokens remain in encrypted secrets and are never included in the browser bundle.

### Platforms and access required

| Platform | Access required | Purpose in FEATURE-05-01 |
|----------|-----------------|--------------------------|
| Blitzy | Environment per target; plaintext variables and encrypted secrets | Store the frontend build and runtime variables (the EPIC-04 API base URL as a plaintext variable) and credentials as encrypted secrets per <https://docs.blitzy.com/administration/environments> |
| Vercel | Project access; per-scope environment variables; per-PR preview deployments | Build and host the Next.js App Router frontend; expose one preview deployment per pull request and the production deployment on `main` |

### Step-by-step configuration (complete before the views are implemented)

1. Create the Blitzy environment(s) and store the frontend variables — the EPIC-04 API base URL and any public client configuration — as plaintext, with credentials stored as encrypted secrets, per <https://docs.blitzy.com/administration/environments>.
2. Connect the repository to Vercel and enable the GitHub integration so each pull request produces a preview deployment and `main` produces the production deployment.
3. Set the Vercel project environment variables for the Preview and Production scopes so the shell resolves the EPIC-04 API base URL in each scope, with the Preview scope pointing at a non-production (preview) backend and database.
4. Confirm the EPIC-04 read and review-queue endpoints (or their published contracts) respond from the Preview environment before any screen is wired to live data.
5. Validate the wiring by deploying the shell to a Vercel preview URL and confirming it renders the route entry points (search, `card/[id]` detail, and the review queue) with no server secret present in the browser bundle.

## User Stories Index

This feature is delivered through two stories. Each link is relative to this file inside the `EPIC-05/` directory.

1. **[STORY-05-01-01 — Configure Vercel Preview & Environment Access](FEATURE-05-01/STORY-05-01-01-configure-vercel-preview-and-env-access.md)** — configure Vercel preview deployments and environment access for the frontend, with one preview deployment per pull request and previews isolated from production data; cite <https://docs.blitzy.com/administration/environments>.
2. **[STORY-05-01-02 — Implement Application Shell](FEATURE-05-01/STORY-05-01-02-implement-application-shell.md)** — implement the Next.js App Router application layout/shell (the shared page frame, the navigation, and the search entry point) that hosts the search, card-detail, and review-queue route entry points the later views render within.

## Dependencies

### Upstream (must be complete first)

- **EPIC-01 — Environment & Configuration Foundation:** supplies the Blitzy environments, the Next.js + TypeScript scaffold, the Vercel project, and the secrets baseline the frontend builds on.
- **EPIC-04 — Backend Application & API:** supplies the read and review-queue endpoints the shell's views consume — character search and autocomplete, the two-column digital | physical results, card/variation detail, the 90-day/1-year price-history and trend, and the operator review-queue. This dependency is informational at the shell stage: the shell renders the route entry points before the endpoints are wired, and no screen renders live data until its backing endpoint exists.

### Downstream (informational — not a build prerequisite of this feature)

- **[FEATURE-05-02 — Search & Results Experience](FEATURE-05-02-search-and-results-experience.md):** renders the character search input and the two-column digital | physical results within this shell.
- **[FEATURE-05-03 — Detail & Review Workbench UI](FEATURE-05-03-detail-and-review-workbench-ui.md):** renders the card/variation detail page, the price-history chart, and the operator review-queue workbench within this shell.
- **EPIC-06 — Testing & CI/CD Quality Gates:** authors UI test coverage against this shell and the EPIC-05 screens, targeting a UI coverage floor of **≥50%**.

## Definition of Done

- [ ] Both stories (STORY-05-01-01, STORY-05-01-02) are complete.
- [ ] Vercel preview deployments and environment access are configured per <https://docs.blitzy.com/administration/environments>, with non-sensitive values stored as plaintext variables and credentials stored as encrypted secrets.
- [ ] Each pull request produces a Vercel preview deployment, and the production deployment is produced on `main`.
- [ ] Preview deployments read a preview-scoped configuration and do not use production data.
- [ ] The Next.js App Router application shell (shared page frame, navigation, and search entry point) is implemented and hosts the search, card/variation detail, and operator review-queue route entry points.
- [ ] The shell resolves the EPIC-04 API base URL from environment configuration in each Vercel scope.
- [ ] No server secret (for example `DATABASE_URL` or any API token) is present in the browser bundle; the browser receives only client-safe configuration.
- [ ] No component library or design system is introduced; the shell layout is described and built with concrete, measurable states.
- [ ] **Testing:** UI tests pass for the application shell and meet the **≥50%** UI coverage target tracked in EPIC-06.
