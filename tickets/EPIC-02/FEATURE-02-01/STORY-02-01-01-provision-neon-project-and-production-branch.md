# STORY-02-01-01: Provision the Neon Project & Production Branch

*Parent feature: [FEATURE-02-01 — Neon Project & Branching Topology](../FEATURE-02-01-neon-project-and-branching-topology.md) · Parent epic: [EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md)*

This is the first and foundational story of FEATURE-02-01. It provisions the CompVault Neon Postgres project on **PostgreSQL 15+**, generates a **Neon API key** carrying branch-create permission, creates the **protected `production` branch**, and stores the production **pooled `DATABASE_URL`** and **unpooled `DATABASE_URL_UNPOOLED`** as **encrypted secrets** in Blitzy. The `production` branch is marked **protected** so it cannot be accidentally deleted or reset, and child branches of a protected production branch receive isolated credentials. A Neon branch is a copy-on-write clone of its parent, so the `production` branch created here is the source of truth from which the single long-lived `dev-qa` branch is cloned ([STORY-02-01-02](STORY-02-01-02-configure-per-pr-preview-branches.md) and [STORY-02-01-03](STORY-02-01-03-configure-per-ci-ephemeral-branches.md) document how Vercel Preview deployments, CI, migration rehearsal, and local development all share that one `dev-qa` branch). This is the **hard upstream prerequisite** for the rest of EPIC-02, for `EPIC-03` data writes, and for `EPIC-06`'s `dev-qa` test branch; the pooled-versus-unpooled connection discipline this story establishes is documented in detail in [STORY-02-01-04](STORY-02-01-04-document-pooled-and-unpooled-connections.md).

## User Story

> As a **Platform Engineer**, I want a Neon project (PostgreSQL 15+) with an API key and a production branch, so that the application has a managed, branch-capable production database.

## Environment Access & Configuration

- **Canonical reference.** All environment provisioning for this story follows the Blitzy environments reference at <https://docs.blitzy.com/administration/environments>. Per that reference (informational — Blitzy cannot create environments), the single Blitzy environment is configured manually, build and run instructions are supplied in natural language, non-sensitive values are stored as **plaintext variables** and sensitive credentials are stored as **encrypted secrets**, and the environment is then **attached to the project**.
- **Neon.** Create the Neon project on **PostgreSQL 15+**; generate a **Neon API key** carrying branch-create permission (to clone the `dev-qa` branch from `production`); create the **protected `production` branch**; and retrieve the production branch's **pooled** connection string and its **unpooled / direct** connection string.
- **Blitzy.** Store the pooled `DATABASE_URL`, the unpooled `DATABASE_URL_UNPOOLED`, and the Neon API key as **encrypted secrets** — never as plaintext variables. Non-sensitive values, such as the Neon region or the project name, MAY be stored as **plaintext variables**. Then **attach the environment to the project**.
- **Engine floor — PostgreSQL 15+.** The Neon project MUST run **PostgreSQL 15 or newer**, because the `valuation` table declares `UNIQUE NULLS NOT DISTINCT (variation_id, grade_id, window_days, cost_basis)` — a constraint introduced in PostgreSQL 15 that keeps digital rows (where `grade_id` is NULL) unique. Any Postgres server below 15 rejects this constraint.
- **Pooled vs unpooled (named here, detailed in STORY-02-01-04).** The production branch exposes two connection strings: the **pooled `DATABASE_URL`** (PgBouncer-pooled, read at application **runtime**) and the **unpooled `DATABASE_URL_UNPOOLED`** (direct, used for **DDL and migrations**). Both are stored as encrypted secrets here; the full runtime-versus-migration usage rule is documented in [STORY-02-01-04](STORY-02-01-04-document-pooled-and-unpooled-connections.md).

### Platforms and access required

