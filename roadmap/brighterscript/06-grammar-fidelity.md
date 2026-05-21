# 06 — Grammar fidelity: full-surface real-world gaps (+ remaining-work index)

## What this is

A standalone phase for the work left after `roadmap/05` Phase 7 closed the **device/runnable**
backlog. It is the follow-up home for:

1. **The 6 deferred grammar gaps** the full-surface real-world stress-test surfaced (`roadmap/05`
   §"Phase 7" item 6) — each a bsc-confirmed-valid `.bs`/`.brs` construct the grammar wrongly
   rejects. These are the **primary, actionable** work below.
2. An **index of every other open initiative / remaining item** in the repo, so this is the one
   place to see "what's left" (§"Other remaining work").

Pick a gap, run the per-gap loop, keep all gates green, re-measure the corpus. Each gap is sized,
risk-rated, and has a minimal repro so it is resumable cold.

## Status (2026-05-21)

The stress-test cloned a real full-surface corpus (`maestro-roku` `b1f7f35`, `rooibos` `1fe183b`,
`promises` `7acd59a`, `bslib`, `ropm` = **246 `.bs`**, excluding 14 `.maestro-templates/` `$NAME$`
scaffolding stubs that are invalid BrightScript and correctly rejected). Baseline parse rate
**210/246**. Triaged the 36 failures to **8 distinct root causes**, all bsc-confirmed valid:

- ✅ **R1** multi-line empty AA `{`⏎`}` (10 files) — FIXED (`roadmap/05` item 6).
- ✅ **R4** numeric type designators `1.0!` / `1%` (1 file) — FIXED (`roadmap/05` item 6).
- ⏳ **R2, R3, R5, R6, R8, R9** — DEFERRED here (28 files remain; parse rate after R1+R4 = **218/246**).

The two fixed ones were low-risk lexer/list shape changes. The six below are higher-risk (external
scanner / contextual keywords, GLR ambiguity, the per-token `_nl`-suppression design, expression
precedence) against a **device-validated** grammar — hence a dedicated phase. **Commit each fix
separately** so there is always a clean rollback point before the next piece of grammar surgery.

## The standing full-surface regression corpus

`/tmp` is ephemeral; re-clone with the pinned SHAs when resuming:

```sh
git clone --depth 1 https://github.com/georgejecook/maestro    /tmp/maestro-test  && (cd /tmp/maestro-test  && git fetch --depth 1 origin b1f7f35 2>/dev/null; true)
git clone --depth 1 https://github.com/rokucommunity/rooibos    /tmp/rooibos-test
git clone --depth 1 https://github.com/rokucommunity/promises   /tmp/promises-test
git clone --depth 1 https://github.com/rokucommunity/bslib      /tmp/bslib-test
git clone --depth 1 https://github.com/rokucommunity/ropm       /tmp/ropm-test
```

Measure (run from repo root); exclude the scaffolding stubs (R7, not bugs):

```sh
cd tree-sitter-brighterscript; TS=../node_modules/.bin/tree-sitter
total=0; clean=0; fail=0
for repo in /tmp/maestro-test /tmp/rooibos-test /tmp/promises-test /tmp/bslib-test /tmp/ropm-test; do
  while IFS= read -r f; do
    case "$f" in *.maestro-templates*) continue;; esac
    total=$((total+1))
    if $TS parse "$f" 2>/dev/null | grep -q "ERROR\|MISSING"; then fail=$((fail+1)); else clean=$((clean+1)); fi
  done < <(find "$repo" -name '*.bs' -not -path '*/node_modules/*' -not -path '*/out/*' \
             -not -path '*/build/*' -not -path '*/dist/*' -not -path '*/.roku-deploy/*')
done
echo "clean=$clean fail=$fail total=$total"   # target: 246/246 (excl. scaffolding)
```

**Stretch goal (own sub-task):** turn this into a committed gate (e.g. `grammar/check_realworld.py`
or an npm script) that re-clones the pinned SHAs and asserts a non-regressing pass rate, so the
full surface joins angel-roku as a standing regression instead of an ad-hoc /tmp run.

## Per-gap loop (run for each gap)

1. **Reproduce** from `/tmp/*-test` (or the minimal repro below) with `tree-sitter parse`; confirm
   the `ERROR`/`MISSING`. Confirm bsc accepts it (it does — already verified; re-confirm if unsure
   with a throwaway `bsc --project` over a one-file project).
2. **Locate** the rule. Base-grammar constructs live in `tree-sitter-brightscript/grammar.js`
   (`+ src/scanner.c`); brighterscript-only ones in `tree-sitter-brighterscript/grammar.js`
   (`+ src/scanner.c`). Most of these are **base** (so the fix also helps `.brs`).
3. **Spec parity.** If the EBNF (`grammar/brightscript.ebnf` / `brighterscript.ebnf`) is stricter
   than reality, update it too (R1/R4 showed the EBNF was sometimes already permissive — check
   first). Keep L0 green.
