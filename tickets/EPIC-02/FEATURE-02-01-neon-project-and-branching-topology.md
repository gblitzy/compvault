# FEATURE-02-01: Neon Project & Branching Topology

*Parent epic: [EPIC-02 — Database Platform & Schema](../EPIC-02-database-platform-and-schema.md)*

## Feature Summary

This feature provisions the CompVault Neon Postgres project and establishes its copy-on-write branching topology first — two long-lived branches: the protected `production` branch (the source of truth) and one long-lived `dev-qa` branch shared by Vercel Preview (dev/qa) deployments, CI, migration rehearsal, and local development — and documents the pooled-versus-unpooled connection-string discipline that every later database, ingestion, and test write depends on. The business value is a Postgres where all dev/qa work runs against the shared `dev-qa` branch (a copy-on-write clone of `production`) instead of mutating live data, so downstream work is repeatable and never touches production. Scope is limited to provisioning Neon, the two branch roles, the pooled and unpooled connection documentation, and the verification of the existing local Neon connection; it does **not** author the Drizzle schema or migrations ([FEATURE-02-02](FEATURE-02-02-drizzle-schema-and-migrations.md)) or the runtime client and seed data ([FEATURE-02-03](FEATURE-02-03-data-access-layer-and-seed-data.md)). **This is EPIC-02's hard prerequisite: Neon branching is provisioned before any schema, migration, ingestion, or test work runs.**

## Environment Access & Configuration

This is EPIC-02's mandatory per-epic environment-access feature. All environment configuration follows the canonical Blitzy environments reference: <https://docs.blitzy.com/administration/environments> (informational — Blitzy cannot create environments, so the single Blitzy environment is configured manually). Per that reference, the single Blitzy environment is configured by hand: build and run instructions are supplied in natural language, non-sensitive values are stored as plaintext environment variables and credentials are stored as encrypted secrets, and the environment is attached to the project. This step-by-step configuration is completed in full **before** any dependent work — EPIC-03 data writes and EPIC-06's `dev-qa` test branch — proceeds.

**Runtime floor:** PostgreSQL **15+** is required. The `valuation` table relies on `UNIQUE NULLS NOT DISTINCT (variation_id, grade_id, window_days, cost_basis)` — a constraint introduced in PostgreSQL 15 that keeps digital rows (where `grade_id` is NULL) unique — so the Neon project MUST be provisioned on PostgreSQL 15 or newer.

### Platforms and access required

| Platform | Access required | Purpose in FEATURE-02-01 |
|----------|-----------------|--------------------------|
| Blitzy | The single Blitzy environment; plaintext variables and encrypted secrets | Store the pooled `DATABASE_URL` and the unpooled `DATABASE_URL_UNPOOLED` as encrypted secrets per <https://docs.blitzy.com/administration/environments> |
| Neon | Project plus a project API key; access to the `production` (protected) and `dev-qa` branches; pooled and unpooled connection strings | Provision the project and the protected `production` branch, create one long-lived `dev-qa` branch alongside it, and expose both the pooled and unpooled connection strings |

### Connection-string discipline (pooled vs unpooled)

Two connection strings are kept distinct and stored separately as encrypted secrets in Blitzy (mirrored to Vercel and GitHub by EPIC-01):

- **Pooled `DATABASE_URL`** — the PgBouncer-pooled connection read at application **runtime**, so the many short-lived serverless invocations do not exhaust raw Postgres connections.
- **Unpooled `DATABASE_URL_UNPOOLED`** — the **direct** connection used for **DDL and migrations** (`drizzle-kit` and the `migrate.yml` workflow authored in FEATURE-02-02).

**Mixing the two breaks migrations:** DDL and migrations run only on the unpooled `DATABASE_URL_UNPOOLED`, and runtime reads run only on the pooled `DATABASE_URL`. The Neon serverless driver stack consumed by the runtime client is `@neondatabase/serverless` plus `ws`; the attached environment setup command `npm install @neondatabase/serverless ws` is recorded here as content for the access-layer feature ([FEATURE-02-03](FEATURE-02-03-data-access-layer-and-seed-data.md)) and is not executed by this documentation work.

### Neon branching topology (provisioned first)

A Neon branch is a copy-on-write clone of its parent, so each branch carries the parent's schema and data without a full physical copy. This feature provisions two branch roles before any dependent work runs:

1. **`production` branch** — the long-lived, **protected** primary branch and the source of truth that `dev-qa` clones from. Marking it protected prevents accidental deletes or resets, and child branches of a protected production branch receive isolated credentials. It runs PostgreSQL **15+**.
2. **`dev-qa` branch** — one long-lived copy-on-write clone of `production`, shared by Vercel Preview (dev/qa) deployments, CI, migration rehearsal, and local development. Whether the existing local Neon connection is enough for local and test access is an open verification item tracked in `STORY-02-01-04`, not assumed.

### CI database access (upstream gate)

1. CI runs against the shared long-lived `dev-qa` branch; no per-run branch is created or torn down.
2. The `dev-qa` branch connection string is injected as the job's `DATABASE_URL`, and schema migrations run against it on the unpooled `DATABASE_URL_UNPOOLED`.
3. The job runs its migrations and tests against the shared `dev-qa` branch.
4. Because previews and CI now share the single `dev-qa` branch, per-run database isolation is lost — concurrent CI runs and open PRs share `dev-qa` state. This is the inherent consequence of the two-environment model.

This database access is the **upstream gate** for EPIC-03 data writes and for EPIC-06's `dev-qa` test branch (`STORY-06-01-03`); both wait on this feature's branching stories (`STORY-02-01-*`).

### Step-by-step configuration (complete before dependent work begins)

