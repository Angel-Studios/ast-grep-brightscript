# 03 — Tree-sitter grammar: STATUS / handoff

Living progress log for `roadmap/03-tree-sitter-grammar.md`. Read this first when
resuming. Companion memory: `tree-sitter-grammar-design.md` (locked design decisions).

## TL;DR
The two tree-sitter grammars are **authored, built, validated against the
device-corrected harness, and registered as ast-grep custom languages** (both load,
ABI 15 ↔ ast-grep 0.42.3). Language **injection** of BrightScript into SceneGraph
`<script>` bodies is wired and verified (CDATA + bare inline). The **EBNF↔node-types
parity** gate (`check_parity.py`) is GREEN, the BrightScript `test/corpus` fixtures
are written (`tree-sitter test` GREEN: 53 brs + 33 sg), and the final ast-grep sweep
is DONE — all **129 (language, kind) pairs** match (95 brightscript + 34 scenegraph,
0 rejected). Docs are updated and the `.gitignore` policy is settled. **All roadmap/03
acceptance criteria are met** (see checklist at the bottom).

## Toolchain (installed; no sudo)
- `./node_modules/.bin/tree-sitter` = tree-sitter-cli **0.26.9** (emits ABI 15).
- `./node_modules/.bin/ast-grep` = @ast-grep/cli **0.42.3** (loads ABI 15 — verified).
- Both are repo devDependencies (package.json). gcc 13, node 24, bun 1.3 present.
- **grammar.js is ESM** (`export default grammar({...})`; package.json `"type":"module"`).
- `tree-sitter parse` only finds the grammar when run **from inside the grammar dir**
  (e.g. `cd tree-sitter-brightscript && ../node_modules/.bin/tree-sitter parse <file>`).
  From the repo root it errors `No language found`. ast-grep uses sgconfig.yml instead.

## DONE

