# STORY-05-02-01: Implement Search Input with Autocomplete

*Parent feature: [FEATURE-05-02 — Search & Results Experience](../FEATURE-05-02-search-and-results-experience.md) · Parent epic: [EPIC-05 — Frontend User Interface](../../EPIC-05-frontend-user-interface.md)*

This is the **first of the three** stories in FEATURE-05-02 (Search & Results Experience) and the primary search entry point of EPIC-05. It describes the character-first search input with autocomplete that renders in the application-shell header: as a collector types character text, the input calls the EPIC-04 character-search endpoint and renders matching suggestions sourced from `character.name` and `character.aliases` (for example, typing `Vad` surfaces `Darth Vader`); choosing a suggestion navigates to the two-column results view. It builds on the application shell ([STORY-05-01-02](../FEATURE-05-01/STORY-05-01-02-implement-application-shell.md)) and **consumes — but does not implement —** the EPIC-04 endpoint, and it queries no database directly. The input introduces no component library or design system and is described with concrete, measurable states, per PRD §4.1 (FR-1), §8, and §8.5.

## User Story

**As a** Collector (end user), **I want** a character-first search input with autocomplete, **so that** I can find a character (for example Vader or Grogu) without typing the exact full name.

## Environment Access

Environment access and preview deployment for this view are configured once in [FEATURE-05-01 — Frontend Foundation & Environment Access](../FEATURE-05-01-frontend-foundation-and-environment-access.md) per the canonical Blitzy environments reference <https://docs.blitzy.com/administration/environments>; this search input additionally depends on the EPIC-04 character-search + autocomplete endpoint to return suggestions. The full environment-configuration procedure is not duplicated here.

## Acceptance Criteria

1. **(input-validation — 2-character threshold, debounce, and empty input)** Given the search input is focused, When the entered query holds fewer than 2 non-whitespace characters (including an empty string or a whitespace-only value), Then no autocomplete request is sent to the EPIC-04 character-search endpoint and any open suggestion list is dismissed from view; When the query holds 2 or more non-whitespace characters and 250 milliseconds elapse with no further keystroke, Then exactly one autocomplete request is sent for the current query value, and successive keystrokes inside any 250-millisecond window collapse into a single request.
2. **(valid-output — name and alias match)** Given the catalog contains a character whose `character.name` is "Darth Vader" and a character "Grogu" that carries the alias "The Child" in its `character.aliases` array, When the query "Vad" is entered, Then the suggestion list renders a "Darth Vader" entry sourced from `character.name`; AND When the query "The Ch" is entered, Then the suggestion list renders the "Grogu" entry matched on its alias.
3. **(valid-output — selection navigates)** Given a suggestion list is rendered, When a suggestion is chosen by pointer click or by keyboard (arrow keys move the highlighted entry and Enter selects it), Then the application navigates to the two-column results view for the selected character.
4. **(accessibility — combobox/listbox semantics)** Given the search input renders, When the suggestion list is closed, Then the input exposes `role="combobox"` with `aria-expanded="false"` and is reachable by Tab in DOM order with a visible focus indicator at a contrast ratio of at least 3:1; When the suggestion list opens, Then `aria-expanded` becomes `"true"`, the list exposes `role="listbox"`, each suggestion exposes `role="option"`, the highlighted option is referenced by `aria-activedescendant`, and the "no matches" and "search unavailable" states are announced through an `aria-live="polite"` region.
5. **(ui-state — in-flight/loading)** Given a query at or beyond the 2-non-whitespace-character threshold has triggered an autocomplete request after the 250-millisecond debounce, When the request is in flight, Then a labeled loading indicator renders in the suggestion region while the input keeps focus and stays editable; When the most recent request resolves or fails, Then the loading indicator is removed in the same render that shows the suggestions, the "no matches" state, or the "search unavailable" state.
6. **(error-handling — endpoint error)** Given the character-search endpoint returns an HTTP status code of 500 or higher, When the autocomplete request fails, Then a labeled "search unavailable" error state renders, the previously rendered suggestions are cleared, and the search input stays focusable and editable.
7. **(edge-case — no matches)** Given a query of 2 or more non-whitespace characters that matches no `character.name` value and no entry in any `character.aliases` array, When the endpoint returns an empty result set, Then a "no matches" state renders in place of an empty dropdown.
8. **(edge-case — out-of-order/stale responses)** Given two autocomplete requests for different query values are in flight, When the response for the earlier query arrives after the response for the later query, Then the earlier (stale) response is discarded and only the suggestions for the most recently entered query are displayed.

## Sub-tasks

- [ ] Build the character-first search input in the application-shell header (@frontend-engineer)
- [ ] Debounce the input by 250 milliseconds so an autocomplete request is issued only at or beyond the 2-non-whitespace-character threshold and successive keystrokes inside a 250-millisecond window collapse into one request (@frontend-engineer)
- [ ] Call the EPIC-04 character-search + autocomplete endpoint and map its response to suggestion entries (@frontend-engineer)
- [ ] Render the suggestion list with pointer selection and keyboard selection (arrow keys move the highlight, Enter selects) (@frontend-engineer)
- [ ] Apply combobox/listbox ARIA semantics — `role="combobox"`/`aria-expanded` on the input, `role="listbox"`/`role="option"` on the list, `aria-activedescendant` on the highlighted option, a visible focus indicator, and an `aria-live="polite"` region for the "no matches" and "search unavailable" announcements (@frontend-engineer)
- [ ] Render a labeled in-flight loading indicator after the debounce and remove it when the most recent request resolves or fails, keeping the input focused (@frontend-engineer)
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
- [ ] An autocomplete request fires only at or beyond the 2-non-whitespace-character threshold and only after a 250-millisecond debounce; an empty or whitespace-only input sends no request.
- [ ] Suggestions render from `character.name` and `character.aliases`; choosing one by pointer or keyboard navigates to the two-column results view.
- [ ] The input exposes combobox semantics with `aria-expanded`, the suggestion list exposes `listbox`/`option` roles with `aria-activedescendant` on the highlight, a visible keyboard focus indicator at a contrast ratio of at least 3:1 is shown, and the "no matches" and "search unavailable" states are announced through an `aria-live="polite"` region.
- [ ] A labeled in-flight loading indicator renders after the 250-millisecond debounce and is removed when the most recent request resolves or fails, with the input keeping focus throughout.
- [ ] An endpoint error (HTTP status code 500 or higher) renders a labeled "search unavailable" state while the input stays focusable and editable; a query that matches no name and no alias renders a "no matches" state.
- [ ] An out-of-order (stale) response is discarded so that only the most recent query's suggestions are displayed.
- [ ] No component library or design system is introduced; the input, suggestion list, and keyboard interaction are described and built with concrete, measurable states.
- [ ] No prohibited vague quality term appears in any acceptance-criteria statement; every such statement names a measurable pass/fail condition.
- [ ] **Testing:** UI tests pass for the 250-millisecond debounce and 2-character threshold, the suggestion render (name match and alias match), the combobox/listbox ARIA semantics and keyboard focus, the in-flight loading state, the "no matches" state, the "search unavailable" error state, and stale-response discarding; the UI coverage target is **≥50%** where code applies.
