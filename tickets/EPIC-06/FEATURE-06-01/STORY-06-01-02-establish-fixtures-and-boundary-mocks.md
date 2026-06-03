# STORY-06-01-02: Establish Fixtures & Boundary Mocks

*Parent feature: [FEATURE-06-01 — Test Harness & Environment Access](../FEATURE-06-01-test-harness-and-environment-access.md) · Parent epic: [EPIC-06 — Testing & CI/CD Quality Gates](../../EPIC-06-testing-and-cicd-quality-gates.md)*

This is the second story of FEATURE-06-01. It establishes the shared `__fixtures__` directory and the boundary mocks that the single Vitest harness from [STORY-06-01-01](STORY-06-01-01-configure-vitest-and-env-access.md) loads, so that every later EPIC-06 suite runs offline against deterministic inputs. The per-CI Neon-branch wiring is the concern of the sibling story [STORY-06-01-03](STORY-06-01-03-wire-integration-tests-to-neon-branch.md); this story scopes only the fixtures and the network/proxy and LLM boundary mocks. The eBay sold-listing HTML fixtures mirror the cards and helper field shapes defined by the read-only actor `apify/src/main.js`.

## User Story

As a **QA Engineer**, I want shared `__fixtures__` and boundary mocks that stub the network/proxy boundary and the LLM client, so that every Vitest suite runs deterministically offline with no live eBay request, no live proxy session, and no live model call.

## Acceptance Criteria

1. **(input-validation)** Given every file under `__fixtures__` outside the `__fixtures__/invalid/` negative-fixture directory, When the harness loads the valid fixture set, Then each HTML fixture parses as valid HTML and each JSON fixture parses as valid JSON, with 0 parse errors reported across the valid fixture set.
2. **(valid-output)** Given the multi-card eBay sold-listing HTML fixture, When `parsePrice` and `parseSoldDate` run against text obtained via `firstText`, and `extractItemId` runs against each card's listing-link `href` (from `a.s-item__link`, `a.s-card__link`, or `a[href*="/itm/"]`), across its `li.s-item` and `li.s-card` cards, Then `extractItemId` returns the embedded eBay item id of 6 or more digits, `parsePrice` returns the `priceMin`, `priceMax`, and `currency` recorded for that card, and `parseSoldDate` returns `soldDate` as an ISO `YYYY-MM-DD` string equal to the fixture's known value.
3. **(error-handling)** Given the anti-bot interstitial HTML fixture that contains one of `captcha`, `pardon our interruption`, `checking your browser`, or `access denied` and exposes 0 `li.s-item`/`li.s-card` cards, When the card-extraction path runs, Then the interstitial/retry path is triggered (an `Error` is thrown) and 0 card objects are produced.
4. **(edge-case)** Given the empty-results HTML fixture that exposes 0 `li.s-item`/`li.s-card` cards and contains none of the four interstitial phrases, When extraction runs, Then it yields 0 parsed cards and throws 0 errors.
5. **(valid-output)** Given the LLM-client boundary mock seeded with a fixed JSON response sample, When an extraction test invokes the LLM-fallback path, Then the mock returns that fixed JSON, an assertion on a named field of the parsed result equals the fixture's recorded value, and 0 calls reach a live model endpoint.
6. **(error-handling)** Given the network/proxy boundary mock is active for a suite run, When the `CheerioCrawler` path executes against the HTML fixtures, Then 0 outbound HTTP requests leave the process and 0 Apify `RESIDENTIAL` proxy sessions are opened.
7. **(error-handling)** Given the corrupt/invalid JSON fixture stored under `__fixtures__/invalid/` (excluded from the valid-fixture loader of AC1), When the JSON loader reads it, Then the loader raises a named parse error (for example `SyntaxError`) and returns no partial object.

## Sub-tasks

- Create the `__fixtures__` directory and the eBay sold-listing HTML fixtures that mirror the actor's `li.s-item` and `li.s-card` cards — multi-card, single-card, empty-results, and anti-bot interstitial variants — each exposing the link, title, price, sold-date caption, and image selectors the helpers read — `@qa-engineer`
- Add the LLM JSON response samples and the eBay/LLM JSON request and response payloads as valid fixtures, plus one corrupt/invalid JSON sample placed under `__fixtures__/invalid/` and reserved for the error path so the valid-fixture loader does not read it — `@qa-engineer`
- Implement the network/proxy boundary mock so the `CheerioCrawler` reads the local HTML fixtures instead of the live web, with no Apify `RESIDENTIAL` proxy traffic — `@test-engineer`
- Implement the LLM-client boundary mock that returns the fixed JSON samples with 0 calls to a live model endpoint — `@test-engineer`
- Add one sample helper test that runs `parsePrice` and `parseSoldDate` against text from the multi-card HTML fixture and `extractItemId` against that fixture's listing-link `href`, importing the helpers through the side-effect-free helper boundary (coordinated with `STORY-06-01-01` and `STORY-06-02-03`) offline, to prove the fixtures and mocks are importable with 0 actor side effects — `@qa-engineer`