| Platform | Access required | Purpose in STORY-02-01-01 |
|----------|-----------------|---------------------------|
| Blitzy | The single Blitzy environment; plaintext variables and encrypted secrets | Store the pooled `DATABASE_URL`, the unpooled `DATABASE_URL_UNPOOLED`, and the Neon API key as encrypted secrets per <https://docs.blitzy.com/administration/environments> |
| Neon | Project plus an API key carrying branch-create permission; the protected `production` branch; pooled and unpooled connection strings | Provision the project on PostgreSQL 15+, create the production branch, and expose both the pooled and unpooled connection strings |

### Step-by-step configuration (complete before dependent work begins)

1. Create the Neon project on **PostgreSQL 15+**, and confirm the reported Postgres version is 15 or higher so the `valuation` `UNIQUE NULLS NOT DISTINCT` constraint is supported.
2. Generate the **Neon API key** carrying branch create and delete permission, and store it as an **encrypted secret** per <https://docs.blitzy.com/administration/environments>.
3. Create and confirm the **protected `production` branch** as the single long-lived parent branch (mark it protected to prevent accidental deletes/resets).
4. Retrieve the production branch's **pooled** connection string (`DATABASE_URL`) and its **unpooled** connection string (`DATABASE_URL_UNPOOLED`).
5. Store both connection strings as **encrypted secrets** in Blitzy (not plaintext variables), with non-sensitive values such as the region or project name stored as plaintext variables, per <https://docs.blitzy.com/administration/environments>.
6. **Attach the environment to the project**, and record the selected region and compute size as named values.

## Acceptance Criteria

1. **(valid-output)** **Given** the Neon project, **When** the production branch is queried for its Postgres version, **Then** it reports 15 or higher.
2. **(valid-output)** **Given** the production branch, **When** its pooled and unpooled connection strings are retrieved, **Then** both are stored as encrypted secrets in Blitzy (not plaintext variables).
3. **(input-validation)** **Given** a requested Postgres version below 15, **When** provisioning is validated, **Then** it is rejected with a named version-floor error citing the PostgreSQL 15+ requirement.
4. **(error-handling)** **Given** an invalid or absent Neon API key, **When** a branch operation is attempted, **Then** it fails with a named authentication error and 0 branches are created.
5. **(edge-case)** **Given** the production branch, **When** the `dev-qa` branch is later created, **Then** the `production` branch is its copy-on-write parent.
6. **(valid-output)** **Given** the project-creation request, **When** the Neon project is provisioned, **Then** the selected region and compute size are recorded as named values, not left as unrecorded defaults.
7. **(valid-output)** **Given** the production branch, **When** it is identified, **Then** it carries the deterministic name `production` and exactly 1 production branch exists as the single long-lived parent.

## Sub-tasks

- Create the Neon project on PostgreSQL 15+ — `@platform-engineer`
- Generate the Neon API key carrying branch create and delete permission and store it as an encrypted secret per <https://docs.blitzy.com/administration/environments> — `@platform-engineer`
- Create and confirm the protected `production` branch (marked protected) — `@platform-engineer`
- Retrieve the pooled `DATABASE_URL` and the unpooled `DATABASE_URL_UNPOOLED` and store both as encrypted secrets in Blitzy — `@devops-engineer`
- Attach the environment to the project and record the region and compute selection — `@devops-engineer`

## Edge Cases

- **Empty/Null:** the Neon API key is missing or empty → branch operations fail fast with a named authentication error and 0 branches are created.
- **Invalid:** a Postgres version below 15 is requested → the request is rejected with the named version-floor error citing the PostgreSQL 15+ requirement.
- **Boundary:** the project region and compute size are recorded at creation as named values — a defined selection, not an unrecorded default.
- **Concurrent:** two provisioning attempts run at the same time → 0 duplicate projects are created; one project exists and the second attempt detects the existing project.

## Dependencies

### Upstream (must be complete first)

- **`EPIC-01` — Environment & Configuration Foundation:** supplies the Blitzy environments and the secrets baseline. Specifically, the secret-storage step `STORY-01-01-02` is where the encrypted secrets this story produces — the Neon API key, the pooled `DATABASE_URL`, and the unpooled `DATABASE_URL_UNPOOLED` — are stored. Cited cross-epic by identifier.

