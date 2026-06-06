# STORY-05-01-01: Configure Vercel Preview & Environment Access

*Parent feature: [FEATURE-05-01 — Frontend Foundation & Environment Access](../FEATURE-05-01-frontend-foundation-and-environment-access.md) · Parent epic: [EPIC-05 — Frontend User Interface](../../EPIC-05-frontend-user-interface.md)*

This is the environment-access story of FEATURE-05-01 and the first of its **two** stories. It configures the Vercel two-environment deployment model — the Production scope and the Preview (= dev/qa) scope — and the managed environment access from which the frontend reads its configuration, so the sibling application-shell story ([STORY-05-01-02](STORY-05-01-02-implement-application-shell.md)) and every later EPIC-05 view are built and reviewed against a live Preview (= dev/qa) deployment URL rather than a local-only build. This step-by-step environment configuration is finished in full **before** the search and results views (FEATURE-05-02) and the detail and review-queue workbench views (FEATURE-05-03) are implemented.

## User Story

**As a** Frontend Engineer, **I want** the Vercel Production and Preview (= dev/qa) scopes and environment access configured, **so that** all non-production branches and pull requests deploy under the Preview (= dev/qa) scope against the shared Neon `dev-qa` branch and the frontend reads its configuration from managed environments.

## Environment Access & Configuration

- **Canonical reference.** All environment provisioning for this story follows the Blitzy environments reference at <https://docs.blitzy.com/administration/environments>. Per that reference, an environment is created for each target, build and run instructions are supplied in natural language, non-sensitive values are stored as plaintext variables and sensitive credentials are stored as encrypted secrets, and the environment is then attached to the project.
- **Platforms.** **Blitzy** provides the managed environment and the encrypted secret storage. **Vercel** is the frontend host: it builds the application, exposes the Production scope (git branch `main` → Neon `production`) and the Preview (= dev/qa) scope (all non-production branches/PRs → Neon `dev-qa`), and supplies the per-scope environment variables the frontend reads.
- **Deployment model.** The UI is a Next.js App Router frontend deployed on Vercel (the application and its API routes run as stateless request/response on Vercel) using exactly two deployed environments. The Production scope deploys from the git branch `main` and points at the Neon `production` branch; the Preview (= dev/qa) scope applies to all non-production git branches and pull requests, produces a shareable preview URL for each, and points at the shared Neon `dev-qa` branch. The Preview (= dev/qa) scope reads a preview-scoped configuration and never points at production data. Because previews and CI now share the single `dev-qa` branch, per-run database isolation is lost — concurrent CI runs and open PRs share `dev-qa` state. This is the inherent consequence of the two-environment model. The Development scope is local-only (consumed via `vercel env pull`) and is not a third deployed environment.
- **Client-safe exposure.** Only client-safe configuration reaches the browser. Browser-exposed values carry a `NEXT_PUBLIC_`-prefixed name; server-only secrets such as `DATABASE_URL` stay in encrypted secrets and are excluded from the client bundle.
- **Sequencing.** This step-by-step environment configuration completes **before** the UI implementation work in FEATURE-05-02 (search and results) and FEATURE-05-03 (detail and review-queue workbench) proceeds.

### Platforms and access required

| Platform | Access required | Purpose in STORY-05-01-01 |
|----------|-----------------|---------------------------|
| Blitzy | Environment per target; plaintext variables and encrypted secrets | Store the frontend build and runtime variables as plaintext and credentials as encrypted secrets per <https://docs.blitzy.com/administration/environments>, then attach the environment to the project |
| Vercel | Project access; GitHub integration; per-scope environment variables; Production and Preview (= dev/qa) deployment scopes | Build and host the Next.js App Router frontend; expose the Production scope (git branch `main` → Neon `production`) and the Preview (= dev/qa) scope (all non-production branches/PRs → Neon `dev-qa`) at unique URLs |

### Step-by-step configuration (complete before the views are implemented)

1. Create the Blitzy environment(s) for the frontend target per <https://docs.blitzy.com/administration/environments>.
2. Store non-sensitive values as plaintext variables and credentials as encrypted secrets, then attach the environment to the project so the build reads its variables.
3. Connect the repository to Vercel, enable the GitHub integration, and set the Production Branch to `main`, so pushes to `main` deploy under the Production scope and all non-production branches/pull requests deploy under the Preview (= dev/qa) scope.
4. Set the Vercel Preview (= dev/qa) and Production environment variables so the frontend resolves its configuration in each scope, with the Production scope pointing at the Neon `production` branch and the Preview (= dev/qa) scope pointing at the shared non-production Neon `dev-qa` branch connection string.
5. Open a test pull request, confirm the Preview (= dev/qa) deployment resolves at a unique URL, and inspect the client bundle to confirm no server-only secret value is present.

## Acceptance Criteria

