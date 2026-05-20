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
  typecast is modeled in the EBNF but deferred in the grammar.)
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

### Phase 5 — Tree-sitter: add the BrighterScript grammar layer + injection

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

### Phase 6 — Register & validate ast-grep over BrighterScript

- Register the grammar (or `.bs` dialect) under `sgconfig.yml` `customLanguages` so `.bs` is
  searchable — fulfills "parse BrighterScript from ast-grep".
- Extend the EBNF-rule ↔ `node-types.json` parity check (`roadmap/03` step 8) to cover
  `brighterscript.ebnf`.
- Validate ast-grep patterns match BrighterScript kinds (namespace/class/annotation/…); run
  patterns over `angel-roku`'s `.bs` as a real-world matching regression.

**Acceptance:** ast-grep matches BrighterScript patterns on `.bs` (including `angel-roku`); all
parity checks green.

### Phase 7 — Grow the subset (iterative)

Repeat Phases 1→6 per feature, driven by real-world demand: ternary `?:`, `??`, `?.`, template
strings, `import`, `const`, `enum`, `interface`, `try/catch/throw`, `typecast`, full type system.
Each feature runs the same loop: spec → coverage leaf → harness `.bs` → bsc + device → grammar →
ast-grep. `angel-roku` (and any newly added repos) remain the regression corpus.

---

## Dependencies / sequencing

```
Phase 0 ─ (independent; do first as a warm-up of the loop)
Phase 1 → Phase 2 → Phase 3 → Phase 4         (spec → taxonomy → corpus+bsc → device)
                       └────────────→ Phase 5 → Phase 6   (tree-sitter → ast-grep)
                                         ▲
                              roadmap/03 (BrightScript tree-sitter grammar)
Phase 7 ─ loops 1→6 per new feature
```

## End-to-end acceptance (definition of done for the initiative)

A BrighterScript `.bs` file can be searched/linted/rewritten with ast-grep via the custom language;
the BrighterScript subset corpus parses clean (zero ERROR) in tree-sitter and its transpiled output
**runs on a real Roku** (`##SPEC## fail=0`); `bsc` accepts the same `.bs` syntax; coverage parity,
EBNF-internal, XSD, and EBNF↔node-types checks are all green; `angel-roku` is the standing real-world
regression corpus. The device remains the final authority.