### Downstream (informational — not a build prerequisite of this story)

- Sibling stories — every other FEATURE-02-01 story branches from the production branch created here:
  - **[STORY-02-01-02 — Configure Preview Deployments Against the Shared Dev/QA Branch](STORY-02-01-02-configure-per-pr-preview-branches.md):** documents how Vercel Preview (dev/qa) deployments share the single long-lived `dev-qa` branch cloned from this `production` branch.
  - **[STORY-02-01-03 — Configure CI Against the Shared Dev/QA Branch](STORY-02-01-03-configure-per-ci-ephemeral-branches.md):** documents how CI runs against the single long-lived `dev-qa` branch cloned from this `production` branch.
  - **[STORY-02-01-04 — Document Pooled & Unpooled Connections](STORY-02-01-04-document-pooled-and-unpooled-connections.md):** reads the pooled and unpooled connection strings provisioned here and documents the runtime-versus-migration usage rule.
- Cross-epic consumers (cited by identifier): all of `EPIC-02` schema, migration, and seed work runs against this project and production branch; `EPIC-03` data writes target these branches through the pooled `DATABASE_URL`; and `EPIC-06`'s `dev-qa` test branch (`STORY-06-01-03`) targets the shared `dev-qa` branch cloned from this `production` branch.

## Story Estimation Guidance

- **Effort: Medium** — the work spans Neon project creation, API key generation, production branch creation, and storing three encrypted secrets in Blitzy, which exceeds a single-step edit but stays short of multi-system implementation.
- **Complexity: Low–Medium** — the steps follow the fixed Neon provisioning path and the canonical Blitzy environments procedure; the one branching concern is keeping the pooled and unpooled strings distinct.
- **Uncertainty: Low** — the provisioning path is fixed and documented, and no integration wiring or unresolved unknown gates this story (the local-Neon question is carried by [STORY-02-01-04](STORY-02-01-04-document-pooled-and-unpooled-connections.md), not here).
- **Fibonacci Story Points: 3.** The multi-secret provisioning lifts this above a 1; the fixed provisioning path and the absence of integration unknowns hold it below a 5. Points measure relative size, not a duration.

## Definition of Done

- [ ] The Neon project is provisioned on PostgreSQL 15+, anchored to the `valuation` table's `UNIQUE NULLS NOT DISTINCT` constraint that requires PostgreSQL 15 or newer.
- [ ] A Neon API key exists and is stored as an encrypted secret per <https://docs.blitzy.com/administration/environments>.
- [ ] The protected `production` branch exists as the single long-lived parent branch (marked protected to prevent accidental deletes/resets).
- [ ] The pooled `DATABASE_URL` and the unpooled `DATABASE_URL_UNPOOLED` are stored as encrypted secrets in Blitzy (not plaintext variables) per <https://docs.blitzy.com/administration/environments>.
- [ ] The environment is attached to the project, with the selected region and compute size recorded as named values.
- [ ] The pooled-versus-unpooled split is named (pooled `DATABASE_URL` for runtime, unpooled `DATABASE_URL_UNPOOLED` for DDL and migrations), with the detailed discipline deferred to [STORY-02-01-04](STORY-02-01-04-document-pooled-and-unpooled-connections.md).
- [ ] No prohibited vague quality term appears in any acceptance criterion; every criterion names a measurable pass/fail condition (an exact version number, a named error, a branch count, or "encrypted secret" versus "plaintext variable").
- [ ] All relative links resolve: the parent feature index, the parent epic index, and the sibling stories STORY-02-01-02, STORY-02-01-03, and STORY-02-01-04.
- [ ] **Testing:** A connection to the production branch succeeds, reports PostgreSQL 15 or higher, and both connection strings are confirmed stored as encrypted secrets per <https://docs.blitzy.com/administration/environments>.
