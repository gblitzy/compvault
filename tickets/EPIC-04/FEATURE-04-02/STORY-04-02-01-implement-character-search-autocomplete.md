# STORY-04-02-01: Implement Character Search & Autocomplete

Feature → [FEATURE-04-02 — Search & Detail Endpoints](../FEATURE-04-02-search-and-detail-endpoints.md) · Epic → [EPIC-04 — Backend Application & API](../../EPIC-04-backend-application-and-api.md)

This is the **first** of the four stories in FEATURE-04-02 (Search & Detail Endpoints) and the entry point of the CompVault read path. It specifies the **character search + autocomplete endpoint**: a **GET** handler that accepts a single query parameter named **`q`** (the typed character term) and turns it into either a ranked list of known character-name suggestions (autocomplete mode) or the set of cards featuring a resolved character (resolve mode). The product authority is PRD §4.1 — FR-1 makes search by **character** the primary entry point with **autocomplete on known characters** (for example, typing `Vader`), and FR-3 keeps results **character-centric** (the digital | physical variation grouping is the next story, `STORY-04-02-02`, not this one).

The data model is the catalog skeleton from `docs/schema.sql`: the `character` table (`id` BIGINT identity PK; `name` TEXT NOT NULL **UNIQUE**; `aliases` JSONB NOT NULL DEFAULT `'[]'`, for example `['The Child']` for Grogu), the `card_character` many-to-many join (PRIMARY KEY (`card_id`, `character_id`); `card_id` → `card(id)` ON DELETE CASCADE; `character_id` → `character(id)`), and the `card` table (`id`, `set_id`, `card_number`, `name`, `subject_type`, `source`). Resolve mode runs the canonical character-search join — schema **Example Query 1**: `SELECT c.* FROM card c JOIN card_character cc ON cc.card_id = c.id JOIN character ch ON ch.id = cc.character_id WHERE ch.name ILIKE` the term — and the `idx_cardchar_character` index on `card_character (character_id)` backs that join. Fuzzy/trigram search via `pg_trgm` (the commented-out `CREATE EXTENSION pg_trgm` plus an `idx_character_name_trgm` GIN index) is an **OPTIONAL** future enhancement and is **out of scope** for this story.

Built on the FEATURE-04-01 scaffolding, the handler opens a short-lived Neon connection through the **pooled** `DATABASE_URL` and never the unpooled `DATABASE_URL_UNPOOLED` (which EPIC-02 reserves for DDL and migrations), threads the operator `userId` from the `getUserId()` seam (v1 = the single seeded operator), validates `q` and returns HTTP **400** with an `error` field named `q` on an empty or missing value, reads official data sources only, and issues no LLM call in the request path. The catalog reads (`character`, `card`, `card_character`) are **GLOBAL** shared data: they are scoped by the search term, never filtered by `userId`.

## User Story

> As a **Backend Engineer**, I want a character search + autocomplete endpoint, so that the frontend can resolve a typed character name (for example `Vader`) to the cards featuring that character.

## API Contract

- **Method and path:** `GET /api/characters/search`
- **Query parameters:** `q` (required, the non-empty character term; an empty or missing `q` returns HTTP **400** with the safe error envelope `{ "error": "q" }`), `mode` (optional, one of `autocomplete` or `resolve`, default `autocomplete`), and `limit` (optional, `[1, 100]`, caps the `autocomplete` suggestion count). These parameters and the safe error envelope are governed by the shared validator in [STORY-04-01-03](../FEATURE-04-01/STORY-04-01-03-implement-query-parameter-validation.md). The EPIC-05 search input ([STORY-05-02-01](../../EPIC-05/FEATURE-05-02/STORY-05-02-01-implement-search-input-with-autocomplete.md)) calls this exact path.
- **Autocomplete response** (`mode=autocomplete`, HTTP **200**):

  ```json
  {
    "query": "Va",
    "mode": "autocomplete",
    "suggestions": [
      { "character_id": 12, "name": "Darth Vader", "alias_matched": false },
      { "character_id": 41, "name": "Vaneé", "alias_matched": false }
    ]
  }
  ```

  `suggestions` is ordered by `character.name`; each entry carries `character_id` (BIGINT), `name` (the `character.name`), and `alias_matched` (`true` when the term matched a `character.aliases` entry rather than `character.name`). A `q` of length 1 (below the 2-character minimum) returns `suggestions: []`.
