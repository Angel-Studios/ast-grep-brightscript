# 05 — BrighterScript support (parse `.bs` with ast-grep, device-confirm it runs)

## Goal

Extend the project so that **BrighterScript** (`.bs`, the RokuCommunity superset that
transpiles to BrightScript) is:

1. **Parsable by ast-grep** — a tree-sitter grammar dialect that accepts BrighterScript and
   registers as an ast-grep custom language, so `.bs` files (and `.bs` injected into SceneGraph
   `<script>`) are searchable / lintable / rewritable.
2. **Device-confirmed valid** — every BrighterScript construct captured in the corpus is proven
   correct end-to-end: bsc accepts the `.bs` syntax, *and* the transpiled `.brs` is sideloaded and
   **runs on a real Roku** (emits `##SPEC## status=PASS`). The device stays the tiebreaker.

This is the BrightScript pipeline (`roadmap/03`) extended one layer up the language stack. It does
NOT replace `roadmap/03` — it depends on it (the BrighterScript grammar reuses the BrightScript core
for statement/expression bodies).

## Status (2026-05-20)

**Phases 0–6 are DONE (Phase 4 DEVICE-CONFIRMED). Phase 7 (grow) is ongoing.**

DONE:

- **Phase 0** — the plain-BrightScript + SceneGraph gaps the audit proved are closed, already
  device-run.
- **Phase 1** — an **exhaustive** `grammar/brighterscript.ebnf` is authored (start
  `BrighterScriptSourceFile`), and `check_ebnf.py` understands the import+shadow relationship (it
  imports `brightscript.ebnf` and a locally redefined rule shadows the imported one).
- **Phase 2** — `coverage.json` gained the `brighterscript` layer (37 leaves: 24 device-testable via
  transpile + 13 parse-only; total leaves now 657), and `check_coverage.py` now scans `.bs`
  test/corpus sources too.
- **Phase 3** — the `.bs` corpus lives in the harness (`source/tests/test_bs.bs` for the 24 runnable
  specs, 13 parse-only files under `corpus/parse-only/`) and `bsc` is the syntax ground truth via
  `npm run check`.
- **Phase 4** — **DEVICE-CONFIRMED.** The deploy build (`bsconfig.deploy.json`, called from
  `scripts/roku-deploy.ts`) transpiles `.bs`→`.brs`, stages, and packages; the result was sideloaded
  and ran on a Roku (OS 15.1.4) with a clean `##SPEC## event=run-end pass=497 fail=0` — all 24
  `bs.*` BrighterScript specs PASS. Recorded as DEVICE_FACTS #18.

**Scope change (note):** the original locked decision was "used-subset-first" (model only what
`angel-roku` uses today). The user **upgraded the scope to spec-EXHAUSTIVE**: the EBNF + coverage now
model the **FULL** BrighterScript language surface, authored against the BrighterScript compiler
source (rokucommunity/brighterscript v0.72.2, the same version as the installed `bsc`) as the
canonical authority. The harness corpus + on-device validation still **start at the real-world
subset and GROW** (Phase 7). Where the phase bodies below still read "subset-first", read them
through this lens — the spec/coverage are exhaustive; the runnable/device-validated set grows.

- **Phase 5** — **DONE.** `tree-sitter-brighterscript/` EXTENDS the brightscript tree-sitter grammar
  via tree-sitter grammar inheritance (`grammar(base, {...})`) — the same shadow/override model as the
  EBNF — adding namespace/class/interface/enum/const/import/typecast/alias/type, annotations,
  ternary/`??`/`new`/callfunc/computed-AA-key, typed forms, templates, regex, and source literals;
  rule names mirror the EBNF. `src/scanner.c` is a renamed copy of the brightscript scanner (same
  externals) with the BrighterScript declaration keywords added to the reserved set (the external
  `IdentStart` wins over the internal keyword token, so a contextual keyword is only recognized where
  the grammar makes IdentStart invalid — declaration keywords had to be reserved; `new` is re-admitted
  as the constructor/member name). ABI15, built to `brighterscript.so`. Parses CLEAN: `test_bs.bs`,
  all 13 parse-only `.bs`, and **52/52 authored `angel-roku` `.bs`**; 38 `test/corpus` tests pass;
  negatives ERROR; all 42 new `bs.*` kinds present in `node-types.json`. (Expression-level `expr as T`
  typecast was deferred here; it is now implemented — see Phase 7 backlog item 1.)
