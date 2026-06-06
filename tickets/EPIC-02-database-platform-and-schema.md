# EPIC-02: Provision the Database Platform & Schema — stand up Neon branching first, mirror docs/schema.sql in a Drizzle schema, and deliver a pooled access layer with seed data

## Epic Summary

EPIC-02 stands up the CompVault database platform: it provisions the Neon Postgres project and its branching topology first (the hard prerequisite), then authors a Drizzle ORM schema that mirrors the canonical `docs/schema.sql`, and finally delivers the pooled access layer (the `getUserId()` seam) and the catalog seed data. The business value is a branch-isolated Postgres carrying a typed schema that mirrors the canonical data model behind a pooled access layer, so every later epic builds on one source of truth and previews, CI, migration rehearsal, and local development all run against one shared long-lived `dev-qa` branch (a copy-on-write clone of `production`) instead of against production data. Scope is limited to provisioning Neon, the branching topology, the Drizzle schema and migrations, the pooled access layer, the `getUserId()` seam, and the catalog seed; this epic implements no ingestion (EPIC-03), no API (EPIC-04), and no UI (EPIC-05), and the Drizzle schema mirrors but never contradicts `docs/schema.sql`.

## Environment Access & Configuration

All environment provisioning for this epic follows the canonical Blitzy environments reference: <https://docs.blitzy.com/administration/environments>. Non-sensitive values are stored as plaintext environment variables and credentials are stored as encrypted secrets, after which the environment is attached to the project. This step-by-step configuration is completed in full **before** any schema, migration, or data-write work proceeds.

The database is Neon serverless Postgres, accessed from the Next.js application through Neon's pooled driver so that the many short-lived serverless invocations do not exhaust raw Postgres connections. Two connection strings are kept distinct: the **pooled** `DATABASE_URL` is read at runtime by the application, and the **unpooled** `DATABASE_URL_UNPOOLED` is used for DDL and migrations — mixing the two breaks migrations, so each is stored and consumed separately. The Neon serverless driver stack is `@neondatabase/serverless` plus `ws`; the attached environment setup command `npm install @neondatabase/serverless ws` is recorded here as content for the access-layer feature and is not executed by this documentation work.

**Runtime floor:** PostgreSQL **15+** is required, because the `valuation` table relies on `UNIQUE NULLS NOT DISTINCT (variation_id, grade_id, window_days, cost_basis)` — a constraint introduced in PostgreSQL 15 that keeps digital rows (where `grade_id` is NULL) unique.

### Platforms and access required

| Platform | Access required | Purpose in EPIC-02 |
|----------|-----------------|--------------------|
| Blitzy | single environment (manual build/run + hand-entered secrets); plaintext variables and encrypted secrets | Store the pooled `DATABASE_URL` and the unpooled `DATABASE_URL_UNPOOLED` as encrypted secrets in the single Blitzy environment per the Blitzy environments reference |
| Neon | Project plus API key; protected `production` branch; one long-lived `dev-qa` branch; pooled and unpooled connection strings | Provision the project and the protected `production` branch, create one long-lived `dev-qa` branch shared by previews, CI, migration rehearsal, and local dev, and expose both the pooled and unpooled connection strings |

### Neon branching topology (provisioned first)

Neon branches are copy-on-write clones of their parent, so each branch carries the parent's schema and data without a full copy. This epic provisions two long-lived branches before any dependent work runs:

1. **`production` branch** — the long-lived primary branch and the source of truth that `dev-qa` clones from; mark it **protected** (prevents accidental deletes/resets); runs PostgreSQL **15+**.
2. **`dev-qa` branch** — one long-lived branch cloned from `production`, shared by Vercel Preview (dev/qa) deployments, CI runs, the migration rehearsal workflow, and local development. This single branch replaces the former separate preview, CI, and local-development branches. Whether the existing local Neon connection is enough for local and test access remains an open verification item tracked in `STORY-02-01-04`, not assumed.

Because previews and CI now share the single `dev-qa` branch, per-run database isolation is lost — concurrent CI runs and open PRs share `dev-qa` state. This is the inherent consequence of the two-environment model.

### Step-by-step configuration (complete before dependent work begins)

1. Configure the single Blitzy environment and store the pooled `DATABASE_URL` and the unpooled `DATABASE_URL_UNPOOLED` as encrypted secrets, with non-sensitive values stored as plaintext, per <https://docs.blitzy.com/administration/environments> (informational only — Blitzy cannot create environments).
2. Provision the Neon project and its protected `production` branch, and record both the pooled and the unpooled connection strings for it.
3. Confirm the Neon project runs PostgreSQL **15+** so the `valuation` `UNIQUE NULLS NOT DISTINCT` constraint is supported.
4. Grant a Neon API key, then create one long-lived `dev-qa` branch from `production` that previews, CI, the migration rehearsal workflow, and local development all share.
5. Verify whether the existing local Neon connection (targeting the `dev-qa` branch) is enough for local and test access; record the outcome and any gap as the explicit open item in `STORY-02-01-04`.
6. Confirm the unpooled `DATABASE_URL_UNPOOLED` is reachable for migrations and the pooled `DATABASE_URL` is reachable for runtime reads before the schema and access-layer work begins.

