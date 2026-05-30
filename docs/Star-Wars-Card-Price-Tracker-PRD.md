# Product Requirements Document
## CompVault — collectible trading-card price intelligence
*(Initial focus: Star Wars cards. "Star Wars" / "Topps" are referenced only descriptively; the brand is CompVault.)*

**Status:** Draft v0.2
**Owner:** Gabriel
**Last updated:** May 30, 2026

---

## 1. Overview

A web app that lets Star Wars card collectors search by **character** and instantly compare **digital** vs **physical** card values side by side — including sold prices, sale dates, descriptions, similar cards, price-history trends, and a direct comparison between a digital card and its physical counterpart (and vice versa).

The system ingests data from eBay (the single source of truth for both physical cards and the digital "Star Wars Card Trader / SWCT" cards that resell on eBay), normalizes messy listing text into a structured card catalog, and accumulates a price-history database going forward over time.

### Problem
Collectors today have no single place to answer: *"What is this specific Grogu variation worth, in digital vs physical, right now and over time, and is it trending up or down?"* eBay's own tools only show 90 days of sold data via search, don't separate digital from physical cleanly, and don't model card variations (parallels, serial-numbered prints) as first-class objects.

### Goals
- Search any character and see digital vs physical comparison in two columns.
- Treat **card variations** (`/25`, `1/1`, serial `15/50`) as the core unit of value.
- Show **sold price history** with a clear up/down trend signal.
- Link a digital card to its physical counterpart where one exists, and surface the comparison both directions.
- Run as cheaply as possible at first (free eBay API tier), with a path to a paid multi-user product later.

### Non-goals (for now)
- Integrating with the SWCT app directly (closed economy, no public API). All digital data comes from eBay resale listings.
- Buying/selling, escrow, or transactions inside the app.
- Grading services, authentication, or population reports beyond what listings provide.

---

## 2. Target users

| Persona | Needs |
|---|---|
| **Collector (primary)** | Look up a character, judge fair value, spot trends, decide buy/sell/hold. |
| **Flipper / reseller** | Find under/over-priced variations, track momentum, compare formats for arbitrage. |
| **You (operator)** | Validate the concept cheaply, then convert engaged users into paying customers. |

v1 is a single-user tool (you); accounts and a paid tier come in a later phase (see §10). Pricing model still open.

---

## 3. Core concepts & data model

The hardest part of this product is **card identity** — turning a messy eBay title into a structured record. These are the entities the whole app is built on.

### 3.1 Entity glossary

- **Card (canonical):** The abstract card, independent of format or copy. e.g. *"Grogu — 2023 Topps Star Wars Flagship — Base."* Attributes: character(s), set, year, card number, subject/type.
- **Variation (a.k.a. parallel):** A specific version of a Card. e.g. *Base*, *Blue parallel /50*, *Red /25*, *1/1 Superfractor*. Key attribute: **print run** (the denominator — 50, 25, 1).
- **Format:** `digital` or `physical`. This is what splits the two columns. A Card+Variation may exist in one or both formats.
- **Grade / condition:** PSA 10, PSA 9, CGC 9.5, BGS, raw/ungraded, etc. A major price axis **for physical only** (digital is effectively always mint and ungraded).
- **Sale (sold observation):** A completed sale. Attributes: matched Card + Variation + Format + Grade, price, currency, **date sold**, serial number if known, source URL, description snippet, raw title. This is the time-series backbone.
- **Listing (active observation):** A currently-active listing. Same shape as a Sale but with asking price + first/last seen timestamps.

### 3.2 Print run vs serial number — important distinction

The user raised this directly. We model **two separate fields**:

- **Print run** (`print_run`): how many copies exist of this variation. `/25` → 25, `1/1` → 1. This belongs to the **Variation**.
- **Serial number** (`serial_number` + `serial_run`): which exact copy a listing is. `15/50` means copy **#15 of 50**. This belongs to the individual **Sale/Listing**, not the variation.

Most price tracking happens at the **variation level** (all `/50` copies form one price series). The specific serial can carry a premium (e.g. `1/50`, low numbers, "jersey number" matches) — captured as a per-sale attribute, flaggable later.

> **Parsing ambiguity to resolve:** `15/50` in a title can mean *serial 15 of 50* OR *card #15 in a 50-card set*. Heuristic: when a parallel/print-run context is present, treat as serial; otherwise treat as card number. Low-confidence parses go to a review queue (§6).

