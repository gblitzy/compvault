# STORY-05-01-02: Implement Application Shell

*Parent feature: [FEATURE-05-01 — Frontend Foundation & Environment Access](../FEATURE-05-01-frontend-foundation-and-environment-access.md) · Parent epic: [EPIC-05 — Frontend User Interface](../../EPIC-05-frontend-user-interface.md)*

This is the second of the **two** stories in FEATURE-05-01 and the application-shell story of EPIC-05. It implements the Next.js App Router root layout — a persistent header region that hosts the search entry point and a content outlet that renders the active route — within which every later EPIC-05 view renders. It builds on the environment-access story ([STORY-05-01-01](STORY-05-01-01-configure-vercel-preview-and-env-access.md)), which is finished first. The shell introduces no component library or design system and calls no backend endpoint; it hosts the route entry points (`/search`, `/card/[id]`, `/compare`, and the internal review queue) that FEATURE-05-02 and FEATURE-05-03 fill with content, per PRD §7.6.1 and §8.

## User Story

**As a** Frontend Engineer, **I want** a Next.js App Router application shell/layout, **so that** the search, detail, and review-queue views render within a consistent structure.

## Acceptance Criteria

1. **(valid-output — layout)** Given the application is deployed and the root URL is requested, When the page loads, Then a persistent root layout renders containing a header region that hosts the search entry point and a content outlet that renders the active route's content.
2. **(valid-output — routing/persistence)** Given the App Router root layout is mounted, When a user navigates to `/search`, `/card/[id]`, or `/compare`, Then the matching route segment renders inside the shared content outlet while the header region stays mounted across navigation.
3. **(input-validation — unknown route)** Given a request to a path that matches no defined route segment, When the router resolves the path, Then the defined not-found page renders and the response carries HTTP status 404 with a link back to the search entry point.
4. **(error-handling — error boundary)** Given a child route segment throws a render error, When the error boundary catches it, Then a defined error state renders inside the shell with the header region still visible (not a blank page) and a retry control is shown.
5. **(edge-case — responsive/mobile-first)** Given a viewport width of 375 CSS pixels, When the shell renders, Then the header region and content outlet stack in a single column with no horizontal scrollbar (mobile-first per PRD §8.5).
6. **(edge-case — no-JS/server render)** Given JavaScript is disabled in the browser, When the root URL is requested, Then the server-rendered shell markup (header region and content outlet) is present in the initial HTML response.

## Sub-tasks

- [ ] Create the App Router root layout (`app/layout.tsx`) (@frontend-engineer)
- [ ] Define the header region (hosting the search entry point) and the content outlet (@frontend-engineer)
- [ ] Add a not-found route (`app/not-found.tsx`) returning HTTP 404 (@frontend-engineer)
- [ ] Add an error boundary (`app/error.tsx`) rendering a defined error state with a retry control (@frontend-engineer)
- [ ] Mount the route entry points `app/(routes)/search`, `card/[id]`, `compare/`, and the internal review-queue entry (@frontend-engineer)
- [ ] Verify the shell renders in a single column with no horizontal scrollbar at a 375 px viewport (@frontend-engineer)

## Edge Cases

- **Invalid — unknown route:** an unmatched path renders the not-found page with HTTP 404.
- **Error — child render failure:** a child view throws; the error boundary renders the defined error state while the header region remains.
- **Boundary — narrow/mobile viewport:** at a 375 px viewport the shell renders a single column with no horizontal scrollbar.
- **Boundary — no-JS/hydration fallback:** with JavaScript disabled the server-rendered shell markup is present in the initial HTML.

## Dependencies

### Upstream (must be complete first)

- **[STORY-05-01-01 — Configure Vercel Preview & Environment Access](STORY-05-01-01-configure-vercel-preview-and-env-access.md):** environment access must be configured before the shell is implemented.
- **[STORY-01-02-01 — Initialize Next.js + TypeScript Project](../../EPIC-01/FEATURE-01-02/STORY-01-02-01-initialize-nextjs-typescript-project.md):** the Next.js App Router + TypeScript scaffold the root layout and route entry points are built on.
- **[STORY-01-02-03 — Establish Directory Layout](../../EPIC-01/FEATURE-01-02/STORY-01-02-03-establish-directory-layout.md):** the `app/` directory layout the root layout, not-found page, error boundary, and route entry points live in.

### Informational (not a build prerequisite of this story)

- **[EPIC-04 — Backend Application & API](../../EPIC-04-backend-application-and-api.md):** the read and review-queue endpoints the views will consume — informational at the shell stage; the shell does not call endpoints yet.

### Parent feature

- **[FEATURE-05-01 — Frontend Foundation & Environment Access](../FEATURE-05-01-frontend-foundation-and-environment-access.md)**

## Story Estimation Guidance

- **Effort: moderate** — a root layout, a not-found page, an error boundary, and route-entry mounting.
- **Complexity: low-to-moderate** — standard App Router constructs with no design system and no backend calls.
- **Uncertainty: low** — the route entry points and the mobile-first target are fixed by PRD §7.6.1 and §8.5.
- **Fibonacci Story Points: 3.**

## Definition of Done

- [ ] App Router root layout implemented with a header region (hosting the search entry) and a content outlet.
- [ ] Route entry points `app/(routes)/search`, `card/[id]`, `compare/` and the internal review-queue entry mount within the shell.
- [ ] Not-found page returns HTTP 404 for unmatched routes with a link to search.
- [ ] Error boundary renders a defined error state (header region remains) instead of a blank page.
- [ ] Shell renders in a single column with no horizontal scrollbar at a 375 px viewport (mobile-first).
- [ ] No design system / component library introduced; no server secret appears in the client bundle.
- [ ] **Testing:** UI tests pass for layout render, the not-found page, the error boundary, and the 375 px responsive breakpoint; the UI coverage target is **≥50%** where code applies.
