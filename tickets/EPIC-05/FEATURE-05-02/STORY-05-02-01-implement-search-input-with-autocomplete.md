# STORY-05-02-01: Implement Search Input with Autocomplete

*Parent feature: [FEATURE-05-02 — Search & Results Experience](../FEATURE-05-02-search-and-results-experience.md) · Parent epic: [EPIC-05 — Frontend User Interface](../../EPIC-05-frontend-user-interface.md)*

This is the **first of the three** stories in FEATURE-05-02 (Search & Results Experience) and the primary search entry point of EPIC-05. It describes the character-first search input with autocomplete that renders in the application-shell header: as a collector types character text, the input calls the EPIC-04 character-search endpoint and renders matching suggestions sourced from `character.name` and `character.aliases` (for example, typing `Vad` surfaces `Darth Vader`); choosing a suggestion navigates to the two-column results view. It builds on the application shell ([STORY-05-01-02](../FEATURE-05-01/STORY-05-01-02-implement-application-shell.md)) and **consumes — but does not implement —** the EPIC-04 endpoint, and it queries no database directly. The input introduces no component library or design system and is described with concrete, measurable states, per PRD §4.1 (FR-1), §8, and §8.5.

## User Story

**As a** Collector (end user), **I want** a character-first search input with autocomplete, **so that** I can find a character (for example Vader or Grogu) without typing the exact full name.

## Environment Access

Environment access and preview deployment for this view are configured once in [FEATURE-05-01 — Frontend Foundation & Environment Access](../FEATURE-05-01-frontend-foundation-and-environment-access.md) per the canonical Blitzy environments reference <https://docs.blitzy.com/administration/environments>; this search input additionally depends on the EPIC-04 character-search + autocomplete endpoint to return suggestions. The full environment-configuration procedure is not duplicated here.

## Acceptance Criteria

1. **(input-validation — 2-character threshold)** Given the search input is focused, When the entered query holds fewer than 2 non-whitespace characters, Then no autocomplete request is sent to the EPIC-04 character-search endpoint; When the 2nd non-whitespace character is entered, Then exactly one autocomplete request is sent for the current query value.
2. **(input-validation — empty or whitespace-only input)** Given the search input holds an empty string or only whitespace characters, When the input value changes, Then no autocomplete request is sent and any open suggestion list is dismissed from view.
3. **(valid-output — name match)** Given the catalog contains a character whose `character.name` is "Darth Vader", When the query "Vad" is entered, Then the suggestion list renders a "Darth Vader" entry sourced from `character.name`.
4. **(valid-output — alias match)** Given a character "Grogu" carries the alias "The Child" in its `character.aliases` array, When the query "The Ch" is entered, Then the suggestion list renders the "Grogu" entry matched on its alias.
5. **(valid-output — selection navigates)** Given a suggestion list is rendered, When a suggestion is chosen by pointer click or by keyboard (arrow keys move the highlighted entry and Enter selects it), Then the application navigates to the two-column results view for the selected character.
6. **(error-handling — endpoint error)** Given the character-search endpoint returns an HTTP status code of 500 or higher, When the autocomplete request fails, Then a labeled "search unavailable" error state renders, the previously rendered suggestions are cleared, and the search input stays focusable and editable.
7. **(edge-case — no matches)** Given a query of 2 or more non-whitespace characters that matches no `character.name` value and no entry in any `character.aliases` array, When the endpoint returns an empty result set, Then a "no matches" state renders in place of an empty dropdown.
8. **(edge-case — out-of-order/stale responses)** Given two autocomplete requests for different query values are in flight, When the response for the earlier query arrives after the response for the later query, Then the earlier (stale) response is discarded and only the suggestions for the most recently entered query are displayed.

## Sub-tasks

