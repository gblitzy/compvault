# STORY-02-03-03: Author the Catalog Seed Script

Feature: [FEATURE-02-03](../FEATURE-02-03-data-access-layer-and-seed-data.md) · Epic: [EPIC-02](../../EPIC-02-database-platform-and-schema.md)

## User Story

> As a Database Engineer, I want an idempotent catalog seed script that loads the baseline card skeleton, so that the application has queryable sets, characters, cards, parallels, variations, and grades before ingestion runs.

## Connection & Environment Note

The seed writes to a Neon branch provisioned per [FEATURE-02-01 — Neon Project & Branching Topology](../FEATURE-02-01-neon-project-and-branching-topology.md) and runs only after the schema and migrations from [FEATURE-02-02 — Drizzle Schema & Migrations](../FEATURE-02-02-drizzle-schema-and-migrations.md) have been applied to that branch. It connects through the pooled `DATABASE_URL` exposed by the pooled Neon client ([STORY-02-03-01](STORY-02-03-01-implement-pooled-neon-client.md)) and never the unpooled `DATABASE_URL_UNPOOLED` (which is reserved for DDL and migrations); the full per-epic environment provisioning is documented in FEATURE-02-01 per <https://docs.blitzy.com/administration/environments> and is not duplicated here.

## Acceptance Criteria

1. **(valid-output)** **Given** an empty database, **When** the seed runs once, **Then** exactly one row exists per seeded natural key across `card_set`, `character`, `card`, `card_character`, `parallel_type`, `variation`, and `grade`, and every `card_character` link resolves to an existing `card` row and an existing `character` row.
2. **(edge-case)** **Given** a database already seeded once, **When** the seed runs a second time, **Then** the row count for every seeded table (`card_set`, `character`, `card`, `card_character`, `parallel_type`, `variation`, `grade`, `app_user`) is unchanged and 0 duplicate rows are inserted.
3. **(input-validation)** **Given** a seed entry missing a required field (for example, a `card` entry without a `set_id`), **When** the seed runs, **Then** it rejects that entry with a named validation error and inserts 0 partial rows for that entry.
4. **(error-handling)** **Given** a foreign-key target that is absent (for example, a `variation` referencing a `parallel_type` that was not seeded), **When** the seed runs, **Then** it fails with a named error and leaves 0 orphan rows.
5. **(valid-output)** **Given** the seed completes, **When** `app_user` is queried, **Then** exactly one operator row exists — the row `getUserId()` returns — keyed on `app_user.email`.
6. **(valid-output)** **Given** the seed completes, **When** the `source` value of each seeded `card_set`, `card`, and `variation` row is inspected, **Then** every physical row carries a `catalog_source` of `topps_odds`, `checklist_db`, or `manual`, and 0 rows carry `listing_derived` (digital SWCT rows are derived by `EPIC-03` ingestion, not seeded here).
7. **(valid-output)** **Given** every seed insert and upsert in the script, **When** the seed write paths are inspected, **Then** each executes through Drizzle ORM or a parameterized statement, 0 paths build SQL by string concatenation, and a static check (or test) over the seed path confirms 0 string-concatenated SQL.

## Sub-tasks

- Author the seed loading `card_set`, `character`, `card`, `card_character`, `parallel_type`, `variation`, and `grade` plus exactly one operator `app_user` row — `@database-engineer`
- Key every insert on its natural unique key — `card_set (name, year)`, `character.name`, `card (set_id, card_number)`, `card_character (card_id, character_id)`, `parallel_type.name`, `variation (card_id, parallel_type_id, format)`, `grade.label`, and `app_user.email` — so a re-run inserts 0 duplicate rows (idempotent upsert) — `@database-engineer`
- Tag physical catalog rows with a `catalog_source` of `topps_odds`, `checklist_db`, or `manual`, and insert 0 `listing_derived` rows (digital is ingestion-derived) — `@database-engineer`
- Reject any entry missing a required field (for example a `card` without a `set_id`) with a named validation error and insert 0 partial rows — `@database-engineer`
- Resolve `card_character` many-to-many links to existing `card` and `character` rows, and fail with a named error on an absent foreign-key target so 0 orphan rows remain — `@backend-engineer`
- Provide the single operator `app_user` row that `getUserId()` returns ([STORY-02-03-02](STORY-02-03-02-implement-getuserid-seam.md)), keyed on `app_user.email` so a re-run does not insert a second operator row — `@backend-engineer`
- Write every seed insert and upsert through Drizzle ORM or parameterized statements, build 0 SQL strings by concatenation, and add a static check (or test) over the seed path that fails on any string-concatenated SQL — `@database-engineer`

## Edge Cases

