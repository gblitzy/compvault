# STORY-02-03-01: Implement the Pooled Neon Client

Feature: [FEATURE-02-03](../FEATURE-02-03-data-access-layer-and-seed-data.md) · Epic: [EPIC-02](../../EPIC-02-database-platform-and-schema.md)

## User Story

> As a Backend Engineer, I want a pooled Neon database client that reads the pooled DATABASE_URL at runtime, so that the application issues queries over a connection-pooled, serverless-safe driver.

## Connection & Environment Note

The pooled `DATABASE_URL` secret is provisioned per [FEATURE-02-01 — Neon Project & Branching Topology](../FEATURE-02-01-neon-project-and-branching-topology.md) (documented per <https://docs.blitzy.com/administration/environments>; the connection string itself is detailed in [STORY-02-01-04](../FEATURE-02-01/STORY-02-01-04-document-pooled-and-unpooled-connections.md)), so this story does not duplicate that per-epic environment-access feature. The client (`db/client.ts`) uses the `@neondatabase/serverless` + `ws` driver stack on Node `>=20.20.2` (the application engine floor from the root `package.json`; the earlier `>=18` originated from the Apify actor's `apify/package.json`) and reads the pooled `DATABASE_URL` at runtime — never the unpooled `DATABASE_URL_UNPOOLED`, which is reserved for DDL and migrations under `FEATURE-02-02`; the command `npm install @neondatabase/serverless ws` is named here as content, not executed by this documentation ticket.

## Acceptance Criteria

1. **(input-validation)** **Given** `DATABASE_URL` is unset or an empty string, **When** the `db/client.ts` module initializes, **Then** it throws a named configuration error before any query is issued and opens 0 connections.
2. **(valid-output)** **Given** a valid pooled `DATABASE_URL`, **When** a `SELECT 1` health query runs through the client, **Then** it returns 1 row with 0 connection errors.
3. **(valid-output)** **Given** the `db/client.ts` module, **When** its dependencies are inspected, **Then** it reads the pooled `DATABASE_URL` and wires the `ws` WebSocket dependency the `@neondatabase/serverless` driver requires, with 0 references to the unpooled `DATABASE_URL_UNPOOLED`.
4. **(error-handling)** **Given** an unreachable database host, **When** a query runs through the client, **Then** the client surfaces a named connection error after a bounded retry count of 3 attempts and returns control rather than retrying without bound.
5. **(edge-case)** **Given** the unpooled `DATABASE_URL_UNPOOLED` is supplied as the runtime connection string, **When** the client initializes, **Then** the misconfiguration is flagged with a named error because the runtime path requires the pooled `DATABASE_URL`.
6. **(edge-case)** **Given** more than one serverless invocation, **When** they query concurrently through `db/client.ts`, **Then** they share the single exported pooled client instance and open no more than the pool's bounded connection count.
7. **(valid-output)** **Given** the query helpers exported by `db/client.ts`, **When** their read and write paths are inspected, **Then** every path executes through Drizzle ORM or a parameterized driver call, 0 paths build SQL by string concatenation, and a static check (or test) confirms 0 string-concatenated SQL statements.

## Sub-tasks

- Implement `db/client.ts` as a single shared module that reads the pooled `DATABASE_URL` and exports one reusable pooled client built on `@neondatabase/serverless` + `ws` — `@backend-engineer`
- Add a fail-fast guard that throws a named configuration error before any query is issued when `DATABASE_URL` is absent or an empty string — `@backend-engineer`
- Wire the `ws` WebSocket dependency the `@neondatabase/serverless` driver requires and confirm a `SELECT 1` health query returns 1 row with 0 connection errors — `@backend-engineer`
- Bound connection-failure handling to a retry count of 3 attempts so an unreachable host surfaces a named error and does not retry without bound — `@backend-engineer`
- Document that the unpooled `DATABASE_URL_UNPOOLED` is not read at runtime (it is reserved for DDL and migrations under `FEATURE-02-02`) and flag its use as the runtime connection string as a misconfiguration — `@devops-engineer`
- Route every read and write exposed by `db/client.ts` through Drizzle ORM or parameterized driver calls, build 0 SQL strings by concatenation, and add a static check (or test) that fails on any string-concatenated SQL — `@backend-engineer`

## Edge Cases

- **Empty/Null:** `DATABASE_URL` is missing or an empty string → the client throws a named configuration error before any query and opens 0 connections.
- **Invalid:** a malformed connection string (for example, a value missing the `postgres://` scheme or the host segment) → initialization fails with a named error and is not retried as a transient fault.
- **Boundary:** connection-pool saturation under concurrent queries → the pooled client holds connections to the pool's bounded maximum and queues further work rather than exhausting the pool.
- **Concurrent:** more than one serverless invocation imports `db/client.ts` at the same time → each shares the single exported pooled client instance and opens no more than the pool's bounded connection count.

## Dependencies

### Upstream (must be complete first)

- **`EPIC-01`** (by identifier): the encrypted-secrets baseline that holds the `DATABASE_URL` secret this client reads at runtime.
- **[STORY-02-01-01 — Provision the Neon Project & Production Branch](../FEATURE-02-01/STORY-02-01-01-provision-neon-project-and-production-branch.md):** provisions the Neon project and production branch the client connects to.
- **[STORY-02-01-04 — Document Pooled & Unpooled Connections](../FEATURE-02-01/STORY-02-01-04-document-pooled-and-unpooled-connections.md):** documents the pooled `DATABASE_URL` (and the unpooled `DATABASE_URL_UNPOOLED` reserved for migrations) that this client reads.
- **`FEATURE-02-02`** (by identifier): the Drizzle schema and applied migrations, so real catalog and sales queries through this client resolve against existing tables.

### Downstream (informational — not a build prerequisite of this story)

- **`EPIC-04`** (by identifier): the Backend Application & API threads its request-handler queries through this pooled client.
- **[STORY-02-03-02 — Implement the getUserId Seam](STORY-02-03-02-implement-getuserid-seam.md):** reads the operator `app_user` row through the database this client connects to.
- **[STORY-02-03-03 — Author the Catalog Seed Script](STORY-02-03-03-author-catalog-seed-script.md):** writes the baseline catalog through the pooled client this story exports.

## Story Estimation Guidance

- **Effort: Low–Medium** — one shared module that reads one secret, exports one pooled client, and adds a fail-fast guard plus a bounded-retry path; no schema change and no new platform access.
- **Complexity: Low** — a single connection-pool setup over a fixed driver stack (`@neondatabase/serverless` + `ws`), one configuration guard, and one bounded-retry rule, with no business logic in the client.
- **Uncertainty: Low** — the driver stack, the pooled `DATABASE_URL`, and the Node `>=20.20.2` floor are fixed inputs, and a `SELECT 1` health query is a known check, so the target is defined.
- **Fibonacci Story Points: 3** — Low–Medium effort with Low complexity and Low uncertainty place the estimate at 3; the fail-fast guard, the bounded-retry path, and the pooled-versus-unpooled discipline hold it above a 2. Points measure relative size, not a duration.

## Definition of Done

- [ ] `db/client.ts` is a single shared module that reads the pooled `DATABASE_URL` using `@neondatabase/serverless` + `ws` on Node `>=20.20.2` and exports one reusable pooled client.
- [ ] A missing or empty `DATABASE_URL` throws a named configuration error before any query is issued and opens 0 connections.
- [ ] A `SELECT 1` health query through the client returns 1 row with 0 connection errors.
- [ ] The `ws` WebSocket dependency the `@neondatabase/serverless` driver requires is wired, and the client reads the pooled `DATABASE_URL` with 0 references to the unpooled `DATABASE_URL_UNPOOLED`.
- [ ] An unreachable host surfaces a named connection error after a bounded retry count of 3 attempts and does not retry without bound.
- [ ] Supplying the unpooled `DATABASE_URL_UNPOOLED` as the runtime connection string is documented as a flagged misconfiguration (the runtime path requires the pooled `DATABASE_URL`).
- [ ] Concurrent serverless invocations share the single exported pooled client instance and open no more than the pool's bounded connection count.
- [ ] Every read and write exposed by `db/client.ts` executes through Drizzle ORM or parameterized driver calls, with 0 string-concatenated SQL, and a static check (or test) confirms 0 string-concatenated SQL statements.
- [ ] No prohibited vague quality term appears in any acceptance criterion; every criterion names a measurable pass/fail condition (a named error, "1 row", "0 connection errors", or "3 attempts").
- [ ] All relative links resolve: the parent feature index, the parent epic index, the `FEATURE-02-01` stories `STORY-02-01-01` and `STORY-02-01-04`, and the sibling stories `STORY-02-03-02` and `STORY-02-03-03`; `EPIC-01`, `EPIC-04`, and `FEATURE-02-02` are cited by plain identifier.
- [ ] **Testing:** an integration test on a Neon branch opens the pooled client, runs a `SELECT 1` health query returning 1 row, and asserts that a missing `DATABASE_URL` throws a named error before any query is issued.
