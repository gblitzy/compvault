# FEATURE-02-02: Drizzle Schema & Migrations

*Parent epic: [EPIC-02 — Database Platform & Schema](../EPIC-02-database-platform-and-schema.md)*

## Feature Summary

This feature delivers the typed Drizzle ORM schema and the migration pipeline for CompVault: it authors `db/schema.ts` as a one-to-one mirror of the canonical `docs/schema.sql`, configures `drizzle-kit` to generate the initial migration from that schema, and creates a `migrate.yml` workflow that rehearses migrations on a Neon branch before merge. The business value is a version-controlled, type-checked, machine-verifiable database schema whose every enum, table, and constraint matches the single source of truth, so downstream ingestion, API, and test work builds on a schema that cannot silently drift from `docs/schema.sql`. Scope is limited to authoring `db/schema.ts`, configuring `drizzle-kit` plus the initial migration, and creating the `migrate.yml` rehearsal workflow; it does **not** provision Neon or its branches ([FEATURE-02-01](FEATURE-02-01-neon-project-and-branching-topology.md)), implement the runtime client or seed data ([FEATURE-02-03](FEATURE-02-03-data-access-layer-and-seed-data.md)), or write application logic (EPIC-03/EPIC-04).

## Environment Access & Configuration

The full platform access for this epic — Blitzy encrypted secrets, the Neon project and branches, and both connection strings — is provisioned in [FEATURE-02-01 — Neon Project & Branching Topology](FEATURE-02-01-neon-project-and-branching-topology.md) and documented per the canonical Blitzy environments reference: <https://docs.blitzy.com/administration/environments>. This feature consumes that access and does not duplicate the full configuration steps; the access this feature depends on is summarized below.

- **Unpooled connection for migrations and DDL.** `drizzle-kit` and the `migrate.yml` workflow run every migration and every DDL statement against the **unpooled** `DATABASE_URL_UNPOOLED` connection. The pooled `DATABASE_URL` is reserved for application runtime reads only. **Mixing the two breaks migrations:** DDL and migrations must never run on the pooled `DATABASE_URL`, and runtime reads must never run on the unpooled `DATABASE_URL_UNPOOLED`.
- **PostgreSQL 15+ is required.** The `valuation` table relies on `UNIQUE NULLS NOT DISTINCT (variation_id, grade_id, window_days, cost_basis)` — a constraint introduced in PostgreSQL 15 that keeps digital rows (where `grade_id` is NULL) unique — so the migration target MUST run PostgreSQL 15 or newer.
- **Rehearsal on a Neon branch.** The `migrate.yml` workflow applies the generated migration against a Neon branch (the per-PR / per-CI branch provisioned in FEATURE-02-01) on the unpooled `DATABASE_URL_UNPOOLED` before merge. It is triggered by pull request and by manual dispatch; it carries no cron schedule.

## User Stories Index

This feature is delivered through three stories. Each link is relative to this file and resolves inside the `FEATURE-02-02/` subfolder.

1. **[STORY-02-02-01 — Author the Drizzle Schema](FEATURE-02-02/STORY-02-02-01-author-drizzle-schema.md)** — author `db/schema.ts` mirroring all 9 enums and all 20 tables of `docs/schema.sql`, preserving `raw_listing UNIQUE (source, source_item_id)`, `valuation UNIQUE NULLS NOT DISTINCT (variation_id, grade_id, window_days, cost_basis)`, every other natural key, and the hot-path indexes; the schema never contradicts `docs/schema.sql`.
2. **[STORY-02-02-02 — Configure drizzle-kit & the Initial Migration](FEATURE-02-02/STORY-02-02-02-configure-drizzle-kit-and-initial-migration.md)** — configure `drizzle-kit` against the unpooled `DATABASE_URL_UNPOOLED` and generate the initial migration from `db/schema.ts`.
3. **[STORY-02-02-03 — Create the Migration Rehearsal Workflow](FEATURE-02-02/STORY-02-02-03-create-migration-rehearsal-workflow.md)** — create a `migrate.yml` workflow that applies the migration on a Neon branch using the unpooled `DATABASE_URL_UNPOOLED`, required green by EPIC-06 branch protection (`STORY-06-03-03`).

## Dependencies

### Upstream (must be complete first)

