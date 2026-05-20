# 03 — Tree-sitter grammar + ast-grep custom language (the end goal)

## Goal
Author `tree-sitter-brightscript/` from the EBNF, build the parser, validate it
against the harness corpus + `coverage.json`, and register it as an **ast-grep
custom language** so `.brs` / SceneGraph `.xml` are searchable, lintable, and
rewritable with ast-grep.

## Context (updated after plans 01–02 + the stdlib expansion)
- **Methodology:** `.claude/skills/ast-grep-custom-language/SKILL.md` — READ FIRST.
- **Spec:** `grammar/brightscript.ebnf` + `grammar/scenegraph.ebnf` — device-corrected,
  with `(* DEVICE-CONFIRMED (DEVICE_FACTS.md #N) *)` annotations on every rule the
  device adjudicated. Honor those annotations literally.
- **Single source of truth:** `grammar/coverage.json` — **611 leaves / 3 layers**
  (`brightscript` 243, `scenegraph` 71, `stdlib` 297). **468 are device-testable
  and PASS on hardware** (`##SPEC## run-end fail=0`, Roku OS 15.1.4); **143 are
  non-device** (corpus). `grammar/check_coverage.py` (validation **Level 1**) keeps
  coverage.json ↔ implemented specs/corpus in sync — keep it green.
- **Target node kinds:** the `kind`s in `coverage.json` — **136 distinct**, and
  these must appear in the generated `node-types.json`. NOTE: the 297 stdlib leaves
  add **zero new kinds** — they reuse `CallExpression` / `CreateObjectCall` /
  `MemberSuffix`. So the standard library is covered *structurally* by the generic
  call/member nodes; there is **no per-API node** to author. Get calls + member
  access + `CreateObject` right and the whole stdlib matches.
- **Positive corpus (must parse with ZERO ERROR):** the entire device-validated
  harness — `roku-test-harness/source/**/*.brs` (468 specs across 13 test modules)
  + `roku-test-harness/components/*.brs` + the `<script>` CDATA/text in
  `components/*.xml`.
- **Negative + parse-only corpus:** `roku-test-harness/corpus/` (NOT compiled into
  the channel; excluded from the deploy zip + bsconfig). `corpus/negative/` (15
  files) and `corpus/parse-only/` (31 files); each file tags its leaves with
  `coverage-id:` / `expect:`.