## Edge Cases

- **Empty/Null:** the empty-results fixture exposes 0 `li.s-item`/`li.s-card` cards and contains none of the four interstitial phrases → extraction yields 0 parsed cards and throws 0 errors.
- **Boundary:** the single-card fixture exposes exactly 1 `li.s-item`/`li.s-card` card → extraction yields exactly 1 parsed card.
- **Invalid:** the corrupt/invalid JSON fixture under `__fixtures__/invalid/` → the JSON loader raises a named parse error (for example `SyntaxError`) and returns no partial object.
- **Anti-bot:** the interstitial fixture contains one of `captcha`, `pardon our interruption`, `checking your browser`, or `access denied` and exposes 0 cards → the retry/throw path is triggered (an `Error` is thrown).

## Dependencies

### Upstream (must be complete first)

- **[STORY-06-01-01 — Configure Vitest & Environment Access](STORY-06-01-01-configure-vitest-and-env-access.md):** the single Vitest harness that loads the `__fixtures__` and resolves the boundary mocks established here. The fixtures and mocks plug into that one configuration.
- **Reference authority — `apify/src/main.js`:** the authoritative reference (this fixtures story does not modify it) that fixes the card selectors (`li.s-item`, `li.s-card`), the field selectors (link `a.s-item__link`/`a.s-card__link`/`a[href*="/itm/"]`, title `.s-item__title`/`.s-card__title` with the leading "Shop on eBay" placeholder skipped, price `.s-item__price`/`.s-card__price`, sold-date `.s-item__caption--signal`/`.s-item__caption`/`.s-card__caption`, image `.s-item__image-wrapper img`/`.s-item__image img`/`img.s-card__image`), the helper functions (`extractItemId`, `parsePrice`, `parseSoldDate`, `firstText`), and the four interstitial phrases the HTML fixtures mirror. The sample helper test imports `extractItemId`, `parsePrice`, and `parseSoldDate` through the side-effect-free importable helper boundary coordinated with `STORY-06-01-01` and `STORY-06-02-03`, so it runs with 0 actor side effects. `apify/package.json` fixes the ES-module type (`"type": "module"`) and the `cheerio ^1.0.0` parser the fixtures are read with on Node `>=18`.

### Downstream (informational — not a build prerequisite of this story)

- **[STORY-06-01-03 — Wire Integration Tests to a Neon Branch](STORY-06-01-03-wire-integration-tests-to-neon-branch.md):** the sibling story that wires integration tests to a per-CI Neon branch on the same harness.
- **FEATURE-06-02 — Unit & Integration Suites:** the suites that consume these fixtures and boundary mocks (for example the Apify helper tests) are authored there, not in this story.

## Story Estimation Guidance

- **Effort: Medium** — the work spans 4 HTML fixtures, multiple JSON samples, 2 boundary mocks, and 1 sample helper test, which exceeds a single-file change.
- **Complexity: Medium** — the HTML fixtures must mirror the real eBay card DOM (`li.s-item`/`li.s-card` plus the link, title, price, sold-date, and image selectors) and the exact field shapes the helpers return, so the fixture values and the helper outputs stay aligned with `apify/src/main.js`.
- **Uncertainty: Low** — the card selectors, the four interstitial phrases, and the helper return shapes are fixed by `apify/src/main.js`, which leaves the fixture contents defined ahead of implementation.
- **Estimate: 3 points (Fibonacci).** Mirroring a known DOM and known helper shapes with no external integration keeps this at a 3 rather than a 5.

## Definition of Done

- [ ] The `__fixtures__` directory is created with eBay sold-listing HTML mirroring the actor's `li.s-item` and `li.s-card` cards, LLM JSON response samples, and eBay/LLM JSON payloads.
- [ ] The HTML fixtures include the multi-card, single-card, empty-results, and anti-bot interstitial variants, and the JSON set includes one corrupt/invalid sample placed under `__fixtures__/invalid/`.
- [ ] The network/proxy boundary mock and the LLM-client boundary mock are implemented so suites read fixtures with 0 outbound HTTP requests and 0 live model calls.
- [ ] Every valid HTML fixture parses as valid HTML and every valid JSON fixture (every fixture outside `__fixtures__/invalid/`) parses as valid JSON, with 0 parse errors across the valid fixture set; the corrupt sample under `__fixtures__/invalid/` is excluded from this check and instead drives the AC7 error path.
- [ ] The anti-bot interstitial fixture, containing one of `captcha`, `pardon our interruption`, `checking your browser`, or `access denied`, triggers the retry/throw path.
- [ ] The empty-results fixture yields 0 parsed cards and throws 0 errors.
- [ ] No prohibited vague terms appear in the acceptance criteria.
- [ ] All relative links resolve: the parent feature index, the parent epic index, and the sibling stories STORY-06-01-01 and STORY-06-01-03.
- [ ] **Testing:** Fixtures and mocks are importable and a sample helper test passes against them offline.
