-- ============================================================================
-- CompVault — Database Schema (PostgreSQL)
-- Collectible trading-card price intelligence (initial focus: Star Wars cards).
-- Companion to the PRD. Reflects decisions through 2026-05-30:
--   * eBay is the sole source of pricing/sales data (US marketplace for MVP).
--   * Catalog is HYBRID: physical seeded from Topps odds sheets + checklist DBs;
--     digital (SWCT) auto-derived by clustering eBay listings.
--   * Physical & digital usually share set + card identity. Parallels are either
--     SHARED across formats (Mojo /50, numbered, Superfractor 1/1) or
--     FORMAT-EXCLUSIVE (Gilded Gold/Silver/Bronze/Tungsten = digital-only;
--     printing plates / some inserts = physical-only).
--   * print_run lives on the VARIATION; serial_number lives on each SALE.
--   * Cost basis for comps = item + shipping (shipping captured on listings & sales).
--   * Images: store URLs only and hotlink; no stored copies. image_status = live/gone.
--   * Lots/bundles & mislabels are flagged (extraction) and excluded from comps (sale_observation).
--   * Operations: ingestion_query drives the job; ingestion_run powers the admin monitor.
--   * User data: collection_item ("My Collection") + saved_search, scoped by owner_user_id (NULL in v1).
--   * Single-user v1, but a latent user/ownership concept is included.
-- ============================================================================

-- Optional: fuzzy character search
-- CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ──────────────────────────────────────────────────────────────────────────
-- Enums
-- ──────────────────────────────────────────────────────────────────────────
CREATE TYPE format_t            AS ENUM ('physical', 'digital');
CREATE TYPE format_availability AS ENUM ('physical', 'digital', 'both');
CREATE TYPE catalog_source      AS ENUM ('topps_odds', 'checklist_db', 'listing_derived', 'manual');
CREATE TYPE match_status        AS ENUM ('pending', 'auto', 'reviewed', 'rejected');
CREATE TYPE listing_status      AS ENUM ('active', 'ended_unsold', 'sold', 'unknown');
CREATE TYPE image_status_t      AS ENUM ('live', 'gone', 'unknown');
CREATE TYPE review_kind         AS ENUM ('extraction', 'match', 'new_cluster', 'merge_candidate');
CREATE TYPE review_state        AS ENUM ('open', 'resolved', 'dismissed');

-- ──────────────────────────────────────────────────────────────────────────
-- CATALOG (the card skeleton)
-- ──────────────────────────────────────────────────────────────────────────

-- A set may exist in physical, digital, or both formats. Modeled once,
-- format-agnostic; which formats it carries is recorded on format_availability.
CREATE TABLE card_set (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name                TEXT NOT NULL,                     -- '2023 Topps Star Wars Flagship'
    year                SMALLINT,
    manufacturer        TEXT NOT NULL DEFAULT 'Topps',
    franchise           TEXT NOT NULL DEFAULT 'Star Wars',
    format_availability format_availability NOT NULL DEFAULT 'both',
    source              catalog_source NOT NULL,
    topps_odds_url      TEXT,                              -- source odds-sheet PDF, if any
    notes               TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (name, year)
);

CREATE TABLE character (
    id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name     TEXT NOT NULL UNIQUE,                          -- 'Grogu'
    aliases  JSONB NOT NULL DEFAULT '[]'                    -- ['The Child']
);

-- The canonical card: one row per (set, card number). Format-agnostic.
CREATE TABLE card (
    id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    set_id            BIGINT NOT NULL REFERENCES card_set(id),
    card_number       TEXT,                                 -- TEXT: handles 'A-OD', 'LAY-1', etc.
    name              TEXT,                                 -- card title, if distinct from character
    subject_type      TEXT,                                 -- character / ship / location / moment
    source            catalog_source NOT NULL,
    source_confidence REAL,                                 -- 0..1, meaningful for listing_derived
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (set_id, card_number)
);

