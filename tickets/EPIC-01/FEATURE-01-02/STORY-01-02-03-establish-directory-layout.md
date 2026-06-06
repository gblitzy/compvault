# STORY-01-02-03: Establish the Directory Layout

*Parent feature: [FEATURE-01-02 — Application Scaffolding & Tooling](../FEATURE-01-02-application-scaffolding-and-tooling.md) · Parent epic: [EPIC-01 — Environment & Configuration Foundation](../../EPIC-01-environment-and-configuration-foundation.md)*

## User Story
**As a** Platform Engineer, **I want** to establish the `app/ db/ lib/ jobs/ scripts/ .github/` directory layout, **so that** later epics add code in a consistent, predictable structure.

## Environment Access & Configuration
This story builds within the managed environments provisioned by [FEATURE-01-01 — Blitzy Environment Provisioning](../FEATURE-01-01-blitzy-environment-provisioning.md), documented per the canonical reference: <https://docs.blitzy.com/administration/environments>.

- **Toolchain floor:** Node `>=20.20.2` for the application runtime (from the root `package.json` `engines.node`); the Apify actor keeps its own `>=18` floor (from `apify/package.json`; the Apify container image is Node 20).
- **Layout authority:** the six top-level directories mirror the repository scaffold in PRD §7.6.1 for the single TypeScript Next.js (App Router) repo.
- **No install in this task:** this ticket describes the directory work; the directories are created when the ticket is implemented. Full environment steps are not duplicated here — see FEATURE-01-01.

### Step-by-step configuration (complete BEFORE dependent work)
1. Confirm the initialized project from [STORY-01-02-01](STORY-01-02-01-initialize-nextjs-typescript-project.md) exists.
2. Create the six top-level directories `app/`, `db/`, `lib/`, `jobs/`, `scripts/`, and `.github/` at the repository root.
3. Add a tracked placeholder file (for example `.gitkeep`) in each otherwise-empty directory so the structure is committed to version control.
4. Record which later epic populates each directory: `db/` → EPIC-02; `jobs/` and `scripts/` → EPIC-03; `app/api` → EPIC-04; `app/` UI → EPIC-05; `.github/workflows/` → EPIC-06.
5. Leave root config files (`drizzle.config.ts`, `vercel.json`, `.env.example`) to FEATURE-01-03 and later epics; this story does not author them.

## Acceptance Criteria (Given/When/Then)
1. **(Valid output)** **Given** the initialized project, **when** the directory layout is established, **then** the six directories `app/`, `db/`, `lib/`, `jobs/`, `scripts/`, and `.github/` exist at the repository root.
2. **(Valid output — tracked)** **Given** an otherwise-empty directory, **when** it is created, **then** it carries a placeholder file so the directory is committed to version control.
3. **(Input validation — names)** **Given** the directory-name set, **when** each directory is created, **then** its name matches one of the exact set `{app, db, lib, jobs, scripts, .github}` and any name outside this set is not created by this story.
4. **(Error handling)** **Given** a directory name that already exists at the repository root, **when** the layout step runs, **then** the existing directory is left unchanged and no duplicate is created.
5. **(Edge case — scope boundary)** **Given** the root config files `drizzle.config.ts`, `vercel.json`, and `.env.example`, **when** this story completes, **then** none of those files is authored here, because they are authored by FEATURE-01-03 and later epics.
6. **(Edge case — coexistence)** **Given** the existing `apify/` and `docs/` directories, **when** the six directories are created, **then** `apify/` and `docs/` are unchanged and are not moved into the new layout.
7. **(Valid output — baseline holds)** **Given** the six new directories, **when** ESLint and `tsc --noEmit` run, **then** both exit `0` because the directories contain no source that violates the rules.

## Sub-Tasks
- [ ] Create the six directories `app/`, `db/`, `lib/`, `jobs/`, `scripts/`, and `.github/` at the repository root. `@platform-engineer`
- [ ] Add a tracked placeholder file in each otherwise-empty directory. `@platform-engineer`
- [ ] Record which later epic populates each directory (`db/` → EPIC-02; `jobs/`+`scripts/` → EPIC-03; `app/api` → EPIC-04; `app/` UI → EPIC-05; `.github/workflows/` → EPIC-06). `@platform-engineer`
- [ ] Confirm `apify/` and `docs/` are preserved and not relocated. `@platform-engineer`
- [ ] Run ESLint and `tsc --noEmit` to confirm the layout holds the baseline. `@devops-engineer`

## Edge Cases
- **Empty/Null:** a directory is created with no source files — a placeholder file keeps it tracked in version control.
- **Boundary:** all six directory names must be present; if five of the six exist, the layout is not marked done.
- **Invalid:** a directory name outside the set `{app, db, lib, jobs, scripts, .github}` — it is not created by this story.
- **Concurrent:** two layout runs create the same directory at the same time — one directory is created and the other run treats it as already present.

## Dependencies
- **Upstream:** [STORY-01-02-01](STORY-01-02-01-initialize-nextjs-typescript-project.md) (the project must be initialized first).
- **Downstream (informational):** EPIC-02 populates `db/`; EPIC-03 populates `jobs/` and `scripts/`; EPIC-04 populates `app/api`; EPIC-05 populates `app/` UI; EPIC-06 populates `.github/workflows/`. Parent feature: [FEATURE-01-02](../FEATURE-01-02-application-scaffolding-and-tooling.md). Parent epic: [EPIC-01](../../EPIC-01-environment-and-configuration-foundation.md).

## Story Estimation Guidance
- **Effort:** Low (six directories plus placeholder files).
- **Complexity:** Low (directory creation; no application logic).
- **Uncertainty:** Low (the layout is fixed by PRD §7.6.1).
- **Fibonacci points:** 2

## Definition of Done
- [ ] The six directories `app/`, `db/`, `lib/`, `jobs/`, `scripts/`, and `.github/` exist at the repository root.
- [ ] Each otherwise-empty directory carries a tracked placeholder file.
- [ ] Root config files (`drizzle.config.ts`, `vercel.json`, `.env.example`) are not authored here.
- [ ] The existing `apify/` and `docs/` directories are preserved unchanged.
- [ ] **Testing:** ESLint and `tsc --noEmit` both exit `0` after the layout is established, confirming the baseline holds before later epics add code.
