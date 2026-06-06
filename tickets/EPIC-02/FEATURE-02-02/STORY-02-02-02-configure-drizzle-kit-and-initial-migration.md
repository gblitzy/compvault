# STORY-02-02-02: Configure drizzle-kit & the Initial Migration

*Parent feature: [FEATURE-02-02 — Drizzle Schema & Migrations](../FEATURE-02-02-drizzle-schema-and-migrations.md) · Parent epic: [EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md)*

This is the second of the three stories of FEATURE-02-02. It configures `drizzle-kit` (the migration tooling) against the unpooled `DATABASE_URL_UNPOOLED` connection and generates the initial migration set **from** the `db/schema.ts` authored in [`STORY-02-02-01`](STORY-02-02-01-author-drizzle-schema.md). When that migration set is applied to the `dev-qa` Neon branch through the unpooled connection, it creates all 9 enums and all 20 tables of the canonical schema (`docs/schema.sql`). The migration set produced here is the artifact that [`STORY-02-02-03`](STORY-02-02-03-create-migration-rehearsal-workflow.md)'s `migrate.yml` rehearsal workflow applies, and that `EPIC-06` integration tests replay on the shared `dev-qa` Neon branch. The migration is generated, never hand-written: `db/schema.ts` is the single input and `docs/schema.sql` remains the canonical authority it must reproduce.

## User Story

> As a Database Engineer, I want drizzle-kit configured against the unpooled connection and an initial migration generated, so that the schema can be applied to any Neon branch reproducibly.

## Connection & Environment Note

All migration commands (`drizzle-kit generate` and `drizzle-kit migrate`) and `drizzle.config.ts` read the unpooled `DATABASE_URL_UNPOOLED` connection and never the pooled `DATABASE_URL` — mixing the pooled and unpooled connections breaks migrations, and this is the documented failure mode. The unpooled secret and the Neon branch to apply the migration to are provisioned per [FEATURE-02-01 — Neon Project & Branching Topology](../FEATURE-02-01-neon-project-and-branching-topology.md) (see [`STORY-02-01-04`](../FEATURE-02-01/STORY-02-01-04-document-pooled-and-unpooled-connections.md)); the target Neon database runs **PostgreSQL 15+** because `valuation`'s `UNIQUE NULLS NOT DISTINCT (variation_id, grade_id, window_days, cost_basis)` is rejected on any server below version 15.

## Acceptance Criteria

1. **(input-validation)** **Given** `DATABASE_URL_UNPOOLED` is unset, **When** `drizzle-kit generate` or `drizzle-kit migrate` runs, **Then** it exits non-zero with a named missing-variable error and writes no migration file.
2. **(input-validation)** **Given** `drizzle.config.ts`, **When** its migration connection is inspected, **Then** it reads the unpooled `DATABASE_URL_UNPOOLED` and not the pooled `DATABASE_URL`.
3. **(valid-output)** **Given** `db/schema.ts`, **When** the initial migration is generated, **Then** a single migration set is produced that creates all 9 enums and all 20 tables.
4. **(valid-output)** **Given** the generated migration set, **When** it is applied to the `dev-qa` Neon branch through the unpooled `DATABASE_URL_UNPOOLED`, **Then** the run exits 0 and all 20 tables exist in the branch.
5. **(valid-output)** **Given** the migration applied to a fresh branch, **When** the resulting schema is inspected, **Then** the `raw_listing` `UNIQUE (source, source_item_id)` constraint and the `valuation` `UNIQUE NULLS NOT DISTINCT (variation_id, grade_id, window_days, cost_basis)` constraint both exist.
6. **(valid-output)** **Given** the SQL generated from `db/schema.ts` (the generated migration set), **When** it is diffed against the canonical `docs/schema.sql`, **Then** the diff reports 0 missing and 0 renamed enums, tables, constraints, indexes, and named columns, and the migration is not accepted until that count reaches 0.
7. **(error-handling)** **Given** the pooled `DATABASE_URL` is supplied in place of the unpooled `DATABASE_URL_UNPOOLED`, **When** migrations run, **Then** the run is rejected and exits non-zero (mixing the pooled and unpooled connections breaks migrations).
8. **(edge-case)** **Given** an unchanged `db/schema.ts`, **When** the migration is re-generated, **Then** 0 new migration files are produced.

## Sub-tasks

- Author `drizzle.config.ts` pointing the migrations driver at the unpooled `DATABASE_URL_UNPOOLED` and never the pooled `DATABASE_URL` — `@database-engineer`
- Generate the initial migration set from `db/schema.ts` with the `drizzle-kit generate` command so the set creates all 9 enums and all 20 tables — `@database-engineer`
- Apply the migration to the `dev-qa` Neon branch through the unpooled `DATABASE_URL_UNPOOLED` with the `drizzle-kit migrate` command and confirm all 20 tables exist (exit 0) — `@database-engineer`
- Add a fail-fast guard that exits non-zero with a named missing-variable error when `DATABASE_URL_UNPOOLED` is absent — `@devops-engineer`
- Document that the pooled `DATABASE_URL` is rejected for migration runs because mixing the pooled and unpooled connections breaks migrations — `@database-engineer`
- Verify the generated migration reproduces the `raw_listing UNIQUE (source, source_item_id)` and `valuation UNIQUE NULLS NOT DISTINCT (variation_id, grade_id, window_days, cost_basis)` constraints on the branch — `@database-engineer`
- Diff the SQL generated from `db/schema.ts` (the generated migration set) against the canonical `docs/schema.sql` and resolve every difference so the diff reports 0 missing and 0 renamed enums, tables, constraints, indexes, and named columns before the migration is accepted — `@database-engineer`