- **Resolve response** (`mode=resolve`, HTTP **200**):

  ```json
  {
    "query": "Darth Vader",
    "mode": "resolve",
    "character": { "character_id": 12, "name": "Darth Vader" },
    "cards": [
      { "card_id": 880, "set_id": 14, "card_number": "A-OD", "name": "Darth Vader" }
    ]
  }
  ```

  `cards` carries every `card` joined through `card_character` to the resolved `character` (schema Example Query 1), each entry carrying `card_id`, `set_id`, `card_number`, and `name`.
- **Empty-state shapes** (HTTP **200**, never HTTP 404): a non-empty `q` that matches no `character.name` and no `character.aliases` entry returns `suggestions: []` in autocomplete mode, and `character: null` with `cards: []` in resolve mode.
- **Error envelope** (HTTP **400**): `{ "error": "q" }` for an empty or missing `q`, returned before any catalog query.

## Acceptance Criteria

1. **(valid-output — autocomplete)** **Given** known characters whose `name` values share a prefix of length **≥ 2 characters** (for example `Va` → `Vader`, `Vaneé`), **When** the operator calls `GET /api/characters/search?q=Va&mode=autocomplete`, **Then** the response is HTTP **200** and the body's `suggestions` array is **ordered by character `name`**, each entry carrying `character_id`, `name`, and `alias_matched`.
2. **(valid-output — resolve)** **Given** a `character.name` that exists (for example `Darth Vader`), **When** the endpoint is called with that exact `q` and `mode=resolve`, **Then** the response is HTTP **200**, the body's `character` carries the resolved `character_id` and `name`, and its `cards` array contains **every `card` joined through `card_character` to that `character`** via the `ch.name ILIKE` join (schema Example Query 1), each entry carrying `card_id`, `set_id`, `card_number`, and `name`.
3. **(input-validation — empty/missing `q`)** **Given** a request whose `q` parameter is empty or missing, **When** the request is processed, **Then** the response is HTTP **400** with an `error` field named `q`, and no catalog query is run.
4. **(error-handling — unknown character)** **Given** a non-empty `q` that matches no `character.name` and no `character.aliases` entry, **When** the request is processed, **Then** the response is HTTP **200** with `suggestions: []` in autocomplete mode and `character: null` with `cards: []` in resolve mode (never HTTP 404).
5. **(edge-case — alias match)** **Given** a term that matches only an entry in `character.aliases` (for example `The Child` for Grogu), **When** the endpoint is called, **Then** the response is HTTP **200** and resolves to the aliased `character` and that character's joined cards.
6. **(edge-case — below the autocomplete minimum)** **Given** a single-character `q` (length 1, below the **2-character** autocomplete minimum), **When** the request is processed, **Then** the response is HTTP **200** with an empty suggestion list and no `error` field.

## Sub-tasks

- [ ] Implement the `GET /api/characters/search` handler with the `q`, `mode` (`autocomplete`/`resolve`, default `autocomplete`), and `limit` parameters, joining `card` → `card_character` → `character` on `ch.name ILIKE` the term in resolve mode (schema Example Query 1, backed by `idx_cardchar_character`), opening a short-lived connection through the pooled `DATABASE_URL` (@backend-engineer)
- [ ] Implement the autocomplete branch that returns the `suggestions` array — each entry carrying `character_id`, `name`, and `alias_matched` — **ordered by `name`** when `q` has length **≥ 2 characters**, and the resolve branch that returns `character` plus the `cards` array (`card_id`, `set_id`, `card_number`, `name`) (@backend-engineer)
- [ ] Validate `q` so an empty or missing value returns HTTP **400** with an `error` field named `q` and runs no catalog query (@backend-engineer)
- [ ] Implement alias resolution that matches a term against the `character.aliases` JSONB array (for example `The Child` → Grogu) and resolves to the aliased character (@backend-engineer)
- [ ] Return an empty suggestion list (HTTP **200**, no `error`) for a `q` of length 1, and an empty result array (HTTP **200**, never 404) for a non-empty term that matches no `name` and no `aliases` entry (@backend-engineer)
- [ ] Thread the operator `userId` from the `getUserId()` seam and keep the catalog reads (`character`, `card`, `card_character`) GLOBAL — scoped by the search term, never filtered by `userId` (@backend-engineer)
- [ ] Author API integration tests against the `dev-qa` Neon branch covering autocomplete (`q=Va`), resolve (exact `name`), empty-`q` HTTP 400, unknown-character empty array, and alias-only resolution (@qa-engineer)
- [ ] Confirm the handler sources data through official APIs only and issues zero LLM calls in the request path (@tech-lead)

## Edge Cases

