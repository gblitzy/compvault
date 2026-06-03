# STORY-03-03-03: Document Deferred eBay API Integration

*Parent feature: [FEATURE-03-03 — Scheduled Ingestion Orchestration](../FEATURE-03-03-scheduled-ingestion-orchestration.md) · Parent epic: [EPIC-03 — Data Ingestion Pipeline](../../EPIC-03-data-ingestion-pipeline.md)*

**Status: DEFERRED / BLOCKED on approved eBay API access — not scheduled, and not a dependency of any active story.**

This is the **third** of the three stories in FEATURE-03-03 (Scheduled Ingestion Orchestration). It **documents** the future eBay Browse / Marketplace-Insights API integration as a tracked, **DEFERRED/BLOCKED** item so the team can activate it the moment approved access is granted, without it blocking any current work. This is a planning and tracking ticket only: it authors no application code, no SQL, and no workflow YAML. Its acceptance criteria assert documentation completeness and status facts — the named APIs, the named credentials, the blocked status, the activation trigger, and the cross-story non-dependency — rather than any runtime behavior, because the work itself is deferred.

Two eBay APIs are in scope of the future integration. The **eBay Browse API** (free tier) is the official active-listings feed. The **eBay Marketplace Insights API** supplies a 90-day sold-history window and is **limited-release: it must be applied for and the application may be denied** — the PRD treats it as a bonus, not a dependency. The eBay path authenticates with an **OAuth client-credentials token**; its credentials are **`EBAY_CLIENT_ID`** and **`EBAY_CLIENT_SECRET`**, which will be stored as **encrypted secrets** (never plaintext) per the canonical Blitzy environments reference at <https://docs.blitzy.com/administration/environments> once the deferral is lifted.

The deferral introduces **no dependency** into the active backlog. CompVault accumulates sold-history **forward** from day one — there is no historical backfill source — and the `ebay-sold-listings` Apify actor is the **primary live ingestion source now** ([FEATURE-03-01 — Apify Actor Integration](../FEATURE-03-01-apify-actor-integration.md)). If and when eBay access is granted, the Marketplace Insights feed flips on as an **additive** 90-day sold-history source layered on top of that forward accumulation. The **activation trigger** is a single condition — the user obtains approved eBay API access — described as a trigger, not a date. This story is **NOT a prerequisite** of `STORY-03-03-01`, `STORY-03-03-02`, or any other active story, and it gates no other work.

**Compliance posture:** the main application calls **official APIs only** — the eBay API is the official sold-data path documented here for future activation; the `ebay-sold-listings` Apify actor is the **single sanctioned out-of-band scraping exception** and the primary live source today.

## User Story

> **As a** Platform Engineer, **I want** the future eBay Browse / Marketplace-Insights API integration documented as a tracked, access-blocked item, **so that** the team can activate it when approved access is granted without it blocking any current work.

## Acceptance Criteria

1. **(valid-output — documentation completeness)** **Given** the deferred-integration ticket, **When** it is reviewed, **Then** it names both the **eBay Browse API** (active listings) and the **eBay Marketplace Insights API** (90-day sold history) and states that Marketplace Insights is limited-release, must be applied for, and may be denied.

2. **(valid-output — named credentials)** **Given** the ticket, **When** the required credentials are listed, **Then** it names **`EBAY_CLIENT_ID`** and **`EBAY_CLIENT_SECRET`** as OAuth client-credentials and cites <https://docs.blitzy.com/administration/environments> as the location where these encrypted secrets will be stored once access is granted.

3. **(input-validation — non-dependency assertion)** **Given** the Dependencies sections of `STORY-03-03-01` and `STORY-03-03-02`, **When** they are inspected, **Then** `STORY-03-03-03` does not appear as a prerequisite of either story, nor of any other active story.

4. **(valid-output — blocked status and trigger)** **Given** the ticket, **When** its status is read, **Then** it is marked **DEFERRED/BLOCKED** and the activation trigger is stated as "the user obtains approved eBay API access."

5. **(edge-case — access denied indefinitely)** **Given** approved access is never granted, **When** the active ingestion pipeline runs, **Then** the Apify actor remains the primary live source and the deferred eBay integration introduces 0 failures into any active run.

6. **(edge-case — access granted later)** **Given** approved access is later granted, **When** the documented activation path is followed, **Then** Marketplace Insights is enabled as an **additive** 90-day sold-history source on top of the forward accumulation that already runs from day one.

7. **(error-handling — credentials present but unverified)** **Given** `EBAY_CLIENT_ID` / `EBAY_CLIENT_SECRET` are present in the environment but the access grant is unverified, **When** the integration status is evaluated, **Then** it remains **BLOCKED** until the grant is verified — credential presence alone does not unblock it.

## Sub-tasks

