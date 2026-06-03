# STORY-02-02-01: Author the Drizzle Schema

*Parent feature: [FEATURE-02-02 — Drizzle Schema & Migrations](../FEATURE-02-02-drizzle-schema-and-migrations.md) · Parent epic: [EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md)*

This is the first and foundational story of FEATURE-02-02. It authors the Drizzle ORM schema (`db/schema.ts`) as a one-to-one mirror of the canonical `docs/schema.sql`, reproducing every enum, table, column, default, and constraint with matching names. This typed schema is the single foundation from which `STORY-02-02-02` generates the initial migration and `STORY-02-02-03` rehearses it on a Neon branch. The guiding rule is **mirror, never contradict**: `docs/schema.sql` is the single source of truth, and any divergence in `db/schema.ts` is a defect surfaced by the generated-SQL diff described below.

## User Story

> As a Database Engineer, I want a Drizzle schema (db/schema.ts) that mirrors docs/schema.sql exactly, so that the application has a typed, version-controlled model matching the canonical database.

## Schema Scope

`db/schema.ts` reproduces **all 9 enums** and **all 20 tables** of `docs/schema.sql` with matching names, value lists, columns, defaults, and constraints. The schema is named and described here; this is a documentation story and it does **not** paste the TypeScript schema body or any SQL body.

**The 9 enums (exact names and value lists):**

- `format_t` = `('physical','digital')`
- `format_availability` = `('physical','digital','both')`
- `catalog_source` = `('topps_odds','checklist_db','listing_derived','manual')`
- `match_status` = `('pending','auto','reviewed','rejected')`
- `listing_status` = `('active','ended_unsold','sold','unknown')`
- `image_status_t` = `('live','gone','unknown')`
- `review_kind` = `('extraction','match','new_cluster','merge_candidate')`
- `review_state` = `('open','resolved','dismissed')`
- `plan_t` = `('free','pro')`

**The 20 tables (exact names):** `card_set`, `character`, `card`, `card_character`, `parallel_type`, `variation`, `grade`, `raw_listing`, `extraction`, `sale_observation`, `ingestion_query`, `ingestion_run`, `counterpart_override`, `review_queue`, `app_user`, `watchlist`, `collection_item`, `saved_search`, `subscription`, `valuation`.

**Unique constraints and the CHECK that gate downstream epics (preserved, never dropped or renamed):**

- `raw_listing` **`UNIQUE (source, source_item_id)`** — the idempotent upsert key consumed by `EPIC-03` ingestion.
- `valuation` **`UNIQUE NULLS NOT DISTINCT (variation_id, grade_id, window_days, cost_basis)`** — keeps digital rows (`grade_id` NULL) unique and backs the price-history endpoint queried by `EPIC-04`.
- Other natural keys: `card_set UNIQUE (name, year)`; `character.name UNIQUE`; `card UNIQUE (set_id, card_number)`; `card_character` primary key `(card_id, character_id)`; `parallel_type.name UNIQUE`; `variation UNIQUE (card_id, parallel_type_id, format)`; `grade.label UNIQUE`; `subscription UNIQUE (user_id)`; `app_user.email UNIQUE`.
- `counterpart_override.link_level` carries `CHECK (link_level IN ('card','variation'))`.

**Type conventions reproduced from the canonical SQL:**

- Identity primary keys are `BIGINT GENERATED ALWAYS AS IDENTITY` **except** `grade.id`, which is `SMALLINT GENERATED ALWAYS AS IDENTITY`. `SMALLINT` is also used for `valuation.grade_id`, `valuation.window_days`, `sale_observation.grade_id`, and `collection_item.grade_id`.
- Timestamps are `TIMESTAMPTZ NOT NULL DEFAULT now()`; monetary columns are `NUMERIC(12,2)`; `grade.grade_value` is `NUMERIC(3,1)`.
- `card.card_number` is `TEXT` so it stores values such as `'A-OD'` and `'LAY-1'`.
- `owner_user_id` on `watchlist`, `collection_item`, and `saved_search` is **nullable** (NULL in v1 denotes the single operator), which informs the `getUserId()` seam delivered in `FEATURE-02-03`. It is modeled as nullable, not `NOT NULL`.
- JSONB columns are reproduced on `character.aliases` (DEFAULT `'[]'`), `raw_listing.item_aspects`, `raw_listing.additional_image_urls`, `extraction.quality_flags`, `review_queue.payload`, `ingestion_query.aspect_filter`, and `saved_search.params`.

**Hot-path indexes represented in the Drizzle schema (11 total):** `idx_card_set` on `card(set_id)`; `idx_cardchar_character` on `card_character(character_id)`; `idx_variation_card_par` on `variation(card_id, parallel_type_id)`; `idx_sale_variation_date` on `sale_observation(variation_id, sale_date)`; `idx_sale_card_date` on `sale_observation(card_id, sale_date)`; `idx_sale_format_date` on `sale_observation(format, sale_date)`; `idx_rawlisting_status` on `raw_listing(status)`; `idx_collection_owner` on `collection_item(owner_user_id)`; `idx_ingestion_query_on` on `ingestion_query(enabled)`; `idx_sale_comps` on `sale_observation(variation_id, sale_date)` as a **partial** index `WHERE NOT excluded_from_comps`; and `idx_valuation_variation` on `valuation(variation_id, grade_id)`.

