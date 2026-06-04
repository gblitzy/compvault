# FEATURE-06-02: Unit & Integration Suites

*Parent epic: [EPIC-06 — Testing & CI/CD Quality Gates](../EPIC-06-testing-and-cicd-quality-gates.md)*

## Feature Summary

This feature authors the three layered automated test suites that prove CompVault's parsing, API, and ingestion-helper logic against measurable coverage bars: fast pure-function unit tests for the title parsers, the input validators, and the confidence/score logic; database-backed API integration tests that run schema migrations against an isolated per-CI Neon branch before exercising the route handlers; and Apify-helper tests for the actor's `extractItemId`, `parsePrice`, and `parseSoldDate` functions against HTML and string fixtures. The business value is a documented, layered safety net that catches parsing, contract, and ingestion regressions at the suite closest to the defect and fails the build when line coverage drops below each suite's named threshold. Scope is limited to authoring the suites; the single Vitest configuration, the `__fixtures__`, and the boundary mocks are delivered by [FEATURE-06-01 — Test Harness & Environment Access](FEATURE-06-01-test-harness-and-environment-access.md), and the coverage and secret-presence gates that block merges are enforced by [FEATURE-06-03 — CI/CD Pipeline & Quality Gates](FEATURE-06-03-cicd-pipeline-and-quality-gates.md).

## Environment Access & Configuration

The API integration suite (STORY-06-02-02) is the one suite that reaches an external service: it consumes the **per-CI Neon branch** connection string injected as the test `DATABASE_URL`, configured per the canonical Blitzy environments reference <https://docs.blitzy.com/administration/environments> and realized in [FEATURE-06-01 — Test Harness & Environment Access](FEATURE-06-01-test-harness-and-environment-access.md) (specifically STORY-06-01-03, which provisions the branch and runs migrations against it using the unpooled `DATABASE_URL_UNPOOLED` for DDL). The `valuation` table's `UNIQUE NULLS NOT DISTINCT` constraint requires the branch to run PostgreSQL 15+. The unit suite (STORY-06-02-01) and the Apify-helper suite (STORY-06-02-03) run on Node `>=18` with no external service, reading only the `__fixtures__` and boundary mocks from FEATURE-06-01. The full environment provisioning steps are not duplicated here; they live in [FEATURE-06-01 — Test Harness & Environment Access](FEATURE-06-01-test-harness-and-environment-access.md) and the parent [EPIC-06 — Testing & CI/CD Quality Gates](../EPIC-06-testing-and-cicd-quality-gates.md).

## User Stories Index

This feature is delivered through three stories. Each link is relative to this file inside the `EPIC-06/` directory.

1. **[STORY-06-02-01 — Author Unit Tests (Parsers, Validators, Score)](FEATURE-06-02/STORY-06-02-01-author-unit-tests-parsers-validators-score.md)** — author unit tests for the EPIC-03 title parsers, the input validators, and the confidence/score logic; line coverage target **≥90%**. Runs on Node `>=18` with no external service.
2. **[STORY-06-02-02 — Author Integration Tests (API Routes)](FEATURE-06-02/STORY-06-02-02-author-integration-tests-api-routes.md)** — author API route integration tests executed against a per-CI Neon branch with migrations applied first, exercising the `docs/schema.sql` entities the routes read and write (`character`/`card`/`card_character` search, `variation`/`parallel_type` two-column digital|physical results, `sale_observation` sales, `valuation` price-history with `window_days` 90 and 365, and the `review_queue`); line coverage target **≥75%**.
3. **[STORY-06-02-03 — Author Apify Helper Tests](FEATURE-06-02/STORY-06-02-03-author-apify-helper-tests.md)** — author unit tests for the actor helpers `extractItemId`, `parsePrice`, and `parseSoldDate` from `apify/src/main.js` against HTML and string fixtures (cards `li.s-item` / `li.s-card`); line coverage target **≥90%**.

## Dependencies

### Upstream (must be complete first)

- **EPIC-01 — Environment & Configuration Foundation:** supplies the Blitzy environment, the Next.js + TypeScript scaffold, and the secrets baseline the suites run within.
- **[FEATURE-06-01 — Test Harness & Environment Access](FEATURE-06-01-test-harness-and-environment-access.md):** supplies the single Vitest configuration, the `__fixtures__` (eBay/LLM JSON, Apify HTML), the boundary mocks, and the per-CI Neon branch wiring. STORY-06-02-02 depends on STORY-06-01-03, which in turn depends on EPIC-02 branching (`STORY-02-01-*`).
- **EPIC-02 — Database Platform & Schema:** supplies the `docs/schema.sql`-derived Drizzle schema and the Neon branch the integration suite migrates and queries; the `valuation` table's `UNIQUE NULLS NOT DISTINCT` constraint requires PostgreSQL 15+.
- **EPIC-03 — Data Ingestion Pipeline:** supplies the title parsers, the confidence-gated matcher, and the score logic that the unit suite (STORY-06-02-01) exercises.
- **EPIC-04 — Backend Application & API:** supplies the API route handlers that the integration suite (STORY-06-02-02) exercises.

### Downstream (informational — not a build prerequisite of this feature)

- **[FEATURE-06-03 — CI/CD Pipeline & Quality Gates](FEATURE-06-03-cicd-pipeline-and-quality-gates.md):** invokes these suites from `ci.yml`, enforces their coverage thresholds (parsers/validators/score **≥90%**, API/jobs **≥75%**, Apify helpers **≥90%**; UI **≥50%** is owned by EPIC-05), and blocks merges that fall below them.

## Definition of Done

- [ ] All 3 stories (STORY-06-02-01, STORY-06-02-02, STORY-06-02-03) are complete.
- [ ] Unit tests for the title parsers, the input validators, and the confidence/score logic pass with line coverage **≥90%**.
- [ ] API integration tests pass against a per-CI Neon branch with migrations applied first, with line coverage **≥75%**, configured per <https://docs.blitzy.com/administration/environments>.
- [ ] Apify helper tests for `extractItemId`, `parsePrice`, and `parseSoldDate` (from `apify/src/main.js`) pass against HTML and string fixtures with line coverage **≥90%**.
- [ ] Each of the three suites includes at least one input-validation test, one valid-output test, one error-handling test, and one edge-case test.
- [ ] The integration suite's dependency on the per-CI Neon branch (FEATURE-06-01 STORY-06-01-03, gated by EPIC-02 `STORY-02-01-*`) is recorded in STORY-06-02-02.
- [ ] No prohibited vague quality term appears in any acceptance criterion; every criterion states a measurable pass/fail condition.
- [ ] **Testing:** all three suites run green under `vitest run` and report line coverage at or above their named thresholds (**≥90%** unit, **≥75%** API integration, **≥90%** Apify helpers).
