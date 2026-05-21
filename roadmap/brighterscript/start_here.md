# start_here.md — pick up Phase 7 (BrighterScript "grow") seamlessly

You're continuing the **BrighterScript (`.bs`) initiative** (`roadmap/05-brighterscript-support.md`).
**Phases 0–6 are COMPLETE.** Phase 7 = grow the runnable/device-validated subset, iteratively. Read
this, run the green-check, then pick a backlog item from roadmap/05 §"Phase 7".

## What exists now (one line each)
- **`grammar/brighterscript.ebnf`** — EXHAUSTIVE spec of the `.bs` superset. It IMPORTS
  `brightscript.ebnf` and *shadows/overrides* only the seam rules (Expression, Type, Primary,
  PostfixSuffix, AAEntry, AssignmentStatement, ForEachStatement, TopLevelItem) + adds the new ones.
- **`tree-sitter-brighterscript/`** — the grammar, built to `brighterscript.so`. It EXTENDS the
  BrightScript grammar via tree-sitter inheritance: `grammar(base, {...})` in `grammar.js`. Same
  shadow/override model as the EBNF. `src/scanner.c` is a renamed copy of the brightscript scanner.
- **`coverage.json`** — has a `brighterscript` layer (38 leaves: 26 device-via-transpile + 12
  parse-only). `device_testable:true` brighterscript leaves run on-device VIA TRANSPILE.
- **Harness**: `roku-test-harness/source/tests/test_bs.bs` (Main-scope specs, registered in
  `TestSuite.brs` as `test_bs_all`) + `test_bs_sg.bs` (render-phase specs needing a live `roSGNode`,
  e.g. callfunc — invoked from `main.brs` after `test_scenegraph_all`); `corpus/parse-only/bs_*.bs`
  (parse-only). The deploy build (`bsconfig.deploy.json` via `scripts/roku-deploy.ts`) transpiles
  `.bs`→`.brs`.
- **ast-grep**: `sgconfig.yml` registers `brighterscript` (`.bs`) and injects it into SceneGraph
  `<script type="text/brighterscript">` bodies (`BrighterScriptBody` node).