**Engine floor.** The schema targets a **PostgreSQL 15+** Neon database provisioned per [FEATURE-02-01 — Neon Project & Branching Topology](../FEATURE-02-01-neon-project-and-branching-topology.md); PostgreSQL 15 is the floor because `valuation`'s `UNIQUE NULLS NOT DISTINCT` is rejected by any Postgres server below version 15.

## Acceptance Criteria

1. **(valid-output)** **Given** `docs/schema.sql`, **When** `db/schema.ts` is authored, **Then** it declares all 9 enums with identical value lists and all 20 tables.
2. **(valid-output)** **Given** the `raw_listing` table, **When** the schema is generated to SQL, **Then** it contains `UNIQUE (source, source_item_id)`.
3. **(valid-output)** **Given** the `valuation` table, **When** the schema is generated to SQL, **Then** it contains `UNIQUE NULLS NOT DISTINCT (variation_id, grade_id, window_days, cost_basis)`.
4. **(error-handling)** **Given** a generated-SQL diff of `db/schema.ts` against `docs/schema.sql`, **When** the two are compared, **Then** zero enums and zero tables are missing or renamed.
5. **(input-validation)** **Given** the 9 enum declarations, **When** each value list is checked against `docs/schema.sql`, **Then** every value matches character-for-character and the per-enum value counts (2, 3, 4, 4, 4, 3, 4, 3, 2 — 29 values total) are identical, and any added, removed, or misspelled value fails the check.
6. **(edge-case)** **Given** the schema, **When** it is inspected, **Then** `owner_user_id` on `watchlist`, `collection_item`, and `saved_search` is modeled as nullable, and the `counterpart_override` `CHECK (link_level IN ('card','variation'))` is present.
7. **(valid-output)** **Given** `grade.id`, `valuation.grade_id`, `valuation.window_days`, `sale_observation.grade_id`, and `collection_item.grade_id`, **When** the schema is generated, **Then** each is `SMALLINT` and not `BIGINT`, and `card.card_number` is `TEXT` (it stores values such as `'A-OD'` and `'LAY-1'`).

## Sub-tasks

- Declare all 9 enums (`format_t`, `format_availability`, `catalog_source`, `match_status`, `listing_status`, `image_status_t`, `review_kind`, `review_state`, `plan_t`) with value lists identical to `docs/schema.sql` — `@database-engineer`
- Declare all 20 tables (`card_set`, `character`, `card`, `card_character`, `parallel_type`, `variation`, `grade`, `raw_listing`, `extraction`, `sale_observation`, `ingestion_query`, `ingestion_run`, `counterpart_override`, `review_queue`, `app_user`, `watchlist`, `collection_item`, `saved_search`, `subscription`, `valuation`) with matching columns, defaults, and identity/timestamp/money types — `@database-engineer`
- Preserve `raw_listing UNIQUE (source, source_item_id)`, `valuation UNIQUE NULLS NOT DISTINCT (variation_id, grade_id, window_days, cost_basis)`, every other natural key, and the `counterpart_override CHECK (link_level IN ('card','variation'))` — `@database-engineer`
- Model `grade.id` as the only `SMALLINT GENERATED ALWAYS AS IDENTITY` primary key, model `valuation.grade_id`, `valuation.window_days`, `sale_observation.grade_id`, and `collection_item.grade_id` as ordinary `SMALLINT` non-identity columns (foreign-key or value columns, not identity), and model the nullable `owner_user_id` columns (`watchlist`, `collection_item`, `saved_search`) — `@database-engineer`
- Map the 7 JSONB columns (`character.aliases` default `'[]'`, `raw_listing.item_aspects`, `raw_listing.additional_image_urls`, `extraction.quality_flags`, `review_queue.payload`, `ingestion_query.aspect_filter`, `saved_search.params`) — `@database-engineer`
- Represent the 11 hot-path indexes, including the partial `idx_sale_comps ... WHERE NOT excluded_from_comps` and `idx_valuation_variation` on `valuation(variation_id, grade_id)` — `@database-engineer`
- Run a generated-SQL diff of `db/schema.ts` against `docs/schema.sql` and resolve every difference to zero missing or renamed enums and tables — `@database-engineer`

## Edge Cases

- **Boundary:** a `valuation` digital row with `grade_id` NULL stays unique under `NULLS NOT DISTINCT` — a second NULL-grade row for the same `(variation_id, window_days, cost_basis)` is rejected.
- **Invalid:** an enum value typo (for example, a misspelled `catalog_source` member such as `topps_odd` instead of `topps_odds`) is caught by the schema-diff check and fails it.
- **Empty/Null:** nullable columns such as `owner_user_id` on `watchlist`, `collection_item`, and `saved_search` are modeled as nullable, not `NOT NULL`, so a NULL owner is accepted in v1.
- **Boundary:** `TEXT` `card_number` stores non-numeric values such as `'A-OD'` and `'LAY-1'`; it is not an integer column and does not reject these values.

