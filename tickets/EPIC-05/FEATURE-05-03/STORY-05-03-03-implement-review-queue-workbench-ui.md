# STORY-05-03-03: Implement Review-Queue Workbench UI

*Parent feature: [FEATURE-05-03 — Detail & Review Workbench UI](../FEATURE-05-03-detail-and-review-workbench-ui.md) · Parent epic: [EPIC-05 — Frontend User Interface](../../EPIC-05-frontend-user-interface.md)*

This is the **third of the three** stories in FEATURE-05-03 (Detail & Review Workbench UI). It describes the **operator-only review-queue workbench** — the core operator loop (PRD §8.6) where the seeded operator works through open low-confidence items to keep the catalog free of duplicates and mis-parses. The workbench lists each open `review_queue` item by its `kind` (`extraction`, `match`, `new_cluster`, `merge_candidate`) and its human-readable `reason`, renders the structured `payload` detail, and exposes per-item **approve / correct / dismiss** actions plus a **duplicate-canonical-card merge** action (the main defense against catalog fragmentation) and the operator **counterpart-override** action (manual digital↔physical links where the computed match is wrong or missing, backed by the `counterpart_override` table). Resolving or dismissing an item moves it out of the open list as its `state` transitions from `open` to `resolved` or `dismissed`. Access is gated to the operator role — in v1 the single seeded operator returned by the `getUserId()` seam (`owner_user_id` is NULL in v1; authentication is deferred). The workbench **consumes — but does not implement —** the EPIC-04 review-queue list/resolve endpoints and the counterpart-override endpoint, and queries no database directly. It introduces no component library or design system and is described with concrete, measurable states, per PRD §8.6 and §10 (Phase 1 MVP) and the `review_queue` / `counterpart_override` tables in `docs/schema.sql`.

## User Story

**As an** Operator, **I want** a review-queue workbench that lists open low-confidence items with approve/correct/dismiss and duplicate-card merge actions, **so that** I can resolve mis-parses and prevent catalog fragmentation.

## Environment Access

Environment access and preview deployment for this view are configured once in [FEATURE-05-01 — Frontend Foundation & Environment Access](../FEATURE-05-01-frontend-foundation-and-environment-access.md) per the canonical Blitzy environments reference <https://docs.blitzy.com/administration/environments>; this workbench additionally requires the EPIC-04 review-queue list/resolve endpoints and the counterpart-override endpoint to return and accept the items it renders and resolves. The full environment-configuration procedure is not duplicated here.

## Acceptance Criteria

1. **(valid-output — open list renders)** Given at least one `review_queue` item with `state = 'open'`, When the workbench renders, Then each open item displays its `kind` (one of `extraction`, `match`, `new_cluster`, `merge_candidate`) and its `reason` text, alongside the approve, correct, dismiss, and duplicate-card merge action controls.
2. **(valid-output — resolve removes from open list)** Given an open item, When the operator approves, corrects, or dismisses it through the EPIC-04 review-queue resolve endpoint and the endpoint returns a success status (HTTP status code below 400), Then the item is removed from the open list and its `state` is set to `resolved` (or `dismissed` for a dismiss action).
3. **(input-validation — correction form)** Given the correction form for an item, When the operator submits it, Then the form validates that every required field is present before submit, and a submission with an empty required field is rejected with a labeled field error and no resolve request is sent to the endpoint.
4. **(error-handling — failed resolve)** Given a resolve action is submitted, When the resolve endpoint returns an error status (HTTP status code 500 or higher), Then a labeled error state renders and the item stays in the open list with its `state` unchanged.
5. **(edge-case — empty queue)** Given zero `review_queue` items with `state = 'open'`, When the workbench renders, Then an `empty queue` state renders in place of the list grid.
6. **(edge-case — concurrent/stale resolution)** Given an item that was already resolved by another action since it was loaded, When the operator submits a resolve for that item, Then a `stale item` message renders and the item is refreshed out of the open list rather than double-resolved.

## Sub-tasks

- [ ] Build the operator-only workbench list view of open `review_queue` items (@frontend-engineer)
- [ ] Render each item's `kind`, `reason`, and `payload` detail (@frontend-engineer)
- [ ] Wire approve/correct/dismiss to the EPIC-04 review-queue resolve endpoint (@frontend-engineer)
- [ ] Wire the duplicate-card merge action (and the counterpart-override action) (@frontend-engineer)
- [ ] Handle the empty-queue, resolve-error, and stale-item states (@frontend-engineer)

