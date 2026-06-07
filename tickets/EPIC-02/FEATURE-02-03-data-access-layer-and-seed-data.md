# FEATURE-02-03: Data Access Layer & Seed Data

*Parent epic: [EPIC-02 — Database Platform & Schema](../EPIC-02-database-platform-and-schema.md)*

## Feature Summary

This feature delivers the runtime data access layer and the catalog seed data on top of the provisioned Neon database ([FEATURE-02-01](FEATURE-02-01-neon-project-and-branching-topology.md)) and the applied Drizzle schema and migrations ([FEATURE-02-02](FEATURE-02-02-drizzle-schema-and-migrations.md)): the pooled Neon client the application reads through at runtime, the `getUserId()` seam that returns the seeded operator `app_user` id, and the idempotent catalog seed that loads the baseline sets, characters, cards, parallels, variations, and grades skeleton. The business value is a working, populated access layer — a pooled, typed runtime client plus a latent multi-tenancy seam plus a re-runnable catalog seed — so the backend (EPIC-04) can query a populated database from its first request without re-running ingestion. Scope is limited to the pooled client, the `getUserId()` seam, and the baseline catalog seed; it does **not** provision Neon or its branches ([FEATURE-02-01](FEATURE-02-01-neon-project-and-branching-topology.md)), author the schema or migrations ([FEATURE-02-02](FEATURE-02-02-drizzle-schema-and-migrations.md)), ingest sales or derive the digital (SWCT) catalog (EPIC-03), or expose any API or UI (EPIC-04/EPIC-05).

## Environment Access & Configuration

The full platform access for this epic — Blitzy encrypted secrets, the Neon project and branches, and both connection strings — is provisioned in [FEATURE-02-01 — Neon Project & Branching Topology](FEATURE-02-01-neon-project-and-branching-topology.md) and documented per the canonical Blitzy environments reference: <https://docs.blitzy.com/administration/environments>. This feature consumes that access and does not duplicate the full configuration steps; the access this feature depends on is summarized below.

- **Pooled connection at runtime.** The pooled Neon client reads the **pooled `DATABASE_URL`** secret at application runtime and never reads the unpooled `DATABASE_URL_UNPOOLED`. The unpooled `DATABASE_URL_UNPOOLED` is reserved for DDL and migrations ([FEATURE-02-02](FEATURE-02-02-drizzle-schema-and-migrations.md)); **mixing the two is an error** — runtime reads run only on the pooled `DATABASE_URL`, and DDL and migrations run only on the unpooled `DATABASE_URL_UNPOOLED`.
- **Driver stack and runtime floor.** The client uses the `@neondatabase/serverless` plus `ws` driver stack and runs on Node `>=20.20.2` (the application engine floor from the root `package.json` `engines.node`; the earlier `>=18` value originated from the existing Apify actor's `apify/package.json` `engines.node`). The attached environment setup command `npm install @neondatabase/serverless ws` is recorded here as content and is not executed by this documentation work.
- **Schema must exist before the seed runs.** The catalog seed depends on the schema and migrations from [FEATURE-02-02 — Drizzle Schema & Migrations](FEATURE-02-02-drizzle-schema-and-migrations.md) having been applied; the seed writes rows into tables the migration creates, so it runs only after that migration has run against the target branch.

## User Stories Index

This feature is delivered through three stories. Each link is relative to this file and resolves inside the `FEATURE-02-03/` subfolder.

1. **[STORY-02-03-01 — Implement the Pooled Neon Client](FEATURE-02-03/STORY-02-03-01-implement-pooled-neon-client.md)** — implement the pooled Neon client on the `@neondatabase/serverless` plus `ws` driver stack, reading the pooled `DATABASE_URL`; a missing `DATABASE_URL` throws before any query is issued.
2. **[STORY-02-03-02 — Implement the getUserId Seam](FEATURE-02-03/STORY-02-03-02-implement-getuserid-seam.md)** — implement `getUserId()` returning the seeded operator `app_user` id, the latent multi-tenancy seam that keeps `owner_user_id` NULL in v1 so adding accounts later is non-breaking.
3. **[STORY-02-03-03 — Author the Catalog Seed Script](FEATURE-02-03/STORY-02-03-03-author-catalog-seed-script.md)** — author an idempotent catalog seed that loads the baseline `card_set`, `character`, `card`, `card_character`, `parallel_type`, `variation`, and `grade` skeleton, keyed on the schema's natural unique keys so re-running it adds no duplicate rows.

## Dependencies

### Upstream (must be complete first)

- **EPIC-01 — Environment & Configuration Foundation:** the secrets baseline holds the pooled `DATABASE_URL` that the runtime client reads.
- **[FEATURE-02-01 — Neon Project & Branching Topology](FEATURE-02-01-neon-project-and-branching-topology.md):** provisions the Neon project and the pooled connection string this client connects through.
- **[FEATURE-02-02 — Drizzle Schema & Migrations](FEATURE-02-02-drizzle-schema-and-migrations.md):** authors and applies the schema and migrations; the seed requires these tables to exist before it writes any row.

### Downstream (informational — not a build prerequisite of this feature)

- **EPIC-03 — Data Ingestion Pipeline:** writes sales and derives the digital catalog through the database this access layer connects to; the digital (SWCT) `listing_derived` rows this feature does not seed are derived there.
- **EPIC-04 — Backend Application & API:** threads `userId` from the `getUserId()` seam (`STORY-02-03-02`) through its handlers and queries the catalog and time-series tables through this pooled client.
- **EPIC-06 — Testing & CI/CD Quality Gates:** `STORY-06-02-02` integration tests query through the shared `dev-qa` Neon branch, exercising this access layer and the seed against the shared `dev-qa` branch (a copy-on-write clone of the `production` branch).

## Definition of Done

- [ ] All 3 stories (STORY-02-03-01, STORY-02-03-02, STORY-02-03-03) are complete.
- [ ] The pooled Neon client connects through the pooled `DATABASE_URL` on the `@neondatabase/serverless` plus `ws` driver stack under Node `>=20.20.2`, and never reads the unpooled `DATABASE_URL_UNPOOLED`.
- [ ] A missing `DATABASE_URL` throws before any query is issued, so the client fails fast instead of connecting with an empty connection string.
- [ ] `getUserId()` returns the seeded operator `app_user` id as a non-null value, and the multi-tenancy seam keeps `owner_user_id` NULL on `watchlist`, `collection_item`, and `saved_search` in v1.
- [ ] The catalog seed loads the baseline `card_set`, `character`, `card`, `card_character`, `parallel_type`, `variation`, and `grade` rows, and re-running the seed twice leaves exactly one row per natural unique key (`card_set (name, year)`, `character.name`, `card (set_id, card_number)`, `card_character (card_id, character_id)`, `parallel_type.name`, `variation (card_id, parallel_type_id, format)`, and `grade.label`).
- [ ] The seed marks physical catalog rows with a `catalog_source` of `manual`, `topps_odds`, or `checklist_db`, and writes zero digital (SWCT) `listing_derived` rows (those are derived by EPIC-03 ingestion, not seeded here).
- [ ] Every data-access read and every seed insert and upsert across this feature (the pooled client, the `getUserId()` lookup, and the catalog seed) executes through Drizzle ORM or parameterized driver calls, with 0 string-concatenated SQL, and a static check (or test) confirms 0 string-concatenated SQL.
- [ ] **Testing:** an integration test on the `dev-qa` Neon branch runs the seed twice and asserts that every catalog table's row count is unchanged on the second run and that `getUserId()` returns a non-null id.