- **Ground-truth ledgers:** `grammar/DEVICE_FACTS.md` (#1–#17) and
  `grammar/BSC_DRIFT.md` (where BrighterScript disagrees with the device — the
  device always wins; `bsc` is advisory only).

## Device-confirmed constraints the grammar MUST encode

These were settled on-device this phase; getting them wrong means the grammar
diverges from the real language. Each cites its `DEVICE_FACTS.md` entry.

**Significant newlines (the key external-scanner subtlety) — #14.**
A newline (`EOS`) is suppressed at depth>0 **only inside `[ ]` / `{ }` collection
literals and call ARGUMENT LISTS** — NOT inside a grouping `( )`. `x = (1 +`⏎`2)`
is a Syntax Error. So the scanner cannot simply "suppress newlines at any open
bracket depth": it must distinguish a grouping paren from a collection/arg-list
context (or treat grouping `(` as newline-terminating). This is the single most
important external-scanner decision.

**ERROR-node cases (syntax rejections → the parser must produce ERROR).** These
live in `corpus/negative/` and the grammar should *fail* on them:
- leading `let` on assignment (#2)
- `#if` with `and`/`or`/`not`/parens (#1) — `CCExpression` is a single bool/const
- nested **named** function/sub declaration (#5) — functions are top-level only;
  anonymous function *values* in expression position remain valid
- `dim a(n)` paren bounds (#8) — only `dim a[n]` brackets
- optional-call `?()` as a bare **statement** `o.fn?()` (#9) — valid only in
  EXPRESSION position (`y = f?()`)
- newline inside a grouping `( )` (#14)
- `stringarray` init with unquoted elements (#3)

**Parse-clean-but-device-rejected (SEMANTIC, not ERROR → lint-rule territory).**
These are well-formed syntax the parser should accept WITHOUT an ERROR node; a
future ast-grep **rule** flags them. Tagged in `corpus/negative/` with a note:
- `as interface` / `as <CustomType>` e.g. `as roSGNode` (#6, #7) — parses as
  `as Identifier`; only the intrinsic type set is device-valid
- SceneGraph `type="str"` field alias (#11) — valid XML; `str` is not a real type

**Accept these (device-valid, even though `bsc` may reject — see BSC_DRIFT):**
- `next` and `next <var>` as a `for` terminator (#10)

**Lexer quirks (from the EBNF "Notes for the implementer"):** case-insensitive
keywords/identifiers; maximal munch (`&hFF&` is ONE LongInteger token, not `&hFF`
+ `&`); type-designator suffixes `$ % ! # &`; `""` string escape (no backslash
escapes); `'` and `rem` comments as `extra`; `?`-print vs `?.`/`?[`/`?(`
optional-chaining disambiguated by NO leading space; `line_num` substitution.

**Standard-library matching (semantic, documented for rule authors, not parse):**
`CreateObject("roInt", v)` ignores the value (#15); the ifString `Mid` *method* is
0-indexed while the global `Mid()` is 1-indexed (#16); `roTimespan.Mark()` is void
(#17). The grammar parses all of these as ordinary calls — these facts matter only
to anyone writing ast-grep lint rules over stdlib usage.

## Steps
1. **Scaffold** `tree-sitter-brightscript/` (grammar.js, binding, package.json).
   Pin compatible `tree-sitter-cli` vs ast-grep ABI (skill pitfalls).
2. **Translate `brightscript.ebnf` → grammar.js:**
   - Lexical: case-insensitive keywords, identifier type-suffixes (`$ % ! # &`),
     numeric literal forms + maximal munch, the `""` string escape, comments as `extra`.
   - Expression cascade → `prec.left`/`prec.right` per Part 5 — preserve
     associativity: `^` right-assoc and **tighter** than unary minus (`-2^2 = -4`);
     `and`/`or` short-circuit; comparison non-chaining.
   - Statements, blocks, declarations; `field(...)` the selectable parts (callee,
     method name, args, condition, body) so stdlib calls/members are matchable.
   - Conditional compilation — `CCExpression` is a single bool/const only (#1).
3. **External scanner (C)** for what EBNF can't express, prioritized by the
   constraints above: significant newlines / `EOS` with the **grouping-paren vs
   collection/arg-list distinction (#14)**; `?`-print vs `?.`/`?[`/`?(` (space
   rule); block-if vs single-line-if; fused/spaced `end x`; bare `end`.
4. **`scenegraph.ebnf` → XML grammar + LANGUAGE INJECTION** of BrightScript into
   `<script>` CDATA, **bare (non-CDATA) `<script>` text**, and external `uri`
   scripts. NOTE (#12): the device *tolerates but does not execute* bare inline
   script — irrelevant to the GRAMMAR, which must still inject/parse all three forms.
5. **`test/corpus/`** from the device-validated harness + `coverage.json` snippets:
   - positive: harness `source/**` + `components/**` → **zero ERROR**
   - `corpus/parse-only/**` → **zero ERROR**
   - `corpus/negative/**` SYNTAX rejections → assert **ERROR**; the SEMANTIC ones
     (as-interface/custom, `type="str"`) → assert a clean parse (lint, not ERROR)
6. **Build** the `.so`; add `sgconfig.yml` registering it under `customLanguages`.
7. **Validate:** parse the whole harness with **zero ERROR**; every `coverage.json`
   `kind` (136) is present in `node-types.json`; ast-grep patterns match the
   expected kinds; syntax-negatives produce ERROR.
8. **Parity check (new validation level):** EBNF rule names ↔ `node-types.json`,
   so the EBNF can't silently drift from the grammar. Pair it with the existing
   `check_coverage.py` (coverage ↔ specs/corpus) so spec, corpus, and grammar all
   stay locked together.

## Acceptance
ast-grep matches BrightScript + SceneGraph patterns (including stdlib call/member
usage) via the custom language; the device-validated harness corpus parses clean
(zero ERROR); `corpus/parse-only/` parses clean; `corpus/negative/` syntax cases
produce ERROR (semantic cases parse clean, flagged by lint rules); all 136 coverage
`kind`s are represented; both parity checks are green. The Roku device remains the
tiebreaker for any construct the grammar and the docs disagree on.
