# FEATURE-01-01: Blitzy Environment Provisioning

*Parent epic: [EPIC-01 — Environment & Configuration Foundation](../EPIC-01-environment-and-configuration-foundation.md)*

## Feature Summary

This feature manually configures the **single Blitzy environment** — supplies its copy-paste build and run instructions, defines the plaintext variables and encrypted secrets it carries, attaches it to the project, and validates it with a test build that exits 0. The business value is one configured place to build, run, and deploy: with the single environment configured, attached, and passing a test build, every later epic inherits a settled execution target instead of provisioning its own. This is **EPIC-01's mandatory Environment Access & Configuration feature** — the per-epic environment-access obligation realized for the foundation. Scope is limited to manually configuring the single Blitzy environment, defining its plaintext variables and encrypted secrets, attaching it to the project, and running the validation build; it does **not** scaffold the application (that is [FEATURE-01-02 — Application Scaffolding & Tooling](FEATURE-01-02-application-scaffolding-and-tooling.md)) and it does **not** author `.env.example` or configure the Vercel and GitHub Actions secrets (that is [FEATURE-01-03 — Secrets & Variable Management](FEATURE-01-03-secrets-and-variable-management.md)). This feature is delivered through **3 stories**.

## Environment Access & Configuration

All configuration for this feature is performed manually in the single existing Blitzy environment; the canonical Blitzy environments reference <https://docs.blitzy.com/administration/environments> is **informational only** — Blitzy cannot create environments. Copy-paste build (`npm install` → `npm run build`) and run (`npm run start`) instructions are supplied, non-sensitive values are stored as plaintext environment variables and credentials are stored as encrypted secrets entered by hand, and the environment is attached to the project. This step-by-step configuration is completed in full **before** the application scaffold (FEATURE-01-02), the secrets baseline (FEATURE-01-03), and every dependent epic (EPIC-02 through EPIC-06) proceed.

The platform accessed here is **Blitzy**: this feature manually configures the **single Blitzy environment** and attaches it to the project.

**Plaintext variables vs encrypted secrets.** Non-sensitive configuration values (for example, a deployment region label or a feature flag) are stored as **plaintext variables**, readable in the Blitzy dashboard. Sensitive credentials (for example, a database connection string or an API token) are stored as **encrypted secrets** — held encrypted at rest and never written in plaintext. This split is defined for the single environment so that non-sensitive values stay legible while credentials stay protected.

**Runtime floor:** Node `>=20.20.2` for the application toolchain (the application floor, from the root `package.json` `engines.node`). The Apify actor keeps its own lower floor of Node `>=18` (set through its `engines.node` field in `apify/package.json`; its container image runs Node 20). The single Blitzy environment pins the project Node version at `>=20.20.2`, which satisfies both the application and the actor. The application targets the **Next.js App Router deployed on Vercel**, so the environment's copy-paste build and run instructions match that stack.

### Platforms and access required

| Platform | Access required | Purpose in FEATURE-01-01 |
|----------|-----------------|--------------------------|
| Blitzy | single environment (manual build/run + hand-entered secrets); plaintext variables and encrypted secrets; project attachment | Manually configure the single environment — supply the copy-paste build (`npm install` → `npm run build`) and run (`npm run start`) instructions, store non-sensitive values as plaintext variables and credentials as encrypted secrets entered by hand, attach the environment to the project, and validate it with a test build that exits 0 per <https://docs.blitzy.com/administration/environments> (informational only) |

### Step-by-step configuration (complete before dependent features and epics proceed)

1. Manually configure the single existing Blitzy environment per <https://docs.blitzy.com/administration/environments> (informational only — Blitzy cannot create environments).
2. Supply the environment's copy-paste build and run instructions — build with `npm install` then `npm run build` (must exit 0), run with `npm run start` — matching the Next.js App Router on Vercel stack and the Node `>=20.20.2` application runtime floor (the Apify actor keeps its own `>=18`).
3. Store the environment's non-sensitive configuration values as **plaintext variables** in the Blitzy dashboard.
4. Store the environment's sensitive credentials as **encrypted secrets**, held encrypted at rest and never written in plaintext.
5. Attach the single environment to the project.
6. Validate the single environment with a test build that exits 0 (a missing required active secret halts the build with a non-zero exit code that names the missing key) before the application scaffold (FEATURE-01-02), the secrets baseline (FEATURE-01-03), and the dependent epics (EPIC-02 through EPIC-06) proceed.

## User Stories Index

This feature is delivered through three stories. Each link is relative to this file inside the `EPIC-01/` directory.

1. **[STORY-01-01-01 — Create the Blitzy Environments](FEATURE-01-01/STORY-01-01-01-create-blitzy-environments.md)** — manually configure the single Blitzy environment per <https://docs.blitzy.com/administration/environments> (informational only), with its copy-paste build (`npm install` → `npm run build`) and run (`npm run start`) instructions matching the Next.js App Router on Vercel stack and the Node `>=20.20.2` application floor (the Apify actor keeps its own `>=18`).
2. **[STORY-01-01-02 — Define Secrets & Variables](FEATURE-01-01/STORY-01-01-02-define-secrets-and-variables.md)** — define the plaintext variables (non-sensitive configuration) and the encrypted secrets (sensitive credentials, encrypted at rest) for the single environment in the Blitzy dashboard.
3. **[STORY-01-01-03 — Attach Environments & Validate Build](FEATURE-01-01/STORY-01-01-03-attach-environments-and-validate-build.md)** — attach the single environment to the project and validate it with a test build that exits 0.

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
- [ ] The single Blitzy environment is manually configured per <https://docs.blitzy.com/administration/environments> (informational only — Blitzy cannot create environments).
- [ ] Plaintext variables (non-sensitive configuration) and encrypted secrets (sensitive credentials, encrypted at rest and never written in plaintext) are defined for the single environment.
- [ ] The single environment is attached to the project.
- [ ] The single environment is validated with a test build that exits 0.
- [ ] The Node `>=20.20.2` application runtime floor (the Apify actor keeps its own `>=18`) and the Next.js-App-Router-on-Vercel target are recorded in the environment's copy-paste build and run instructions.
- [ ] No prohibited vague quality term appears in any measurable statement; every such statement names a concrete pass/fail condition.
- [ ] **Testing:** a test build on the single Blitzy environment exits 0, validating the environment before the dependent features (FEATURE-01-02, FEATURE-01-03) and epics (EPIC-02 through EPIC-06) proceed.
