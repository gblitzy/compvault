# STORY-06-02-03: Author Apify Helper Tests

*Parent feature: [FEATURE-06-02 — Unit & Integration Suites](../FEATURE-06-02-unit-and-integration-suites.md) · Parent epic: [EPIC-06 — Testing & CI/CD Quality Gates](../../EPIC-06-testing-and-cicd-quality-gates.md)*

## User Story

As a QA Engineer, I want unit tests for the actor helpers parsePrice, parseSoldDate, and extractItemId against HTML and string fixtures, so that ingestion-parsing regressions are caught before merge and the ≥90% coverage bar is enforced.

These three helpers live in the existing Apify actor source `apify/src/main.js`. This story authors tests for them; it does not modify the actor. The helpers are pure string/URL functions: `extractItemId` pulls the numeric eBay item id out of a listing URL, `parsePrice` turns a price caption into `{ priceRaw, priceMin, priceMax, currency }`, and `parseSoldDate` turns a sold-date caption into `{ soldDateRaw, soldDate }`. The string inputs are sourced both directly and from the `li.s-item` / `li.s-card` listing-card HTML fixtures established in `STORY-06-01-02`, and the suite runs under the Vitest harness from `STORY-06-01-01`.

## Acceptance Criteria

1. **(input-validation)** *Given* a `null` argument, *When* `parsePrice(null)` and `parseSoldDate(null)` execute, *Then* `parsePrice(null)` returns the object `{ priceRaw: null, priceMin: null, priceMax: null, currency: null }`, `parseSoldDate(null)` returns the object `{ soldDateRaw: null, soldDate: null }`, and 0 exceptions are thrown.

2. **(input-validation)** *Given* the empty string `""` as the argument to `parsePrice`, *When* the test executes, *Then* the return value is the object `{ priceRaw: null, priceMin: null, priceMax: null, currency: null }`.

3. **(valid-output — price)** *Given* the string fixture `"$12.50"`, *When* `parsePrice` executes, *Then* it returns `priceRaw = "$12.50"`, `priceMin = 12.5`, `priceMax = 12.5`, and `currency = "$"`.

4. **(valid-output — date)** *Given* the caption fixture `"Sold  Mar 15, 2026"` (two space characters after the word "Sold"), *When* `parseSoldDate` executes, *Then* it returns `soldDate = "2026-03-15"` and `soldDateRaw = "Sold Mar 15, 2026"` (the input whitespace is normalized to single space characters).

5. **(valid-output — id)** *Given* the listing URL `"https://www.ebay.com/itm/167382912345"` whose id has 12 digits, *When* `extractItemId` executes, *Then* it returns the string `"167382912345"`.

6. **(error-handling)** *Given* the URL `"https://www.ebay.com/sch/i.html?_nkw=luke+skywalker"` that contains no `/itm/<digits>` segment, *When* `extractItemId` executes, *Then* it returns `null` and throws 0 exceptions.

7. **(edge-case — boundary)** *Given* the URL `"https://www.ebay.com/itm/12345"` whose id has 5 digits (one digit below the `\d{6,}` floor), *When* `extractItemId` executes, *Then* it returns `null`; **AND** *Given* the range string `"£10.00 to £20.00"`, *When* `parsePrice` executes, *Then* it returns `priceMin = 10`, `priceMax = 20`, and `currency = "£"`.

8. **(coverage gate)** *Given* the helper suite runs under `vitest run` with coverage instrumentation, *When* line coverage for `parsePrice`, `parseSoldDate`, and `extractItemId` is below the **≥90%** bar, *Then* the test command exits with a non-zero status and the build fails.

## Sub-tasks