-- Cards can feature multiple characters (e.g. 'Darth Vader, Obi-Wan, Stormtrooper').
CREATE TABLE card_character (
    card_id      BIGINT NOT NULL REFERENCES card(id) ON DELETE CASCADE,
    character_id BIGINT NOT NULL REFERENCES character(id),
    PRIMARY KEY (card_id, character_id)
);

-- A parallel family, reusable across sets/cards. THE KEY FIELD is
-- format_availability: 'both' for refractor-family (Mojo, Superfractor, numbered),
-- 'digital' for Gilded tiers, 'physical' for printing plates etc.
CREATE TABLE parallel_type (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name                TEXT NOT NULL UNIQUE,               -- 'Base','Mojo Refractor','Superfractor','Gilded Gold'
    family              TEXT,                               -- 'refractor','gilded','foil','base','printing_plate'
    format_availability format_availability NOT NULL,
    rarity_rank         SMALLINT,                           -- optional ordering (lower = more common)
    notes               TEXT
);

-- A concrete collectible: a card in a specific parallel and format.
-- print_run is set/card-specific (e.g. Green is /25 here, /99 elsewhere).
-- The VARIATION-LEVEL cross-format counterpart = two rows sharing
-- (card_id, parallel_type_id) that differ in `format` — only possible when the
-- parallel_type is available in both formats.
CREATE TABLE variation (
    id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    card_id           BIGINT NOT NULL REFERENCES card(id),
    parallel_type_id  BIGINT NOT NULL REFERENCES parallel_type(id),
    format            format_t NOT NULL,
    print_run         INTEGER,                              -- 50, 25, 1 (1/1); NULL = unnumbered
    pack_odds         TEXT,                                 -- '1:264' from Topps odds sheet (physical)
    rep_image_url     TEXT,                                 -- chosen display image (hotlinked)
    rep_image_key     TEXT,                                 -- optional: object-storage key if a thumbnail is cached
    source            catalog_source NOT NULL,
    source_confidence REAL,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (card_id, parallel_type_id, format)
);

-- Physical grading. Digital is effectively always mint/ungraded → grade_id NULL.
CREATE TABLE grade (
    id          SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    grader      TEXT NOT NULL,                              -- 'PSA','CGC','BGS','SGC','RAW'
    grade_value NUMERIC(3,1),                               -- 10, 9.5; NULL for raw
    label       TEXT NOT NULL UNIQUE,                       -- 'PSA 10','CGC 9.5','Raw'
    tier        TEXT                                        -- price-series bucket: 'GEM10','NM9','RAW','OTHER' (MVP separates these, groups the long tail)
);

-- ──────────────────────────────────────────────────────────────────────────
-- INGESTION (raw eBay data → extraction → matched sales)
-- ──────────────────────────────────────────────────────────────────────────

-- Raw, unmodified observation of an eBay listing. Source of truth for re-parsing.
-- Active asking prices are read directly from here (status = 'active').
CREATE TABLE raw_listing (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source         TEXT NOT NULL DEFAULT 'ebay',
    source_item_id TEXT NOT NULL,
    marketplace    TEXT,                                    -- 'EBAY_US','EBAY_GB'
    title          TEXT,
    description    TEXT,
    item_aspects   JSONB,                                   -- includes 'Features: Digital', Set, Character...
    asking_price   NUMERIC(12,2),
    shipping_cost  NUMERIC(12,2),                           -- for item+shipping cost basis (NULL if free/unknown)
    currency       TEXT,
    seller         TEXT,
    listing_url    TEXT,
    primary_image_url    TEXT,                              -- image.imageUrl from Browse API (hotlinked, not copied)
    additional_image_urls JSONB,                            -- array of additionalImages URLs
    image_status   image_status_t NOT NULL DEFAULT 'unknown', -- live = URL resolves; gone = listing ended/purged
    status         listing_status NOT NULL DEFAULT 'active',
    first_seen     TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen      TIMESTAMPTZ NOT NULL DEFAULT now(),
    end_date       TIMESTAMPTZ,
    UNIQUE (source, source_item_id)
);

