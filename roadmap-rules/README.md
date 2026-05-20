# roadmap-rules/ — ast-grep rules from real-world (angel-roku) patterns

This directory plans a distinct initiative from `roadmap/` (which is about the *grammar* —
parsing BrightScript/SceneGraph/BrighterScript). Here the grammar is already **built and
registered** (`sgconfig.yml` customLanguages + injection; see `CLAUDE.md` "PARSER BUILT"). This is
about **what we do with it**: author ast-grep **rules** (search / lint / rewrite) that match the
code patterns real Roku apps actually use, and validate those rules against a corpus in
`roku-test-harness/` that **mimics the production `angel-roku` app**.

## Why

The whole point of registering BrightScript/SceneGraph as an ast-grep language is to *search, lint,
and rewrite* it. We now have a real, large production app next door (`../angel-roku`) that tells us
which patterns matter. We mined it (2026-05-20, six parallel agents) for rule-worthy patterns; the
result is **[CATALOG.md](CATALOG.md)** — ~60 deduped patterns, each with real `file:line` evidence,
a frequency count, an ast-grep rule sketch, and a mimicking harness snippet. The phased plan turns
that catalog into shipped rules + a validation gate.

## The validation model (two tiers)

Each rule must be proven against code that mimics production:

1. **Rule unit tests** — ast-grep's native rule-test format (`valid:` / `invalid:` inline snippets)
   for every rule. Fast, no device. The first-line correctness gate.
2. **Mimicking corpus** — realistic `.brs` / `.bs` / `.xml` files in `roku-test-harness/` that
   reproduce the angel-roku patterns (positive *and* negative examples), tagged so a scan asserts
   each rule matches its positives and not its negatives. Because these files are valid
   BrightScript/BrighterScript, they ride the **existing device loop** (compile-on-sideload +
   `##SPEC##`) — so the corpus the rules run over is itself device-confirmed, consistent with the
   project ethos. Anti-pattern examples are *valid code that compiles and runs*; they're flagged by
   a rule, not rejected by the device.

A new validation gate (Level 6) keeps rules ↔ tests ↔ corpus in sync, alongside the existing gates
0–5.

## How this relates to the rest of the repo

- `rules/` — the live ast-grep rule files (`ruleDirs` in `sgconfig.yml`; currently empty). This
  roadmap fills it.
- `roku-test-harness/` — gains a mimicking-pattern corpus (Tier 2 above).
- `grammar/coverage.json` — the node `kind`s the rules match on (BrightScript/SceneGraph today;
  BrighterScript kinds arrive with `roadmap/05`).
- `roadmap/05-brighterscript-support.md` — **dependency** for the BrighterScript/rooibos rules
  (Phase 04 here): those need the `.bs` grammar + ast-grep registration from roadmap 05 Phases 5/6.
- `../angel-roku` — the standing real-world **regression scan target**: running the finished rules
  over it should reproduce the catalog's frequency counts (Phase 05 here).

## Cross-cutting caveats to resolve BEFORE authoring rules (see [00-foundation.md](00-foundation.md))

These came straight out of the mining pass and will bite every rule author if not settled first:

- **Metavariable sigil.** BrightScript uses `$` as a type-designator suffix, so the built grammar
  may register an `expandoChar` (e.g. `_VAR` instead of `$VAR`). Confirm what the grammar actually
  uses before writing a single pattern.
- **Case-insensitivity vs. rewrites.** BrightScript folds case (`CreateObject`/`createObject`,
  `and`/`AND`, `ParseJson`/`PARSEJSON`, `invalid`/`Invalid`). Case-normalization *rewrite* rules
  (CATALOG C7/C8) only work if the grammar preserves raw token text or supports a regex constraint
  on the callee token — verify against the built parser.
- **No arithmetic in rules.** `dimension-divisible-by-3` (CATALOG A9) can't be expressed as a pure
  ast-grep rule (no `% 3`); it needs a `constraints` regex trick or a companion script.
- **Relational / cross-language rules** (onChange-handler-exists, observe/unobserve balance,
  component-name = filename, duplicate `@it`) exceed a single stock rule — they need ast-grep
  `utils`/`rewriters` or a companion script over `sg scan --json`. Quarantined to Phase 05.
- **Confirm node fields.** The sketches use `kind`s from `coverage.json` but assumed field names
  (`condition`, `callee`, args). Inspect the emitted S-expressions / `node-types.json` before
  finalizing relational `has:` / `follows:` constraints.

## Phase index

| Phase | File | Scope | Depends on |
|------|------|-------|-----------|
| 00 | [00-foundation.md](00-foundation.md) | Rule format, rule-test infra, mimicking corpus, Level-6 gate, resolve the caveats above | — |
| 01 | [01-lint-rules.md](01-lint-rules.md) | Team-codified (bslint/.cursor/skill) + anti-pattern lint rules — CATALOG A + D | 00 |
| 02 | [02-search-and-rewrite-rules.md](02-search-and-rewrite-rules.md) | Idiom/navigation search + codemod/autofix rules — CATALOG B + C | 00 |
| 03 | [03-scenegraph-rules.md](03-scenegraph-rules.md) | SceneGraph XML rules — CATALOG E | 00 |
| 04 | [04-brighterscript-rules.md](04-brighterscript-rules.md) | rooibos/`.bs` rules — CATALOG F | 00, **roadmap/05 Ph.5–6** |
| 05 | [05-relational-and-regression.md](05-relational-and-regression.md) | Cross-language/relational rules + scan `angel-roku` as regression + CI | 01–04 |

Build order: 00 first; 01/02/03 can proceed in parallel (all run on the already-built grammars);
04 waits on BrighterScript ast-grep support; 05 last.