4. **Fix** grammar.js: `prec`/`prec.left/right` first, `conflicts` only for genuine deferred
   ambiguity, scanner `RESERVED[]` / externals only when a contextual keyword demands it.
   `tree-sitter generate` (resolve conflicts), then **rebuild the `.so` yourself** — the sub-agent
   sandbox blocks the C compiler:
   ```sh
   cd tree-sitter-brightscript   && ../node_modules/.bin/tree-sitter generate && ../node_modules/.bin/tree-sitter build --output brightscript.so
   cd tree-sitter-brighterscript && ../node_modules/.bin/tree-sitter generate && ../node_modules/.bin/tree-sitter build --output brighterscript.so
   ```
   (Always rebuild **both** — brighterscript inherits the base via `grammar(base, {...})`.)
5. **Corpus test.** Add a positive (and, where meaningful, an `:error` negative) `test/corpus/*.txt`
   case for the construct. `tree-sitter test` stays green for **all three** grammars
   (base / brighterscript / scenegraph).
6. **Regress.** angel-roku must stay **52/52** zero-ERROR; re-run the full-surface measure and
   confirm the pass rate went **up** and nothing regressed. Keep L0/L1/L3/L5 + bsc green.
7. **Device (if the construct has a runtime signal).** These are mostly parse-fidelity variants of
   already-device-confirmed constructs, so device re-validation is usually optional — but for the
   ones that touch the **newline-suppression design (R9)** or **scanner (R2/R5)**, deploy the
   harness (`npm run roku:deploy`) and confirm `##SPEC## fail=0` to prove no lowering/runtime
   regression. Record anything new in `DEVICE_FACTS.md`.

---

## Gap backlog (priority = value ÷ risk; tackle top-down)

### R8 — multi-line annotation argument list  *(brighterscript; 1 file; LOW–MED risk)*
Most contained brighterscript fix — good warm-up.
```brighterscript
@params(
  1,
  2
)
sub annotated()
end sub
```
Single-line `@params(1, 2)` parses; newlines inside the annotation parens do not. The brighterscript
`Annotation` rule's argument list needs to tolerate `_nl` between/around args (same shape as the
`ArgumentList` newline question, but local to the annotation). File: `maestro core/JsonCombiner.spec.bs`.

### R5 — single quote inside an *interpolated* template string  *(brighterscript; 2 files; MED risk)*
```brighterscript
a = `Failed key '${key}' in section '${name}'`
```
The literal-text segments of a template that ALSO contains `${...}` don't escape `'`; the comment
token (`'…`→EOL) eats the rest of the line. `` `it's here` `` (no interpolation) parses fine — so the
template lexer mode handles `'` correctly only when there is no interpolation. Fix the template-chars
lexing (the `token.immediate` chars run / scanner) so `'` is ordinary inside ALL template literals,
interpolated or not. Files: `maestro core/Request.bs`, `core/Registry.bs`.

### R3 — call chain off a function-expression argument  *(base; 5 files; MED risk)*
```brightscript
p.then(function(x)
  return x
end function).catch(function(e)
  print e
end function)
```
Fails once **≥2** chained calls each take an anon-function arg; even `p.then(1).catch(<anon>)` fails
(a non-empty-arg call followed by a member-call whose arg is an anon function). `a.b(1).c(2)` and a
single anon-arg call parse fine. Root cause: GLR ambiguity — `(<anonfn>)` is parsable as a
`CallSuffix` `ArgumentList` *or* a `ParenExpr` (Primary) in the left-recursive `CallExpression` /
`PostfixExpr` chain (the `[$.ArgumentList, $.ParenExpr]` conflict already exists). Likely fix:
disfavor `ParenExpr` holding a bare `AnonymousFunction` (a `(function…)` is virtually always a call
arg or an IIFE, not a parenthesized value) and/or a targeted precedence on `CallSuffix`. **Must keep
the Phase-0 IIFE `(function() … end function)()` working** — add it to the corpus alongside the fix.
Files: `promises/{MainScene,TaskWithInternalPromises}.bs`, `promises *.spec.bs`, `rooibos Promises.spec.bs`.