## Dependencies

### Upstream (must be complete first)

- **[FEATURE-02-01 — Neon Project & Branching Topology](../FEATURE-02-01-neon-project-and-branching-topology.md):** a provisioned **PostgreSQL 15+** Neon project, required because `valuation`'s `UNIQUE NULLS NOT DISTINCT` is rejected on any Postgres server below version 15.

### Downstream (informational — not a build prerequisite of this story)

- **[STORY-02-02-02 — Configure drizzle-kit & the Initial Migration](STORY-02-02-02-configure-drizzle-kit-and-initial-migration.md):** generates the initial migration **from** this schema.
- **[STORY-02-02-03 — Create the Migration Rehearsal Workflow](STORY-02-02-03-create-migration-rehearsal-workflow.md):** rehearses that migration on a Neon branch.
- `FEATURE-02-03` seeds the tables this schema defines; `EPIC-03` writes to `raw_listing`, `extraction`, `sale_observation`, `ingestion_run`, and `review_queue`; `EPIC-04` queries the catalog tables, the `sale_observation` time series, and the `valuation` cache. These are cited by identifier.

## Story Estimation Guidance

- **Effort: High** — the schema reproduces 9 enums and 20 tables with every column, default, unique constraint, CHECK, and index, so the surface area is large even though each element is mechanical.
- **Complexity: High** — 20 tables plus 9 enums plus the unique/`NULLS NOT DISTINCT`/CHECK constraints plus 11 indexes plus the `SMALLINT`/`TEXT`/`NUMERIC`/JSONB type discipline must each map onto the Drizzle equivalent without drift.
- **Uncertainty: Low** — the canonical SQL already exists in `docs/schema.sql`, so the target is fixed and the work mirrors a known source rather than designing new structure.
- **Fibonacci Story Points: 8** — the High effort and High complexity push the estimate to 8; the Low uncertainty (a fixed canonical source) holds it below a 13. Points measure relative size, not a duration.

## Definition of Done

- [ ] `db/schema.ts` declares all 9 enums (`format_t`, `format_availability`, `catalog_source`, `match_status`, `listing_status`, `image_status_t`, `review_kind`, `review_state`, `plan_t`) with value lists identical to `docs/schema.sql`.
- [ ] `db/schema.ts` declares all 20 tables (`card_set`, `character`, `card`, `card_character`, `parallel_type`, `variation`, `grade`, `raw_listing`, `extraction`, `sale_observation`, `ingestion_query`, `ingestion_run`, `counterpart_override`, `review_queue`, `app_user`, `watchlist`, `collection_item`, `saved_search`, `subscription`, `valuation`) with matching columns, defaults, and constraints, and never contradicts the canonical SQL.
- [ ] `raw_listing UNIQUE (source, source_item_id)` and `valuation UNIQUE NULLS NOT DISTINCT (variation_id, grade_id, window_days, cost_basis)` are preserved.
- [ ] Every other natural key is preserved (`card_set UNIQUE (name, year)`, `character.name UNIQUE`, `card UNIQUE (set_id, card_number)`, `card_character` PK `(card_id, character_id)`, `parallel_type.name UNIQUE`, `variation UNIQUE (card_id, parallel_type_id, format)`, `grade.label UNIQUE`, `subscription UNIQUE (user_id)`, `app_user.email UNIQUE`), and `counterpart_override CHECK (link_level IN ('card','variation'))` is present.
- [ ] The identity/timestamp/money conventions match, including the `SMALLINT` exceptions for `grade.id`, `valuation.grade_id`, and `valuation.window_days`, and `card.card_number` is `TEXT`.
- [ ] `owner_user_id` on `watchlist`, `collection_item`, and `saved_search` is modeled as nullable.
- [ ] The 11 hot-path indexes are represented, including the partial `idx_sale_comps` (`WHERE NOT excluded_from_comps`) and `idx_valuation_variation`.
- [ ] PostgreSQL 15+ is documented as the engine floor (required by `valuation`'s `UNIQUE NULLS NOT DISTINCT`).
- [ ] No prohibited vague quality term appears in any acceptance criterion; every criterion names a measurable pass/fail condition (an exact count, an exact constraint, an exact column list, or "zero missing or renamed").
- [ ] All relative links resolve: the parent feature index, the parent epic index, the `FEATURE-02-01` index, and the sibling stories `STORY-02-02-02` and `STORY-02-02-03`.
- [ ] **Testing:** a generated-SQL diff of `db/schema.ts` against `docs/schema.sql` reports zero missing or renamed enums or tables, and the `raw_listing` and `valuation` unique constraints are present.