### tree-sitter-brightscript/ (grammar.js + src/scanner.c) — task 3, 4 ✅
- Full translation of `grammar/brightscript.ebnf`; rule names mirror coverage kinds.
- **External scanner** (`src/scanner.c`, externals `[IdentStart, _nl]`):
  - `IdentStart` is emitted only for a whole word that is NOT a hard reserved keyword
    (case-insensitive set in the C file). This solves the keyword/identifier prefix
    bug (`print`→`printer`, `invalid`→`invalidate`, `rem`→`remember`) since tree-sitter
    resolves two context-valid tokens by precedence, not longest-match. `mod` IS reserved
    (binary-operator keyword); other contextual keywords (`as`,`in`,type names) are not —
    they resolve via `valid_symbols`.
  - `_nl` is emitted only when `valid_symbols[_nl]`, so the grouping-paren rule (#14)
    and collection/arg-list newline-suppression fall out of grammar shape, no bracket
    stack needed.
- **Key grammar decisions** (all empirically forced):
  - Numeric maximal-munch by token prec: LongInteger 6 > Double 5 > Float 4 > Hex 2 > Integer 1.
  - `StringChar`/`EscapedQuote` prec 4 to beat the `rem`/`'` Comment extra (prec 3).
  - `end x`/`exit x`/`continue x`/`else if` are FUSED space-tolerant tokens (`fused()` helper)
    so they beat bare `end` (EndStatement) by longest-match.
  - Postfix layer is **left-recursive**: `CallExpression = (_Expression CallSuffix)`,
    `PostfixExpr = (_Expression member|index|attr|optchain-suffix)`. So a chain ENDING in a
    call is a `CallExpression` (incl. expression position / the whole stdlib), a chain ending
    in member/index is a `PostfixExpr`, and continuation like `f(x)[0].c` nests correctly.
  - `AssignTarget = choice(Identifier, PostfixExpr)` (an l-value); GLR conflicts:
    `[AssignTarget,_Expression] [AssignTarget,Primary] [ArgumentList,ParenExpr] [IndexSuffix,ArrayElement]`.
  - `ExpressionStatement = choice(CallExpression, BuiltinCall, CreateObjectCall)`.
  - Print: `tab()/pos()` positional items may be juxtaposed with one following item;
    other items need `;`/`,`. `Type` accepts any identifier (intrinsic-only is a lint concern).
- **Validation (run from inside tree-sitter-brightscript/):**
  - `source/**` + `components/*.brs` (19 files) parse **ZERO ERROR**.
  - `corpus/parse-only/*.brs` (17) clean.
  - `corpus/negative/*.brs`: 10 SYNTAX negatives → ERROR; 3 SEMANTIC (`as interface`/`as roSGNode`/`#error`) → clean.
  - `brightscript.so` builds.

### tree-sitter-scenegraph/ — task 5 ✅ (re-reviewed: grammar.js sanity-read + all 34 kinds matchable via live ast-grep sweep)
- grammar.js from `grammar/scenegraph.ebnf`; all **34 scenegraph kinds** present in node-types.json.
- `components/*.xml` + `corpus/parse-only/sg_*.xml` parse ZERO ERROR; negatives parse clean (semantic).
- `test/corpus/*.txt` = 33 tests, `tree-sitter test` GREEN. `scenegraph.so` builds.
- **Injection point:** BrightScript body is node kind **`BrightScriptBody`** in field **`content`**
  of `ScriptCData` and `ScriptText`. (Wire ast-grep injection to this.)
- Sub-agent noted: EBNF `Component` lacked the self-closing `<component/>` form (added in grammar;
  reflect back into scenegraph.ebnf). Prolog fixtures with a leading comment parse the decl as `PI`.

### Registration + injection — task 6 ✅
- `sgconfig.yml` registers `brightscript` (.brs) + `scenegraph` (.xml) under `customLanguages`.
  `ruleDirs: [rules]` (empty `rules/` dir, reserved for lint rules). ast-grep loads both, matches concrete kinds.
- `languageInjections` block injects brightscript into the scenegraph `BrightScriptBody` node
  (`kind: BrightScriptBody` + `pattern: $CONTENT`); verified matching inside `.xml` `<script>` CDATA + bare text.

### Coverage reconciliation (used the user's latitude) ✅
- ast-grep 0.42.3 does NOT expand supertypes → reassigned the 6 supertype/non-node kinds to concrete:
  Literal→{Integer,String,Boolean,Invalid}Literal, NumericLiteral→LongIntegerLiteral, Primary→Identifier,
  AnonymousFunction→AnonFunctionExpr, OptChainSuffix→OC_BRACKET, NL→EOS, mixed_chain PostfixExpr→CallExpression.
- Fixed mislabels: `print("x")`→PrintStatement; Type/Box/GetGlobalAA→BuiltinCall; bytearray.index→CreateObjectCall.
- Fixed 4 buggy snippets in coverage.json (incomplete decls; `\"`→`""` in parsejson; bare-expr split_elem).
- Updated the matching harness `t.spec` kinds. **130 distinct coverage kinds, all in node-types.json.**

### Validation gates ✅
- `python3 grammar/check_coverage.py` — GREEN (coverage ↔ harness/corpus).
- `python3 grammar/check_grammar.py` — NEW (Level 3). GREEN: every coverage kind ∈ node-types.json
  (both grammars) + every brightscript/stdlib snippet (540) parses with its kind present / syntax-negatives ERROR.

### Skill / memory ✅
- `.claude/skills/ast-grep-custom-language/SKILL.md` corrected: supertypes are NOT ast-grep-matchable.
- memory `tree-sitter-grammar-design.md` records the locked decisions.

## REMAINING (do these next)

1. ✅ **DONE — ast-grep language injection** (task 6): `sgconfig.yml` has a `languageInjections` block
   matching `kind: BrightScriptBody` with `pattern: $CONTENT` (the `$CONTENT` metavar is REQUIRED by
   ast-grep to mark the injected subregion). Verified: brightscript rules match inside `.xml` `<script>`
   CDATA bodies AND bare (non-CDATA) inline `<script>` text.
2. ✅ **DONE — Independently verify the scenegraph grammar:** the live ast-grep sweep confirmed all
   **34 scenegraph kinds are MATCHABLE** (not just present in node-types.json), 0 rejected.
3. ✅ **DONE — EBNF↔node-types parity validator** (task 8, roadmap Step 8): `grammar/check_parity.py`
   exists and is GREEN (Level 5) — EBNF rule names ↔ node-types.json kinds, with lexical-helper rules
   allowlisted. Paired with check_coverage + check_grammar, all green.
4. ✅ **DONE — test/corpus fixtures for tree-sitter-brightscript** (task 7): 7 files (literals,
   expressions, statements, control_flow, declarations, postfix_calls, conditional_compilation) =
   53 tests, `tree-sitter test` GREEN. (Scenegraph: 3 files, 33 tests, GREEN.)
5. ✅ **DONE — Docs:** `grammar/CLAUDE.md` validation table now has Level 3 (check_grammar) + Level 5
   (check_parity); root `CLAUDE.md` status flipped to "PARSER BUILT", repo map adds tree-sitter-*/,
   sgconfig.yml, rules/ (dropped the "Not yet present" block); `roadmap/03-tree-sitter-grammar.md` has
   a "Status: COMPLETE" note; README status banner + pipeline updated.
6. ✅ **DONE — Reflect grammar-driven spec fixes back into the EBNF** (self-closing `<component/>`;
   note Type-accepts-identifier).
7. ✅ **DONE — .gitignore decision:** the generated `src/` (parser.c, node-types.json, grammar.json,
   scanner.c, tree_sitter/ headers) was ALREADY committed in `1072061` and stays committed — the
   standard tree-sitter distribution layout, and required because the validators read
   `src/node-types.json` (so the gates are green on a fresh clone; `tree-sitter generate` reproduces it
   byte-identically). Only the compiled `.so`/`.wasm` + build dirs are ignored. Added: a root-`.gitignore`
   note documenting this + `__pycache__/`/`*.pyc`; a `tree-sitter-scenegraph/.gitignore` mirroring the
   brightscript one (it had none).
8. ✅ **DONE — Final ast-grep sweep:** the live matchability sweep PASSED — **129 distinct (language,
   kind) pairs** (95 brightscript + 34 scenegraph) are ALL matchable by ast-grep (0 rejected, 0 missing).

## Acceptance checklist (roadmap/03)
- [x] harness parses zero ERROR  - [x] corpus/parse-only clean  - [x] negatives: syntax ERROR / semantic clean
- [x] all coverage kinds represented in node-types.json (**128 distinct kind names / 129 (language,kind)
  pairs** — `Comment` is the one kind shared by both grammars; the older "130" was pre-edit)
  - [x] custom languages registered + load
- [x] ast-grep patterns match kinds (full sweep DONE — 129 (language, kind) pairs, 0 rejected)  - [x] language injection wired
- [x] check_coverage GREEN + [x] check_grammar GREEN  - [x] check_parity (EBNF↔node-types) GREEN  - [x] test/corpus (brs) green

## Findings / reconciliations (this session)
- **`neg_sg_stringarray_unquoted` is SEMANTIC, not a syntax error.** roadmap/03 grouped DEVICE_FACTS
  #3 (`type="stringarray" value="[a, b, c]"`) under "syntax rejections → must produce ERROR", but the
  `value="..."` attribute is an OPAQUE quoted string to the XML grammar (`FieldInitValue → AttValue`);
  its array micro-syntax is not parsed, and checking it needs type-directed analysis, not context-free
  parsing. The grammar correctly parses it CLEAN → it belongs with the other SEMANTIC negatives
  (lint, not parse-ERROR). Annotated the corpus file to say so (mirrors `sg_field_type_str_alias.xml`).
  So the negative split is really **9 syntax (brs, → ERROR) + the 4 semantic** (`as interface`,
  `as roSGNode`, `type="str"`, `stringarray` unquoted; `#error` parses clean as a valid CC directive).
- **`for each … next` — open device question.** The grammar (and `scenegraph`… no, BrightScript EBNF
  `ForEachStatement`) accepts ONLY `end for`/`endfor` for for-each; `next` is rejected, per the EBNF
  note "`next` is NOT permitted for for-each per docs (but legacy parsers tolerate it)". This is NOT
  device-confirmed (DEVICE_FACTS #10 covers only the NUMERIC `for`). Candidate for a future device
  probe; if the device accepts `for each … next`, relax `ForEachStatement` and add a DEVICE_FACTS entry.
