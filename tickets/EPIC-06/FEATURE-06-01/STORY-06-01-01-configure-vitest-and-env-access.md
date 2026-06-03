# STORY-06-01-01: Configure Vitest & Environment Access

*Parent feature: [FEATURE-06-01 — Test Harness & Environment Access](../FEATURE-06-01-test-harness-and-environment-access.md) · Parent epic: [EPIC-06 — Testing & CI/CD Quality Gates](../../EPIC-06-testing-and-cicd-quality-gates.md)*

This is the first and foundational story of FEATURE-06-01. It stands up the single Vitest harness that every later EPIC-06 suite runs on, and it completes EPIC-06's mandatory environment access. The sibling stories — fixtures and boundary mocks ([STORY-06-01-02](STORY-06-01-02-establish-fixtures-and-boundary-mocks.md)) and the per-CI Neon-branch wiring ([STORY-06-01-03](STORY-06-01-03-wire-integration-tests-to-neon-branch.md)) — build on the harness configured here.

## User Story

As a **Platform Engineer**, I want Vitest configured to run both the TypeScript application and the JavaScript ES-module Apify actor under Node `>=18` with environment access set up, so that every later EPIC-06 suite has one deterministic, documented place to run before any other EPIC-06 work proceeds.

## Environment Access & Configuration

All environment provisioning for this story follows the canonical Blitzy environments reference: <https://docs.blitzy.com/administration/environments>. Per that reference, an environment is created for each target, build and run instructions are supplied in natural language, non-sensitive values are stored as plaintext environment variables and credentials are stored as encrypted secrets, and the environment is then attached to the project. This configuration is finished in full **before** `vitest run` executes.

**Runtime floor:** Node `>=18` for both the TypeScript application and the JavaScript Apify actor under test, matching the actor's `engines.node` declaration in `apify/package.json`. The CI runner pins the project Node version at or above this floor so one Vitest invocation exercises both targets on a single runtime.

### Platforms and access required

| Platform | Access required | Purpose in STORY-06-01-01 |
|----------|-----------------|---------------------------|
| Blitzy | Environment per target; plaintext variables and encrypted secrets | Store the test `DATABASE_URL` and CI credentials as encrypted secrets per <https://docs.blitzy.com/administration/environments> |
| Neon | Connection string of the per-CI ephemeral test branch | Supplies the value the harness reads as the test `DATABASE_URL`; the branch lifecycle is owned by STORY-06-01-03 and depends on EPIC-02 `STORY-02-01-*` (referenced here, not duplicated) |
| GitHub Actions | CI runners; encrypted repository or organization secrets | Run `vitest run` on every pull request and inject the secrets the harness consumes |

### Step-by-step configuration (complete before `vitest run`)

1. Create the Blitzy environment for the target per <https://docs.blitzy.com/administration/environments>.
2. Add non-sensitive values as plaintext variables, and add credentials — the test `DATABASE_URL` among them — as encrypted secrets.
3. Attach the environment to the project so the harness reads the variables and secrets at run time.
4. Confirm the runner reports a Node version of 18.0.0 or higher for both the TypeScript application and the JavaScript actor.
5. Run `vitest run` to execute the configured harness across both targets.

## Acceptance Criteria

1. **(input-validation)** Given a Node runtime below 18 (for example Node 16.20.2), When harness setup runs, Then setup exits with a non-zero code and emits a message that names the `>=18` engine floor and the detected version.
2. **(valid-output)** Given Node `>=18` and a test set in which every test passes, When `vitest run` executes, Then it discovers and runs at least one test in the TypeScript application and at least one test that imports the JavaScript Apify actor's side-effect-free helper boundary, and the process exits with code 0.
3. **(error-handling)** Given the test `DATABASE_URL` is unset, When the harness reaches database-dependent tests, Then execution halts before those tests run and the log names the missing `DATABASE_URL` variable.
4. **(edge-case)** Given the Apify actor's side-effect-free ES-module helper boundary (`"type": "module"` in `apify/package.json`) is imported under Vitest, When a test loads that boundary, Then it resolves with 0 CommonJS transform errors AND triggers 0 actor side effects — `Actor.init()`, `Actor.getInput()`, the `searchTerms` validation, and `crawler.run()` do not execute during import.
5. **(edge-case)** Given 0 test files match the configured globs, When `vitest run` executes, Then it reports `no test files found` and exits with the configured non-zero code rather than reporting a passing run.
6. **(error-handling)** Given a malformed Vitest configuration file, When `vitest run` starts, Then the runner exits with a non-zero code and emits a message that names the configuration parse failure.

## Sub-tasks