1. Configure the single Blitzy environment and store the pooled `DATABASE_URL` and the unpooled `DATABASE_URL_UNPOOLED` as encrypted secrets, with non-sensitive values stored as plaintext, per <https://docs.blitzy.com/administration/environments>.
2. Provision the Neon project and its production branch, and confirm the project runs PostgreSQL **15+** so the `valuation` `UNIQUE NULLS NOT DISTINCT` constraint is supported.
3. Record both the pooled and the unpooled connection strings for the production branch as distinct encrypted secrets.
4. Grant a Neon API key with branch-create permission, mark the `production` branch protected, then create the one long-lived `dev-qa` branch from `production`.
5. Verify whether the existing local Neon connection is enough for local development and test access against the shared `dev-qa` branch; record the outcome and any gap discovered as the explicit open item in `STORY-02-01-04`.
6. Confirm the unpooled `DATABASE_URL_UNPOOLED` is reachable for migrations and the pooled `DATABASE_URL` is reachable for runtime reads before the schema work in FEATURE-02-02 and any dependent epic begins.

## User Stories Index

This feature is delivered through four stories. Each link is relative to this file and resolves inside the `FEATURE-02-01/` subfolder.

1. **[STORY-02-01-01 — Provision the Neon Project & Production Branch](FEATURE-02-01/STORY-02-01-01-provision-neon-project-and-production-branch.md)** — create the Neon project on PostgreSQL **15+** plus an API key, and create the protected `production` branch; cite <https://docs.blitzy.com/administration/environments>.
2. **[STORY-02-01-02 — Configure Preview Deployments Against the Shared Dev/QA Branch](FEATURE-02-01/STORY-02-01-02-configure-per-pr-preview-branches.md)** — point every Vercel Preview (dev/qa) deployment at the shared long-lived `dev-qa` branch so a preview never reads production data; no separate Neon branch is created or torn down for each pull request.
3. **[STORY-02-01-03 — Configure CI Against the Shared Dev/QA Branch](FEATURE-02-01/STORY-02-01-03-configure-per-ci-ephemeral-branches.md)** — run CI against the shared long-lived `dev-qa` branch, applying migrations on the unpooled `DATABASE_URL_UNPOOLED`; no per-run branch is created or torn down. This is the prerequisite for EPIC-06's `STORY-06-01-03`.
4. **[STORY-02-01-04 — Document Pooled & Unpooled Connections](FEATURE-02-01/STORY-02-01-04-document-pooled-and-unpooled-connections.md)** — document the pooled `DATABASE_URL` versus unpooled `DATABASE_URL_UNPOOLED` split and verify whether the existing local Neon connection is enough for local and test access, recording any gap as an open item (the local-Neon uncertainty is preserved, not assumed).

## Dependencies

### Upstream (must be complete first)

- **EPIC-01 — Environment & Configuration Foundation:** supplies the single Blitzy environment, the Next.js + TypeScript scaffold, and the secrets baseline into which the pooled `DATABASE_URL` and the unpooled `DATABASE_URL_UNPOOLED` are stored and attached to the project.

### Downstream (informational — not a build prerequisite of this feature)

- **[FEATURE-02-02 — Drizzle Schema & Migrations](FEATURE-02-02-drizzle-schema-and-migrations.md):** authors the schema and migrations that run against the branches and the unpooled connection this feature provisions.
- **[FEATURE-02-03 — Data Access Layer & Seed Data](FEATURE-02-03-data-access-layer-and-seed-data.md):** implements the pooled Neon client (`@neondatabase/serverless` plus `ws`) and the seed script over the pooled connection this feature documents.
- **EPIC-03 — Data Ingestion Pipeline:** every ingestion write targets these two branches through the pooled `DATABASE_URL`; the branching stories (`STORY-02-01-*`) are a hard prerequisite of every ingestion write.
- **EPIC-04 — Backend Application & API:** reads through the access layer built on these connections.
- **EPIC-06 — Testing & CI/CD Quality Gates:** the integration-test wiring story (`STORY-06-01-03`) depends directly on `STORY-02-01-03`; its integration suite targets the shared `dev-qa` branch and runs migrations against it on the unpooled `DATABASE_URL_UNPOOLED`, creating and tearing down no per-run branch.

## Definition of Done

- [ ] All 4 stories (STORY-02-01-01, STORY-02-01-02, STORY-02-01-03, STORY-02-01-04) are complete.
- [ ] The Neon project is provisioned on PostgreSQL **15+** with an API key and a protected `production` branch, configured per <https://docs.blitzy.com/administration/environments>.
- [ ] Every Vercel Preview (dev/qa) deployment points at the shared long-lived `dev-qa` branch, with no preview pointing at production data; no separate Neon branch is created for each pull request.
- [ ] CI runs against the shared long-lived `dev-qa` branch (a copy-on-write clone of `production`); no per-run branch is created or torn down.
- [ ] The pooled `DATABASE_URL` and the unpooled `DATABASE_URL_UNPOOLED` are documented as distinct connections and stored as encrypted secrets in Blitzy, with the rule that DDL and migrations use the unpooled URL and runtime reads use the pooled URL.
- [ ] The Neon serverless driver stack (`@neondatabase/serverless` plus `ws`) is named as the runtime connection driver, recorded as content for FEATURE-02-03 and not executed in this feature.
- [ ] Whether the existing local Neon connection is enough for local and test access is verified, and any gap discovered is recorded as an open item in `STORY-02-01-04`.
- [ ] The branching topology is documented as the upstream gate for EPIC-03 data writes and EPIC-06's `dev-qa` test branch (`STORY-06-01-03`).
- [ ] **Testing:** a connection is opened against the shared `dev-qa` branch and a connectivity check returns zero connection errors; no per-run branch is created or torn down (per-run isolation is intentionally traded away — see the CI database access section above).
