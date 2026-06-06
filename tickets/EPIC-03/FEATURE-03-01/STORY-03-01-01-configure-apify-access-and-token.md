# STORY-03-01-01: Configure Apify Access & Token

*Parent feature: [FEATURE-03-01 — Apify Actor Integration](../FEATURE-03-01-apify-actor-integration.md) · Parent epic: [EPIC-03 — Data Ingestion Pipeline](../../EPIC-03-data-ingestion-pipeline.md)*

This is the **first** of the three stories in FEATURE-03-01 (Apify Actor Integration) and is EPIC-03's **mandatory Environment Access & Configuration story**. It configures Apify Platform access and the **`APIFY_TOKEN`** encrypted secret following the canonical Blitzy environments process at <https://docs.blitzy.com/administration/environments>, so the ingestion job can invoke the existing `ebay-sold-listings` actor across the local/dev, CI, and runtime contexts, reading the `APIFY_TOKEN` from the single Blitzy environment. This story is **pure configuration**: no actor is invoked here (the invocation is the subject of [STORY-03-01-02 — Invoke Actor & Persist Raw Listings](STORY-03-01-02-invoke-actor-and-persist-raw-listings.md)), and the step-by-step environment configuration described here is completed in full **before** any actor invocation.

Per the Blitzy environments reference <https://docs.blitzy.com/administration/environments> (informational — Blitzy cannot create environments), the single Blitzy environment is configured manually: build and run instructions are supplied in natural language, **non-sensitive values are stored as plaintext variables and credentials are stored as encrypted secrets**, and the environment is attached to the project. The `APIFY_TOKEN` is a sensitive credential, so it is stored as an **encrypted secret in the single Blitzy environment and is never stored as plaintext**; it is consumed locally (`export APIFY_TOKEN=...`), in CI (GitHub Actions encrypted secrets), and at runtime. A local run exports the token (`export APIFY_TOKEN=...`) before `node src/main.js` (or `apify run` with the Apify CLI); a CI or runtime invocation reads the same token from encrypted secrets and never from a local shell. The actor `ebay-sold-listings` is an ES module (`type: module`) that runs on **Node `>=18`** — the floor declared by the actor (`engines.node` `>=18` in `apify/package.json`), which the Apify container image pins at Node 20 (`apify/actor-node:20`).

**Compliance posture:** the main application reads official data sources only; the `ebay-sold-listings` Apify actor is the single sanctioned out-of-band scraping exception, and no request handler issues an LLM call. Apify is the primary live ingestion source now — the eBay Browse/Marketplace-Insights API integration is deferred and tracked in [FEATURE-03-03 — Scheduled Ingestion Orchestration](../FEATURE-03-03-scheduled-ingestion-orchestration.md) (`STORY-03-03-03`). This story has **no upstream data dependency**: it touches no database, and neither the pooled `DATABASE_URL` nor the unpooled `DATABASE_URL_UNPOOLED` is read here.

## User Story

> **As a** Platform Engineer, **I want** Apify Platform access and the `APIFY_TOKEN` secret configured following the Blitzy environments process, **so that** the ingestion job can invoke the `ebay-sold-listings` actor across local, CI, and runtime contexts.

## Acceptance Criteria

1. **(valid-output — configuration)** **Given** the Blitzy environments process at <https://docs.blitzy.com/administration/environments> is followed (informational — Blitzy cannot create environments), **When** the single Blitzy environment is configured manually, **Then** `APIFY_TOKEN` is stored as an **encrypted secret** (never plaintext) in the single Blitzy environment and the environment is attached to the project.

2. **(valid-output — authentication)** **Given** `APIFY_TOKEN` is present in the runtime environment, **When** an Apify API authentication check is performed, **Then** the Apify Platform returns HTTP 200 with an authenticated identity and the actor `ebay-sold-listings` is listed as runnable.

3. **(input-validation / error-handling)** **Given** `APIFY_TOKEN` is unset or an empty string, **When** the ingestion job reads it at startup, **Then** startup halts with a non-zero exit code before any actor run and a log line names the missing `APIFY_TOKEN`.