- **Empty/Null — `q` empty or missing:** the request returns HTTP **400** with an `error` field named `q`, and no catalog query is run.
- **Boundary — single-character `q`:** a `q` of length 1 (below the 2-character autocomplete minimum) returns HTTP **200** with an empty suggestion list and no `error` field; this is a boundary outcome, not an error.
- **Invalid / no match — unknown term:** a non-empty `q` with no matching `character.name` and no matching `character.aliases` entry returns HTTP **200** with an empty result array (never HTTP 404).
- **Alias-only match — `The Child`:** a `q` that matches only an entry in the `character.aliases` JSONB array (for example `The Child` for Grogu) resolves to the aliased `character` and returns that character's joined cards at HTTP **200**.
- **SQL wildcard literal — `%` or `_` in `q`:** a `q` containing the SQL `LIKE` wildcard characters `%` or `_` is bound as a literal value through a parameterized query, never interpolated into SQL text, so the term is matched as literal characters rather than acting as an injection or an unbounded wildcard.

## Dependencies

### Upstream (must be complete first)

- **[FEATURE-04-01 — Backend Foundation & Environment Access](../FEATURE-04-01-backend-foundation-and-environment-access.md):** the API route scaffolding, the provisioned environment access (per <https://docs.blitzy.com/administration/environments>), the `getUserId()` threading, and the query-parameter validation this endpoint reuses.
- **[EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md):** the catalog tables `character`, `card`, and `card_character` plus the `idx_cardchar_character` index, the pooled Neon access layer, the `getUserId()` seam (`STORY-02-03-02`, the seeded operator user), and the catalog seed (`STORY-02-03-03`) that populates `character` / `card` / `card_character` for this endpoint to read.

### Downstream (informational — not a build prerequisite of this story)

- **[EPIC-05 — Frontend User Interface](../../EPIC-05-frontend-user-interface.md):** the search input with autocomplete (`STORY-05-02-01`) consumes this endpoint.
- **[EPIC-06 — Testing & CI/CD Quality Gates](../../EPIC-06-testing-and-cicd-quality-gates.md):** `STORY-06-02-02` integration-tests these API routes against the `dev-qa` Neon branch at an API coverage floor of **≥75%**.

### Parent feature

- **[FEATURE-04-02 — Search & Detail Endpoints](../FEATURE-04-02-search-and-detail-endpoints.md)**

## Story Estimation Guidance

- **Effort: Low-Medium** — one read handler over a two-join path (`card` → `card_character` → `character`) plus the autocomplete branch and the alias-array lookup.
- **Complexity: Low-Medium** — the join is fixed by schema Example Query 1 and backed by `idx_cardchar_character`; matching the `character.aliases` JSONB array adds light complexity; `pg_trgm` fuzzy search is out of this story's scope.
- **Uncertainty: Low** — the data model is fixed by `docs/schema.sql` and the endpoint contract (the `q` parameter, the 2-character autocomplete minimum, the HTTP 200/400 outcomes) is fully specified here.
- **Fibonacci Story Points: 3.** The two-join read plus the alias-array match and the autocomplete branch sit above a 1; the fixed schema, the backing index, and the deferred `pg_trgm` scope hold it below a 5. Points measure relative size, not a duration.

## Definition of Done

- [ ] The endpoint is `GET /api/characters/search` and returns the autocomplete `suggestions` array (`character_id`, `name`, `alias_matched`) ordered by `name` for a `q` of length **≥ 2 characters** in `mode=autocomplete`.
- [ ] In `mode=resolve`, an exact `character.name` (for example `Darth Vader`) returns `character` (`character_id`, `name`) plus a `cards` array (`card_id`, `set_id`, `card_number`, `name`) of every `card` joined through `card_character` to that `character` via the `ch.name ILIKE` join (schema Example Query 1).
- [ ] A term that matches only a `character.aliases` JSONB entry (for example `The Child`) resolves to the aliased `character`.
- [ ] An empty or missing `q` returns HTTP **400** with an `error` field named `q`, and no catalog query is run.
- [ ] A non-empty `q` that matches no `name` and no `aliases` entry returns HTTP **200** with `suggestions: []` in autocomplete mode and `character: null` with `cards: []` in resolve mode, never HTTP 404.
- [ ] A single-character `q` returns HTTP **200** with an empty suggestion list and no `error` field.
- [ ] The handler reads the pooled `DATABASE_URL` (never `DATABASE_URL_UNPOOLED`), threads `userId` from the `getUserId()` seam, keeps the catalog reads GLOBAL (not filtered by `userId`), and issues no LLM call in the request path.
- [ ] No prohibited vague quality term appears in any acceptance-criteria statement; every statement names a measurable pass/fail condition (an HTTP status code, an exact column or error-field name, or the 2-character autocomplete minimum).
- [ ] **Testing:** API integration tests against the `dev-qa` Neon branch pass with a ≥75% coverage target.
