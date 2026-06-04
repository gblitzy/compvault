# FEATURE-02-01: Neon Project & Branching Topology

*Parent epic: [EPIC-02 — Database Platform & Schema](../EPIC-02-database-platform-and-schema.md)*

## Feature Summary

This feature provisions the CompVault Neon Postgres project and establishes its copy-on-write branching topology first — production, per-PR preview, per-CI ephemeral, and local development — and documents the pooled-versus-unpooled connection-string discipline that every later database, ingestion, and test write depends on. The business value is a branch-isolated Postgres where each pull request and each CI run receives its own throwaway clone of the production branch instead of sharing live data, so downstream work is repeatable and never mutates production. Scope is limited to provisioning Neon, the four branch roles, the pooled and unpooled connection documentation, and the verification of the existing local Neon connection; it does **not** author the Drizzle schema or migrations ([FEATURE-02-02](FEATURE-02-02-drizzle-schema-and-migrations.md)) or the runtime client and seed data ([FEATURE-02-03](FEATURE-02-03-data-access-layer-and-seed-data.md)). **This is EPIC-02's hard prerequisite: Neon branching is provisioned before any schema, migration, ingestion, or test work runs.**

## Environment Access & Configuration

This is EPIC-02's mandatory per-epic environment-access feature. All environment provisioning follows the canonical Blitzy environments reference: <https://docs.blitzy.com/administration/environments>. Per that reference, an environment is created for each target, build and run instructions are supplied in natural language, non-sensitive values are stored as plaintext environment variables and credentials are stored as encrypted secrets, and the environment is then attached to the project. This step-by-step configuration is completed in full **before** any dependent work — EPIC-03 data writes and EPIC-06's per-CI test branch — proceeds.

**Runtime floor:** PostgreSQL **15+** is required. The `valuation` table relies on `UNIQUE NULLS NOT DISTINCT (variation_id, grade_id, window_days, cost_basis)` — a constraint introduced in PostgreSQL 15 that keeps digital rows (where `grade_id` is NULL) unique — so the Neon project MUST be provisioned on PostgreSQL 15 or newer.

### Platforms and access required

| Platform | Access required | Purpose in FEATURE-02-01 |
|----------|-----------------|--------------------------|
| Blitzy | Environment per target; plaintext variables and encrypted secrets | Store the pooled `DATABASE_URL` and the unpooled `DATABASE_URL_UNPOOLED` as encrypted secrets per <https://docs.blitzy.com/administration/environments> |
| Neon | Project plus API key carrying branch create and delete permission; production branch; pooled and unpooled connection strings | Provision the project and production branch, configure per-PR preview branches and per-CI ephemeral branches, and expose both the pooled and unpooled connection strings |

### Connection-string discipline (pooled vs unpooled)

Two connection strings are kept distinct and stored separately as encrypted secrets in Blitzy (mirrored to Vercel and GitHub by EPIC-01):

- **Pooled `DATABASE_URL`** — the PgBouncer-pooled connection read at application **runtime**, so the many short-lived serverless invocations do not exhaust raw Postgres connections.
- **Unpooled `DATABASE_URL_UNPOOLED`** — the **direct** connection used for **DDL and migrations** (`drizzle-kit` and the `migrate.yml` workflow authored in FEATURE-02-02).

**Mixing the two breaks migrations:** DDL and migrations run only on the unpooled `DATABASE_URL_UNPOOLED`, and runtime reads run only on the pooled `DATABASE_URL`. The Neon serverless driver stack consumed by the runtime client is `@neondatabase/serverless` plus `ws`; the attached environment setup command `npm install @neondatabase/serverless ws` is recorded here as content for the access-layer feature ([FEATURE-02-03](FEATURE-02-03-data-access-layer-and-seed-data.md)) and is not executed by this documentation work.

### Neon branching topology (provisioned first)

A Neon branch is a copy-on-write clone of its parent, so each branch carries the parent's schema and data without a full physical copy. This feature provisions four branch roles before any dependent work runs:

1. **Production branch** — the long-lived primary branch and the source of truth that every other branch clones from.
2. **Per-PR preview branch** — one branch per pull request, paired with the Vercel preview deployment so a preview never reads production data.
3. **Per-CI ephemeral branch** — a throwaway branch created from the production branch at pipeline start and deleted on completion.
4. **Local development branch** — the branch backing local work; whether the existing local Neon connection is enough for local and test access is an open verification item tracked in `STORY-02-01-04`, not assumed.

### Per-CI Neon branch lifecycle (upstream gate)

1. At pipeline start, a Neon branch is created as a copy-on-write clone of the production branch.
2. The branch connection string is injected as the job's `DATABASE_URL`, and schema migrations run against it on the unpooled `DATABASE_URL_UNPOOLED`.
3. The job runs its migrations and tests against the freshly created branch.
4. On pipeline completion — whether the run passes or fails — the branch is deleted, so no ephemeral branch outlives its pipeline and zero residual branches remain.

This branching is the **upstream gate** for EPIC-03 data writes and for EPIC-06's per-CI test branch (`STORY-06-01-03`); both wait on this feature's branching stories (`STORY-02-01-*`).

### Step-by-step configuration (complete before dependent work begins)