- Configure Vitest to include BOTH the TypeScript application globs AND the JavaScript actor (`apify/`) ESM globs in one configuration, so the actor's side-effect-free helper boundary is discovered without loading the side-effectful `apify/src/main.js` entrypoint — `@platform-engineer`
- Document the Node `>=18` engine assertion that fails setup on a runtime below 18 — `@platform-engineer`
- Document environment access citing <https://docs.blitzy.com/administration/environments> across Blitzy, Neon, and GitHub Actions — `@test-engineer`
- Document the required-variable guard that halts execution before database-dependent tests when the test `DATABASE_URL` is unset — `@test-engineer`
- Verify the actor's side-effect-free ES-module helper boundary resolves under Vitest with 0 CommonJS transform errors and 0 actor side effects (no `Actor.init()`, `Actor.getInput()`, `searchTerms` validation, or `crawler.run()` on import); coordinate this boundary with STORY-06-02-03 so helper unit tests import the real helpers without running the scraper — `@platform-engineer`

## Edge Cases

- **Empty:** 0 test files are discovered for the configured globs → the runner reports `no test files found` and returns the configured no-tests outcome rather than a passing run.
- **Boundary:** Node is exactly 18.0.0 → setup passes, because the `>=18` floor is inclusive of 18.0.0.
- **Invalid:** the Vitest configuration is malformed → the runner exits with a non-zero code and names the configuration parse failure rather than running 0 tests silently.
- **Concurrent:** two CI jobs share one Vitest configuration and run in parallel → each job reads its own injected test `DATABASE_URL` and exits on its own results, with neither job overwriting the other's output.

## Dependencies

### Upstream (must be complete first)

- **`EPIC-01`** — Environment & Configuration Foundation: supplies the Blitzy encrypted secret storage and the Next.js + TypeScript scaffold this harness configuration relies on. Cited by identifier because it is a cross-epic dependency.
- **Reference:** <https://docs.blitzy.com/administration/environments> — the canonical environment-configuration reference this story cites.

### Downstream (informational — build on this harness)

- **[STORY-06-01-02 — Establish Fixtures & Boundary Mocks](STORY-06-01-02-establish-fixtures-and-boundary-mocks.md):** adds the `__fixtures__` and boundary mocks that the harness configured here resolves.
- **[STORY-06-01-03 — Wire Integration Tests to a Neon Branch](STORY-06-01-03-wire-integration-tests-to-neon-branch.md):** owns the per-CI Neon branch lifecycle whose connection string becomes the test `DATABASE_URL` this harness reads; depends on EPIC-02 `STORY-02-01-*`.

## Story Estimation Guidance

- **Effort: Medium** — one Vitest configuration spans two language targets (TypeScript application globs and JavaScript ESM actor globs) plus the environment-access documentation, which exceeds a single-file change.
- **Complexity: Medium** — the configuration must load the actor's side-effect-free ES-module helper boundary under the same runner as the TypeScript application with 0 CommonJS transform errors (without triggering the top-level `await Actor.init()`/`crawler.run()` entrypoint in `apify/src/main.js`), and must enforce both the Node `>=18` floor and the `DATABASE_URL` guard.
- **Uncertainty: Low** — the runner (Vitest), the runtime floor (Node `>=18`), and the actor module type (`"type": "module"`) are fixed by `apify/package.json`, which leaves the resolution path defined ahead of implementation.
- **Estimate: 5 points (Fibonacci).** The cross-target configuration and the environment-access wiring place this above a 3; the absence of unknown external integrations keeps it below an 8.

## Definition of Done

- [ ] A single Vitest configuration runs both the TypeScript application and the ES-module JavaScript Apify actor's helper boundary under Node `>=18`.
- [ ] Environment access is documented and cites <https://docs.blitzy.com/administration/environments>.
- [ ] The Blitzy, Neon, and GitHub Actions platforms are enumerated, and the required test `DATABASE_URL` encrypted secret is named.
- [ ] The Node `>=18` floor is stated for both the TypeScript application and the JavaScript actor, matching the actor's `engines.node` declaration.
- [ ] The actor's side-effect-free ES-module helper boundary resolves under Vitest with 0 CommonJS transform errors and triggers 0 actor side effects on import (no `Actor.init()`, `Actor.getInput()`, `searchTerms` validation, or `crawler.run()`).
- [ ] The required-variable guard halts execution before database-dependent tests when the test `DATABASE_URL` is unset and names the missing variable.
- [ ] No prohibited vague terms appear in the acceptance criteria.
- [ ] All relative links resolve: the parent feature index, the parent epic index, and the two sibling stories.
- [ ] **Testing:** `vitest run` executes the TypeScript app suite and the JavaScript actor helper-boundary suite green under Node `>=18`.