### 3.3 Digital ↔ physical counterpart linking

Physical and digital usually **share the same set + card identity** (same set, same card number, same character), so the counterpart is not a fuzzy heuristic — it's the **same canonical Card expressed in two formats**. Matching works at two levels:

- **Card-level counterpart (almost always available):** the same Card in the other format, used whenever both formats carry the set.
- **Variation-level counterpart (shared parallels only):** the same parallel in both formats. Digital **mimics the physical refractor family** — Mojo `/50`, other numbered parallels, and Superfractor `1/1` exist in both — so those map exactly. Format-exclusive parallels do **not** map: **Gilded** (Gold/Silver/Bronze/Tungsten borders) is **digital-only**; printing plates and some inserts are physical-only.

Consequence for the model: parallels are first-class (`parallel_type`) with a **format availability** of physical / digital / both. The default counterpart is *computed* (same card, or same card + parallel, across formats), not stored; a small override table handles exceptions. The UI shows the exact cross-format match where a shared parallel exists, falls back to a card-level comparison otherwise, and labels *"digital-exclusive / no physical counterpart"* where appropriate.

---

## 4. Functional requirements

### 4.1 Search (primary entry point)
- FR-1: Search by **character** (primary). Autocomplete on known characters (e.g. type "Vader").
- FR-2: Filter controls, all combinable:
  - **Format toggle:** Both (default, two columns) / Digital-only / Physical-only.
  - **Variation filter:** by parallel + print run (`base`, `/25`, `/50`, `1/1`, etc.).
  - **Grade** (physical), **set**, **year**, **price range**.
  - **Date-sold range with granularity:** day / week / month / year. The selected granularity also sets how the history chart buckets points.
- FR-3: Results are **character-centric**, then grouped by variation. All filters apply live to both the chart and the sold-listings table.

### 4.2 Character results — the two-column view
- FR-4: Display results in **two columns: Digital | Physical**.
- FR-5: Each row = a Card/Variation, showing: latest sold price, sold date, condition/grade, serial (if present), a short description snippet, and a sparkline trend.
- FR-6: Filters apply across both columns simultaneously.
- FR-7: "Similar cards" surfaced per result: same character/other variations, same variation/other characters, and nearest-by-value.

### 4.3 Card / variation detail
- FR-8: **Price-history chart** of sold prices over time, with selectable range and **granularity (day / week / month / year)** that drives point bucketing; honors the active format and variation filters.
- FR-9: **Trend indicator**: ▲ / ▼ with % change over the selected window (e.g. "+18% / 90d").
- FR-10: **Recent sales table**: price, date sold, grade, serial #, source link, description snippet.
- FR-11: **Digital ↔ Physical comparison panel**: counterpart's current value, the ratio (e.g. "physical is 3.2× the digital"), and both trend lines overlaid. Works in both directions.
- FR-12: Distinct price series for **PSA/BGS 10, 9, and Raw** (physical); the long tail of grades is grouped.

### 4.4 Comparison view
- FR-13: Dedicated side-by-side view: same card, digital vs physical, with both histories, current spread, and spread-over-time.

### 4.5 Deal scoring (current listings → buy side)
- FR-16: For each active listing (auction or BIN), compute a **deal rating** — Great / Good / Fair / Overpriced — by comparing its effective price to the matched variation+grade valuation (§6.5).
- FR-17: **Effective price** = item price + shipping (total cost to buyer), matched **like-for-like on grade and format**. Never score across grades (raw vs PSA 10) or formats.
- FR-18: **Auctions show a deal ceiling, not a rating of the (low) opening bid.** Surface a **suggested max bid** — the highest price at which winning still rates Good or better (default: ≤ median = Good, ≤ p25 = Great), shown net of expected shipping. As the live bid climbs toward and past that ceiling, the rating updates live ("below target → approaching fair → over ceiling"). An optional **investment ceiling** (a lower max bid that leaves resale margin after fees) supports the flip use case.
- FR-19: Pair the rating with the **trend** (§4.3) so the investment view shows both axes: a great price on a rising card vs a great price on a falling one are surfaced differently.
- FR-20: **Confidence gate** — show sample size; if history is thin (below the minimum-sample threshold), display "low confidence / insufficient history" instead of a confident rating.
- FR-21: Optional **flip view** — estimated resale value minus eBay/payment fees and shipping → potential margin, clearly labeled an estimate, not a guarantee.

