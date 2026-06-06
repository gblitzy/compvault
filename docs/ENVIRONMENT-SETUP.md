# CompVault — Environment Setup Guide

> **Human-executable operator runbook.** This guide provisions **one Blitzy environment** (configured manually), **two Neon environments** (the `production` and `dev-qa` branches), and **two Vercel environments** (the **Production** scope and the **Preview** scope = dev/qa). Every resource below is created **manually** by following the steps — nothing in this runbook is automated. Work top to bottom: configure the single Blitzy environment and enter its secrets (Sections 1–2), then create the two Neon branches (Section 3), then wire the two Vercel scopes (Section 4).

**Conventions used throughout this guide:**

- **Blitzy:** there is exactly one — *the single Blitzy environment*.
- **Neon branches:** `production` (protected) and `dev-qa` (long-lived).
- **Vercel scopes:** `Production` and `Preview` (Preview = dev/qa); the `Development` scope is local-only.
- **`main`** always refers to the **git** branch that triggers Vercel production deploys — never to a Neon database branch (the Neon production database branch is named `production`).

---

## Section 1 — Blitzy: Single-Environment Build & Run Steps

There is **exactly one Blitzy environment**, and it is configured **manually**. Blitzy cannot create environments, so the dashboard reference at <https://docs.blitzy.com/administration/environments> is **informational only** — you paste the instructions below into the one environment that already exists rather than provisioning a new one.

The application is a **Next.js App Router** project (deployed on Vercel). Configure the single Blitzy environment as follows.

### Runtime configuration

Set the environment's Node version to **20** — use the highest documented floor, **`>=20.20.2`**, taken from the root `package.json` `engines.node`.