- **Empty/Null:** an empty seed dataset inserts 0 rows and the script exits 0 — a no-op run is a pass, not a failure.
- **Boundary:** a `card` featuring multiple characters (for example a card listing Darth Vader, Obi-Wan, and a Stormtrooper) produces more than one `card_character` link row for that one `card`, exercising the many-to-many.
- **Invalid:** a duplicate `character.name` in the input collapses to one row — the `character.name` unique key blocks the second insert.
- **Concurrent:** two seed runs executing at the same time insert 0 duplicate rows, because idempotency rests on the natural unique keys and the upsert rather than on run ordering.

## Dependencies

### Upstream (must be complete first)

- **[FEATURE-02-02 — Drizzle Schema & Migrations](../FEATURE-02-02-drizzle-schema-and-migrations.md):** the schema and applied migrations must exist before the seed writes any row; the seed populates the tables this feature's migration creates.
- **[FEATURE-02-01 — Neon Project & Branching Topology](../FEATURE-02-01-neon-project-and-branching-topology.md):** provides the Neon branch and the pooled connection string the seed writes through.
- **[STORY-02-03-01 — Implement the Pooled Neon Client](STORY-02-03-01-implement-pooled-neon-client.md):** the pooled client the seed connects through (the pooled `DATABASE_URL`, never the unpooled `DATABASE_URL_UNPOOLED`).

### Downstream (informational — not a build prerequisite of this story)

- **[STORY-02-03-02 — Implement the getUserId Seam](STORY-02-03-02-implement-getuserid-seam.md):** consumes the single operator `app_user` row this seed inserts; `getUserId()` returns that row's id.
- `EPIC-03` derives the digital (SWCT) catalog and writes sales on top of this physical skeleton; the `listing_derived` rows this seed does not write are created there.
- `EPIC-04` queries the seeded catalog tables through the pooled client from its first request.
- `EPIC-06` `STORY-06-02-02` integration tests run against a seeded Neon branch — cited by identifier.

## Story Estimation Guidance

- **Effort: Medium** — the seed loads 7 skeleton tables plus the operator row, each insert guarded by an idempotent upsert on its natural key, a bounded but multi-table surface.
- **Complexity: Medium** — catalog modeling spans 7 skeleton tables plus the operator `app_user` row, the `card_character` many-to-many, and the `catalog_source` tagging discipline, each keyed on a distinct natural unique key.
- **Uncertainty: Low–Medium** — the table shapes and natural keys are fixed by `docs/schema.sql`, so the target is known; the residual unknown is whether the existing local Neon connection provisioned in [FEATURE-02-01](../FEATURE-02-01-neon-project-and-branching-topology.md) is enough to run the seed and its integration test against a local or test branch.
- **Fibonacci Story Points: 5** — Medium effort and Medium complexity across 7 tables plus the operator row land the estimate at 5; the Low–Medium uncertainty (a fixed canonical schema) holds it below an 8. Points measure relative size, not a duration.

## Definition of Done

- [ ] The seed loads the baseline `card_set`, `character`, `card`, `card_character`, `parallel_type`, `variation`, and `grade` rows plus exactly one operator `app_user` row.
- [ ] Every insert is keyed on its natural unique key (`card_set (name, year)`, `character.name`, `card (set_id, card_number)`, `card_character (card_id, character_id)`, `parallel_type.name`, `variation (card_id, parallel_type_id, format)`, `grade.label`, `app_user.email`) so a second run inserts 0 duplicate rows (idempotent).
- [ ] Physical rows carry a `catalog_source` of `topps_odds`, `checklist_db`, or `manual`, and 0 `listing_derived` rows are inserted (digital SWCT is derived by `EPIC-03` ingestion, not seeded here).
- [ ] A seed entry missing a required field (for example a `card` without a `set_id`) is rejected with a named validation error and inserts 0 partial rows.
- [ ] An absent foreign-key target (for example a `variation` referencing an unseeded `parallel_type`) fails with a named error and leaves 0 orphan rows.
- [ ] Every `card_character` link resolves to an existing `card` row and an existing `character` row.
- [ ] The seed inserts 0 rows into `sale_observation`, `raw_listing`, `extraction`, and `valuation` — sales ingestion and the digital catalog are `EPIC-03`'s responsibility, not this seed's.
- [ ] Every seed insert and upsert executes through Drizzle ORM or parameterized statements, with 0 string-concatenated SQL, and a static check (or test) over the seed path confirms 0 string-concatenated SQL.
- [ ] No prohibited vague quality term appears in any acceptance criterion; every criterion names a measurable pass/fail condition (an exact count, a named error, or a named table).
- [ ] All relative links resolve: the parent feature index, the parent epic index, the `FEATURE-02-01` and `FEATURE-02-02` indexes, and the sibling stories `STORY-02-03-01` and `STORY-02-03-02`.
- [ ] **Testing:** an integration test on a Neon branch runs the seed twice and asserts that every seeded table's row count is identical after the second run (idempotent) and that all referential links (`card_character`, and `variation` → `card` / `parallel_type`) resolve.