-- Parsed fields from a raw_listing. Kept separate from matching so the parser
-- can be re-run/versioned without losing history. NOTE the serial split:
-- ex_serial_number/ex_serial_run capture '15/50'; ex_print_run is the /50 of the variation.
CREATE TABLE extraction (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    raw_listing_id   BIGINT NOT NULL REFERENCES raw_listing(id) ON DELETE CASCADE,
    extractor_version TEXT NOT NULL,
    ex_character     TEXT,
    ex_set           TEXT,
    ex_year          SMALLINT,
    ex_card_number   TEXT,
    ex_parallel      TEXT,
    ex_print_run     INTEGER,                               -- variation print run (the 50 in '/50')
    ex_serial_number INTEGER,                               -- per-copy: the 15 in '15/50'
    ex_serial_run    INTEGER,                               -- per-copy: the 50 in '15/50'
    ex_grade         TEXT,
    ex_format        format_t,
    is_lot           BOOLEAN NOT NULL DEFAULT FALSE,         -- "set of N" / "lot of N" / multi-card
    quality_flags    JSONB,                                  -- e.g. {"raw_vs_graded_mismatch": true}
    confidence       REAL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- A completed sale, matched onto the catalog. The time-series backbone.
-- card_id is denormalized for fast character-centric queries.
CREATE TABLE sale_observation (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    raw_listing_id  BIGINT REFERENCES raw_listing(id),
    variation_id    BIGINT REFERENCES variation(id),        -- NULL until matched
    card_id         BIGINT REFERENCES card(id),             -- denormalized
    grade_id        SMALLINT REFERENCES grade(id),          -- physical only; NULL for digital
    format          format_t NOT NULL,
    sale_price      NUMERIC(12,2) NOT NULL,
    shipping_cost   NUMERIC(12,2),                          -- item+shipping cost basis = sale_price + shipping_cost
    currency        TEXT NOT NULL DEFAULT 'USD',
    sale_date       DATE NOT NULL,
    serial_number   INTEGER,                                -- per-copy: 15
    serial_run      INTEGER,                                -- per-copy: 50 (≈ variation.print_run)
    match_confidence REAL,
    match_status    match_status NOT NULL DEFAULT 'pending',
    excluded_from_comps BOOLEAN NOT NULL DEFAULT FALSE,      -- TRUE for lots/bundles/mislabels → kept out of price series
    exclude_reason  TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ──────────────────────────────────────────────────────────────────────────
-- OPERATIONS (saved queries that drive ingestion; run history for the monitor)
-- ──────────────────────────────────────────────────────────────────────────

-- The eBay searches the daily job runs. Managed in the admin saved-query tool;
-- enabling/disabling here controls both coverage and the 5,000-call/day budget.
CREATE TABLE ingestion_query (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    label         TEXT,                                      -- e.g. 'Grogu — all'
    query_text    TEXT NOT NULL,                             -- eBay keyword query
    marketplace   TEXT NOT NULL DEFAULT 'EBAY_US',
    category_id   TEXT,                                      -- optional eBay category filter
    aspect_filter JSONB,                                     -- optional structured filters
    enabled       BOOLEAN NOT NULL DEFAULT TRUE,
    last_run_at   TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- One row per ingestion run; powers the admin job monitor.
CREATE TABLE ingestion_run (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    started_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at  TIMESTAMPTZ,
    status       TEXT NOT NULL DEFAULT 'running',            -- running / ok / failed
    items_seen   INTEGER NOT NULL DEFAULT 0,
    items_new    INTEGER NOT NULL DEFAULT 0,
    sales_recorded INTEGER NOT NULL DEFAULT 0,
    calls_used   INTEGER NOT NULL DEFAULT 0,                 -- vs the 5,000/day budget
    queued_for_review INTEGER NOT NULL DEFAULT 0,
    error_count  INTEGER NOT NULL DEFAULT 0,
    notes        TEXT
);

-- ──────────────────────────────────────────────────────────────────────────
-- COUNTERPARTS, REVIEW, USERS
-- ──────────────────────────────────────────────────────────────────────────

-- Counterparts are normally COMPUTED, not stored (same card_id across formats,
-- or same card_id + parallel_type_id across formats). This table records only
-- manual exceptions/overrides the curator sets.
CREATE TABLE counterpart_override (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    link_level       TEXT NOT NULL CHECK (link_level IN ('card', 'variation')),
    physical_ref_id  BIGINT NOT NULL,                       -- card_id or variation_id (per link_level)
    digital_ref_id   BIGINT NOT NULL,
    is_manual        BOOLEAN NOT NULL DEFAULT TRUE,
    confidence       REAL,
    notes            TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Low-confidence extractions/matches and new/duplicate clusters land here.
CREATE TABLE review_queue (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    kind        review_kind NOT NULL,
    ref_table   TEXT,
    ref_id      BIGINT,
    reason      TEXT,
    payload     JSONB,
    state       review_state NOT NULL DEFAULT 'open',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at TIMESTAMPTZ,
    resolved_by BIGINT
);

-- Latent multi-tenancy. v1 is single-user; owner_user_id stays NULL until
-- accounts ship, so adding them later is non-breaking.
CREATE TABLE app_user (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email        TEXT UNIQUE,
    display_name TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE watchlist (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner_user_id BIGINT REFERENCES app_user(id),          -- NULL in v1 = the single operator
    card_id       BIGINT REFERENCES card(id),
    variation_id  BIGINT REFERENCES variation(id),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- "My Collection" — cards the user owns (works pre-multi-user with owner_user_id NULL).
-- acquisition_price enables collection-value and P&L views.
CREATE TABLE collection_item (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner_user_id    BIGINT REFERENCES app_user(id),        -- NULL in v1 = the single operator
    variation_id     BIGINT NOT NULL REFERENCES variation(id),
    grade_id         SMALLINT REFERENCES grade(id),         -- physical only
    serial_number    INTEGER,                               -- the specific copy owned, if known
    quantity         INTEGER NOT NULL DEFAULT 1,
    acquisition_price NUMERIC(12,2),
    acquired_at      DATE,
    notes            TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Reseller saved searches + alert config (alerts are Phase 3).
CREATE TABLE saved_search (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner_user_id BIGINT REFERENCES app_user(id),           -- NULL in v1 = the single operator
    label         TEXT,
    params        JSONB NOT NULL,                           -- character/format/variation/grade/price filters
    alert_on      TEXT,                                     -- e.g. 'great_deal', 'price_drop', NULL = no alert
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Billing (Phase 3 stub — Stripe). Inactive in v1; enabling is additive. ──
CREATE TYPE plan_t AS ENUM ('free', 'pro');

-- One row per user, kept in sync by the Stripe webhook route. The DB is the
-- source of truth for entitlements; the webhook — never the client — updates it.
CREATE TABLE subscription (
    id                     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id                BIGINT NOT NULL REFERENCES app_user(id),
    plan                   plan_t NOT NULL DEFAULT 'free',
    status                 TEXT,                            -- Stripe sub status: active, past_due, canceled...
    stripe_customer_id     TEXT,
    stripe_subscription_id TEXT,
    current_period_end     TIMESTAMPTZ,
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id)
);

-- ──────────────────────────────────────────────────────────────────────────
-- VALUATION (cache; powers deal scoring §4.5 + pricing assistant §4.6)
-- ──────────────────────────────────────────────────────────────────────────

-- One computed row per (variation, grade, window), refreshed by a periodic job
-- from sale_observation. Both the buy-side deal score and the sell-side price
-- band read from here. Never mixes grades or formats (format is implied by the
-- variation; grade is NULL for digital).
CREATE TABLE valuation (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    variation_id BIGINT NOT NULL REFERENCES variation(id),
    grade_id     SMALLINT REFERENCES grade(id),       -- NULL for digital / ungraded
    window_days  SMALLINT NOT NULL,                   -- 90, 365
    cost_basis   TEXT NOT NULL DEFAULT 'item_plus_shipping',
    p25          NUMERIC(12,2),
    median       NUMERIC(12,2),
    p75          NUMERIC(12,2),
    price_min    NUMERIC(12,2),
    price_max    NUMERIC(12,2),
    sample_size  INTEGER NOT NULL,                    -- drives the confidence gate
    sales_per_month  REAL,                            -- liquidity / sell-through signal
    avg_days_to_sell REAL,                            -- est. time-to-sell over the window
    trend_pct    REAL,                                -- vs prior window
    trend_dir    SMALLINT,                            -- -1 down / 0 flat / +1 up
    confidence   REAL,                                -- 0..1
    currency     TEXT NOT NULL DEFAULT 'USD',
    computed_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- NULLS NOT DISTINCT requires PostgreSQL 15+, so digital (grade_id NULL) stays unique:
    UNIQUE NULLS NOT DISTINCT (variation_id, grade_id, window_days, cost_basis)
);
CREATE INDEX idx_valuation_variation ON valuation (variation_id, grade_id);

-- ──────────────────────────────────────────────────────────────────────────
-- Indexes (hot paths)
-- ──────────────────────────────────────────────────────────────────────────
CREATE INDEX idx_card_set            ON card (set_id);
CREATE INDEX idx_cardchar_character  ON card_character (character_id);
CREATE INDEX idx_variation_card_par  ON variation (card_id, parallel_type_id);
CREATE INDEX idx_sale_variation_date ON sale_observation (variation_id, sale_date);
CREATE INDEX idx_sale_card_date      ON sale_observation (card_id, sale_date);
CREATE INDEX idx_sale_format_date    ON sale_observation (format, sale_date);
CREATE INDEX idx_rawlisting_status   ON raw_listing (status);
CREATE INDEX idx_collection_owner    ON collection_item (owner_user_id);
CREATE INDEX idx_ingestion_query_on  ON ingestion_query (enabled);
CREATE INDEX idx_sale_comps          ON sale_observation (variation_id, sale_date) WHERE NOT excluded_from_comps;
-- Fuzzy character search (requires pg_trgm):
-- CREATE INDEX idx_character_name_trgm ON character USING gin (name gin_trgm_ops);


-- ============================================================================
-- EXAMPLE QUERIES (reference — not part of the migration)
-- ============================================================================
--
-- 1) Character search → every card featuring that character:
-- SELECT c.* FROM card c
--   JOIN card_character cc ON cc.card_id = c.id
--   JOIN character ch ON ch.id = cc.character_id
--  WHERE ch.name ILIKE 'Grogu';
--
-- 2) Two-column view: latest sold price per variation, split by format:
-- SELECT v.id, pt.name AS parallel, v.format, v.print_run,
--        s.sale_price, s.sale_date
--   FROM variation v
--   JOIN parallel_type pt ON pt.id = v.parallel_type_id
--   LEFT JOIN LATERAL (
--        SELECT sale_price, sale_date FROM sale_observation so
--         WHERE so.variation_id = v.id
--         ORDER BY so.sale_date DESC LIMIT 1
--   ) s ON TRUE
--  WHERE v.card_id = $1;          -- ORDER/group by v.format in the app for the 2 columns
--
-- 3) Price history + trend (median sold price per month, last 12 months):
-- SELECT date_trunc('month', sale_date) AS month,
--        percentile_cont(0.5) WITHIN GROUP (ORDER BY sale_price) AS median_price,
--        count(*) AS n
--   FROM sale_observation
--  WHERE variation_id = $1 AND sale_date >= now() - INTERVAL '12 months'
--  GROUP BY 1 ORDER BY 1;
--   -- Trend = median 90d vs prior 90d; n>=1 shows low-confidence, n>=5 confident.
--
-- 4) Variation-level cross-format counterpart (shared parallel only):
-- SELECT v2.* FROM variation v1
--   JOIN variation v2
--     ON v2.card_id = v1.card_id
--    AND v2.parallel_type_id = v1.parallel_type_id
--    AND v2.format <> v1.format
--  WHERE v1.id = $1;              -- returns nothing for Gilded (digital-only) → fall back to card-level
--
-- 5) Card-level cross-format counterpart (the fallback):
-- SELECT v.* FROM variation v
--  WHERE v.card_id = (SELECT card_id FROM variation WHERE id = $1)
--    AND v.format <> (SELECT format FROM variation WHERE id = $1);