### R9 — nested multi-line array literal as a call argument  *(base; 2 files; MED–HIGH risk)*
```brightscript
return [foo("L", [
    bar("Init", 1)
  ]
)]
```
The newline after the inner `]` errors. Root cause: the `_nl` external token is emitted whenever
**any** active context accepts it — the OUTER `[…]` makes `_nl` valid, so it leaks into `foo(…)`'s
`ArgumentList`, which today relies on `_nl` being *invalid* (suppressed) inside `( )`. A non-nested
`foo([`⏎`1`⏎`])` parses fine. Fix: make `ArgumentList` **consume `_nl` explicitly** (allow newlines
around args/commas, like `sepList` does for collections) so an emitted `_nl` is absorbed instead of
breaking the arg list. This touches the **device-validated newline-suppression design** (grammar.js
header note + DEVICE_FACTS #14) — verify the simple `foo(1)`⏎`bar(2)` statement-terminator case and
multiline-arg cases still parse, and device-re-validate (`##SPEC## fail=0`).

### R2 — reserved keyword / builtin used as an identifier  *(base + brighterscript; ~14 files; HIGH risk)*
Biggest impact, hardest. Builtin/keyword words used where BrighterScript allows an ordinary name:
```brightscript
class C
  function run() as dynamic       ' also: try, createObject — method name = keyword
  end function
  public type as string           ' field name = keyword
end class
enum Type                         ' enum name = keyword
  a = "a"
end enum
namespace mc.private              ' keyword as namespace path segment
end namespace
x = new mc.Sub("y")               ' keyword as new-type path segment
m = { continue: "c", back: "b" }  ' keyword AA keys
```
All bsc-valid. Root cause (see `start_here.md` gotchas + memory `tree-sitter-grammar-design`): the
external `IdentStart` scanner token beats internal `ci()` keyword tokens, and reserved words are
excluded from `IdentStart`, so a keyword is only usable as a name where the grammar explicitly admits
it (`_NameOrKeyword` / `_reserved_word`, used for member access + AA keys). **Split into sub-tasks**,
each fixed + corpus-tested + regressed independently:
- **R2a** class member declaration *name* (method/field) may be a reserved word — brighterscript
  class grammar.
- **R2b** AA key may be a reserved word not yet in `_reserved_word` (e.g. `continue`; check `back`) —
  extend the base `_reserved_word` list (and verify it doesn't break those keywords elsewhere).
- **R2c** namespace / type / `new`-type **path segments** may be reserved words (`mc.private`,
  `mc.Sub`) — brighterscript dotted-name grammar.
- **R2d** `enum` (and other declaration) *name* may be a reserved word.
Each sub-case risks regressing keyword recognition or the contextual-keyword scanner — add a focused
corpus positive AND confirm the keyword still works in its keyword role. Device-re-validate after the
scanner touch.

### R6 — additive-left comparison in an `if` condition  *(base; 1 file; HIGH risk)*
```brightscript
if a + 1 >= b then   ' also: if a - 1 > b ; if a + 1 = b
  print 1
end if
```
The condition reduces to `a`, then `+ 1 >= b` becomes an ERROR (the `+` is taken as a unary start of
a single-line-if inline statement). `while a + 1 >= b`, `if a >= b + 1`, `if a * 2 >= b`, and the same
expression as an assignment all parse — the trigger is the `IfStatement = choice(BlockIf,
SingleLineIf)` split combined with the binary/unary `+`/`-` overlap (a `_Statement`, reachable as a
single-line-if body, can start via a unary `+`). **High blast-radius on the expression grammar for a
single file → lowest priority.** If attempted: needs a precedence/conflict that prefers continuing
the condition expression over starting an inline statement, without breaking single-line-if
(`if x then print 1`) or the binary/unary `+` everywhere else. A declared `[$.BlockIf,$.SingleLineIf]`
conflict was tried and reported *unnecessary* (not the conflict point) — investigate the actual
ExpressionStatement/`CallExpression`-callee path instead.

### Not bugs (do not "fix")
- **R7** `$NAME$` scaffolding templates (14 `.maestro-templates/` files) — invalid BrightScript;
  correct rejection. Excluded from the corpus measure.
- One genuine source typo (`@it("…")n`, maestro `StyleManager.spec.bs`) — correct rejection.

## Acceptance (this phase)

- Each tackled gap: grammar fixed, EBNF parity kept, a `test/corpus` case added, all three
  tree-sitter suites green, L0/L1/L3/L5 + bsc green, **angel-roku 52/52** zero-ERROR, and the
  full-surface pass rate strictly increased with no new failures.
- Phase done when the full-surface corpus parses **246/246** (excl. scaffolding) OR every remaining
  failure is adjudicated *not a grammar bug* (and recorded here).
- Stretch: the full-surface corpus is wired into a committed regression gate.

---

## Other remaining work (index — not part of the gap backlog above)

- **ast-grep rules initiative — `roadmap/audit-for-rules/` (NOT STARTED).** Distinct from the grammar:
  authoring ast-grep search/lint/rewrite **rules** from the angel-roku pattern mine (`CATALOG.md`,
  ~60 patterns) + a mimicking harness corpus + a new Level-6 validation gate. `rules/` is currently
  empty; phases `00-foundation` → `05-relational-and-regression` are planned there. Phase 04
  (BrighterScript/rooibos rules) depended on `roadmap/05` Phases 5/6, which are now **done**, so this
  initiative is unblocked. See [`../audit-for-rules/README.md`](../audit-for-rules/README.md).
- **Demand-driven BrighterScript surface (`roadmap/05` Phase 7 item 4).** New `.bs` constructs that a
  synced repo starts using; the 52/52 authored-`.bs` regression (and now the full-surface corpus) is
  the tripwire. No queued item until one appears.
- **Erased-on-transpile leaves stay parse-only by design** — the 10 `interface`/`type`/`typecast`/
  `alias`/`type_alias` brighterscript leaves have no runtime signal; **no work** (recorded for
  clarity, not a TODO).
- **bsc↔device drift** is tracked in `grammar/BSC_DRIFT.md`; add a row whenever a new construct makes
  the two disagree. Not a backlog item, a standing discipline.
