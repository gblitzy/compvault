# STORY-01-02-01: Initialize the Next.js + TypeScript Project

*Parent feature: [FEATURE-01-02 — Application Scaffolding & Tooling](../FEATURE-01-02-application-scaffolding-and-tooling.md) · Parent epic: [EPIC-01 — Environment & Configuration Foundation](../../EPIC-01-environment-and-configuration-foundation.md)*

## User Story
**As a** Platform Engineer, **I want** to initialize a Next.js App Router + TypeScript project at the repository root, **so that** the application has a typed, deployable foundation.

## Environment Access & Configuration
This story builds within the single Blitzy environment attached by [FEATURE-01-01 — Blitzy Environment Provisioning](../FEATURE-01-01-blitzy-environment-provisioning.md), documented per the canonical reference: <https://docs.blitzy.com/administration/environments>.

- **Toolchain floor:** Node `>=20.20.2` for the application runtime (from the root `package.json` `engines.node`); the Apify actor keeps its own `>=18` floor (from `apify/package.json`; the Apify container image is Node 20).
- **Target:** the application is a Next.js App Router project deployed on Vercel (stateless serverless request/response).
- **No install in this task:** this ticket describes the scaffold work; the initialization command executes when the ticket is implemented, not during backlog authoring. Full environment steps are not duplicated here — see FEATURE-01-01.

### Step-by-step configuration (complete BEFORE dependent work)
1. Confirm **the single Blitzy environment** from FEATURE-01-01 is attached and validated.
2. From the repository root, initialize a Next.js App Router project with TypeScript enabled.
3. Set `strict` to `true` in `tsconfig.json` and pin `engines.node` to `>=20.20.2` in `package.json`.
4. Confirm the App Router (`app/`) is selected and the Pages Router (`pages/`) is not generated.
5. Record the package manifest and lockfile at the repository root in the team runbook.

## Acceptance Criteria (Given/When/Then)
1. **(Valid output)** **Given** a repository root with no application manifest, **when** the Platform Engineer initializes the Next.js App Router + TypeScript project, **then** a `package.json`, a `tsconfig.json`, and an `app/` directory exist at the repository root and `package.json` declares the `next` dependency.
2. **(Valid output — App Router)** **Given** the initialized project, **when** the router mode is inspected, **then** the `app/` directory is present and the `pages/` directory is absent.
3. **(Input validation — Node floor)** **Given** the package manifest, **when** the `engines.node` field is read, **then** it specifies `>=20.20.2` and a Node runtime below `20.20.2` is rejected by the toolchain.
4. **(Input validation — TypeScript strict)** **Given** the initialized project, **when** `tsconfig.json` is read, **then** `strict` is set to `true` and the `.ts` and `.tsx` extensions are recognized by the compiler.
5. **(Error handling)** **Given** a pre-existing file at the repository root that collides with a scaffold-generated file, **when** the initialization runs, **then** it halts with a non-zero exit code, names the conflicting path, and leaves `README.md`, `apify/`, and `docs/` unchanged.
6. **(Valid output — build)** **Given** the initialized project, **when** the Next.js production build runs, **then** the build exits `0` and emits the `.next` build output.
7. **(Edge case — coexistence)** **Given** the existing `apify/` and `docs/` directories, **when** the project is initialized at the repository root, **then** both directories are unchanged and are excluded from the Next.js build.

## Sub-Tasks
- [ ] Confirm the single Blitzy environment from FEATURE-01-01 is attached and validated. `@platform-engineer`
- [ ] Initialize the Next.js App Router + TypeScript project at the repository root. `@platform-engineer`
- [ ] Set `strict: true` in `tsconfig.json` and pin `engines.node` to `>=20.20.2` in `package.json`. `@platform-engineer`
- [ ] Confirm the existing `README.md`, `apify/`, and `docs/` paths are preserved and excluded from the build. `@platform-engineer`
- [ ] Run the Next.js production build and capture the exit code. `@devops-engineer`
- [ ] Record the package manifest and lockfile at the repository root in the runbook. `@platform-engineer`

## Edge Cases
- **Empty/Null:** the repository root contains no manifest before initialization — initialization creates `package.json` and `tsconfig.json` from the template.
- **Boundary:** a Node runtime at `20.20.2` is accepted; a runtime below `20.20.2` is rejected by the `>=20.20.2` floor.
- **Invalid:** a pre-existing file collides with a scaffold-generated file — initialization halts with a non-zero exit code and names the conflicting path.
- **Concurrent:** two initialization attempts run against the repository root at the same time — one writes the manifest and the other halts on the already-present manifest.

## Dependencies
- **Upstream:** [FEATURE-01-01 — Blitzy Environment Provisioning](../FEATURE-01-01-blitzy-environment-provisioning.md) (the single environment the project builds and runs within).
- **Downstream (informational):** [STORY-01-02-02](STORY-01-02-02-configure-eslint-and-typecheck.md) and [STORY-01-02-03](STORY-01-02-03-establish-directory-layout.md) require the initialized project. Parent feature: [FEATURE-01-02](../FEATURE-01-02-application-scaffolding-and-tooling.md). Parent epic: [EPIC-01](../../EPIC-01-environment-and-configuration-foundation.md).

## Story Estimation Guidance
- **Effort:** Low–Medium (one scaffold command plus manifest configuration).
- **Complexity:** Low (standard Next.js initialization; no application logic).
- **Uncertainty:** Low (the stack and the App Router target are fixed by the PRD).
- **Fibonacci points:** 3

## Definition of Done
- [ ] `package.json`, `tsconfig.json`, and `app/` exist at the repository root with the `next` dependency declared.
- [ ] The App Router is active (`app/` present) and the Pages Router (`pages/`) is absent.
- [ ] `engines.node` is `>=20.20.2` and `tsconfig.json` sets `strict: true`.
- [ ] The existing `README.md`, `apify/`, and `docs/` paths are preserved unchanged.
- [ ] **Testing:** the Next.js production build exits `0` before STORY-01-02-02 and STORY-01-02-03 proceed.