- **Device-proven**: a real Roku run is green (`##SPEC## pass=501 fail=0`, 28 `bs.*` PASS,
  DEVICE_FACTS #18–#20).

## Verify everything is green (do this first)
```sh
cd /home/james/Developer/ast-grep-brightscript
python3 grammar/check_ebnf.py            # L0
python3 grammar/check_coverage.py        # L1
python3 grammar/check_scenegraph_xsd.py  # L2
python3 grammar/check_grammar.py         # L3
python3 grammar/check_parity.py          # L5
npm run check                            # L4 (bsc) — advisory
(cd tree-sitter-brighterscript && ../node_modules/.bin/tree-sitter test)  # 44 tests
(cd tree-sitter-scenegraph   && ../node_modules/.bin/tree-sitter test)    # 36 tests
```
All must pass before and after your change.

## The per-feature loop (run for EACH Phase-7 item)
1. **Spec** it in `grammar/brighterscript.ebnf` (override a seam rule or add a production; reuse
   imported brightscript rules where possible). Keep L0 green.
2. **Coverage leaf** in `coverage.json` (`layer:"brighterscript"`, `kind` = the EBNF rule name;
   `device_testable:true`+`expect:value:X` if it runs, else `false`+`expect:parse`). Append in the
   compact one-record-per-line style — use a tiny Python script, don't hand-edit 135 KB.
3. **Harness**: device leaf → add a `t.spec("<id>","<kind>",...)` + assertion to `test_bs.bs`;
   parse-only → add a tagged `roku-test-harness/corpus/parse-only/<id>.bs` (`' coverage-id: <id>`).
   Keep L1 green (`check_coverage.py` scans `.brs` AND `.bs`).
4. **bsc**: `npm run check` must accept the new `.bs` (it's the syntax authority). Log any bsc-vs-device
   divergence in `BSC_DRIFT.md`.
5. **Device** (for device leaves): `npm run roku:deploy`, capture + read `##SPEC##` (see below),
   confirm PASS. Record new device facts in `DEVICE_FACTS.md`.
6. **Grammar**: implement in `tree-sitter-brighterscript/grammar.js` → `tree-sitter generate` (fix
   conflicts: `prec` first, `conflicts` only for real ambiguity) → **rebuild the `.so`** (below) →
   add `test/corpus/*.txt` cases (positives + an `:error` negative). Re-parse `test_bs.bs`, the
   corpus, and the 52 authored `angel-roku` `.bs` → zero ERROR.
7. **ast-grep / parity**: confirm the new `kind` is matchable; keep L3 + L5 green.

## Hard-won gotchas (read before touching the grammar)
- **Build the `.so` yourself.** ast-grep loads the compiled library, NOT `grammar.js`. After ANY
  grammar change: `cd tree-sitter-<name> && ../node_modules/.bin/tree-sitter generate && \
  ../node_modules/.bin/tree-sitter build --output <name>.so`. **Sub-agents' sandbox BLOCKS the C
  compiler** — the *main* agent must run the build (the parent can; delegate generate/edit, build here).
- **Contextual keywords don't "just work".** The external `IdentStart` scanner token BEATS an internal
  `ci()` keyword token, so a new keyword is only recognized where the grammar makes `IdentStart`
  invalid. A declaration keyword usable at a statement/member start (where an identifier is also valid)
  must be ADDED to `RESERVED[]` in `tree-sitter-brighterscript/src/scanner.c` (it becomes a hard
  keyword). If it must still work as a member/AA-key name, add it to the `_reserved_word` override in
  `grammar.js` (BrighterScript `AllowedProperties`). `new` is the worked example (reserved for
  `new Foo()`, re-admitted as the `sub new()` ctor + member name).
- **`check_ebnf.py` strips `(* *)` non-greedily** → never nest `(* ... *)` inside a block comment in
  the EBNF (it closes the outer comment early). Reword instead.
- **BrighterScript language facts** (bsc-enforced, correct): subclass ctor calls `super()` (not
  `super.new()`) before any `m`; a computed AA key `{[k]:v}` must be a compile-time constant
  (const/enum) — BS1144.
- **bsc version**: installed `brighterscript` 0.72.2 == GitHub master == the syntax authority (no
  drift). Canonical source mirror was at `/tmp/bs-src` (`git clone --depth 1
  https://github.com/rokucommunity/brighterscript /tmp/bs-src` to refresh) — read
  `src/lexer/TokenKind.ts`, `src/parser/Parser.ts` for exact syntax.

## Device loop (`.env` is set, `ROKU_HOST=192.168.1.240`)
Simplest: `bun run --cwd roku-listener listen` (live) in the background, then `npm run roku:deploy`;
the listener finishes on `run-end` and writes `roku-listener/out/report.json`. Hang-safe alternative
(hard time bound + raw log), using the committed capturer `scripts/capture-console.py`:
```sh
python3 scripts/capture-console.py 192.168.1.240 65 out/console.log 8085 & CAP=$!
npm run roku:deploy                                                  # transpile+sideload+launch
wait $CAP
python3 - <<'PY'  # trim to the LAST complete run (install auto-launch + ECP launch = 2 runs)
l=open('out/console.log',errors='replace').read().splitlines()
s=[i for i,x in enumerate(l) if 'run-start' in x][-1]; e=[i for i,x in enumerate(l) if 'run-end' in x][-1]
open('out/console.last.log','w').write("\n".join(l[s:e+1])+"\n")
PY
bun run --cwd roku-listener replay out/console.last.log
```
`out/` is gitignored. The Roku debug console allows ONE telnet connection at a time.

## Pointers
- Roadmap + Phase 7 backlog: `roadmap/05-brighterscript-support.md`.
- Methodology: skill `ast-grep-custom-language` (auto-triggers on grammar work); writing `.bs`/`.brs`:
  skill `write-brightscript`.
- Ground-truth ledgers: `grammar/DEVICE_FACTS.md` (device facts, #18 = BrighterScript runs),
  `grammar/BSC_DRIFT.md` (bsc vs device).
- Grammar guide: `grammar/CLAUDE.md`. Repo orientation: `CLAUDE.md`. Project memory:
  `~/.claude/projects/.../memory/` (esp. `brighterscript-initiative`, `tree-sitter-grammar-design`).
- Regression corpus: `../angel-roku` authored `.bs` (exclude `node_modules`/`out`/`build`) — must stay
  52/52 zero-ERROR.

## Next Phase 7 items
- ~~Expression-level type-cast `expr as T` (`TypeCastExpression`)~~ — ✅ **DONE (2026-05-20).** It was
  the only EBNF→grammar gap; now closed (outermost loosest-binding wrapper; two-tier
  `_Expression`/`_ExpressionNoCast` so a cast is never a postfix object and param defaults keep their
  `as Type`; `bs.typecast.expr` leaf is parse-only). See roadmap/05 §"Phase 7" backlog item 1 for the
  full write-up and the worked grammar gotchas it surfaced.
- ~~Device-test parse-only constructs that CAN run (`callfunc` on a real node, multi-file `import`)~~ —
  ✅ **DONE (2026-05-20).** Both promoted to device-via-transpile and PASS on hardware (`pass=499
  fail=0`, DEVICE_FACTS #19). callfunc needed a render-phase module (`source/tests/test_bs_sg.bs`)
  since `test_bs_all` is Main-scope (no `roSGNode`). See roadmap/05 §"Phase 7" backlog item 2.
- ~~Tagged templates & source literals on-device~~ — ✅ **DONE (2026-05-21).** Both promoted
  parse-only → device-via-transpile and PASS on hardware (`##SPEC## pass=501 fail=0`, 28 `bs.*`;
  DEVICE_FACTS #20). Tagged template lowers to `tagFn([lit…],[val…])`; `FUNCTION_NAME` lowers to the
  transpiled function name string. Specs in `test_bs.bs`. See roadmap/05 §"Phase 7" backlog item 3.
- ~~SceneGraph `<script uri="*.bs">` external-script (item 5)~~ — ✅ **DONE (2026-05-21).** Added 4
  parse-only scenegraph coverage leaves + corpus fixtures for the BrighterScript `<script>` forms
  (`ScriptCDataBs`/`ScriptTextBs`/`ScriptExternal`/`ScriptTypeBsAttValue`) the grammar already accepted
  but the taxonomy never tracked. Coverage 658→662. See roadmap/05 §"Phase 7" item 5.
- **Device/runnable backlog DRAINED** (28/28 `bs.*` runtime leaves device-tested). 10 remaining
  parse-only leaves are erased-on-transpile by design (`interface`/`type`/`typecast`/`alias`).
- ◷ **Full-surface grammar stress-test (item 6) — IN PROGRESS.** Cloned a real full-surface corpus
  (maestro-roku/rooibos/promises/bslib/ropm — 246 `.bs` in `/tmp/{maestro,rooibos,promises,bslib,ropm}
  -test`) since angel-roku only exercises a shallow subset. Triaged to 8 root causes; **R1 (multi-line
  empty AA) + R4 (numeric `!`/`%` designators) FIXED** (base+brighterscript rebuilt, base corpus 53→55,
  parse rate 210→218/246, all gates green, angel-roku 52/52). **6 DEFERRED with minimal repros** (R2
  keyword-as-identifier ~14 files; R3 chained anon-fn-arg calls 5; R9 nested multi-line array arg 2; R5
  quote-in-interpolated-template 2; R8 multi-line annotation args 1; R6 additive-left if-condition 1) —
  see roadmap/05 §"Phase 7" item 6 for each repro + why deferred. Pick one and run the grammar loop:
  reproduce from `/tmp/*-test`, fix grammar.js (or scanner.c for R2/R5), regen + **rebuild the `.so`
  yourself**, add a `test/corpus` case, keep base/brighterscript/scenegraph corpus + L0/L1/L3/L5 +
  angel-roku 52/52 green, re-measure the corpus pass rate.