- Document the **eBay Browse API** (active listings) and the **eBay Marketplace Insights API** (90-day sold history; limited-release, must apply, may be denied). `@platform-engineer`
- Record the required OAuth credentials `EBAY_CLIENT_ID` and `EBAY_CLIENT_SECRET`, and cite <https://docs.blitzy.com/administration/environments> for where they will be stored as encrypted secrets when the deferral is lifted. `@platform-engineer`
- Mark the integration **DEFERRED/BLOCKED** with the activation trigger set to approved eBay API access. `@platform-engineer`
- State that this story is **NOT a dependency** of `STORY-03-03-01`, `STORY-03-03-02`, or any other active story; add an informational link to [FEATURE-03-01 — Apify Actor Integration](../FEATURE-03-01-apify-actor-integration.md) (the primary live source now). `@platform-engineer`
- Describe the activation path: once access is verified, enable Marketplace Insights as an additive 90-day sold-history source layered on the existing forward accumulation. `@platform-engineer`
- Note the compliance posture: the main application calls official APIs only (the eBay API is the official sold-data path); the `ebay-sold-listings` Apify actor is the single sanctioned out-of-band scraping exception. `@platform-engineer`

## Edge Cases

- **(Invalid / denied indefinitely)** Approved access is never granted → the active Apify pipeline is unaffected, 0 active runs fail, and the deferred eBay integration is invoked by 0 scheduled runs.
- **(Boundary / granted later)** Approved access is granted later → the documented activation path is followed and Marketplace Insights becomes an additive 90-day sold-history source on top of the forward accumulation.
- **(Empty/Null / unverified credentials)** `EBAY_CLIENT_ID` / `EBAY_CLIENT_SECRET` are present but the grant is unverified → the integration is still treated as **BLOCKED** until the grant is verified; credential presence alone does not unblock it.

## Dependencies

### Upstream (must be complete first)

- **NONE.** No story or epic blocks this documentation and tracking story.

### Downstream (this story blocks nothing)

- **NONE.** This story gates no other work and is a prerequisite of 0 stories.

### Informational only

- **[FEATURE-03-01 — Apify Actor Integration](../FEATURE-03-01-apify-actor-integration.md):** the `ebay-sold-listings` Apify actor is the primary live ingestion source now; the deferred eBay API is the official sold-data path documented here for future activation.

### Explicit non-dependency

- **`STORY-03-03-03` is NOT a prerequisite** of `STORY-03-03-01`, `STORY-03-03-02`, or any other active story, and it appears in no active story's dependency list. `STORY-03-03-01` lists it only as a Downstream/informational item, and `STORY-03-03-02` does not reference it.

### Parent feature

- **[FEATURE-03-03 — Scheduled Ingestion Orchestration](../FEATURE-03-03-scheduled-ingestion-orchestration.md)**

## Story Estimation Guidance

- **Effort: Low** — author a single documentation and tracking ticket; no runtime logic is written and no configuration is executed.
- **Complexity: Low** — documentation and tracking only; the source facts are fixed by §5.1 and §11 of the PRD and by the AAP deferral directive.
- **Uncertainty: Low** — the deferral is a fixed decision; the named credentials, the blocked status, the activation trigger, and the additive-source relationship are confirmed in the PRD.
- **Fibonacci Story Points: 2.** The single-file documentation scope with confirmed source facts places this above a 1 — it threads the cross-story non-dependency assertion and the activation path — while the absence of any runtime logic or executed configuration holds it below a 3. Points measure relative size, not a duration.

## Definition of Done

- [ ] The ticket names the eBay Browse API (active listings) and the eBay Marketplace Insights API (90-day sold history; limited-release, must apply, may be denied).
- [ ] The required OAuth credentials `EBAY_CLIENT_ID` / `EBAY_CLIENT_SECRET` are named, with <https://docs.blitzy.com/administration/environments> cited for their future encrypted-secret storage.
- [ ] The integration is marked DEFERRED/BLOCKED with the activation trigger set to approved eBay API access.
- [ ] The ticket states it is NOT a dependency of `STORY-03-03-01`, `STORY-03-03-02`, or any other active story; the `ebay-sold-listings` Apify actor remains the primary live source.
- [ ] The activation path (Marketplace Insights as an additive 90-day sold-history source on top of the forward accumulation that runs from day one) and the compliance posture (official APIs only; the Apify actor is the single sanctioned out-of-band scraping exception) are documented.
- [ ] No prohibited vague quality term appears in any acceptance criterion, and every criterion names a measurable pass/fail condition (a named API, a named credential, a status value, or a count).
- [ ] **Testing:** a backlog dependency-graph check confirms `STORY-03-03-03` appears in no active story's dependency list, and a documentation review confirms the named credentials (`EBAY_CLIENT_ID` / `EBAY_CLIENT_SECRET`), the DEFERRED/BLOCKED status, and the activation trigger are present.