- **Phase 6** — **DONE.** `brighterscript` registered as an ast-grep `customLanguage` (`.bs`) in
  `sgconfig.yml`; all 37 coverage kinds are ast-grep-matchable; angel-roku ast-grep regression passes
  (52 namespaces / 47 classes / 2257 annotations / 1793 methods). `check_parity` (L5) extended with
  import-union semantics (inherited kinds reconcile against `brightscript.ebnf`) + a brighterscript
  allowlist; `check_grammar` (L3) extended to the brighterscript layer. **All 5 gates green.**
  **SceneGraph `<script>` `.bs` injection — DONE:** the scenegraph grammar now accepts
  `type="text/brighterscript"` and emits a distinct `BrighterScriptBody` node (parallel to
  `BrightScriptBody`); `sgconfig.yml` injects `brighterscript` into `BrighterScriptBody`, leaving the
  existing `BrightScriptBody`→`brightscript` injection unchanged. Verified end-to-end: ast-grep matches
  a `ClassDeclaration` inside a `text/brighterscript` `<script>`, and the plain-BrightScript injection
  still matches. (External `uri`-referenced `.bs`/`.brs` scripts both parse; standalone `.bs` needs no
  injection.) scenegraph grammar rebuilt (88→93 kinds); 36/36 scenegraph corpus tests pass.
- **Phase 7** — grow the runnable/device-validated subset iteratively (expression-level typecast,
  callfunc-on-a-node device test, tagged templates, multi-file import, fuller type checking).

## Locked decisions (from the scoping discussion)

- **Scope = used-subset-first, then grow.** Model exactly what real BrighterScript code uses today
  (evidenced by the `angel-roku` audit, below), validated on-device, then expand on demand. No
  speculative full-spec grammar.
- **Layout = a separate `grammar/brighterscript.ebnf`** that **embeds** `brightscript.ebnf` by
  reference, mirroring how `scenegraph.ebnf` embeds it. The plain-BrightScript spec stays pristine
  and device-validated; the superset layers on top and defers to it for bodies/expressions.
- **Ground truth = BOTH.** `bsc` (the BrighterScript compiler, already a dependency) is the
  authority for whether `.bs` *syntax* is accepted; the **Roku device** (via transpile→sideload→
  `##SPEC##`) is the authority for whether the lowered `.brs` *runs*. Where they disagree, the
  device wins and the drift is logged in `BSC_DRIFT.md`.

## Why now: the `angel-roku` audit (2026-05-20)

Audited the peer repo `../angel-roku` (689 `.brs`, 56 `.bs`, 512 `.xml`; generated `out/`/`build/`
excluded). It is the canonical **real-world corpus / regression target** for this work. Findings:

- **BrighterScript surface actually used is shallow and structural** — all 52 authored `.bs` files
  are rooibos test modules. Constructs: `namespace`/`end namespace` (52), `class … extends … /
  end class` (47), `super` (15), access modifiers `private`(38)/`protected`(25), `override` (23),
  class field declarations (27), annotations `@it`(1757)/`@describe`(440)/`@suite`(46)/`@tags`(13)/
  `@beforeeach`(1), and dotted/namespaced name refs (`tests.foo()`, `extends rooibos.BaseTestSuite`).
  Intrinsic-only type annotations (no `as <CustomType>`). **Absent everywhere:** ternary `?:`, `??`,
  `?.` in `.bs`, template strings, `=>`, `import`, `enum`, `const`, `interface`, `new`, `typecast`,
  `try/catch/throw`. Method bodies are plain BrightScript the existing EBNF already covers. → This
  defines the **Phase 1 subset**; everything absent is deferred to **Phase 7 (grow)**.
