# eBay Sold Listings Scraper (Apify Actor)

Scrapes **completed / sold** eBay listings — final sale prices and sold dates — for a list of search terms. Built for pricing-intelligence use cases (comps, deal scoring, seller pricing).

## How it works

For each search term the actor requests eBay's search page with `LH_Sold=1&LH_Complete=1` (the parameters that switch results to sold/completed items), parses each result card, and pushes structured rows to the default dataset. It paginates up to `maxPagesPerSearch` per term and stops early when a page returns no items.

It uses a `CheerioCrawler` (no headless browser) because the sold-listings search results are server-rendered HTML. That keeps Apify compute cheap. The underlying HTTP client (`got-scraping`) rotates realistic browser headers and TLS fingerprints automatically.

## Input

| Field | Type | Default | Notes |
|---|---|---|---|
| `searchTerms` | string[] | — (required) | One or more keyword queries, searched independently. |
| `ebayDomain` | string | `www.ebay.com` | Regional eBay site (`.co.uk`, `.de`, `.com.au`, etc.). |
| `itemsPerPage` | int (60/120/240) | `240` | eBay's `_ipg`. 240 minimizes request count. |
| `maxPagesPerSearch` | int | `3` | Pages per term. ~240 items/page at the default. |
| `maxItems` | int | `0` | Global cap across all terms. `0` = no limit. |
| `proxyConfiguration` | proxy | `RESIDENTIAL` | See note below. |

Example input:

```json
{
  "searchTerms": ["1977 topps star wars", "mandalorian topps chrome"],
  "ebayDomain": "www.ebay.com",
  "itemsPerPage": "240",
  "maxPagesPerSearch": 3,
  "maxItems": 0,
  "proxyConfiguration": { "useApifyProxy": true, "apifyProxyGroups": ["RESIDENTIAL"] }
}
```

## Output

One dataset record per sold listing:

```json
{
  "searchTerm": "1977 topps star wars",
  "itemId": "123456789012",
  "title": "1977 Topps Star Wars #1 Luke Skywalker PSA 8",
  "priceRaw": "$84.99",
  "priceMin": 84.99,
  "priceMax": 84.99,
  "currency": "$",
  "soldDateRaw": "Sold Mar 15, 2026",
  "soldDate": "2026-03-15",
  "condition": "Pre-Owned",
  "shipping": "+$4.99 shipping",
  "bids": null,
  "imageUrl": "https://i.ebayimg.com/...",
  "url": "https://www.ebay.com/itm/123456789012",
  "scrapedAt": "2026-06-02T14:00:00.000Z"
}
```

`priceMin`/`priceMax` differ only when eBay shows a range (e.g. variations "$10.00 to $20.00"). For single-price sales they're equal.

## Proxies (important)

eBay flags datacenter and unproxied IPs almost immediately (captcha, then IP ban). The actor defaults to Apify **RESIDENTIAL** proxies for that reason. If you still see blocks at higher volume, lower `maxConcurrency` in `src/main.js` and/or reduce pages per run. Realistic safe throughput is roughly one request every 2–4 seconds per IP, which residential rotation handles at the default concurrency of 8.

When the actor detects a captcha/interstitial page it throws, which triggers a retry through a fresh proxy session (up to `maxRequestRetries`).

## Run locally

```bash
npm install
# Apify proxy needs a token when run locally:
export APIFY_TOKEN=your_token
apify run               # if you have the Apify CLI
# or
node src/main.js        # uses ./storage for input/output
```

For a local run without the CLI, put your input in `storage/key_value_stores/default/INPUT.json` and results land in `storage/datasets/default/`.

## Deploy

```bash
apify push
```

Then run from the Apify console or via the API/scheduler.

## Maintenance notes

- eBay periodically changes its DOM and A/B-tests new class names. The parser already tries both `s-item__*` and the newer `s-card__*` selectors. If a run suddenly returns 0 items for a query that should have results, that's a DOM change, not an IP issue — check the live page's class names and add them to the selector arrays in `src/main.js`.
- The first result card is usually a "Shop on eBay" placeholder; it's filtered out by requiring a valid numeric `itemId`.
- The sanctioned alternative for sold data is eBay's **Marketplace Insights API** (approval-gated). If you get access, prefer it for reliability; this actor is the practical fallback when API access isn't available.

## Legal / ToS

eBay's Terms of Service prohibit automated access without permission. Scraping publicly visible pages is generally treated as a civil (ToS) matter rather than criminal, but downstream use of the data in a commercial product can carry its own copyright/database considerations. Scrape unauthenticated and from IPs unrelated to any eBay account you own. This tool is provided for you to evaluate against your own legal and compliance requirements.