4. **(error-handling — invalid credential)** **Given** an invalid or expired `APIFY_TOKEN`, **When** the actor invocation is attempted, **Then** the Apify Platform returns HTTP 401 and the job **fails fast** — it records an authentication-failure error and exits with a non-zero code **without retrying the authentication** (the authentication check is not subject to page-level retries; the actor's `maxRequestRetries` = 5 governs in-run page/anti-bot retries only and is set in [STORY-03-01-02](STORY-03-01-02-invoke-actor-and-persist-raw-listings.md)).

5. **(edge-case / boundary — secret isolation across contexts)** **Given** `APIFY_TOKEN` is exported in the local shell but is absent from the CI (GitHub Actions) encrypted secrets, **When** a CI run starts, **Then** the CI run is blocked with a non-zero exit that names the missing CI secret, and the local token is never read by CI.

6. **(boundary — runtime floor)** **Given** the actor runs on Node `>=18` — the floor declared in `apify/package.json` (container image `apify/actor-node:20`) — **When** the runtime Node major version is checked, **Then** it is 18 or higher; otherwise startup halts with a non-zero exit and a logged Node version error.

## Sub-tasks

- Configure the single Blitzy environment following <https://docs.blitzy.com/administration/environments>, and consume `APIFY_TOKEN` from it locally, in CI, and at runtime. `@platform-engineer`
- Store `APIFY_TOKEN` as an encrypted secret in the single Blitzy environment and document that non-sensitive values are stored as plaintext variables. `@platform-engineer`
- Obtain the Apify Platform API token and verify it authenticates (HTTP 200 identity) against the `ebay-sold-listings` actor. `@platform-engineer`
- Configure the local-run path (`export APIFY_TOKEN=...` then `node src/main.js` or `apify run`) and the CI/runtime path (read `APIFY_TOKEN` from encrypted secrets). `@devops-engineer`
- Add a startup assertion that fails fast with a non-zero exit when `APIFY_TOKEN` is missing or empty, emitting a log line that names `APIFY_TOKEN`. `@devops-engineer`
- Document the Node `>=18` floor — declared by the `ebay-sold-listings` actor in `apify/package.json` (container `apify/actor-node:20`) — and the compliance posture (official data sources only; the Apify actor is the single sanctioned out-of-band scraping exception; no LLM call in any request handler). `@platform-engineer`
- Author an authentication smoke check that returns HTTP 200 with a valid token and exits non-zero on a missing or empty token, and assert the CI encrypted-secret presence. `@qa-engineer`

## Edge Cases

- **Empty/Null:** `APIFY_TOKEN` unset or an empty string → invocation fails fast with a non-zero exit and a logged error that names `APIFY_TOKEN`, before any actor run.
- **Invalid:** token present but invalid or expired → the Apify Platform returns HTTP 401 → the job **fails fast** on the authentication-failure error path and exits with a non-zero code **without retrying the authentication** (the actor's `maxRequestRetries` = 5 applies to in-run page/anti-bot retries only, not to the authentication check).
- **Boundary (secret isolation across contexts):** token exported in the local shell but absent from the CI encrypted secrets → the CI run is blocked with a non-zero exit until the CI secret is configured; the local token is never read by CI.
- **Invalid (runtime):** Node major version below the actor floor of 18 (`apify/package.json`) → startup halts with a non-zero exit and a logged Node version error.

## Dependencies

### Upstream (must be complete first)

- **[EPIC-01 — Environment & Configuration Foundation](../../EPIC-01-environment-and-configuration-foundation.md):** supplies the Blitzy environments and the secrets baseline that stores `APIFY_TOKEN`. Specifically **FEATURE-01-01 (Blitzy Environment Provisioning)** creates and attaches the environments, and **FEATURE-01-03 (Secrets & Variable Management)** establishes the encrypted-secret baseline; this story configures the Apify-specific access on top of that baseline.
- **No upstream data dependency.** This story is pure configuration and requires no Neon or database access: neither the pooled `DATABASE_URL` nor the unpooled `DATABASE_URL_UNPOOLED` is read, and no `raw_listing` write occurs here.

### Downstream (informational — not a build prerequisite of this story)

- **[STORY-03-01-02 — Invoke Actor & Persist Raw Listings](STORY-03-01-02-invoke-actor-and-persist-raw-listings.md):** invokes the `ebay-sold-listings` actor and requires the `APIFY_TOKEN` this story configures.
- **[STORY-03-01-03 — Implement Idempotent Raw-Listing Upsert](STORY-03-01-03-implement-idempotent-raw-listing-upsert.md):** builds on the actor invocation enabled by this token.
- **[FEATURE-03-03 — Scheduled Ingestion Orchestration](../FEATURE-03-03-scheduled-ingestion-orchestration.md):** reads `APIFY_TOKEN` from GitHub Actions encrypted secrets for the recurring run, and tracks the deferred eBay API integration (`STORY-03-03-03`).
- **[EPIC-06 — Testing & CI/CD Quality Gates](../../EPIC-06-testing-and-cicd-quality-gates.md):** `STORY-06-01-01` configures the test-harness environment access, reusing the encrypted-secret presence assertion this story introduces.

### Parent feature

- **[FEATURE-03-01 — Apify Actor Integration](../FEATURE-03-01-apify-actor-integration.md)**

## Story Estimation Guidance

- **Effort: Low–Medium** — cross-environment encrypted-secret configuration plus a startup assertion; no application logic is written in this story.
- **Complexity: Low–Medium** — the same `APIFY_TOKEN` secret is managed across the local/dev, CI, and runtime contexts without leaking it into plaintext or into CI logs.
- **Uncertainty: Low** — the `APIFY_TOKEN` and the `ebay-sold-listings` actor already exist, and the Blitzy environments process is documented at <https://docs.blitzy.com/administration/environments>.
- **Fibonacci Story Points: 3.** The configuration spans the single Blitzy environment (consumed across the local, CI, and runtime contexts) and adds a fail-fast assertion, which holds it above a 1–2, while the absence of application logic and the pre-existing token and actor hold it at a 3. Points measure relative size, not a duration.

## Definition of Done

- [ ] The single Blitzy environment is configured and attached to the project per <https://docs.blitzy.com/administration/environments>, with `APIFY_TOKEN` consumed locally, in CI, and at runtime.
- [ ] `APIFY_TOKEN` is stored as an encrypted secret in the single Blitzy environment (never plaintext) and consumed across the local/dev, CI, and runtime contexts, and non-sensitive values are stored as plaintext variables.
- [ ] The actor `ebay-sold-listings` authenticates with the configured token (HTTP 200 identity check), and the Node `>=18` floor — declared in `apify/package.json` (container `apify/actor-node:20`) — is documented.
- [ ] Startup fails fast with a non-zero exit and a logged message that names `APIFY_TOKEN` when the token is missing or empty.
- [ ] The compliance posture is documented (official data sources only; the `ebay-sold-listings` Apify actor is the single sanctioned out-of-band scraping exception; no LLM call is issued in any request handler).
- [ ] No prohibited vague quality term appears in any acceptance criterion, and every criterion names a measurable pass/fail condition (an HTTP status, an exit code, or a named variable).
- [ ] **Testing:** an authentication smoke check returns HTTP 200 with a valid token and exits non-zero on a missing or empty token; a CI run with no configured secret is blocked with a naming error, verified against the encrypted-secret presence assertion.