## Features Index

This epic is delivered through three features. Each link is relative to this file inside the `EPIC-02/` directory.

1. **[FEATURE-02-01 — Neon Project & Branching Topology](EPIC-02/FEATURE-02-01-neon-project-and-branching-topology.md)** — provision the Neon project and production branch; create one long-lived `dev-qa` branch (shared by previews, CI, migration rehearsal, and local dev); document the pooled `DATABASE_URL` versus the unpooled `DATABASE_URL_UNPOOLED` connections; and verify whether the existing local Neon connection is enough for local and test access. **This is the hard prerequisite — Neon branching first.** This feature carries four stories.
2. **[FEATURE-02-02 — Drizzle Schema & Migrations](EPIC-02/FEATURE-02-02-drizzle-schema-and-migrations.md)** — author `db/schema.ts` mirroring the 9 enums and 20 tables of `docs/schema.sql`, configure `drizzle-kit` and generate the initial migration, and create a `migrate.yml` workflow that rehearses migrations on the `dev-qa` Neon branch using the unpooled `DATABASE_URL_UNPOOLED`. This feature carries three stories.
3. **[FEATURE-02-03 — Data Access Layer & Seed Data](EPIC-02/FEATURE-02-03-data-access-layer-and-seed-data.md)** — implement the pooled Neon client (`@neondatabase/serverless` plus `ws`), implement the `getUserId()` seam returning the seeded operator user, and author the catalog seed script (the sets, characters, and cards baseline). This feature carries three stories.

## Dependencies

### Upstream (must be complete first)

- **EPIC-01 — Environment & Configuration Foundation:** supplies the Blitzy environments, the Next.js + TypeScript scaffold, and the secrets baseline into which the pooled `DATABASE_URL` and the unpooled `DATABASE_URL_UNPOOLED` are stored.

### Downstream (informational — not a build prerequisite of this epic)

- **EPIC-03 — Data Ingestion Pipeline:** every ingestion write targets this epic's database, writing to `raw_listing`, `extraction`, `sale_observation`, `ingestion_run`, and `review_queue` through the pooled `DATABASE_URL`. The branching stories (`STORY-02-01-*`) are a hard prerequisite of every ingestion write.
- **EPIC-04 — Backend Application & API:** reads the catalog tables (`character`, `card`, `card_character`, `variation`, `parallel_type`), the `sale_observation` time series, the `valuation` cache, and the `review_queue` and `counterpart_override` tables through this epic's pooled access layer, threading `userId` from the `getUserId()` seam (`STORY-02-03-02`).
- **EPIC-06 — Testing & CI/CD Quality Gates:** the integration-test wiring story (`STORY-06-01-03`) depends on this epic's branching stories (`STORY-02-01-*`); its integration suite runs against the shared `dev-qa` branch, applying migrations using the unpooled `DATABASE_URL_UNPOOLED` (no per-run branch is created or deleted).

## Definition of Done

- [ ] All 3 child features (FEATURE-02-01, FEATURE-02-02, FEATURE-02-03) are complete.
- [ ] The Neon project plus the protected `production` branch and the shared long-lived `dev-qa` branch are configured per <https://docs.blitzy.com/administration/environments>, with Neon branching provisioned first.
- [ ] The pooled `DATABASE_URL` and the unpooled `DATABASE_URL_UNPOOLED` are documented as distinct connections and stored as encrypted secrets; runtime reads use the pooled connection and DDL/migrations use the unpooled connection.
- [ ] The Neon project runs PostgreSQL **15+** so the `valuation` `UNIQUE NULLS NOT DISTINCT` constraint is supported.
- [ ] The Drizzle schema (`db/schema.ts`) mirrors all 9 enums (`format_t`, `format_availability`, `catalog_source`, `match_status`, `listing_status`, `image_status_t`, `review_kind`, `review_state`, `plan_t`) and all 20 tables (`card_set`, `character`, `card`, `card_character`, `parallel_type`, `variation`, `grade`, `raw_listing`, `extraction`, `sale_observation`, `ingestion_query`, `ingestion_run`, `counterpart_override`, `review_queue`, `app_user`, `watchlist`, `collection_item`, `saved_search`, `subscription`, `valuation`) of `docs/schema.sql`, and never contradicts it.
- [ ] The initial migration generates and applies on the `dev-qa` Neon branch through the unpooled `DATABASE_URL_UNPOOLED`.
- [ ] The pooled Neon client (`@neondatabase/serverless` plus `ws`), the `getUserId()` seam returning the seeded operator user, and the catalog seed script are implemented.
- [ ] Whether the existing local Neon connection is enough for local and test access is verified, and any gap is documented in `STORY-02-01-04`.
- [ ] **Testing:** the `migrate.yml` migration rehearsal runs on the `dev-qa` Neon branch using the unpooled `DATABASE_URL_UNPOOLED` and passes end to end before any dependent epic writes data.
