# FEATURE-01-01: Blitzy Environment Provisioning

*Parent epic: [EPIC-01 — Environment & Configuration Foundation](../EPIC-01-environment-and-configuration-foundation.md)*

## Feature Summary

This feature provisions the three managed Blitzy environments — **Dev**, **Staging**, and **Prod** — defines the plaintext variables and encrypted secrets each one carries, attaches every environment to the project, and validates each with a test build that exits 0. The business value is one configured place to build, run, and deploy: with three named environments attached and a passing test build on each, every later epic inherits a settled execution target instead of provisioning its own. This is **EPIC-01's mandatory Environment Access & Configuration feature** — the per-epic environment-access obligation realized for the foundation. Scope is limited to provisioning the Blitzy environments, defining their plaintext variables and encrypted secrets, attaching them to the project, and running the validation build; it does **not** scaffold the application (that is [FEATURE-01-02 — Application Scaffolding & Tooling](FEATURE-01-02-application-scaffolding-and-tooling.md)) and it does **not** author `.env.example` or configure the Vercel and GitHub Actions secrets (that is [FEATURE-01-03 — Secrets & Variable Management](FEATURE-01-03-secrets-and-variable-management.md)). This feature is delivered through **3 stories**.

## Environment Access & Configuration

All environment provisioning for this feature follows the canonical Blitzy environments reference: <https://docs.blitzy.com/administration/environments>. Per that reference, an environment is created for each target, build and run instructions are supplied in natural language, non-sensitive values are stored as plaintext environment variables and credentials are stored as encrypted secrets, and the environment is then attached to the project. This step-by-step configuration is completed in full **before** the application scaffold (FEATURE-01-02), the secrets baseline (FEATURE-01-03), and every dependent epic (EPIC-02 through EPIC-06) proceed.

The platform accessed here is **Blitzy**: this feature creates the **Dev**, **Staging**, and **Prod** environments and attaches each of the three to the project.

**Plaintext variables vs encrypted secrets.** Non-sensitive configuration values (for example, a deployment region label or a feature flag) are stored as **plaintext variables**, readable in the Blitzy dashboard. Sensitive credentials (for example, a database connection string or an API token) are stored as **encrypted secrets** — held encrypted at rest and never written in plaintext. This split is defined for each of the three environments so that non-sensitive values stay legible while credentials stay protected.

**Runtime floor:** Node `>=18` for the application toolchain. The existing Apify actor sets this floor through its `engines.node` field and its container image runs Node 20; the Blitzy environments pin the project Node version at or above this floor so the application and the actor share one runtime. The application targets the **Next.js App Router deployed on Vercel**, so each environment's natural-language build and run instructions match that stack.

### Platforms and access required

| Platform | Access required | Purpose in FEATURE-01-01 |
|----------|-----------------|--------------------------|
| Blitzy | Dev, Staging, and Prod environments; plaintext variables and encrypted secrets; project attachment | Create the three environments, store non-sensitive values as plaintext variables and credentials as encrypted secrets, attach each environment to the project, and validate each with a test build per <https://docs.blitzy.com/administration/environments> |

### Step-by-step configuration (complete before dependent features and epics proceed)

1. Create the Blitzy **Dev**, **Staging**, and **Prod** environments per <https://docs.blitzy.com/administration/environments>.
2. Supply each environment's build and run instructions in natural language, matching the Next.js App Router on Vercel stack and the Node `>=18` runtime floor.
3. Store each environment's non-sensitive configuration values as **plaintext variables** in the Blitzy dashboard.
4. Store each environment's sensitive credentials as **encrypted secrets**, held encrypted at rest and never written in plaintext.
5. Attach each of the three environments to the project.
6. Validate each environment with a test build that exits 0 before the application scaffold (FEATURE-01-02), the secrets baseline (FEATURE-01-03), and the dependent epics (EPIC-02 through EPIC-06) proceed.

## User Stories Index

This feature is delivered through three stories. Each link is relative to this file inside the `EPIC-01/` directory.

1. **[STORY-01-01-01 — Create the Blitzy Environments](FEATURE-01-01/STORY-01-01-01-create-blitzy-environments.md)** — create the Dev, Staging, and Prod Blitzy environments per <https://docs.blitzy.com/administration/environments>, with each environment's build and run instructions matching the Next.js App Router on Vercel stack and the Node `>=18` floor.
2. **[STORY-01-01-02 — Define Secrets & Variables](FEATURE-01-01/STORY-01-01-02-define-secrets-and-variables.md)** — define the plaintext variables (non-sensitive configuration) and the encrypted secrets (sensitive credentials, encrypted at rest) for each environment in the Blitzy dashboard.
3. **[STORY-01-01-03 — Attach Environments & Validate Build](FEATURE-01-01/STORY-01-01-03-attach-environments-and-validate-build.md)** — attach the three environments to the project and validate each with a test build that exits 0.

## Dependencies

### Upstream (must be complete first)

- **None.** EPIC-01 is the root of the dependency graph and FEATURE-01-01 is its first feature; it has no upstream feature or epic and provisions the environments every later feature and epic builds on.

### Downstream (informational — not a build prerequisite of this feature)

- **[FEATURE-01-02 — Application Scaffolding & Tooling](FEATURE-01-02-application-scaffolding-and-tooling.md):** initializes the Next.js App Router + TypeScript scaffold within these provisioned environments.
- **[FEATURE-01-03 — Secrets & Variable Management](FEATURE-01-03-secrets-and-variable-management.md):** authors `.env.example` and configures the Vercel and GitHub Actions secrets on top of this environment baseline.
- **EPIC-02 — Database Platform & Schema:** provisions Neon and its branching topology within these environments.
- **EPIC-03 — Data Ingestion Pipeline:** runs the Apify-primary ingestion against these environments.
- **EPIC-04 — Backend Application & API:** serves the Next.js API from these environments.
- **EPIC-05 — Frontend User Interface:** renders the UI from these environments.
- **EPIC-06 — Testing & CI/CD Quality Gates:** runs its pipeline against these environments.

## Definition of Done

- [ ] All 3 stories (STORY-01-01-01, STORY-01-01-02, STORY-01-01-03) are complete.
- [ ] The three Blitzy environments — Dev, Staging, and Prod — are created per <https://docs.blitzy.com/administration/environments>.
- [ ] Plaintext variables (non-sensitive configuration) and encrypted secrets (sensitive credentials, encrypted at rest and never written in plaintext) are defined for each of the three environments.
- [ ] Each of the three environments is attached to the project.
- [ ] Each environment is validated with a test build that exits 0.
- [ ] The Node `>=18` runtime floor and the Next.js-App-Router-on-Vercel target are recorded in each environment's build and run instructions.
- [ ] No prohibited vague quality term appears in any measurable statement; every such statement names a concrete pass/fail condition.
- [ ] **Testing:** a test build on each of the three environments exits 0, validating the environment before the dependent features (FEATURE-01-02, FEATURE-01-03) and epics (EPIC-02 through EPIC-06) proceed.
