# STORY-01-02-02: Configure ESLint & Strict Typecheck

## User Story
**As a** Platform Engineer, **I want** to configure ESLint and a `tsc --noEmit` strict typecheck baseline, **so that** every change is linted and type-checked before merge.

## Environment Access & Configuration
This story builds within the managed environments provisioned by [FEATURE-01-01 — Blitzy Environment Provisioning](../FEATURE-01-01-blitzy-environment-provisioning.md), documented per the canonical reference: <https://docs.blitzy.com/administration/environments>.

- **Toolchain floor:** Node `>=18` (sourced from `apify/package.json` `engines.node`; the Apify container image is Node 20).
- **Target:** the linting and typecheck commands run on Node `>=18` and are invoked by the EPIC-06 CI pipeline on every pull request.
- **No install in this task:** this ticket describes the tooling configuration; the commands execute when the ticket is implemented. Full environment steps are not duplicated here — see FEATURE-01-01.

### Step-by-step configuration (complete BEFORE dependent work)
1. Confirm the initialized project from [STORY-01-02-01](STORY-01-02-01-initialize-nextjs-typescript-project.md) exists.
2. Add ESLint with the Next.js + TypeScript shared configuration.
3. Register an npm script that runs `tsc --noEmit` (type-check without emitting JavaScript).
4. Register an npm script that runs ESLint across the scaffold.
5. Record both command names so the EPIC-06 CI pipeline can invoke them.

## Acceptance Criteria (Given/When/Then)
1. **(Valid output)** **Given** the initialized project, **when** ESLint is configured and run across the scaffold, **then** ESLint exits `0` with zero errors.
2. **(Valid output — typecheck)** **Given** the configured project, **when** `tsc --noEmit` runs, **then** it exits `0` with zero type errors and emits no JavaScript output.
3. **(Input validation)** **Given** the package manifest scripts, **when** the type-check script is registered, **then** it includes the `--noEmit` flag and the TypeScript compiler version is at or above the project floor.
4. **(Error handling — lint)** **Given** a file with an ESLint rule violation, **when** ESLint runs, **then** it exits with a non-zero code and reports the file path, the line number, and the rule identifier.
5. **(Error handling — types)** **Given** a file with a type error, **when** `tsc --noEmit` runs, **then** it exits with a non-zero code and names the file and the TypeScript error code.
6. **(Edge case — strict ruleset)** **Given** `strict: true` in `tsconfig.json`, **when** an implicit `any` is introduced where the strict ruleset forbids it, **then** `tsc --noEmit` flags the violation and exits with a non-zero code.
7. **(Valid output — reproducibility)** **Given** the lint and typecheck scripts, **when** they run a second time with no source change, **then** both exit `0` and report identical results.

## Sub-Tasks
- [ ] Add ESLint with the Next.js + TypeScript shared configuration. `@platform-engineer`
- [ ] Register an npm script that runs `tsc --noEmit`. `@platform-engineer`
- [ ] Register an npm script that runs ESLint across the scaffold. `@platform-engineer`
- [ ] Run both commands and capture their exit codes. `@devops-engineer`
- [ ] Record both command names for the EPIC-06 CI pipeline to invoke. `@platform-engineer`

## Edge Cases
- **Empty/Null:** no source files beyond the scaffold exist — ESLint and `tsc --noEmit` both exit `0` over the scaffold.
- **Boundary:** a TypeScript compiler version below the project floor — the type-check script reports the version mismatch and the install is blocked.
- **Invalid:** a syntactically invalid `.ts` file — `tsc --noEmit` exits with a non-zero code and names the file and the parse error.
- **Concurrent:** the lint and typecheck scripts run at the same time — each reports an independent exit code with no shared-state interference.

## Dependencies
- **Upstream:** [STORY-01-02-01](STORY-01-02-01-initialize-nextjs-typescript-project.md) (the project must be initialized first).
- **Downstream (informational):** EPIC-06 (`ci.yml`) invokes these lint and typecheck commands on every pull request. Parent feature: [FEATURE-01-02](../FEATURE-01-02-application-scaffolding-and-tooling.md). Parent epic: [EPIC-01](../../EPIC-01-environment-and-configuration-foundation.md).

## Story Estimation Guidance
- **Effort:** Low–Medium (ESLint configuration plus two npm scripts).
- **Complexity:** Low–Medium (strict typecheck baseline over the scaffold).
- **Uncertainty:** Low (the Next.js + TypeScript lint configuration is standardized).
- **Fibonacci points:** 3

## Definition of Done
- [ ] ESLint is configured and runs with zero errors on the scaffold.
- [ ] `tsc --noEmit` exits `0` with zero type errors and emits no JavaScript.
- [ ] Both commands are registered as npm scripts and recorded for the EPIC-06 CI pipeline.
- [ ] A lint violation and a type error each produce a non-zero exit code with a named file.
- [ ] **Testing:** the ESLint baseline and the `tsc --noEmit` typecheck both exit `0` on the scaffold before dependent work proceeds.