- **EPIC-01 — Environment & Configuration Foundation:** the secrets baseline holds the unpooled `DATABASE_URL_UNPOOLED` that `drizzle-kit` and `migrate.yml` read.
- **[FEATURE-02-01 — Neon Project & Branching Topology](FEATURE-02-01-neon-project-and-branching-topology.md):** provisions the Neon project on PostgreSQL **15+**, the branches the rehearsal runs against, and the unpooled connection string that DDL and migrations require.

### Downstream (informational — not a build prerequisite of this feature)

- **[FEATURE-02-03 — Data Access Layer & Seed Data](FEATURE-02-03-data-access-layer-and-seed-data.md):** seeds the tables this schema defines and implements the runtime client over the pooled `DATABASE_URL`.
- **EPIC-03 — Data Ingestion Pipeline:** writes to `raw_listing`, `extraction`, `sale_observation`, `ingestion_run`, and `review_queue` defined by this schema; the idempotent ingestion upsert depends on `raw_listing UNIQUE (source, source_item_id)`.
- **EPIC-04 — Backend Application & API:** queries the catalog tables, the `sale_observation` time series, and the `valuation` cache this schema defines; the price-history endpoint depends on `valuation UNIQUE NULLS NOT DISTINCT (variation_id, grade_id, window_days, cost_basis)`.
- **EPIC-06 — Testing & CI/CD Quality Gates:** `STORY-06-03-03` branch protection on `main` requires `migrate.yml` to be green, and `STORY-06-02-02` integration tests run these migrations on a per-CI Neon branch using the unpooled `DATABASE_URL_UNPOOLED`.

## Definition of Done

- [ ] All 3 stories (STORY-02-02-01, STORY-02-02-02, STORY-02-02-03) are complete.
- [ ] `db/schema.ts` declares all 9 enums (`format_t`, `format_availability`, `catalog_source`, `match_status`, `listing_status`, `image_status_t`, `review_kind`, `review_state`, `plan_t`) of `docs/schema.sql` with matching names and values.
- [ ] `db/schema.ts` declares all 20 tables (`card_set`, `character`, `card`, `card_character`, `parallel_type`, `variation`, `grade`, `raw_listing`, `extraction`, `sale_observation`, `ingestion_query`, `ingestion_run`, `counterpart_override`, `review_queue`, `app_user`, `watchlist`, `collection_item`, `saved_search`, `subscription`, `valuation`) of `docs/schema.sql` with matching names, columns, defaults, and constraints, and never contradicts the canonical SQL.
- [ ] `raw_listing UNIQUE (source, source_item_id)` is preserved (the idempotent upsert key consumed by EPIC-03 ingestion).
- [ ] `valuation UNIQUE NULLS NOT DISTINCT (variation_id, grade_id, window_days, cost_basis)` is preserved, keeping digital rows (`grade_id` NULL) unique.
- [ ] Every other natural key is preserved: `card_set UNIQUE (name, year)`, `character.name UNIQUE`, `card UNIQUE (set_id, card_number)`, `card_character` PK `(card_id, character_id)`, `parallel_type.name UNIQUE`, `variation UNIQUE (card_id, parallel_type_id, format)`, `grade.label UNIQUE`, `subscription UNIQUE (user_id)`, and `counterpart_override.link_level CHECK (link_level IN ('card', 'variation'))`; `owner_user_id` on `watchlist`, `collection_item`, and `saved_search` stays nullable.
- [ ] The hot-path indexes of `docs/schema.sql` are represented, including `idx_sale_comps` as a partial index `WHERE NOT excluded_from_comps` and `idx_valuation_variation`.
- [ ] `drizzle-kit` is configured against the unpooled `DATABASE_URL_UNPOOLED`, and the initial migration generates from `db/schema.ts`.
- [ ] `migrate.yml` applies the migration on a Neon branch using the unpooled `DATABASE_URL_UNPOOLED` and exits 0; it is triggered by pull request and manual dispatch with no cron schedule.
- [ ] PostgreSQL **15+** is documented as required for `valuation`'s `UNIQUE NULLS NOT DISTINCT`.
- [ ] **Testing:** a migration rehearsal on a Neon branch applies the generated migration through the unpooled `DATABASE_URL_UNPOOLED` with zero errors, and a schema diff against `docs/schema.sql` reports no missing enums and no missing tables.