## Edge Cases

- **Empty — zero open items:** no `review_queue` item has `state = 'open'` → the workbench renders an `empty queue` state in place of an empty grid.
- **Invalid/Error — resolve failure:** the resolve endpoint returns an HTTP status code of 500 or higher → a labeled error state renders and the item stays open with its `state` unchanged.
- **Concurrent — already resolved elsewhere:** an item was resolved by another action since it was loaded → a `stale item` message renders and the item leaves the open list without being double-resolved.
- **Boundary — merge with a single candidate:** a merge action is offered with only one canonical-card candidate → the merge cannot complete (a merge needs two distinct cards) and a labeled `single candidate` state renders.
- **Invalid — non-operator access:** a request from a non-operator identity (the `getUserId()` seam does not resolve to the seeded operator) is blocked from the workbench.

## Dependencies

### Upstream (must be complete first)

- **[STORY-05-01-02 — Implement Application Shell](../FEATURE-05-01/STORY-05-01-02-implement-application-shell.md):** the application-shell layout within which this workbench renders.
- **[STORY-04-03-01 — Implement Review-Queue Endpoints](../../EPIC-04/FEATURE-04-03/STORY-04-03-01-implement-review-queue-endpoints.md):** the EPIC-04 review-queue list and resolve endpoints this workbench consumes.
- **[STORY-04-03-02 — Implement Counterpart-Override Endpoint](../../EPIC-04/FEATURE-04-03/STORY-04-03-02-implement-counterpart-override-endpoint.md):** the EPIC-04 counterpart-override endpoint backing the operator counterpart-override action; epic context — **[EPIC-04 — Backend Application & API](../../EPIC-04-backend-application-and-api.md)**.
- **[STORY-02-03-02 — Implement getUserId Seam](../../EPIC-02/FEATURE-02-03/STORY-02-03-02-implement-getuserid-seam.md):** the operator-identity seam that gates workbench access to the single seeded operator in v1; data model — **[EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md)** (the `review_queue` `kind`/`reason`/`payload`/`state` fields and the `counterpart_override` `link_level`/`physical_ref_id`/`digital_ref_id` fields).

### Parent feature

- **[FEATURE-05-03 — Detail & Review Workbench UI](../FEATURE-05-03-detail-and-review-workbench-ui.md)**

## Story Estimation Guidance

- **Effort: moderate-to-high** — an open-item list, per-item `payload` detail, four action types (approve/correct/dismiss plus merge), a correction form, and labeled empty/error/stale states.
- **Complexity: high** — operator role-gating via the `getUserId()` seam, the duplicate-card merge action, optimistic-versus-stale concurrency handling, and form validation across the heterogeneous `review_queue.kind` payloads.
- **Uncertainty: moderate** — the workbench actions and operator gating are fixed by PRD §8.6 and the `review_queue` schema; the exact endpoint response shapes and the merge contract are owned by EPIC-04.
- **Fibonacci Story Points: 8.**

## Definition of Done

- [ ] The operator-only workbench lists open `review_queue` items, each showing its `kind`, `reason`, and `payload`, with approve/correct/dismiss and duplicate-card merge controls.
- [ ] Resolving or dismissing an item removes it from the open list and sets its `state` to `resolved` or `dismissed`.
- [ ] The correction form validates every required field before submit; a submission with an empty required field is rejected and no resolve request is sent.
- [ ] A failed resolve (HTTP status code 500 or higher) renders a labeled error state and the item stays open with its `state` unchanged; an already-resolved item renders a `stale item` message and leaves the open list without being double-resolved.
- [ ] A zero-open-item queue renders an `empty queue` state; a merge offered with a single candidate renders a `single candidate` state; a request from a non-operator identity (the `getUserId()` seam does not resolve to the seeded operator) is blocked from the workbench.
- [ ] No component library or design system is introduced; the list view, per-item controls, correction form, and merge action are described and built with concrete, measurable states.
- [ ] No prohibited vague quality term appears in any acceptance-criteria statement; every such statement names a measurable pass/fail condition.
- [ ] **Testing:** UI tests pass for the open-list render, resolve/dismiss/merge, the `empty queue` state, the resolve-error state, and the concurrent/stale-item state; the UI coverage target is **≥50%** where code applies.