## Edge Cases

- **Empty/Null:** `DATABASE_URL_UNPOOLED` is missing or empty → drizzle-kit exits non-zero with a named missing-variable error and writes no migration.
- **Invalid:** the pooled `DATABASE_URL` is used for DDL → the migration run is rejected and exits non-zero (mixing the pooled and unpooled connections breaks migrations).
- **Boundary:** the migration is re-generated against an unchanged `db/schema.ts` → 0 new (spurious) migration files are produced.
- **Concurrent:** two migration generations run at once → the migration folder holds one coherent migration set with no partial, truncated, or garbled files.

## Dependencies

### Upstream (must be complete first)

- **[`STORY-02-02-01` — Author the Drizzle Schema](STORY-02-02-01-author-drizzle-schema.md):** provides the `db/schema.ts` the migration is generated from.
- **[`STORY-02-01-04` — Document Pooled & Unpooled Connections](../FEATURE-02-01/STORY-02-01-04-document-pooled-and-unpooled-connections.md):** documents the pooled-vs-unpooled split, including the unpooled `DATABASE_URL_UNPOOLED` this story consumes.
- **[`STORY-02-01-01` — Provision Neon Project & Production Branch](../FEATURE-02-01/STORY-02-01-01-provision-neon-project-and-production-branch.md):** provisions the Neon branch the migration is applied to and the encrypted connection secrets.
- `EPIC-01` provides the encrypted-secrets baseline that stores `DATABASE_URL_UNPOOLED` (cited by identifier).

### Downstream (informational — not a build prerequisite of this story)

- **[`STORY-02-02-03` — Create the Migration Rehearsal Workflow](STORY-02-02-03-create-migration-rehearsal-workflow.md):** its `migrate.yml` workflow applies this migration set on a Neon branch through the unpooled connection.
- `EPIC-06` integration tests run this migration set on the shared `dev-qa` Neon branch before each suite (cited by identifier).

## Story Estimation Guidance

- **Effort: Medium** — one `drizzle.config.ts`, one generated migration set, and one branch-apply verification, scoped to a fixed input (`db/schema.ts`) and a fixed output (9 enums, 20 tables).
- **Complexity: Medium** — the connection discipline (unpooled for DDL, never pooled), the fail-fast missing-variable guard, and the `UNIQUE NULLS NOT DISTINCT` PostgreSQL 15+ constraint each carry a defined failure mode that the configuration handles.
- **Uncertainty: Low–Medium** — the schema source and target counts are fixed, so the only open question is whether the existing local Neon connection reaches the branch through the unpooled endpoint, which [`STORY-02-01-04`](../FEATURE-02-01/STORY-02-01-04-document-pooled-and-unpooled-connections.md) resolves.
- **Fibonacci Story Points: 3** — the Medium effort and Medium complexity sit above a trivial 1–2; the Low–Medium uncertainty (fixed schema source, documented connection split) holds the estimate at 3 rather than 5. Points measure relative size, not a duration.

## Definition of Done

- [ ] `drizzle.config.ts` points migrations at the unpooled `DATABASE_URL_UNPOOLED` and never the pooled `DATABASE_URL`.
- [ ] The initial migration set generates from `db/schema.ts` and creates all 9 enums and all 20 tables.
- [ ] The migration applies on the `dev-qa` Neon branch through the unpooled `DATABASE_URL_UNPOOLED` with exit 0, and all 20 tables exist in the branch.
- [ ] The generated migration reproduces the `raw_listing UNIQUE (source, source_item_id)` and `valuation UNIQUE NULLS NOT DISTINCT (variation_id, grade_id, window_days, cost_basis)` constraints.
- [ ] The SQL generated from `db/schema.ts` is diffed against `docs/schema.sql` and reports 0 missing and 0 renamed enums, tables, constraints, indexes, and named columns before the migration is accepted.
- [ ] An absent `DATABASE_URL_UNPOOLED` fails with a named missing-variable error (exit non-zero) and writes no migration.
- [ ] Using the pooled `DATABASE_URL` for migrations is documented as a failure (mixing the pooled and unpooled connections breaks migrations).
- [ ] Re-generating against an unchanged `db/schema.ts` produces 0 new migration files.
- [ ] PostgreSQL 15+ is stated as the engine floor (required by `valuation`'s `UNIQUE NULLS NOT DISTINCT`).
- [ ] No prohibited vague quality term appears in any acceptance criterion; every criterion names a measurable pass/fail condition (an exact count, an exit code, a named constraint, or a named error).
- [ ] All relative links resolve: the parent feature index, the parent epic index, the sibling stories `STORY-02-02-01` and `STORY-02-02-03`, the `FEATURE-02-01` index, and the `FEATURE-02-01` stories `STORY-02-01-04` and `STORY-02-01-01`.
- [ ] **Testing:** the generated migration applies on the `dev-qa` Neon branch via the unpooled `DATABASE_URL_UNPOOLED` with exit 0 and all 20 tables present.