> **Note on the Node floor.** Some legacy tickets cite Node `>=18`, a value that originated from `apify/package.json` (the Apify actor's own `engines.node` floor; the Apify container image is Node 20). The **application runtime uses Node `>=20.20.2`** — the higher, authoritative floor from the root manifest.

### Build command

Enter all required **active** secrets (see Section 2) **before** building. The build command installs dependencies and then runs the Next.js build; it **must exit `0`**:

```bash
npm install
npm run build
```

`npm install` also installs the Neon serverless driver pair pinned in the root manifest — `@neondatabase/serverless` and `ws`. If you ever need to install that pair explicitly, the command is identical to the one provided during environment setup:

```bash
npm install @neondatabase/serverless ws
```

### Run command

Start the Next.js server:

```bash
npm run start
```

### Validation

1. Confirm all required **active** secrets from Section 2 are present **before** building.
2. Trigger a test build. On success, the build process **exits `0`** and the single Blitzy environment is marked **validated**.
3. If a required secret is missing, the build **halts with a non-zero exit code that names the missing key** (for example, `DATABASE_URL`), and the environment is **not** marked validated. Add the missing key and re-run the test build.

---

## Section 2 — Manual Secrets & Variables List

Enter the following into **the single Blitzy environment** by hand, and mirror the same values into the **Vercel scopes** (see Section 4) and the **GitHub Actions secrets**. Blitzy holds the **source-of-truth** configuration that is mirrored to Vercel and GitHub Actions. **Never commit real values** — `.env`, `.env.local`, and `.env.*.local` are already git-ignored.

| Variable | Type | Status | Purpose |
|----------|------|--------|---------|
| `NODE_ENV` | Plaintext | Active | Runtime mode (`production`) |
| `DATABASE_URL` | Secret (Sensitive) | Active | Pooled Neon connection — application runtime / ingestion |
| `DATABASE_URL_UNPOOLED` | Secret (Sensitive) | Active | Unpooled/direct Neon connection — DDL and migrations |
| `APIFY_TOKEN` | Secret (Sensitive) | Active | Apify API token for ingestion |
| `LLM_API_KEY` | Secret (Sensitive) | Active | LLM key — batch extraction only, never in request handlers |
| `EBAY_CLIENT_ID` | Secret (Sensitive) | Deferred placeholder | eBay integration (blocked on eBay access) |
| `EBAY_CLIENT_SECRET` | Secret (Sensitive) | Deferred placeholder | eBay integration (blocked on eBay access) |
| `STRIPE_SECRET_KEY` | Secret (Sensitive) | Phase-3 placeholder | Billing (future) |
| `STRIPE_WEBHOOK_SECRET` | Secret (Sensitive) | Phase-3 placeholder | Billing webhooks (future) |

The four **active** secrets — `DATABASE_URL`, `DATABASE_URL_UNPOOLED`, `APIFY_TOKEN`, and `LLM_API_KEY` — must be present (non-empty) for the build to succeed. The deferred (eBay) and Phase-3 (Stripe) entries are added as **empty placeholders** and activated later.

### Connection discipline

`DATABASE_URL` is the **pooled** runtime connection (PgBouncer-pooled; read at application runtime, where many short-lived serverless invocations share one bounded pool). `DATABASE_URL_UNPOOLED` is the **unpooled / direct** connection used for **DDL and migrations**. The two must stay **distinct** — running a migration over the pooled `DATABASE_URL` is the documented failure mode: **mixing them breaks migrations**.

### Secret hygiene

Enter every sensitive credential as an **encrypted / Sensitive** entry, never as a plaintext variable. Real credentials are **never committed** to the repository; only placeholder or encrypted entries appear in documentation, and the real `.env*` files stay git-ignored.

---

## Section 3 — Neon: Two-Environment Setup

Neon models environments as **branches**. Create exactly **two long-lived branches** — `production` and `dev-qa`.

1. **Create the Neon project** and generate a **project API key** (carrying branch create/delete permission).
2. **Production environment.** Use the project's default branch as **`production`**; mark it a **protected** branch (this prevents accidental deletes/resets). Confirm the server runs **PostgreSQL 15+** — required by the `valuation` table's `UNIQUE NULLS NOT DISTINCT` constraint; any Postgres server below 15 rejects it.
3. **Dev/QA environment.** Create **one** long-lived branch named **`dev-qa`** from `production` (a copy-on-write clone). This single branch **replaces** the former per-PR preview branches and per-CI ephemeral branches.
4. **Capture connection strings.** For **each** environment, record **both** the pooled (`DATABASE_URL`) and the unpooled (`DATABASE_URL_UNPOOLED`) connection string.
5. **Route consumers.** Vercel **Production** and production migrations use the `production` strings; Vercel **Preview** (dev/qa), CI, migration rehearsal, and local development all use the `dev-qa` strings.

| Neon environment | Branch | Protected | Consumers | Pooled (`DATABASE_URL`) | Unpooled (`DATABASE_URL_UNPOOLED`) |
|------------------|--------|-----------|-----------|--------------------------|-------------------------------------|
| production | `production` (default root) | Yes | Vercel Production, production migrations | runtime queries | DDL/migrations |
| dev/qa | `dev-qa` (long-lived) | No | Vercel Preview, CI, migration rehearsal, local dev | runtime queries | DDL/migrations |

> **Trade-off — per-run database isolation is lost.** Because previews and CI now share the single `dev-qa` branch, **concurrent CI runs and open PRs share `dev-qa` state**. This is the inherent consequence of the two-environment directive: the legacy model gave every PR and every CI run its own isolated throwaway branch, whereas the shared `dev-qa` branch trades that per-run isolation for a simpler two-environment topology.

---

## Section 4 — Vercel: Two-Environment Setup

Frame Vercel as exactly **two environments** using the platform's built-in scopes. The **Development** scope is **local-only** (consumed via `vercel env pull`) and is **not** a third deployed environment.

1. **Link the repository** and set the **Production Branch** to the git branch **`main`**.
2. **Production environment (Production scope).** Add the variable set scoped to **Production**, pointing `DATABASE_URL` / `DATABASE_URL_UNPOOLED` at the Neon **`production`** branch. Mark database/API values **Sensitive** (Sensitive is allowed only in the Production and Preview scopes).
3. **Dev/QA environment (Preview scope).** Add the variable set scoped to **Preview** — which applies to **all non-production git branches and PRs** — pointing `DATABASE_URL` / `DATABASE_URL_UNPOOLED` at the Neon **`dev-qa`** branch. Mark values **Sensitive**.
4. **Local development (optional).** Add **Development**-scoped values only to support `vercel env pull` for local work.
5. **Redeploy** so the scoped variables take effect.

| Vercel environment | Scope | Git trigger | Neon branch | Sensitive secrets |
|--------------------|-------|-------------|-------------|-------------------|
| production | Production | `main` | `production` | Yes |
| dev/qa | Preview | all non-production branches / PRs | `dev-qa` | Yes |
| (local only) | Development | none (CLI `vercel env pull`) | `dev-qa` | n/a (local) |