- Author `parsePrice` test cases for the single price `"$12.50"` (→ `priceMin = 12.5`, `priceMax = 12.5`, `currency = "$"`), the range `"£10.00 to £20.00"` (→ `priceMin = 10`, `priceMax = 20`, `currency = "£"`), the currency-prefixed `"C $9.99"` (→ `priceMin = 9.99`, `priceMax = 9.99`, `currency = "C $"`), the comma-thousands token `"$1,250.00"` (→ `priceMin = 1250`, `priceMax = 1250`), and the `null`/empty-string all-null shape. `@qa-engineer`
- Author `parseSoldDate` test cases for `"Sold  Mar 15, 2026"` (→ `soldDate = "2026-03-15"`, `soldDateRaw = "Sold Mar 15, 2026"`) and for an unparseable token such as `"Best offer accepted"` (→ `soldDate = null`, `soldDateRaw = "Best offer accepted"`). `@qa-engineer`
- Author `extractItemId` test cases for the 12-digit URL `"https://www.ebay.com/itm/167382912345"` (→ `"167382912345"`), the optional-slug URL `"https://www.ebay.com/itm/star-wars-luke/167382912345"` (→ `"167382912345"`), the 5-digit URL `"https://www.ebay.com/itm/12345"` (→ `null`), and a URL with no `/itm/` segment (→ `null`, 0 exceptions). `@qa-engineer`
- Source the price and sold-date strings from the `li.s-item` / `li.s-card` HTML fixtures of `STORY-06-01-02` and feed them through `parsePrice` and `parseSoldDate` to assert the same exact values end-to-end. `@qa-engineer`
- Run the helper suite under Node `>=18` via the `STORY-06-01-01` Vitest harness and assert the helper line-coverage gate at **≥90%**. `@qa-engineer`

## Edge Cases

- **Empty/Null:** `null` (and the empty string `""`) passed to `parsePrice` returns `{ priceRaw: null, priceMin: null, priceMax: null, currency: null }`; `null` passed to `parseSoldDate` returns `{ soldDateRaw: null, soldDate: null }`.
- **Boundary:** a URL whose id has 5 digits makes `extractItemId` return `null`, while a 6-digit id is the shortest id that matches the `\d{6,}` pattern and is returned as a string.
- **Invalid:** a comma-thousands price token such as `"$1,250.00"` has its commas stripped before numeric parsing, so `priceMin = 1250` and `priceMax = 1250` (not `1`).
- **Invalid:** an unparseable date token such as `"Best offer accepted"` makes `parseSoldDate` return `soldDate = null`, while `soldDateRaw` retains the whitespace-normalized input text `"Best offer accepted"`.
- **Edge:** the currency-prefixed price `"C $9.99"` yields `currency = "C $"`, `priceMin = 9.99`, and `priceMax = 9.99`.

## Dependencies

- `STORY-06-01-01` — the Vitest harness (single Vitest configuration and coverage runner) that this suite executes under.
- `STORY-06-01-02` — the Apify HTML fixtures (eBay listing cards `li.s-item` / `li.s-card`) and the price/date string fixtures this suite reads.
- `apify/src/main.js` — REFERENCE only, never modified: the ES-module actor source that defines `parsePrice`, `parseSoldDate`, and `extractItemId`. `apify/package.json` fixes the actor as `type: module` on Node `>=18`.

## Story Estimation Guidance

- **Effort:** Low–Moderate — three small pure helper functions with a bounded set of string and URL inputs.
- **Complexity:** Low — deterministic string and regular-expression parsing with no network, no filesystem, and no database access.
- **Uncertainty:** Low — the three contracts are fixed by the existing `apify/src/main.js` source and are unchanged by this story.
- **Estimate: 3 points** (Fibonacci).

## Definition of Done

- [ ] Tests authored for `parsePrice`, `parseSoldDate`, and `extractItemId` covering valid, `null`, boundary, and invalid inputs.
- [ ] Exact expected values asserted: the parsed numbers `12.5`, `10`, `20`, `9.99`, and `1250`; the ISO date string `"2026-03-15"`; the normalized `soldDateRaw` `"Sold Mar 15, 2026"`; the id string `"167382912345"`; and every `null` return.
- [ ] Suite runs under Node `>=18` against the Apify HTML and string fixtures from `STORY-06-01-02`, executed via the `STORY-06-01-01` Vitest harness.
- [ ] At least one input-validation test, one valid-output test, one error-handling test, and one edge-case test are present; no prohibited vague quality term appears in any acceptance criterion.
- [ ] `apify/src/main.js` is referenced as the source of the three helpers and is not modified by this story.
- [ ] **Testing:** the helper suite runs green under `vitest run` and reports line coverage **≥90%**; line coverage below 90% exits non-zero and fails the build.
