# STORY-02-01-04: Document Pooled & Unpooled Connections

*Parent feature: [FEATURE-02-01 — Neon Project & Branching Topology](../FEATURE-02-01-neon-project-and-branching-topology.md) · Parent epic: [EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md)*

This is the fourth and final story of FEATURE-02-01. It documents the pooled-versus-unpooled connection-string discipline that every later database, ingestion, and test write depends on, and it verifies the existing local Neon connection by applying the full migration set and running the integration suite locally, recording the connection-error count and logging any gap as an open item. It builds on the Neon project and `production` branch from [STORY-02-01-01](STORY-02-01-01-provision-neon-project-and-production-branch.md) and the shared long-lived `dev-qa` branch documented in [STORY-02-01-02](STORY-02-01-02-configure-per-pr-preview-branches.md) and [STORY-02-01-03](STORY-02-01-03-configure-per-ci-ephemeral-branches.md); together they complete EPIC-02's hard prerequisite — Neon branching and connection discipline are established before any schema, migration, ingestion, or test write runs. This story does not provision the connection strings; it reads the encrypted secrets created in STORY-02-01-01 and documents the rule for using each.

## User Story

> As a **Database Engineer**, I want the pooled and unpooled connection strings documented and the existing local Neon connection verified, so that runtime and migration tooling use the correct connection and local-access gaps are recorded.

## Environment Access & Configuration

- **Canonical reference.** All environment provisioning for this story follows the Blitzy environments reference at <https://docs.blitzy.com/administration/environments>. Per that reference (informational — Blitzy cannot create environments), the single Blitzy environment is configured manually, build and run instructions are supplied in natural language, non-sensitive values are stored as **plaintext variables** and sensitive credentials are stored as **encrypted secrets**, and the environment is then **attached to the project**.
- **Connection strings (both stored as encrypted secrets).** Two connection strings are kept distinct and stored as encrypted secrets in **Blitzy**, then consumed by the Neon-connected runtime and migration tooling:
  - **Pooled `DATABASE_URL`** — the PgBouncer-pooled connection read at application **runtime**, where many short-lived serverless invocations share one bounded pool instead of exhausting raw Postgres connections.
  - **Unpooled `DATABASE_URL_UNPOOLED`** — the **direct** connection used for **DDL and migrations** (`drizzle-kit` and the `migrate.yml` rehearsal authored in FEATURE-02-02).
