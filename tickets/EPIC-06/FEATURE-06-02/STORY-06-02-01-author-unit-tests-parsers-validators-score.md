# STORY-06-02-01: Author Unit Tests — Parsers, Validators & Score

*Parent feature: [FEATURE-06-02 — Unit & Integration Suites](../FEATURE-06-02-unit-and-integration-suites.md) · Parent epic: [EPIC-06 — Testing & CI/CD Quality Gates](../../EPIC-06-testing-and-cicd-quality-gates.md)*

## User Story

As a **Backend Test Engineer**, I want unit tests covering the title parsers, the input validators, and the confidence-score classifier, so that parsing and matching regressions are caught before merge and the ≥90% coverage bar is enforced.

These three logic areas — the cheap regex-first title parser, the LLM-fallback output validator, and the confidence-score classifier — are built under `EPIC-03` (`FEATURE-03-02`); this story authors their unit tests and does not modify that code. The suite runs on the Vitest harness from `STORY-06-01-01` and reads the known-title strings, the recorded LLM JSON response, and the boundary mocks established in `STORY-06-01-02`; it reaches 0 external services and makes 0 network calls. Per the product authority, extraction is two-stage and deterministic-first: a regex-first pass over the title and item aspects that pulls the serial (`15/50` → `serial_number=15`, `serial_run=50`), the print run (`/25`, `1/1`), the year, the grade (PSA/CGC/BGS plus value), and the format, with high confidence when structured aspects are present; then an LLM fallback over messy free text that emits a strict JSON schema (`character`, `set`, `year`, `card_number`, `parallel`, `print_run`, `serial`, `grade`, `format`) with a per-field confidence, validated and clamped before use, run in batch jobs only and never in a request handler. The confidence-score classifier then auto-commits a match whose score is at or above the auto-commit threshold and routes any match whose score falls below the threshold to the operator review queue. This is a planning ticket; the test files themselves are authored when this story is executed.

## Acceptance Criteria

1. **(input-validation)** *Given* a title input that is an empty string or `null`, *When* the validator runs, *Then* it returns a typed validation error (a named error type/result) and the parser is invoked 0 times.

2. **(valid-output)** *Given* the known title fixture `"2023 Topps Star Wars Grogu Mojo Refractor /50 PSA 10"`, *When* the regex-first parser runs, *Then* it returns an object whose fields equal `character = "Grogu"`, `parallel = "Mojo Refractor"`, `print_run = 50`, and `grade = "PSA 10"`, with 0 required fields missing.

3. **(valid-output — LLM-fallback validation)** *Given* the recorded LLM JSON response fixture from `STORY-06-01-02` for a messy free-text title, *When* the LLM-fallback output validator runs with the LLM call replaced by the `STORY-06-01-02` boundary mock (0 network calls), *Then* the validated object exposes exactly the 9 strict-schema fields (`character`, `set`, `year`, `card_number`, `parallel`, `print_run`, `serial`, `grade`, `format`), every per-field confidence value is clamped into the closed range `[0, 1]`, and 0 fields outside the schema remain on the object.

4. **(error-handling)** *Given* an unparseable title with 0 recognizable tokens, *When* the parser runs, *Then* it returns a structured no-match result (the object `{ matched: false }`) and throws 0 exceptions.

5. **(edge-case — threshold boundary)** *Given* a confidence score exactly equal to the auto-commit threshold, *When* the score classifier runs, *Then* it returns the auto-commit branch on 100 of 100 repeated runs with 0 divergent results.

6. **(edge-case — below threshold)** *Given* a confidence score one minimal decrement below the auto-commit threshold, *When* the score classifier runs, *Then* it returns the review-queue branch and 0 auto-commit results, confirming the threshold is inclusive at the boundary and exclusive below it.

7. **(edge-case — ambiguity rule)** *Given* the token `15/50` in a title where a parallel or print-run context is present, *When* the parser runs, *Then* it sets `serial_number = 15` and `serial_run = 50`; **AND** *Given* the token `15/50` in a title where 0 parallel and 0 print-run context tokens are present, *When* the parser runs, *Then* it reads `15/50` as a card number, marks the extraction low-confidence, and routes it to the review queue rather than committing a serial.

8. **(coverage gate)** *Given* the unit suite is executed under `vitest run` with coverage instrumentation, *When* line coverage for the parser, validator, and score modules is below 90%, *Then* the test command exits with a non-zero status and the build fails.

## Sub-tasks