- [ ] Build the character-first search input in the application-shell header (@frontend-engineer)
- [ ] Debounce the input so an autocomplete request is issued only at or beyond the 2-non-whitespace-character threshold (@frontend-engineer)
- [ ] Call the EPIC-04 character-search + autocomplete endpoint and map its response to suggestion entries (@frontend-engineer)
- [ ] Render the suggestion list with pointer selection and keyboard selection (arrow keys move the highlight, Enter selects) (@frontend-engineer)
- [ ] Handle the empty/whitespace, "no matches", "search unavailable" error, and stale-response states (@frontend-engineer)

## Edge Cases

- **Empty/Null — empty or whitespace query:** the input holds an empty string or only whitespace; no autocomplete request is sent and the suggestion list is dismissed.
- **Boundary — 1-character query:** a query of exactly 1 non-whitespace character is below the 2-character threshold and sends no autocomplete request.
- **Invalid/empty — no matches:** a query of 2 or more non-whitespace characters that matches no `character.name` and no `character.aliases` entry renders a "no matches" state rather than an empty dropdown.
- **Error — endpoint failure:** the character-search endpoint returns an HTTP status code of 500 or higher; a labeled "search unavailable" state renders and the search input stays focusable and editable.
- **Concurrent — out-of-order responses:** rapid typing produces overlapping in-flight requests; a stale response that arrives after a newer one is discarded, and only the most recent query's suggestions are displayed.

## Dependencies

### Upstream (must be complete first)

- **[STORY-05-01-02 — Implement Application Shell](../FEATURE-05-01/STORY-05-01-02-implement-application-shell.md):** the application-shell header that hosts this search input.
- **[STORY-04-02-01 — Implement Character Search Autocomplete](../../EPIC-04/FEATURE-04-02/STORY-04-02-01-implement-character-search-autocomplete.md):** the EPIC-04 character-search + autocomplete endpoint this input consumes; epic context — **[EPIC-04 — Backend Application & API](../../EPIC-04-backend-application-and-api.md)**.
- **[EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md):** the data model behind suggestions — `character.name`, `character.aliases`, and the `card_character` link.

### Downstream (informational — not a build prerequisite of this story)

- **[STORY-05-02-02 — Implement Two-Column Results View](STORY-05-02-02-implement-two-column-results-view.md):** the view a chosen suggestion navigates to; this search input drives it.

### Parent feature

- **[FEATURE-05-02 — Search & Results Experience](../FEATURE-05-02-search-and-results-experience.md)**

## Story Estimation Guidance

- **Effort: moderate** — a debounced input, an endpoint call, a keyboard-navigable suggestion list, and four non-happy-path states.
- **Complexity: moderate** — the 2-character threshold, alias matching, keyboard selection, and discarding out-of-order (stale) responses.
- **Uncertainty: low-to-moderate** — the autocomplete behavior is fixed by PRD §4.1 (FR-1) and the `character.name`/`character.aliases` model; the exact endpoint response shape is owned by EPIC-04.
- **Fibonacci Story Points: 3.**

## Definition of Done

- [ ] A character-first search input renders in the application-shell header.
- [ ] An autocomplete request fires only at or beyond the 2-non-whitespace-character threshold; an empty or whitespace-only input sends no request.
- [ ] Suggestions render from `character.name` and `character.aliases`; choosing one by pointer or keyboard navigates to the two-column results view.
- [ ] An endpoint error (HTTP status code 500 or higher) renders a labeled "search unavailable" state while the input stays focusable and editable; a query that matches no name and no alias renders a "no matches" state.
- [ ] An out-of-order (stale) response is discarded so that only the most recent query's suggestions are displayed.
- [ ] No component library or design system is introduced; the input, suggestion list, and keyboard interaction are described and built with concrete, measurable states.
- [ ] No prohibited vague quality term appears in any acceptance-criteria statement; every such statement names a measurable pass/fail condition.
- [ ] **Testing:** UI tests pass for the 2-character threshold, the suggestion render (name match and alias match), the "no matches" state, the "search unavailable" error state, and stale-response discarding; the UI coverage target is **≥50%** where code applies.