- **Mixing the two breaks migrations.** DDL and migrations run only on the unpooled `DATABASE_URL_UNPOOLED`; runtime reads run only on the pooled `DATABASE_URL`. Running a migration over the pooled `DATABASE_URL` is the documented failure mode — migrations break, because the pooled connection is not valid for DDL and migrations.
- **Driver stack.** The Neon serverless driver stack consumed by the runtime client is `@neondatabase/serverless` plus `ws`, on **Node `>=20.20.2`** (the application engine floor from the root `package.json`; the earlier `>=18` originated from the Apify actor's `apify/package.json`). The attached environment setup command `npm install @neondatabase/serverless ws` is recorded here as **content** for the access-layer feature (FEATURE-02-03) and is **not executed** by this documentation work.
- **Engine floor.** Both connection strings target a **PostgreSQL 15+** database; the `valuation` table's `UNIQUE NULLS NOT DISTINCT` constraint is rejected by any Postgres server below 15.
- **Source of the strings.** The pooled and unpooled connection strings are provisioned and stored as encrypted secrets in [STORY-02-01-01](STORY-02-01-01-provision-neon-project-and-production-branch.md); this story reads them and documents the usage rule rather than duplicating those provisioning steps.

### Platforms and access required

| Platform | Access required | Purpose in STORY-02-01-04 |
|----------|-----------------|---------------------------|
| Blitzy | The single Blitzy environment; plaintext variables and encrypted secrets | Confirm the pooled `DATABASE_URL` and the unpooled `DATABASE_URL_UNPOOLED` are stored as encrypted secrets per <https://docs.blitzy.com/administration/environments> |
| Neon | Pooled and unpooled connection strings for the `production` and `dev-qa` branches | Read the two connection strings to document the runtime-versus-migration rule and to verify the existing local Neon connection (local development uses the shared `dev-qa` branch) |

### Step-by-step configuration

1. Confirm in **Blitzy** that the pooled `DATABASE_URL` and the unpooled `DATABASE_URL_UNPOOLED` are each stored as **encrypted secrets** (with non-sensitive values stored as plaintext variables), per <https://docs.blitzy.com/administration/environments>, sourced from STORY-02-01-01.
2. Document the usage rule: runtime reads resolve the pooled `DATABASE_URL`; DDL and migrations resolve the unpooled `DATABASE_URL_UNPOOLED`; mixing the two breaks migrations.
3. Name the `@neondatabase/serverless` plus `ws` driver stack on Node `>=20.20.2` as the runtime connection driver, and record `npm install @neondatabase/serverless ws` as content (not executed here).
4. Verify the existing local Neon connection by applying the full migration set through the unpooled `DATABASE_URL_UNPOOLED` and running the integration suite through the pooled `DATABASE_URL`; record the connection-error count.
5. Log any local-access gap discovered in step 4 as an open item (see the Open Question / Note below).

## Acceptance Criteria

1. **(valid-output)** **Given** the documentation, **When** it is reviewed, **Then** it states the pooled `DATABASE_URL` is used at runtime and the unpooled `DATABASE_URL_UNPOOLED` is used for DDL and migrations.
2. **(error-handling)** **Given** the pooled `DATABASE_URL` is used for a migration, **When** the documented failure mode is described, **Then** it states migrations break — the pooled connection is not valid for DDL and migrations.
3. **(input-validation)** **Given** a missing or empty connection string, **When** the runtime or the migration tooling starts, **Then** it fails fast with a named error that identifies the absent variable — `DATABASE_URL` for the runtime or `DATABASE_URL_UNPOOLED` for migrations — and 0 queries run.
4. **(edge-case — local-Neon verification)** **Given** the existing local Neon connection, **When** the full migration set is applied and the integration suite is run locally, **Then** the connection-error count is recorded and any failure is recorded as an open item.
5. **(valid-output)** **Given** the documentation, **When** the driver stack is reviewed, **Then** it names `@neondatabase/serverless` plus `ws` on Node `>=20.20.2` as the runtime connection driver and records `npm install @neondatabase/serverless ws` as content that this story does not execute.
6. **(input-validation — secret storage)** **Given** the environment setup follows <https://docs.blitzy.com/administration/environments>, **When** the two connection strings are stored, **Then** the pooled `DATABASE_URL` and the unpooled `DATABASE_URL_UNPOOLED` are each stored as an **encrypted secret** and not as a plaintext variable; storing either as a plaintext variable fails review.

## Open Question / Note

> **Open verification item — local Neon connection.** The existing local Neon setup **"may or may not be enough"** for local development and test access. This uncertainty is preserved here, outside the acceptance criteria, and is resolved by the local-Neon verification criterion above: the full migration set is applied and the integration suite is run locally, the connection-error count is recorded, and any gap discovered is logged as an open item rather than assumed away. Until that verification pass runs, whether the local connection covers local development and test access remains an open item.

## Sub-tasks

- Document the pooled `DATABASE_URL` (runtime) versus unpooled `DATABASE_URL_UNPOOLED` (DDL and migrations) split and the "mixing breaks migrations" failure mode — `@database-engineer`
- Document the `@neondatabase/serverless` plus `ws` driver stack (Node `>=20.20.2`; `npm install @neondatabase/serverless ws` recorded as content, not executed) — `@database-engineer`
- Verify the existing local Neon connection by applying the full migration set and running the integration suite locally; record the connection-error count — `@database-engineer`
- Record any local-access gap as an open item — `@platform-engineer`
- Confirm both connection strings are stored as encrypted secrets per <https://docs.blitzy.com/administration/environments> — `@platform-engineer`

## Edge Cases

- **Empty/Null:** a missing or empty connection string → the runtime or migration tooling fails fast with a named error that identifies the absent variable (`DATABASE_URL` or `DATABASE_URL_UNPOOLED`).
- **Invalid:** the pooled `DATABASE_URL` is used where the unpooled `DATABASE_URL_UNPOOLED` is required → migrations break (the documented failure mode).
- **Boundary:** the local connection is verified against the **full migration set**, not a single statement, so a partial-migration pass does not stand in for a full-set verification.
- **Concurrent:** the pooled `DATABASE_URL` is exercised under concurrent runtime queries — the pooled path is the connection used for concurrent serverless access, and the unpooled `DATABASE_URL_UNPOOLED` is never placed on that path.

## Dependencies

### Upstream (must be complete first)

- **[STORY-02-01-01 — Provision the Neon Project & Production Branch](STORY-02-01-01-provision-neon-project-and-production-branch.md):** provisions the pooled and unpooled connection strings and stores them as encrypted secrets; this story reads them and documents the usage rule.
- **`EPIC-01` — Environment & Configuration Foundation:** supplies the Blitzy environments and the secrets baseline into which both connection strings are stored. Cited cross-epic by identifier.

### Downstream (informational — not a build prerequisite of this story)

- **`FEATURE-02-02` — Drizzle Schema & Migrations:** its migrations, and `STORY-02-02-03`'s `migrate.yml` rehearsal, run on the unpooled `DATABASE_URL_UNPOOLED` documented here. Cited by identifier.
- **`FEATURE-02-03` — Data Access Layer & Seed Data:** its runtime access layer (the `@neondatabase/serverless` plus `ws` client) reads the pooled `DATABASE_URL` documented here. Cited by identifier.

### Sibling stories

- **[STORY-02-01-02 — Configure Preview Deployments Against the Shared Dev/QA Branch](STORY-02-01-02-configure-per-pr-preview-branches.md)** and **[STORY-02-01-03 — Configure CI Against the Shared Dev/QA Branch](STORY-02-01-03-configure-per-ci-ephemeral-branches.md):** the `dev-qa` branch connection strings those stories expose follow the same pooled-versus-unpooled rule documented in this story.

## Story Estimation Guidance

- **Effort: Low–Medium** — the work is documentation plus a single local verification pass (apply the full migration set, run the integration suite, record the connection-error count), which exceeds a one-line edit but stays short of multi-system wiring.
- **Complexity: Low** — the pooled-versus-unpooled rule and the driver stack are fixed by the upstream provisioning in STORY-02-01-01; this story records the rule and runs one verification rather than designing new behavior.
- **Uncertainty: Medium** — the local-environment unknown (whether the existing local Neon connection covers local development and test access) is unresolved until the verification pass runs and the connection-error count is recorded.
- **Fibonacci Story Points: 3.** The single local-environment unknown lifts this above a 1; the fixed connection rule and the documentation-plus-one-verification scope hold it below a 5. Points measure relative size, not a duration.

## Definition of Done

- [ ] The pooled-versus-unpooled discipline is documented — runtime reads use the pooled `DATABASE_URL`, DDL and migrations use the unpooled `DATABASE_URL_UNPOOLED` — including the "mixing breaks migrations" failure mode.
- [ ] The `@neondatabase/serverless` plus `ws` driver stack on Node `>=20.20.2` is named, with `npm install @neondatabase/serverless ws` recorded as content and not executed by this documentation work.
- [ ] The PostgreSQL 15+ engine floor is stated, anchored to the `valuation` table's `UNIQUE NULLS NOT DISTINCT` constraint.
- [ ] Both connection strings are confirmed stored as encrypted secrets per <https://docs.blitzy.com/administration/environments>, not as plaintext variables, sourced from STORY-02-01-01.
- [ ] The existing local Neon connection has been verified by applying the full migration set and running the integration suite locally, with the connection-error count and any gap recorded as an open item.
- [ ] The Open Question / Note preserves the local-Neon uncertainty (the user's open verification item) outside the acceptance criteria.
- [ ] No prohibited vague quality term appears in any acceptance criterion; every criterion names a measurable pass/fail condition (an exact variable name, a named error, an error count, or "encrypted secret" versus "plaintext variable").
- [ ] All relative links resolve: the parent feature index, the parent epic index, and the sibling stories STORY-02-01-01, STORY-02-01-02, and STORY-02-01-03.
- [ ] **Testing:** The pooled/unpooled documentation is validated against a real migration (unpooled) and a runtime query (pooled), and the local-Neon verification result (pass/fail plus any gap) is recorded as an open item.
