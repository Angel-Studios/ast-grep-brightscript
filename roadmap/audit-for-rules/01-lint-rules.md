# 01 — Lint rules (team-codified + anti-pattern)

## Goal
Ship the BrightScript **lint** rules: the patterns the team already enforces (CATALOG **A**) and the
bug-class anti-patterns the mining found (CATALOG **D**). These are the highest-value, most
defensible rules and run on the already-built BrightScript grammar.

## Scope (CATALOG ids)
- **A (team-codified):** `no-stop`, `param-missing-type-annotation`, `unsafe-iterator-mutation`,
  `condition-style-no-group`*, `block-if-no-trailing-then`*, `inline-if-requires-then`*,
  `no-manual-font-node`*, `no-alpha-suffix-hex-color`, `no-parsejson-in-controller`,
  `no-raw-string-state-comparison`, `setfocus-outside-setstate`.  (* = has a rewrite/fix; the fix can
  land here or move to Phase 02 — keep the *detection* here.)
- **D (anti-pattern):** `no-leftover-print`, `unsafe-count-loop`, `stringly-typed-type-check`,
  `magic-hex-color`, `invalid-compare-prefer-isvalid`, `stringly-findnode`, `parsejson-unguarded`,
  `sleep-outside-task`, `dynamic-dispatch-unchecked`, `magic-createobject-type`,
  `stringly-observefield`, `deep-non-optional-chain`, `index-access-no-guard`,
  `no-debug-marker-in-shipped`.

Deferred to Phase 05 (relational): `network-response-success-check`, `observe-without-unobserve`,
`dimension-divisible-by-3` (needs ÷3 arithmetic).

## Steps
1. Start with the **guards** (clean-today: `no-stop`, `no-raw-string-state-comparison`,
   `sleep-outside-task`) — they validate the Tier-1/Tier-2 pipeline with synthetic positives before
   tackling fuzzy ones.
2. Author detection rules in CATALOG-priority order; each ships with Tier-1 `valid`/`invalid` tests
   and a Tier-2 corpus snippet derived from the cited angel-roku evidence.
3. For `files:`-scoped rules (`no-parsejson-in-controller`, `sleep-outside-task`,
   `no-font-node-in-xml` exception) encode the path filter and test it.
4. Tune for **precision** — the AST advantage over the team's grep/bslint is no false hits from
   strings/comments/identifiers (`stop` in a comment, `print` in `fingerprint`). Add negatives that
   prove it.
5. Set severities per CATALOG; document each rule's angel-roku evidence in `metadata`.

## Acceptance
Every rule in scope has a `rules/*.yml`, green Tier-1 tests, a Tier-2 corpus tag, and passes Level-6.
Running the set over `../angel-roku` reproduces (within reason) the CATALOG frequency counts
(`no-leftover-print` ~299, `unsafe-count-loop` 90, `magic-hex-color` 214, …) — spot-check a few.

## Dependencies
Phase 00.