- **In-scope plain-BrightScript gaps** (independent of BrighterScript, found in the same audit):
  whitespace-only print separators `? "x " a " y " b` (≈30 sites, **missing from `PrintSep`** — and
  the harness's own `stmt.print.tab` already relies on it); IIFE `(function() … end function)()`
  (17 sites); comma-less newline-separated AA literals; single-line `:`-joined function/anon-fn
  declarations; label-inside-loop. → **Phase 0**.
- **SceneGraph XML gaps:** `<customization>` element (Instant Resume `suspendhandler`/
  `resumehandler` — not even in the XSD); namespaced `<component>` attrs `xmlns:xsi` /
  `xsi:noNamespaceSchemaLocation` (14+ files — contradicts implementer note 5); `<script>` before/
  interleaved with `<interface>` (42 files, non-XSD order); `<?rokuml?>` prolog PI. → **Phase 0**.
- **Not SceneGraph (exclude from the parser):** `charles_rewrite*.xml` (Charles-proxy config); the
  `manifest` (`rsg_version`, `sg_component_libs_required`, `splash_color=#RRGGBB`).

## Existing infrastructure this builds on

- Specs: `grammar/brightscript.ebnf`, `grammar/scenegraph.ebnf` (W3C-EBNF, `(* DEVICE-CONFIRMED *)`
  annotations). New sibling: `grammar/brighterscript.ebnf`.
- Single source of truth: `grammar/coverage.json` (611 leaves / 3 layers / 136 kinds). Add a
  `brighterscript` layer.
- Validators (keep green): `check_ebnf.py` (L0 internal), `check_coverage.py` (L1 parity),
  `check_scenegraph_xsd.py` (L2), `npm run check` = `bsc` (L4 advisory).
- Device loop: `roku-test-harness/` emits `##SPEC##` → `roku-listener/` parses telnet 8085;
  `scripts/roku-deploy.ts` packages+sideloads (compiles on upload = immediate device feedback).
- Ledgers: `DEVICE_FACTS.md` (#1–#17), `BSC_DRIFT.md`.
- Tree-sitter end goal + parity checks: `roadmap/03-tree-sitter-grammar.md`.

---

## Phases

### Phase 0 — Close the in-scope gaps the audit already proved *(plain BrightScript + SceneGraph)*

Independent of BrighterScript; cheap; `angel-roku` is the evidence. Also warms up the exact
spec→coverage→harness→device loop reused for the BrighterScript phases.

- `brightscript.ebnf`: add the whitespace/empty alternative to `PrintSep`; confirm `PostfixExpr`
  allows a `CallSuffix` on a `ParenExpr` (IIFE) and the bare-`EOS` `ElementSep` (comma-less AA);
  annotate single-line `:`-joined declarations and label-in-loop as covered.
- `scenegraph.ebnf`: add a `Customization` production to `ComponentContent`; relax
  `ComponentAttribute` to admit a generic/namespaced attribute (and fix implementer note 5); relax
  `ComponentContent` child ordering (interface/script/children interleaving) with the note; cover a
  non-`xml` prolog PI (`<?rokuml?>`).
- Add `coverage.json` leaves for each; implement them in the harness (`t.spec` for device-testable,
  tagged `corpus/` files for parse-only/negative). Keep L0/L1/L2 green.
- **Device-confirm the uncertain ones:** whitespace-print-separator runtime behavior, and whether
  the dev installer accepts `<customization>` and the namespaced `<component>` attrs. Deploy → read
  `##SPEC##` → record in `DEVICE_FACTS.md` (and any `bsc` disagreement in `BSC_DRIFT.md`).

**Acceptance:** new leaves green across L0/L1/L2; uncertain constructs adjudicated on-device and
logged; `npm run check` reflects any bsc drift.

### Phase 1 — Author `grammar/brighterscript.ebnf` (the subset)

- Fix the subset from the audit: `namespace`, `class`/`extends`/`super`/access-modifiers/`override`/
  class-field-decls, annotations `@Name (Args)?` on declarations, dotted/qualified name references,
  intrinsic-typed members. List the **grow backlog** (Phase 7) explicitly in the header.
- Write the spec in the **same W3C-EBNF notation**, embedding `brightscript.ebnf` (function/method
  bodies + expressions defer to it, exactly as `scenegraph.ebnf` defers for `<script>` content).
- Header cites authority: the installed `brighterscript` package (bsc) lexer/parser token set +
  `angel-roku` usage; pin the bsc version; state the both-ground-truths model. Include a "Notes for
  the tree-sitter implementer" section (annotation `@`, `as <CustomType>` becomes valid in `.bs`
  unlike `.brs`, namespace/class scoping, dotted names).
- Extend `check_ebnf.py` `DEFAULT_TARGETS` with `brighterscript.ebnf` + its start symbol.

**Acceptance:** L0 (`check_ebnf.py`) green including the new file; every modeled construct cites a
real `angel-roku` `.bs` example.

### Phase 2 — Extend the coverage taxonomy

- Add a `brighterscript` layer to `coverage.json`: new `bs.*` leaf ids + `kind`s, each tagged with
  its ground-truth mode (bsc-syntax and/or device-via-transpile).
- Decide the device-testability convention for `.bs` leaves (they are "device-testable **via
  transpile**") and teach `check_coverage.py` to satisfy them from `.bs` spec/corpus sources.

**Acceptance:** L1 (`check_coverage.py`) green with the BrighterScript leaves.

### Phase 3 — BrighterScript corpus in the harness + `bsc`-syntax ground truth

- Add `.bs` exemplars exercising each subset construct, in the rooibos-style shapes `angel-roku`
  uses (namespace-wrapped classes with annotations). Two targets:
  - **device-runnable** `.bs` that transpiles into the channel and folds `##SPEC##` results into the
    existing runner;
  - **parse-only / negative** `.bs` under `corpus/` for tree-sitter ERROR-assertion later.
- Decide: hand-roll a minimal namespace/class harness vs. pull in `rooibos-roku`. Prefer minimal
  hand-rolled to avoid a heavy test-framework dependency, but keep the shapes faithful to the audit.
- Extend `bsconfig.json` / `npm run check` to compile the `.bs`; `bsc` is the syntax authority. Log
  any bsc-vs-device disagreement in `BSC_DRIFT.md`.

**Acceptance:** `npm run check` (bsc) passes over the new `.bs`; L1 parity green.

### Phase 4 — Device-confirm the transpiled BrighterScript *(the headline goal)*

- Make the channel build **transpile `.bs` → `.brs`** before packaging (today the harness is pure
  `.brs`; extend `scripts/roku-deploy.ts` / the build to run bsc transpile into staging).
- Deploy → capture `##SPEC##` via `roku-listener`: the transpiled BrighterScript specs **run on the
  device and PASS (fail=0)**.
- Record device-confirmed BrighterScript facts in `DEVICE_FACTS.md` (e.g. how `namespace`/`class`
  lower to mangled global functions that execute).

**Acceptance:** a device run reports the BrighterScript specs PASS; `DEVICE_FACTS.md` updated. This
closes the "valid as confirmed by running on Roku" half of the goal.

### Phase 5 — Tree-sitter: add the BrighterScript grammar layer + injection  ✅ DONE

*(Depends on `roadmap/03` — the BrightScript tree-sitter grammar must exist first.)*

- Extend the tree-sitter grammar to parse the BrighterScript subset (namespace/class/annotations/
  modifiers/dotted-names), reusing the BrightScript expression/statement core for bodies.
- Handle the `.bs`-only lexer/scanner concerns (annotation `@`; `as <CustomType>` now valid; etc.).
- **Injection:** inject the BrighterScript grammar (not just BrightScript) into SceneGraph
  `<script>` whose `type` is brighterscript / `uri` ends `.bs`.
- `test/corpus/` from Phase 3: valid `.bs` → zero ERROR; negatives → ERROR; all new `bs.*` kinds
  appear in `node-types.json`.

**Acceptance:** tree-sitter parses every `.bs` corpus file with zero ERROR; negatives ERROR; new
kinds present.

### Phase 6 — Register & validate ast-grep over BrighterScript  ✅ DONE

- Register the grammar (or `.bs` dialect) under `sgconfig.yml` `customLanguages` so `.bs` is
  searchable — fulfills "parse BrighterScript from ast-grep".
- Extend the EBNF-rule ↔ `node-types.json` parity check (`roadmap/03` step 8) to cover
  `brighterscript.ebnf`.
- Validate ast-grep patterns match BrighterScript kinds (namespace/class/annotation/…); run
  patterns over `angel-roku`'s `.bs` as a real-world matching regression.

**Acceptance:** ast-grep matches BrighterScript patterns on `.bs` (including `angel-roku`); all
parity checks green.

### Phase 7 — Grow the subset (iterative)  ◷ ACTIVE — the standing track

The spec (`brighterscript.ebnf`) and coverage taxonomy are already **exhaustive** over the language;
the EBNF, tree-sitter grammar, and ast-grep registration accept the full surface. What "grows" in
Phase 7 is the **runnable / device-validated** set and any remaining grammar/EBNF fidelity gaps.
See `start_here.md` (repo root) for the seamless pickup guide and the exact per-feature loop.

**The per-feature loop (run for each item below):**
spec (`brighterscript.ebnf`) → coverage leaf (`coverage.json`, pick device-via-transpile vs
parse-only) → harness `.bs` (`test_bs.bs` t.spec, or a `corpus/parse-only/*.bs`) → `bsc`
(`npm run check`) → device (`npm run roku:deploy` + `roku-listener`) → tree-sitter grammar +
`test/corpus` → ast-grep / parity. Keep all 6 gates green; `angel-roku` is the standing regression
corpus.

**Backlog (rough priority order):**

1. ~~**Expression-level type-cast `expr as T` (`TypeCastExpression`)**~~ — ✅ **DONE (2026-05-20).**
   Implemented as the outermost (loosest-binding, left-assoc, chainable) expression wrapper. The
   `as`-token clash with the typed positions is resolved exactly as bsc does: param defaults parse
   with `findTypeCast=false` (Parser.ts:1042), so a trailing `as Type` there is the parameter's
   declared type — modeled with a two-tier `_Expression`/`_ExpressionNoCast` split where postfix/call
   objects are no-cast (a cast is never a `.`/`[]`/`(` object without parens), so `resp as a.b.c` and
   `x as integer[]` attach the dotted name / `[]` to the TYPE. Added `TypeCastExpression` to
   `brighterscript.ebnf` (impl. note 9), the `bs.typecast.expr` coverage leaf (parse-only — casts are
   erased on transpile), a `corpus/parse-only/bs_typecast_expr.bs`, and 5 `test/corpus` cases + 1
   `:error` negative. All 5 gates green; 44 bs corpus tests; 52/52 angel-roku; ast-grep matches the
   kind. The EBNF and tree-sitter grammar now have NO spec→grammar gap.
2. **Device-test the parse-only constructs that CAN run** — ⏳ **IN PROGRESS (2026-05-20):**
   `import` (multi-file) and `callfunc` (`@.`) are **DONE** — both promoted parse-only →
   device-via-transpile and **confirmed PASS on hardware** (`##SPEC## pass=499 fail=0`, 26 `bs.*`
   specs; DEVICE_FACTS #19). `bs.import.stmt` calls an imported sibling `source/lib/bs_importlib.bs`
   from `test_bs.bs`; `bs.expr.callfunc` runs **render-phase** in the new
   `source/tests/test_bs_sg.bs` (`test_bs_sg_all`, wired into `main.brs` after `test_scenegraph_all`)
   because the callfunc operator needs a live `roSGNode` (the `showcase` node) — `test_bs_all` runs in
   the Main scope where `CreateObject("roSGNode")` is unavailable. **Remaining:** `interface`/`type`/
   `typecast`/`alias`/`type_alias` stay parse-only (erased on transpile — no runtime signal).
3. ~~**Tagged templates & source literals on-device**~~ — ✅ **DONE (2026-05-21).** Both promoted
   parse-only → device-via-transpile and **confirmed PASS on hardware** (`##SPEC## pass=501 fail=0`,
   28 `bs.*` specs; DEVICE_FACTS #20). A tagged template lowers to a plain call
   `tagFn([lit…], [val…])` (literal segments + interpolated values as two arrays), so
   `bsTagJoin`hi ${who}!`` round-trips to `"hi world!"` (`bs.expr.tagged_template`); `FUNCTION_NAME`
   lowers to a string literal of the **transpiled** enclosing function name — top-level it equals the
   source name, `bsWhoAmI()` → `"bsWhoAmI"` (`bs.source_literal.function_name`). Both specs live in
   `test_bs.bs`. This drains the runnable backlog: the **only** remaining parse-only `bs.*` leaves are
   the 10 constructs **erased on transpile** (`interface`/`type`/`typecast`/`alias`/`type_alias`) —
   they leave no runtime signal, so they stay parse-only by design.
4. **New surface as real-world demand appears** — `try/catch/throw` is already plain-BrightScript;
   watch for any BrighterScript construct `angel-roku` (or a newly synced repo) starts using that the
   grammar doesn't yet parse clean (the 52/52 authored-`.bs` regression will catch it).
5. ~~**SceneGraph `<script uri="*.bs">` external-script**~~ — ✅ **DONE (2026-05-21).** The grammar +
   EBNF already accepted every BrighterScript `<script>` form (`ScriptCDataBs`/`ScriptTextBs`/
   `ScriptExternal`+`ScriptTypeBsAttValue`, added in Phase 6), but the **coverage taxonomy had no
   leaves for them** — only the BrightScript siblings. Closed that gap: added 4 parse-only scenegraph
   leaves mirroring the BrightScript script forms — `sg.script.inline_cdata_bs` (ScriptCDataBs),
   `sg.script.inline_text_bs` (ScriptTextBs), `sg.script.external_uri_bs` (ScriptExternal, the literal
   item-5 external `.bs` uri), `sg.script.type_bs` (ScriptTypeBsAttValue) — plus 4 corpus `.xml`
   fixtures, all parsing clean with the right kinds. Parse-only by design: cross-file uri *resolution*
   is not a single-file tree-sitter concern, and bsc lowers inline `.bs`→`.brs` before the device sees
   the component, so the embedding *mechanism* is already device-proven on the BrightScript side
   (DEVICE_FACTS #12). No grammar/EBNF change needed. Coverage 658→662; all gates green.
6. **Full-surface real-world stress-test** — ◷ **IN PROGRESS (2026-05-21).** angel-roku only exercises
   a SHALLOW `.bs` subset (namespace/class/annotations/`as Type`); the full surface (`enum`/`const`/
   `import`/`try`/`new`/optional-chaining/templates) was validated only by hand-written snippets. Cloned
   a real full-surface corpus — **maestro-roku** (`b1f7f35`, 212 `.bs`), **rooibos** (`1fe183b`),
   **promises** (`7acd59a`), bslib, ropm — **246 `.bs`** (excl. 14 `.maestro-templates/` `$NAME$`
   scaffolding stubs, which are invalid BS and correctly rejected). Baseline parse rate **210/246**;
   triaged the 36 failures to **8 distinct root causes** (all bsc-confirmed valid BrighterScript the
   grammar wrongly rejected). **Repos kept in `/tmp/{maestro,rooibos,promises,bslib,ropm}-test`.**
   - ✅ **R1 multi-line empty AA** `{` ⏎ `}` (10 files) — FIXED. `sepList` made the item-bearing part
     optional so a collection that is empty but contains separators (the newline lexes as `ElementSep`)
     parses. The EBNF already allowed it (`LBRACE EOS?`); grammar.js had diverged. Corpus test added.
   - ✅ **R4 numeric type designators** `1.0!` (float), `1%` (integer) (1 file) — FIXED. `FloatLiteral`
     now allows trailing `!` on any decimal/exponent form; `IntegerLiteral` allows trailing `%`. EBNF
     `IntegerLiteral` updated to add `'%'?`; corpus test added.
   - Parse rate after R1+R4: **218/246**. Both grammars rebuilt; base corpus 53→55; angel-roku 52/52;
     all gates green.
   - ⏳ **DEFERRED (higher-risk; minimal repros captured) — 28 files remain across 6 causes.**
     **Full per-gap plans + the index of all other remaining work are now in the dedicated phase
     doc [`06-grammar-fidelity.md`](06-grammar-fidelity.md)** (this list is the summary):
     - **R2 keyword-as-identifier** (~14 files, biggest): builtin/keyword words used as method/field
       names, AA keys, enum names, or namespace/type path segments — `function run()`, `public type as
       string`, `{ continue: 1 }`, `namespace mc.private`, `new mc.Sub()`. All bsc-valid. The hard one:
       the external `IdentStart` scanner + RESERVED set (see start_here gotchas) — contextual, risky.
     - **R3 call-chain off a function-expr arg** (5 files): `p.then(function(x)…end function).catch(
       function(e)…end function)` — fails when ≥2 chained calls each take a multi-line anon-function
       arg (GLR ambiguity: `(anonfn)` as `ArgumentList` vs `ParenExpr` in the left-recursive postfix
       chain). `a.b(1).c(2)` and a single anon-arg call both parse fine.
     - **R9 nested multi-line array as a call arg** (2 files): `[foo("L", [` ⏎ `bar(1)` ⏎ `]` ⏎ `)]` —
       the `_nl` made valid by the OUTER `[…]` leaks into `foo(…)`'s arg list (the newline-suppression
       design is per-token, not per-innermost-context). A simple `foo([`⏎`1`⏎`])` parses fine. Fixing
       needs ArgumentList to consume `_nl` explicitly — touches the device-validated newline design.
     - **R5 single-quote inside an interpolated template** (2 files, brighterscript): `` `'${x}'` `` —
       the template scanner treats `'` as a comment-start. `` `it's` `` (no `${}`) is fine. Scanner work.
     - **R8 multi-line annotation arg list** (1 file, brighterscript): `@params(` ⏎ `1,` ⏎ `2` ⏎ `)` —
       single-line `@params(...)` parses; newlines inside the annotation parens don't.
     - **R6 additive-left comparison in an `if` condition** (1 file): `if a + 1 >= b then` — reduces the
       condition to `a` then errors. `while a + 1 >= b`, `if a >= b + 1`, `if a * 2 >= b`, and the same
       as an assignment all parse — only the if/SingleLineIf split + binary/unary `+` overlap. High
       blast-radius on the expression grammar for 1 file → deferred.
   - **Not bugs:** `$NAME$` scaffolding templates (14 `.maestro-templates/` files) and one genuine typo
     (`@it("…")n`) are correctly rejected.

---

## Dependencies / sequencing

```
Phase 0 ✅ ─ (independent; warm-up of the loop)
Phase 1 ✅ → Phase 2 ✅ → Phase 3 ✅ → Phase 4 ✅   (spec → taxonomy → corpus+bsc → DEVICE)
                            └─────────────→ Phase 5 ✅ → Phase 6 ✅   (tree-sitter → ast-grep)
                                              ▲
                                   roadmap/03 ✅ (BrightScript tree-sitter grammar)
Phase 7 ◷ ─ loops 1→6 per new feature (ACTIVE; see start_here.md)
```

## End-to-end acceptance (definition of done for the initiative)  ✅ MET

A BrighterScript `.bs` file can be searched/linted/rewritten with ast-grep via the custom language
(✅ `brighterscript` customLanguage registered, `.bs`); the BrighterScript corpus parses clean (zero
ERROR) in tree-sitter (✅ `test_bs.bs`, 13 corpus, 52/52 authored `angel-roku` `.bs`; negatives ERROR)
and its transpiled output **runs on a real Roku** (✅ `##SPEC## event=run-end pass=497 fail=0`, all 24
`bs.*` PASS, DEVICE_FACTS #18); `bsc` accepts the same `.bs` syntax (✅ `npm run check`); coverage
parity, EBNF-internal, XSD, and EBNF↔node-types checks are all green (✅ L0/L1/L2/L3/L5); `angel-roku`
is the standing real-world regression corpus. The device remains the final authority.

**Initiative status: Phases 0–6 COMPLETE.** Phase 7 (grow the runnable/device-validated subset) is the
ongoing track — start at `start_here.md`.