### 4.6 Pricing assistant (sell side)
- FR-22: Given a card the user owns (character → variation → grade/format), suggest a **list-price band**: quick-sale anchor (~p25–median), max-value anchor (~p75), and recent median, all from sold history.
- FR-23: Show **expected net after fees** for each anchor, plus a trend note ("up 18% / 90d — you can list toward the high end").
- FR-24: **Fallback when no direct history** — estimate from comparables (same parallel/other characters, card-level counterpart, nearest tier) and label it "estimated from similar cards."
- FR-25: Surface the **cross-format value** (if you hold a digital card, show the physical counterpart's value and vice versa).

### 4.7 Data freshness
- FR-14: Show "last updated" timestamp per card.
- FR-15: New sales appear within one daily ingestion cycle.

---

## 5. Data sources & ingestion

### 5.1 Sources

**Pricing & sales (the money data) — eBay is the single source:**
- **eBay Browse API** (free tier) — active listings; the primary live feed.
- **eBay Marketplace Insights API** — 90-day sold history; *limited-release, must apply, may be denied.* Treated as a bonus, not a dependency.
- History is **accumulated forward** by daily snapshots — the real long-term dataset. (No historical backfill source: eBay offers no cheap API path to old sold data, so the database grows from launch onward.)

**Catalog (the card skeleton) — physical only:**
- **Topps official odds sheets** (topps.com/pages/odds) — per-product PDFs covering both archive and current releases, listing each parallel/insert with its **serial print run and pack odds**. Authoritative source for the `/25`, `/50`, `1/1` counts that feed the Variation entity. Requires a PDF-table parser in the seed pipeline; download and cache politely (the site uses bot detection, so no hammering).
- **Third-party checklist databases** (Cardboard Connection, Beckett, Checklist Insider, Trading Card Database) — for the base **card-number → character/name** mapping that Topps odds sheets often omit. Complementary to the odds sheets. Respect each site's ToS; some (Beckett) are paid.
- **Digital (SWCT)** has no published checklist → its catalog is auto-derived from eBay listings (see §6).

### 5.2 Ingestion job (cost-constrained)
- Run a fixed set of saved queries (per character / per set) on a daily schedule. **MVP queries the US marketplace (EBAY_US) only.**
- Browse API returns ~200 items/call; cache item IDs and only pull detail on new/changed listings to stay under the **5,000 calls/day** free cap.
- Detect "sold/ended" transitions to record Sales.
- Capture **image URLs only** (`image.imageUrl` + `additionalImages`) onto the raw listing — no stored copies. Set `image_status = live`; mark `gone` when the listing ends/purges (or on a failed liveness check).
- Normalize → match → store snapshot.

### 5.3 Digital detection
- Prefer the structured eBay item aspect **`Features: Digital`** to classify format.
- Fallback: keyword/description match on "SWCT", "Card Trader", "digital" when the aspect is absent; flag these as **lower-confidence**.

### 5.4 How eBay data actually arrives (and the quirks to design around)
The shape of the API responses drives the ingestion and risk logic below.

- **Two-tier fetch.** `item_summary/search` returns a *summary* per item — `itemId`, `title`, `price`, `condition`, `conditionId`, `buyingOptions`, `image`, `itemWebUrl`, seller, and item aspects. **Full detail requires a per-item `getItem` call** (adds aspects, full `shippingOptions`, `bidCount`/`currentBidPrice`, `itemEndDate`). Strategy: parse from the summary where possible; spend a `getItem` call only when needed (e.g. to confirm shipping or auction state) to protect the 5,000-call budget.
- **Auctions are opt-in.** Search **excludes auctions by default** and omits `currentBidPrice`/`itemEndDate` unless the query sets `filter=buyingOptions:{AUCTION}` (or `{AUCTION|FIXED_PRICE}`). The auction deal-ceiling feature depends on this filter being set in the saved query.
- **Shipping is unreliable.** The `shippingOptions` container is **sometimes absent** even when the web listing shows shipping, and on `getItem` it's only returned when the `X-EBAY-C-ENDUSERCTX` location header is supplied. Since cost basis = item + shipping, **missing shipping is flagged as estimated — never silently treated as $0**.
- **Change detection is free.** `sellerItemRevision` changes whenever a seller edits a listing (except quantity). Store it and **re-parse only when it changes** — major call-budget saver.
- **Active vs sold are separate feeds.** Browse = active only (asking prices). Sold history = Marketplace Insights (gated). Both write into `raw_listing`/`sale_observation`; treat asking-only data as a labeled fallback, never as a sold comp.
- **IDs:** prefer the RESTful `itemId`; keep `legacyItemId` too, since other tools and URLs use it.

---

## 6. Card catalog + matching engine (core IP)

**Decision (updated — hybrid catalog):** for **physical**, seed canonical cards/variations from authoritative sources — Topps odds sheets (parallels + print runs) plus checklist DBs (card-number → character) — giving a clean ground-truth skeleton. For **digital (SWCT)**, where no checklist exists, **auto-derive** the catalog by clustering eBay listings. Every canonical card carries a `source` flag (`checklist_sourced` vs `listing_derived`). Pricing/sales always come from eBay and are matched onto the catalog.

Pipeline:

1. **Seed (physical):** parse Topps odds-sheet PDFs for parallels + print runs and checklist DBs for card→character; load into canonical cards/variations.
2. **Extract** from each eBay listing (title + item aspects + description): character(s), set, year, card number, variation/parallel, print run, serial number, grade, format. (Rules + regex for serials/print runs; LLM-assisted extraction for messy free text.)
3. **Match** the listing to a seeded canonical card/variation where one exists; for digital (and any unseeded physical), cluster into candidate canonical entries instead.
4. **Confidence score** per extraction and per match. High-confidence auto-commits; low-confidence matches and brand-new clusters go to a **human review queue** to merge duplicates and fix mislabels.
5. **Self-healing** — periodic re-clustering merges duplicate listing-derived entries.

This engine is the moat. Seeding the physical catalog largely removes the fragmentation risk there; fragmentation remains the main risk on the listing-derived **digital** side, mitigated by the review queue + periodic re-clustering.

**Data quality:** the extractor also **flags lots/bundles** ("set of N", "lot of N", multi-card listings) and raw-vs-graded mismatches, so they are excluded from single-card price series rather than polluting comps. Suspected lots surface in the admin data-quality dashboard (§8.6).

---

## 6.5 Valuation engine (powers deal scoring + pricing)

One computed valuation per **(variation, grade, format)**, refreshed periodically from `sale_observation`, feeds both the buy-side deal score (§4.5) and the sell-side pricing assistant (§4.6).

Each valuation holds, over a recency-weighted window (default trailing 90d, fallback 1y):
- **Distribution:** p25 / median / p75, min, max.
- **Sample size (n)** in the window — drives the confidence gate (**low-confidence label at n≥1, confident at n≥5**; n=0 → asking-price estimate, labeled).
- **Trend:** median sold-price change, **90d vs prior 90d** (plus a 30d read when volume allows). A true forecasting model (output as a confidence *range*, not a point) is a Phase 2 item — this thin, irregular data supports showing direction, not prediction.
- **Confidence:** function of n, recency, and variance.
- **Cost basis:** sold price + shipping where available; incorporate Best-Offer accepted prices where present, since the asking price isn't the real one.

Derived outputs:
- **Deal rating** = effective listing price vs the distribution (default: ≤ p25 → Great, p25–median → Good, ~median → Fair, > p75 → Overpriced; thresholds configurable).
- **Deal ceiling / suggested max bid** (auctions) = the highest price that still rates Good or better — default the Good cutoff (≈ median), shown net of expected shipping. Optional **investment ceiling** for flips = resale value − fees − target margin (a lower max bid that preserves profit).
- **Price band** = quick-sale (~p25–median), max-value (~p75), with expected net after fees.
- **Sell-through / liquidity** = sales-per-month and rough days-to-sell over the window — a key reseller signal (price read alongside how fast it moves), and the same query as the distribution.

**Guardrails:** ratings/bands are **informational signals, not financial advice or profit guarantees**; collectibles are volatile and illiquid. Always show n and confidence; suppress confident output below the minimum-sample threshold; never compare across grades or formats.

---

## 7. Non-functional requirements
- **Cost:** MVP runs on eBay free tier ($0 API fees) + minimal hosting. No paid data dependencies in v1.
- **Rate limits:** stay under 5,000 Browse calls/day; request a free Application Growth Check before scaling.
- **Compliance:** use official APIs only; no scraping of eBay search pages (ToS). Respect eBay data-use terms for any cached/displayed data.
- **Images (decided):** store **URLs only** and **hotlink** from eBay's CDN at view time — no stored copies, which sidesteps the copyright/retention exposure entirely. Render with an `<img>` `onError` fallback to a placeholder, and track `image_status` (`live`/`gone`) so the historical view can show "image expired" instead of a broken tile. Trade-off: pictures for *sold* listings disappear over time (price history is kept regardless). If a durable image for a *canonical card* (not a listing) is ever wanted, caching one representative thumbnail is the narrow, more-defensible exception — revisit before public/paid launch.
- **Stack (suggested):** Next.js (Vercel) + managed serverless Postgres; see §7.5 for the full deployment architecture.

---

## 7.5 Deployment architecture (GitHub + Vercel)

### The key split — what runs on Vercel and what cannot
Vercel is serverless: ideal for the app and request/response API, but wrong for long-running or scraping work. Partition accordingly.

**On Vercel (serverless):**
- **Next.js app + API routes** — all read paths: search, charts, deal scores, pricing. Stateless request/response.
- **Stripe webhook route** (Phase 3).

**Managed data services (off Vercel, attached):**
- **Serverless Postgres — recommend Neon** for this app: first-class Vercel + Drizzle integration, scale-to-zero (cheapest when idle), and instant **copy-on-write branching** that gives every PR preview and every CI run its own throwaway database. Access via Neon's **pooled/HTTP driver** — essential, since many short-lived serverless invocations would otherwise exhaust raw Postgres connections. *Choose Supabase instead only if* you'd rather get bundled Auth + Storage from one vendor than assemble best-of-breed — this app's heavy server-side analytical queries don't use Supabase's client-side/RLS/realtime strengths, and it has no instant-branching equivalent.
- **Object storage** (Vercel Blob or Cloudflare R2) for any cached thumbnails.

**Background jobs — NOT a Vercel function:**
- **Recommended home: a scheduled GitHub Actions workflow** runs the daily eBay ingestion + valuation recompute. Jobs can run up to ~6h (no Vercel function timeout), it's free for public repos, and eBay API calls work fine from Actions runners. This keeps Vercel for request/response only — so it can stay on free Hobby until Stripe forces Pro.
- Caveats to design around: scheduled Actions are **UTC-only and commonly delayed 10–30 min** (fine for a daily job, not time-critical work), and GitHub **auto-disables scheduled workflows after 60 days of repo inactivity** (add a keepalive step or push periodically).
- **Graduate path** (sub-daily frequency or stricter reliability): a durable job runner — **Inngest** or **Upstash QStash** — calling your API routes with retries, or a small always-on worker (Railway / Render / Fly.io). LLM-assisted extraction belongs in this worker/queue, never in a request handler.
- (Vercel Cron is a fallback only: its functions time out on long ingests, and Hobby cron is once/day.)

**Off-platform / one-time (never on Vercel):**
- **Topps PDF download** (Playwright, residential IP — datacenter IPs are Cloudflare-blocked) and **PDF parsing**. Run locally; load outputs into Postgres via a script/migration.

### Repo & CI/CD (GitHub → Vercel)
- Single Next.js repo; connect Vercel's GitHub integration → **preview deploy per PR**, production on `main`.
- Separate **preview vs production databases** (Neon branching makes this easy); never point previews at prod data.
- **DB migrations** via Drizzle or Prisma, run in a **GitHub Actions** step (or a deploy hook) — not inside serverless request handlers.
- GitHub Actions for typecheck / lint / test on PR — and it also **hosts the scheduled ingestion** (see Background jobs) and can run migrations against a per-PR **Neon branch** for safe testing.
- **Plan note:** Vercel **Hobby is free but non-commercial and capped at once-per-day cron**; the moment you charge (Stripe), move to **Pro** (commercial use, finer cron, longer function duration).

### Data/runtime layer
- **Drizzle** (lightweight, serverless-friendly) or Prisma as the typed data layer, over the pooled Postgres connection.
- The existing schema already separates **global shared data** (catalog, sales, valuations) from **personal data** (watchlists) — see multi-user below.

### Multi-user readiness (build now, switch on later)
- **Thread a `userId` through every API/data call from day one.** In v1 it's a single seeded user (or hardcoded admin); turning on real auth (**Auth.js** or **Clerk**) then becomes config, not a refactor.
- **Data partition is the key move:** catalog + `sale_observation` + `valuation` are **global** (one shared copy for everyone). Only personal tables — `watchlist`, saved searches, alerts, "my collection" — are scoped by `owner_user_id`. Multi-tenancy is then just a filter on personal tables, while the expensive shared data stays single-copy.
- Keep auth in **middleware** so it's drop-in.

### Stripe billing (Phase 3, stubbed now)
- Use **Stripe Checkout + Customer Portal** (Stripe-hosted UI = least code) and a **webhook route** on Vercel that syncs subscription state into a `subscription` table. **The DB is the source of truth, driven by webhooks — never trust the client.**
- **Entitlements:** a server-side `can(user, feature)` gate maps plan → features (e.g. free: limited history/searches; paid: full history, deal scoring, alerts).
- Schema stubs (`plan`, `subscription`) added now so enabling billing is purely additive.

---

## 7.6 Build plan (scaffold, parser, ingestion)

How the three first code deliverables are built.

### 7.6.1 Repo scaffold — Next.js + Drizzle + Neon (GitHub/Vercel-ready)
Single TypeScript Next.js (App Router) repo:

```
app/                      # UI + API (runs on Vercel)
  (routes)/search, card/[id], compare/
  api/                    # read endpoints; api/stripe/webhook (Phase 3)
db/
  schema.ts               # Drizzle schema, mirrors schema.sql
  client.ts               # Neon pooled/HTTP driver
  migrations/             # drizzle-kit output
lib/
  ebay/                   # OAuth + Browse API client
  matching/               # the extraction parser (§7.6.2)
  valuation/              # valuation compute (§6.5)
  auth/getUserId.ts       # returns the seeded user in v1; swap for Auth.js/Clerk later
  entitlements.ts         # can(user, feature) — billing gate (Phase 3)
jobs/
  ingest.ts               # daily pipeline; run by GitHub Actions or locally
  recompute-valuations.ts
scripts/                  # one-time, LOCAL only
  parse-odds.ts           # Topps PDF -> parallel_type/variation seed
.github/workflows/        # ci.yml, ingest.yml, migrate.yml
drizzle.config.ts  vercel.json  .env.example
```

- **Data layer:** Drizzle ORM over Neon's pooled driver; migrations via `drizzle-kit`, applied in CI (use the unpooled URL for migrations, pooled for the app).
- **Auth seam:** every data call reads `getUserId()` — a constant seeded user in v1 — so enabling real auth is a one-file change.
- **`.env.example`:** `DATABASE_URL` (pooled), `DATABASE_URL_UNPOOLED` (migrations), `EBAY_CLIENT_ID`/`EBAY_CLIENT_SECRET`, `LLM_API_KEY`; later `STRIPE_SECRET_KEY`/`STRIPE_WEBHOOK_SECRET`.

### 7.6.2 Extraction parser (listing → structured fields)
Two stages, deterministic first:
1. **Rules/regex (cheap, high-precision):** pull serial (`15/50` → `serial_number=15`, `serial_run=50`), print run (`/25`, `1/1`), year, grade (PSA/CGC/BGS + value), and format (prefer the `Features: Digital` aspect, else keyword). Tokenize candidate parallel/character. High confidence when structured aspects are present.
2. **LLM fallback (messy titles only):** send title + aspects + description with a **strict JSON schema** (character, set, year, card_number, parallel, print_run, serial, grade, format) and a **per-field confidence**; validate/clamp the JSON before use.
- **Ambiguity rule:** `15/50` = serial when a parallel/print-run context is present, else card number → low confidence → review queue.
- Output rows to `extraction`; the matcher then maps to a seeded `variation` (physical) or clusters (digital); anything below threshold → `review_queue`. Runs inside the ingestion job in batches — never in a request handler; LLM calls are batched.

### 7.6.3 Ingestion workflow (scheduled GitHub Action)
`.github/workflows/ingest.yml` — daily, with manual trigger and a keepalive to dodge the 60-day disable:

```yaml
on:
  schedule: [{ cron: "0 8 * * *" }]   # UTC; expect 10–30 min drift
  workflow_dispatch: {}
jobs:
  ingest:
    runs-on: ubuntu-latest
    timeout-minutes: 120
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - run: npm ci
      - run: node jobs/ingest.ts            # then recompute-valuations.ts
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
          EBAY_CLIENT_ID: ${{ secrets.EBAY_CLIENT_ID }}
          EBAY_CLIENT_SECRET: ${{ secrets.EBAY_CLIENT_SECRET }}
          LLM_API_KEY: ${{ secrets.LLM_API_KEY }}
```

`jobs/ingest.ts` pipeline (idempotent, resumable, budget-aware):
1. Load saved queries (per character/set); get an eBay OAuth client-credentials token.
2. Browse `item_summary/search`, paginate ~200/page; **track a running call count to stay under 5,000/day**; cache seen item IDs to skip duplicates.
3. Upsert `raw_listing` (dedupe on `source_item_id`); detect ended/sold transitions → `sale_observation`; capture image URLs.
4. Run the parser (§7.6.2) on new/changed listings → `extraction` → match/cluster → `review_queue` for low confidence.
5. Run `recompute-valuations.ts` → refresh `valuation`.
6. Log a run summary; a non-zero exit makes the Action fail (GitHub emails you).

Secrets live in GitHub Actions secrets, never committed. The same `jobs/*` scripts run locally for backfill/testing.

---

## 8. Key screens (MVP)
1. **Search bar + autocomplete** (character-first).
2. **Character results** — two-column Digital | Physical with filters and sparklines.
3. **Card/variation detail** — history chart, trend, sales table, counterpart panel.
4. **Comparison view** — digital vs physical side-by-side.
5. (Internal) **Review queue** — approve/correct low-confidence matches.

---

## 8.5 UX & usability (collectors + resellers)

**Shared principles**
- **Image-forward**, but resilient: hotlinked thumbnails with an onError placeholder and an "image expired" state (see §7).
- **Scannable badges** for the things that drive value: variation/parallel (`/25`, `1/1`), grade tier, format. Variations and grades read as chips, not buried text.
- **Confidence is always visible** — every price/deal shows its sample size ("based on 3 sales"), greyed/labeled when thin (n<5). Never a confident-looking number off one sale.
- **Mobile-first** — both personas browse on phones (at shows, while sourcing). Fast autocomplete search with recent searches.
- **Graceful thin/empty states** — no sold data → asking-price estimate, clearly labeled. Deal scores always carry the "informational, not advice" framing.

**Collector / Reseller view toggle** — one organizing idea: same data, reordered emphasis.

**Collector mode**
- **My Collection** — mark cards owned (works pre-multi-user as a local concept; later scoped by `owner_user_id`); collection value rollup.
- **Set-completion view** — X / Y cards owned in a set, missing-card list.
- **Watchlist** with price-drop / great-deal alerts (Phase 3 for push alerts).
- **Visual browse** by character and set; digital-vs-physical comparison front and center.

**Reseller mode**
- **Deals feed** — current listings across watched cards, rated Great/Good/Fair, with the **max-bid ceiling** on auctions.
- **Pricing assistant** — list-price band + **net-after-fees** (per §4.6).
- **Sell-through / liquidity** — sales-per-month and rough days-to-sell, so price is read alongside how fast it moves.
- **Comp lookup** — paste an eBay URL or title → instant matched valuation.
- **Momentum filters** — sort/filter by trend (rising/falling) and liquidity.
- **Saved searches + alerts**.

## 8.6 Admin panel (operations)

Gated by an admin role (ties to the auth seam; in v1 it's just you). Built around this system's real failure modes, not generic CRUD.

- **Review-queue workbench** *(core loop)* — approve/correct extractions and matches; confirm new clusters; **merge duplicate canonical cards** (the main defense against catalog fragmentation).
- **Catalog editor** — merge/split cards & variations; fix character/set/parallel; set `parallel_type.format_availability` (e.g. Gilded = digital) and `print_run`; choose the representative image.
- **Counterpart-override editor** — create/edit manual digital↔physical links where the computed match is wrong or missing.
- **Saved-query manager** — add/edit/disable the eBay search queries that drive ingestion (controls both coverage and the 5,000-call/day budget).
- **Ingestion / job monitor** — last run time, items processed, errors, **calls used vs budget**, and a link to the GitHub Actions run; re-run / backfill triggers.
- **Data-quality dashboard** — match-confidence distribution, % auto-matched vs queued, **duplicate/fragmentation candidates**, suspected **lots/bundles**, zero-sale cards, stale valuations, `image_status = gone` counts.
- **Re-run tools** — re-parse a listing with the latest extractor, re-cluster, recompute a card's valuation.

**Common items the admin fixes** (recurring data problems): duplicate cards from naming variance; misparsed parallel or grade; wrong format (digital listed without the aspect); `15/50` serial-vs-card-number misparse; new set/parallel not yet in catalog; **lots/bundles** masquerading as single cards; raw-vs-graded mislabels.

---

## 9. Success metrics
- Catalog coverage: % of ingested listings matched at high confidence.
- Match accuracy: error rate sampled from the review queue.
- Data depth: # of sales captured per tracked card per month.
- Engagement: searches/user, return rate.
- (Later) conversion to paid.

---

## 10. Phasing

**Phase 0 — Spike:** One character (e.g. Grogu), **both formats**, Browse API, prove the extract → cluster → match pipeline end to end.
**Phase 1 — MVP:** Character search, two-column digital/physical, sales table, basic 90d/1y history + trend, daily ingestion, and the **admin review-queue workbench** — match/extraction correction, duplicate-card merge, and a basic catalog editor (treated as core MVP, since the matcher produces dupes/mis-parses from day one and data degrades without it).
**Phase 2 — Comparison + valuation:** Counterpart linking, spread-over-time, similar-cards engine, grade-split series, low-serial premiums, the richer **admin data-quality dashboard** (fragmentation/lot suspects, zero-sale & stale-valuation surfacing), a **forecasting model** (time-series estimate with a confidence range), and the **valuation engine** (§6.5) with its first consumers — **deal scoring** (§4.5) and the **pricing assistant** (§4.6).
**Phase 3 — Productize:** Multi-user accounts, saved watchlists, alerts ("price up 20%", "great deal on watched card"), paid tier.

---

## 11. Risks & automated controls

Each risk is paired with an **automated, built-in control** so mitigation is mostly system behavior, not manual vigilance.

| Risk | Automated control built into the platform |
|---|---|
| **Call budget overrun (5k/day)** | Live call counter per `ingestion_run`; the job **stops at a safety threshold** (e.g. 90% of budget) and resumes next cycle. `sellerItemRevision` change-detection skips unchanged listings. Summary-first fetch; `getItem` only when required. |
| **Marketplace Insights denied** | No dependency: forward accumulation runs from day one. If/when granted, the sold feed flips on as an additive source. |
| **Matching accuracy / ambiguity** (e.g. `15/50` serial vs card #) | Per-field confidence scoring; anything below threshold auto-routes to the **review queue** instead of committing. Deterministic regex first, LLM only on the messy remainder. |
| **Catalog fragmentation** (one card split into duplicates) | Nightly **auto-clustering** flags duplicate-candidate canonical cards into the queue; admin one-click merge. Seeded physical catalog prevents most of it. |
| **Lot/bundle & mislabel pollution** | Parser auto-flags `is_lot` and raw-vs-graded mismatches; flagged rows set `excluded_from_comps=TRUE` so they never enter a price series. Suspects surfaced in the data-quality dashboard. |
| **Missing/zero shipping** distorting cost basis | Absent `shippingOptions` → shipping marked **estimated**, never $0; valuations note when a comp's cost basis is incomplete. |
| **Thin-volume / unreliable prices** | Confidence gate (n≥1 low-confidence label, n≥5 confident); thin series render as "insufficient history" automatically. |
| **Stale data / silent job failure** | `ingestion_run` health row; a **non-zero exit fails the GitHub Action and emails you**; admin monitor shows last successful run and a freshness alert if a daily run is missed. |
| **GitHub Action auto-disabled (60-day inactivity)** | Scheduled **keepalive** step / periodic commit keeps the workflow enabled. |
| **Image URL rot** | `image_status` flips to `gone`; UI shows an "image expired" placeholder via `onError` — no broken tiles, no stored copies. |
| **eBay ToS / data-use changes** | API-only by policy; a documented monitoring checkpoint for eBay program announcements. (Inherently process, not code.) |
| **Catalog maintenance as new sets release** | New-set detection from unmatched-listing clusters surfaces gaps in the queue; odds-sheet re-parse is a re-runnable script. |

### 11.1 The automation backbone
These controls share four mechanisms already in the schema/architecture:
1. **Confidence + review queue** — the universal "don't auto-commit when unsure" path; the admin workbench is where uncertainty resolves.
2. **`ingestion_run` telemetry** — every run logs calls used, items, errors, queued items; powers budget stops, freshness alerts, and the monitor.
3. **`excluded_from_comps` / quality flags** — keep dirty data *in* the database (for audit) but *out* of valuations.
4. **Idempotent, resumable jobs** — safe to re-run; partial failures self-heal next cycle.
