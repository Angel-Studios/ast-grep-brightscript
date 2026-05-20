# 00 — Foundation: rule format, test infra, mimicking corpus, validation gate

## Goal
Stand up everything needed to author and *prove* ast-grep rules, and resolve the cross-cutting
unknowns that would otherwise block every rule. No rules ship value until this is in place.

## Steps

### 0.1 Spike: resolve the authoring caveats against the BUILT grammar
Do this first — it determines how every later rule is written. Inspect the live grammars
(`tree-sitter-brightscript/`, `tree-sitter-scenegraph/` S-expressions + `node-types.json`) and the
ast-grep registration (`sgconfig.yml`) and record findings in this file:
- **Metavariable sigil / `expandoChar`** — does ast-grep accept `$VAR` for BrightScript, or does the
  `$` type-suffix force an alternate (e.g. `_VAR`)? Write one throwaway pattern and confirm.
- **Raw token text for case-normalization** — does `CreateObject`/`createObject` collapse to one
  node, and can a rule constrain on the *original* spelling (regex on the callee token)? Decides
  whether CATALOG `C7`/`C8` are feasible.
- **Node fields** — capture the actual `field(...)` names on `CallExpression`, `CallSuffix`,
  `MemberSuffix`, `IndexSuffix`, `IfStatement`(condition), `Parameter`(type), `ForStatement`,
  SceneGraph `Field`/`Script`/`Component`/`NodeAttribute`. The CATALOG sketches assumed these.
- **Relational operator support** — confirm `inside`/`has`/`follows`/`precedes`/`stopBy` and
  `constraints`/`utils` behave as assumed on these languages.

### 0.2 Rule file layout + conventions
- One rule per `rules/<id>.yml` (id = CATALOG id). Standard fields: `id`, `language`
  (`brightscript`|`scenegraph`|`brighterscript`), `severity`, `rule`, `message`, optional `fix`,
  `note`, `metadata` (catalog-category, angel-roku evidence ref, frequency).
- Group by category with an id prefix or `metadata.category` (A–F). Keep `ruleDirs: [rules]` in
  `sgconfig.yml` (already wired).
- A `rules/README.md` documenting the conventions + how to run/test.

### 0.3 Tier-1 rule tests (fast, no device)
- Use ast-grep's native rule-test format: for each rule a test file with `valid:` and `invalid:`
  inline snippets (the CATALOG "harness snippet" positive/negative pairs seed these).
- `ast-grep test` runs them. Wire an npm script (e.g. `npm run rules:test`).

### 0.4 Tier-2 mimicking corpus (realistic, device-rideable)
- New corpus area for files that reproduce angel-roku patterns at realistic scale — proposed
  `roku-test-harness/corpus/patterns/<category>/...` (parse-only/scan corpus, NOT compiled into the
  channel) for snippets, plus, where a pattern is a whole valid construct, fold a device-runnable
  exemplar into the harness channel so it rides the existing `##SPEC##` device loop.
- Tag each file with the rule id(s) it exercises and the expected match lines (mirror the existing
  `coverage-id:` / `expect:` corpus-tagging convention) so a scan can assert positives/negatives.
- Anti-pattern examples must be **valid, compilable code** (flagged by a rule, not rejected by the
  device) so the corpus stays device-consistent.

### 0.5 Level-6 validation gate
- Add `grammar/check_rules.py` (or `scripts/`): runs `ast-grep test` (Tier 1) AND scans the Tier-2
  corpus asserting each rule matches its tagged positives and none of its negatives; flags
  rules with no tests, tests with no rule, and corpus tags with no rule. Keep **GREEN**.
- Register it as **Level 6** in `grammar/CLAUDE.md`'s validation table, alongside gates 0–5.

## Acceptance
Caveats from 0.1 are documented here with concrete answers; `rules/` has the layout + README +
`sgconfig.yml` wiring; one trivial end-to-end rule (e.g. `no-stop`) ships with Tier-1 tests + a
Tier-2 corpus tag + passes the new Level-6 gate. The gate runs clean in `test:ci`-style invocation.

## Dependencies
The built grammars + `sgconfig.yml` (done — `CLAUDE.md` "PARSER BUILT"). No others.