1. Create the Blitzy environments and store the pooled `DATABASE_URL` and the unpooled `DATABASE_URL_UNPOOLED` as encrypted secrets, with non-sensitive values stored as plaintext, per <https://docs.blitzy.com/administration/environments>.
2. Provision the Neon project and its production branch, and confirm the project runs PostgreSQL **15+** so the `valuation` `UNIQUE NULLS NOT DISTINCT` constraint is supported.
3. Record both the pooled and the unpooled connection strings for the production branch as distinct encrypted secrets.
4. Grant a Neon API key carrying branch create and delete permission, then configure the per-PR preview branch automation and the per-CI ephemeral branch create-and-teardown.
5. Verify whether the existing local Neon connection is enough for local development and test access; record the outcome and any gap discovered as the explicit open item in `STORY-02-01-04`.
6. Confirm the unpooled `DATABASE_URL_UNPOOLED` is reachable for migrations and the pooled `DATABASE_URL` is reachable for runtime reads before the schema work in FEATURE-02-02 and any dependent epic begins.

## User Stories Index

This feature is delivered through four stories. Each link is relative to this file and resolves inside the `FEATURE-02-01/` subfolder.

1. **[STORY-02-01-01 — Provision the Neon Project & Production Branch](FEATURE-02-01/STORY-02-01-01-provision-neon-project-and-production-branch.md)** — create the Neon project on PostgreSQL **15+** plus an API key, and create the production branch; cite <https://docs.blitzy.com/administration/environments>.
2. **[STORY-02-01-02 — Configure Per-PR Preview Branches](FEATURE-02-01/STORY-02-01-02-configure-per-pr-preview-branches.md)** — configure per-PR preview branch automation, creating one Neon branch per pull request and preview deployment so a preview never reads production data.
3. **[STORY-02-01-03 — Configure Per-CI Ephemeral Branches](FEATURE-02-01/STORY-02-01-03-configure-per-ci-ephemeral-branches.md)** — configure per-CI ephemeral branch create-from-production at pipeline start and teardown on completion; this is the prerequisite for EPIC-06's `STORY-06-01-03`.
4. **[STORY-02-01-04 — Document Pooled & Unpooled Connections](FEATURE-02-01/STORY-02-01-04-document-pooled-and-unpooled-connections.md)** — document the pooled `DATABASE_URL` versus unpooled `DATABASE_URL_UNPOOLED` split and verify whether the existing local Neon connection is enough for local and test access, recording any gap as an open item (the local-Neon uncertainty is preserved, not assumed).

## Dependencies

### Upstream (must be complete first)

- **EPIC-01 — Environment & Configuration Foundation:** supplies the Blitzy environments, the Next.js + TypeScript scaffold, and the secrets baseline into which the pooled `DATABASE_URL` and the unpooled `DATABASE_URL_UNPOOLED` are stored and attached to the project.

### Downstream (informational — not a build prerequisite of this feature)

- **[FEATURE-02-02 — Drizzle Schema & Migrations](FEATURE-02-02-drizzle-schema-and-migrations.md):** authors the schema and migrations that run against the branches and the unpooled connection this feature provisions.
- **[FEATURE-02-03 — Data Access Layer & Seed Data](FEATURE-02-03-data-access-layer-and-seed-data.md):** implements the pooled Neon client (`@neondatabase/serverless` plus `ws`) and the seed script over the pooled connection this feature documents.
- **EPIC-03 — Data Ingestion Pipeline:** every ingestion write targets these branches through the pooled `DATABASE_URL`; the branching stories (`STORY-02-01-*`) are a hard prerequisite of every ingestion write.
- **EPIC-04 — Backend Application & API:** reads through the access layer built on these connections.
- **EPIC-06 — Testing & CI/CD Quality Gates:** the per-CI Neon test-branch story (`STORY-06-01-03`) depends directly on `STORY-02-01-03`; its integration suite creates a branch from production, runs migrations against it on the unpooled `DATABASE_URL_UNPOOLED`, and deletes it on completion.

## Definition of Done

- [ ] All 4 stories (STORY-02-01-01, STORY-02-01-02, STORY-02-01-03, STORY-02-01-04) are complete.
- [ ] The Neon project is provisioned on PostgreSQL **15+** with an API key and a production branch, configured per <https://docs.blitzy.com/administration/environments>.
- [ ] Per-PR preview branch automation is configured, creating one Neon branch per pull request and preview deployment, with no preview pointing at production data.
- [ ] Per-CI ephemeral branches are created from the production branch at pipeline start and deleted on completion.
- [ ] The pooled `DATABASE_URL` and the unpooled `DATABASE_URL_UNPOOLED` are documented as distinct connections and stored as encrypted secrets in Blitzy, with the rule that DDL and migrations use the unpooled URL and runtime reads use the pooled URL.
- [ ] The Neon serverless driver stack (`@neondatabase/serverless` plus `ws`) is named as the runtime connection driver, recorded as content for FEATURE-02-03 and not executed in this feature.
- [ ] Whether the existing local Neon connection is enough for local and test access is verified, and any gap discovered is recorded as an open item in `STORY-02-01-04`.
- [ ] The branching topology is documented as the upstream gate for EPIC-03 data writes and EPIC-06's per-CI test branch (`STORY-06-01-03`).
- [ ] **Testing:** a per-CI ephemeral branch is created from the production branch, a connection is opened against it and a connectivity check returns zero connection errors, and the branch is torn down on completion with zero residual branches left behind.