1. **(env-access — cites Blitzy doc)** Given the Blitzy environments reference at <https://docs.blitzy.com/administration/environments>, When an environment is created for the frontend target, Then non-sensitive values are stored as plaintext variables, credentials are stored as encrypted secrets, and the environment is attached to the project.
2. **(valid-output — Preview scope = dev/qa)** Given the Vercel project is connected to the GitHub repository, When a pull request is opened against `main`, Then Vercel produces a Preview (= dev/qa) deployment reachable at a unique URL that is recorded on the pull request and resolved against the shared Neon `dev-qa` branch.
3. **(valid-output — production on main)** Given a commit is merged to `main`, When the production deployment runs, Then the production build deploys from `main` under the Production scope (→ Neon `production`) while all non-production branches and pull requests deploy under the Preview (= dev/qa) scope (→ Neon `dev-qa`).
4. **(input-validation — missing variable)** Given a required environment variable or secret (for example `DATABASE_URL`) is absent at build time, When the build runs, Then the build fails with a named error identifying the missing variable and no deployment is published.
5. **(error-handling — blocking status check)** Given a Preview (= dev/qa) build fails, When the build status is reported to the pull request, Then a failing status check is posted that blocks the merge until the build status is green.
6. **(edge-case — non-production data)** Given a Preview (= dev/qa) deployment is created for a non-production branch or pull request, When the preview resolves its database connection, Then it targets the shared non-production Neon `dev-qa` connection string and never the `production` database.
7. **(edge-case — client-safe only)** Given the Preview (= dev/qa) or Production client bundle, When it is inspected, Then no server-only secret value (for example `DATABASE_URL`) is present and only variables marked client-safe are exposed to the browser.

## Sub-tasks

- [ ] Create the Blitzy environment(s) per <https://docs.blitzy.com/administration/environments> (@frontend-engineer / @devops)
- [ ] Store credentials as encrypted secrets and non-sensitive values as plaintext variables, then attach the environment to the project (@devops)
- [ ] Connect the Vercel project and the GitHub integration (@devops)
- [ ] Configure the Production scope (deploy from `main` → Neon `production`) and the Preview (= dev/qa) scope (all non-production branches/PRs → Neon `dev-qa`) (@devops)
- [ ] Point the Preview (= dev/qa) scope at the shared non-production Neon `dev-qa` database connection (@devops)
- [ ] Verify a test preview build and confirm no server secret appears in the client bundle (@frontend-engineer)

## Edge Cases

- **Invalid — missing required secret:** a required variable or secret is absent at build time → the build fails with a named error identifying the missing variable and no deployment is published.
- **Invalid — preview pointed at production data:** a Preview (= dev/qa) deployment is configured against the `production` database → this is blocked, and the preview resolves the shared non-production Neon `dev-qa` connection string instead.
- **Error — build failure:** a Preview (= dev/qa) build fails → a blocking status check is posted on the pull request and the merge is blocked until the build status is green.
- **Invalid — environment not attached:** the environment is created but not attached to the project → the configuration is incomplete and the build cannot read its variables.

## Dependencies

### Upstream (must be complete first)

- **[STORY-01-01-01 — Create Blitzy Environments](../../EPIC-01/FEATURE-01-01/STORY-01-01-01-create-blitzy-environments.md):** establishes the Blitzy environments and encrypted secret storage this story attaches the frontend target to.
- **[STORY-01-03-02 — Configure Vercel Env Vars](../../EPIC-01/FEATURE-01-03/STORY-01-03-02-configure-vercel-env-vars.md):** establishes the Vercel project environment variables this story scopes for Preview (= dev/qa) and Production.
- **[EPIC-01 — Environment & Configuration Foundation](../../EPIC-01-environment-and-configuration-foundation.md):** the environment and secrets baseline epic these upstream stories belong to.

### Informational (not a build prerequisite of this story)

- **[EPIC-02 — Database Platform & Schema](../../EPIC-02-database-platform-and-schema.md):** the shared non-production Neon `dev-qa` connection string originates from EPIC-02's Neon branching; informational at the environment stage.
- **[EPIC-04 — Backend Application & API](../../EPIC-04-backend-application-and-api.md):** the read and review-queue endpoints the UI will call; informational at the environment stage.

### Parent feature

- **[FEATURE-05-01 — Frontend Foundation & Environment Access](../FEATURE-05-01-frontend-foundation-and-environment-access.md)**

## Story Estimation Guidance

- **Effort: moderate** — multi-platform configuration spanning Blitzy, Vercel, and the GitHub integration.
- **Complexity: moderate** — coordinating the Preview (= dev/qa) and Production scopes, production-on-`main`, the shared non-production `dev-qa` data, and client-safe variable exposure.
- **Uncertainty: low-to-moderate** — the platform behavior is fixed by PRD §7.5 and the Blitzy environments doc, with verification of a first Preview (= dev/qa) build.
- **Fibonacci Story Points: 5.**

## Definition of Done

- [ ] Blitzy environment(s) created per <https://docs.blitzy.com/administration/environments>, with plaintext variables, encrypted secrets, and the environment attached to the project.
- [ ] Vercel project connected to the GitHub repository; all non-production branches/pull requests deploy under the Preview (= dev/qa) scope (→ Neon `dev-qa`) with a unique URL; production deploys from `main` under the Production scope (→ Neon `production`).
- [ ] A missing required variable or secret fails the build with a named error and publishes no deployment.
- [ ] A failed Preview (= dev/qa) build posts a status check that blocks the merge until the build status is green.
- [ ] The Preview (= dev/qa) scope targets the shared non-production Neon `dev-qa` database; production data is never used by previews.
- [ ] No server secret (for example `DATABASE_URL`) appears in the client bundle; the browser receives only client-safe configuration.
- [ ] No component library or design system is introduced or named.
- [ ] **Testing:** a test/preview build validates environment access before UI work proceeds and the config-validation checks pass; the UI coverage target is **≥50%** where code applies.