- Author regex-first parser tests against the known-title fixtures from `STORY-06-01-02`, asserting `character = "Grogu"`, `parallel = "Mojo Refractor"`, `print_run = 50`, and `grade = "PSA 10"` for the title `"2023 Topps Star Wars Grogu Mojo Refractor /50 PSA 10"`. `@backend-test-engineer`
- Author the `15/50` ambiguity test pair: `serial_number = 15` and `serial_run = 50` when a parallel or print-run context is present, and a card-number reading marked low-confidence and routed to the review queue when 0 such context tokens are present. `@backend-test-engineer`
- Author validator tests asserting a typed rejection (a named error type/result) for empty-string, `null`, and control-character titles, with the parser invoked 0 times on rejection. `@backend-test-engineer`
- Author LLM-fallback validator tests that feed the `STORY-06-01-02` LLM JSON boundary mock through the validate-and-clamp step and assert exactly the 9 strict-schema fields with every per-field confidence clamped into `[0, 1]` and 0 network calls. `@backend-test-engineer`
- Author score-classifier tests exercising the exact auto-commit threshold boundary: at-threshold returns auto-commit on 100 of 100 runs, and one minimal decrement below returns the review-queue branch. `@backend-test-engineer`
- Configure coverage collection for the parser, validator, and score modules and assert the ≥90% line-coverage gate exits non-zero when coverage is below 90%. `@qa-engineer`

## Edge Cases

- **Empty/Null:** an empty-string or `null` title input returns a typed validation error and invokes the parser 0 times.
- **Boundary:** a confidence score exactly at the auto-commit threshold returns the auto-commit branch on 100 of 100 runs, while one minimal decrement below returns the review-queue branch.
- **Invalid:** a title containing non-printable or control characters returns a typed validation error and invokes the parser 0 times.
- **Boundary:** a maximum-length title string returns a result object with 0 truncation errors and throws 0 exceptions.
- **Invalid (ambiguity):** the token `15/50` with 0 parallel and 0 print-run context tokens is read as a card number, marked low-confidence, and routed to the review queue rather than committed as a serial.

## Dependencies

- `STORY-06-01-01` — the Vitest harness (the single Vitest configuration and coverage runner) this unit suite executes under.
- `STORY-06-01-02` — the `__fixtures__` (the known-title strings and the recorded LLM JSON response) and the boundary mocks (the LLM-call replacement) this suite reads; no external service is reached.
- `EPIC-03` — the code under test, built in `FEATURE-03-02`: the regex-first title parser, the LLM-fallback output validator, the input validators, and the confidence-score classifier. This story authors tests for that code and does not implement it.
- Sibling suites `STORY-06-02-02` and `STORY-06-02-03` run on the same Vitest harness but carry 0 build-order dependency on this story; referenced by identifier only.

## Story Estimation Guidance

- **Effort: Moderate** — the work spans three logic areas (the regex-first parser and the LLM-fallback validator, the input validators, and the confidence-score classifier), each exercised across valid, invalid, and boundary inputs.
- **Complexity: Moderate** — coverage is branch-sensitive across the auto-commit threshold boundary and the `15/50` serial-versus-card-number split, plus strict-schema clamping of the LLM-fallback output into the `[0, 1]` per-field confidence range.
- **Uncertainty: Low** — the units are pure, deterministic functions with 0 network, 0 filesystem, and 0 database access; the contracts are fixed by `EPIC-03`, though that code remains unbuilt.
- **Estimate: 5 points (Fibonacci).** The three-area span and the threshold and ambiguity branch coverage place this above a 3; the pure-function determinism and the fixed `STORY-06-01-02` fixtures hold it at a 5 rather than an 8.

## Definition of Done

- [ ] Unit tests are authored for the regex-first parser, the LLM-fallback output validator, the input validators, and the confidence-score classifier.
- [ ] The known-title fixture `"2023 Topps Star Wars Grogu Mojo Refractor /50 PSA 10"` asserts `character = "Grogu"`, `parallel = "Mojo Refractor"`, `print_run = 50`, and `grade = "PSA 10"` with 0 required fields missing.
- [ ] The auto-commit threshold boundary is asserted deterministically (at-threshold returns auto-commit on 100 of 100 runs; one minimal decrement below returns the review queue), and the `15/50` ambiguity split (serial when a parallel or print-run context is present; card number routed to the review queue otherwise) is asserted.
- [ ] The LLM-fallback validator is exercised through the `STORY-06-01-02` boundary mock with 0 network calls and yields exactly the 9 strict-schema fields with every per-field confidence clamped into `[0, 1]`.
- [ ] At least one input-validation test, one valid-output test, one error-handling test, and one edge-case test are present; no prohibited vague quality term appears in any acceptance criterion.
- [ ] `EPIC-03` is referenced as the source of the parser, validator, and score code under test, and this story does not implement that code.
- [ ] **Testing:** the unit suite runs green under `vitest run` and reports line coverage ≥90% for the parser, validator, and score modules; line coverage below 90% exits non-zero and fails the build.
