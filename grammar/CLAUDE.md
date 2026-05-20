# grammar/ — language specifications (EBNF)

This directory holds the **authoritative grammar specifications** that the BrightScript +
SceneGraph tree-sitter / ast-grep parser will be built from. These are *specs*, not code — no
parser is generated from them automatically. They are the human- and AI-readable source of truth.

## Files

| File | Describes | Source of authority |
|------|-----------|---------------------|
| `brightscript.ebnf` | The core BrightScript language: lexical tokens, declarations, statements, the precedence-layered expression grammar, the type system, conditional compilation, exception handling. | [Roku BrightScript Language Reference](https://developer.roku.com/dev/docs/brightscript-language-reference) |
| `scenegraph.ebnf` | Roku SceneGraph component **XML** files, in two layers: (1) a faithful well-formed-XML subset modeled on W3C XML 1.0, and (2) the SceneGraph constraints (`<component>`, `<interface>`/`<field>`/`<function>`, `<script>`, `<children>`, node elements). | [Roku SceneGraph docs](https://developer.roku.com/dev/docs/scenegraph) + the official [RokuSceneGraph.xsd](https://devtools.web.roku.com/schema/RokuSceneGraph.xsd) |
| `brighterscript.ebnf` | The BrighterScript `.bs` **superset** of BrightScript: `namespace`/`class`/`interface`/`enum`/`const`/`import`/`typecast`/`alias`/`type`, ternary `?:`, `??`, optional-chaining, template & regex literals, `new`, callfunc `@.`, computed AA keys, typed forms, and annotations. A thin **delta** that imports `brightscript.ebnf` and shadows only the seam productions it extends. | the [BrighterScript compiler](https://github.com/rokucommunity/brighterscript) source (v0.72.2 — the same version as the installed `bsc`) |

## Notation

Both files use **W3C-style EBNF** (the dialect from the XML spec), consistently:

- `Name ::= expression` — a rule
- `A | B` alternation · `( … )` grouping · `?` optional · `*` zero-or-more · `+` one-or-more
- `'literal'` / `"literal"` terminals · `[a-z]` character classes · `A - B` exception
- Comments: `brightscript.ebnf` uses `(* … *)`; `scenegraph.ebnf` uses `(* … *)` (block form). Keep the chosen style consistent within each file.

Each file documents its own notation in the header — read that header first before editing.

## Key relationship: language injection

`scenegraph.ebnf` **embeds** `brightscript.ebnf`. BrightScript lives inside SceneGraph
`<script><![CDATA[ … ]]></script>` blocks, in external scripts referenced by `uri`, and in
`onChange`/`<function name=...>` symbol references. The SceneGraph grammar marks these embedding
points and defers to the BrightScript grammar by name. When this becomes a tree-sitter grammar,
this is implemented as **language injection** (inject the BrightScript parser into `<script>` CDATA
content). See `../.claude/skills/ast-grep-custom-language/SKILL.md`.

## Key relationship: import + shadow (BrighterScript is a true superset)

`brighterscript.ebnf` relates to `brightscript.ebnf` differently from how `scenegraph.ebnf` does.
SceneGraph **embeds** BrightScript as opaque text inside `<script>` (language injection — the two
grammars stay separate and meet only at the injection point). BrighterScript instead **imports and
overrides** BrightScript: it is a *true superset* in the same language. The delta file IMPORTS
`brightscript.ebnf` and REDEFINES ("shadows") only the seam productions it extends — `TopLevelItem`,
`Expression`, `Type`, `Primary`, `PostfixSuffix`, `AAEntry`, `AssignmentStatement`,
`ForEachStatement` — then adds the new BrighterScript productions (namespace/class/interface/enum/
const/import/typecast/alias/type, ternary `?:`, `??`, template strings, regex literals, `new`,
callfunc `@.`, computed AA keys, typed forms, annotations, the BrighterScript type grammar). Start
symbol: `BrighterScriptSourceFile`. Everything not shadowed is inherited verbatim from the imported
BrightScript spec. `check_ebnf.py` understands this import+shadow model (a locally redefined rule
shadows the imported one).

## How these feed the parser

The intended pipeline (see the skill for the full method):

```
brightscript.ebnf ─┐
                   ├─► tree-sitter grammar.js ─► generated C parser ─► .so ─► ast-grep customLanguage
scenegraph.ebnf  ──┘   (+ language injection)
```

When translating a rule into `grammar.js`, the **precedence-layered expression cascade** (in
`brightscript.ebnf` PART 5: `OrExpr → AndExpr → … → PostfixExpr → Primary`) maps directly onto
tree-sitter `prec`/`prec.left`/`prec.right` levels — preserve the documented associativity of each
level. Named rules become matchable ast-grep `kind`s; remember to `field(...)` the parts you'll
want to select on.

## Conventions when editing

- **Stay faithful to the official docs / XSD.** When a construct is version-gated or uncertain,
  keep it but annotate it with a comment (and the Roku OS version where relevant). Don't silently
  invent syntax.
- **Preserve the "Notes for the tree-sitter implementer" section** at the bottom of each file — it
  records the things EBNF can't express (case-insensitivity, significant newlines, maximal-munch
  lexing, contextual keywords, the field-type enumeration being a semantic not structural
  constraint, etc.). Add to it as you discover more.
- **Keep the two files' notation identical** so they read as a pair.
- These grammars define the coverage target for `../roku-test-harness/` — if you add a construct
  here, the harness should exercise it, and vice-versa.

## Validating the specs

Layered validation — run from the repo root, keep green when editing:

| Level | Command | Checks |
|------|---------|--------|
| 0 — internal consistency | `python3 grammar/check_ebnf.py` | every referenced rule is defined, no duplicates, reachability from the start symbol. Now also checks `brighterscript.ebnf` (start `BrighterScriptSourceFile`) with `brightscript.ebnf` imported — a locally redefined rule shadows the imported one. |
| 1 — coverage parity | `python3 grammar/check_coverage.py` | every `coverage.json` leaf is implemented: each `device_testable:true` id has a matching `t.spec("<id>","<kind>",…)` in `roku-test-harness/source/tests/*.brs` (and the kind cross-checks against `coverage.json`); each non-device (`device_testable:false`) id has a tagged corpus file under `roku-test-harness/corpus/`. Flags missing / mis-keyed / orphaned ids. **GREEN.** |
| 2 — faithful to the XSD | `python3 grammar/check_scenegraph_xsd.py` | `scenegraph.ebnf`'s `FieldType` / `BuiltinNodeClass` / `<field>` attributes match the vendored `RokuSceneGraph.xsd` (`--url` refreshes it). |
| 3 — grammar matches coverage | `python3 grammar/check_grammar.py` | every coverage `kind` is present in the generated `node-types.json` (both grammars) AND every brightscript/stdlib coverage snippet parses with its kind present / syntax-negatives produce ERROR. |
| 4 — corpus is real code | `npm run check` | runs BrighterScript (`bsc`) over `../roku-test-harness/`. NOTE: `bsc` is advisory, not authoritative — it both over- and under-rejects vs the device; cross-check any red line against [BSC_DRIFT.md](BSC_DRIFT.md). |
| 5 — EBNF ↔ grammar parity | `python3 grammar/check_parity.py` | EBNF rule names ↔ `node-types.json` kinds, so the EBNF can't silently drift from the generated grammar. |

Levels 0, 1, 2, 3, and 5 are all green; all THREE tree-sitter grammars are now built
(`tree-sitter-brightscript`, `tree-sitter-scenegraph`, and `tree-sitter-brighterscript` — the last
EXTENDS the brightscript grammar via tree-sitter grammar inheritance). Level 4 (`bsc`) is advisory
only. The **BrighterScript layer is now covered by ALL applicable gates**: L0 (`check_ebnf` validates
`brighterscript.ebnf` with `brightscript.ebnf` imported), L1 (`check_coverage` scans `.bs`
corpus/spec sources), L3 (`check_grammar` checks the brighterscript coverage kinds + parses the
snippets with the brighterscript grammar), and L5 (`check_parity` compares `brighterscript.ebnf` ↔
the brighterscript `node-types.json`, with inherited kinds reconciled against the imported
`brightscript.ebnf`). The grammar is registered as the `brighterscript` ast-grep custom language
(`.bs`) in `sgconfig.yml`.

Ground truth is the device, recorded in [DEVICE_FACTS.md](DEVICE_FACTS.md); where `bsc` and the
device disagree, the divergence is logged in [BSC_DRIFT.md](BSC_DRIFT.md) (the device always wins).
The BrighterScript layer is **device-validated via transpile** — the harness transpiles its `.bs`
specs to `.brs` before sideload, and all 24 device-testable `bs.*` specs run and pass on hardware
(DEVICE_FACTS.md #18).

## ⚠️ Items flagged as unverified (confirm against a device / docs before relying on them)

These were called out by the spec authors as uncertain. Verify before treating as ground truth:

**BrightScript:**
- Fused vs spaced keywords (`endwhile`/`end while`, `exitfor`/`exit for`) — fused `exitfor`/`endfor` are weakly documented.
- ~~Line continuation~~ — **RESOLVED (device, [DEVICE_FACTS.md](DEVICE_FACTS.md) #14)**: no continuation char. Newlines are non-significant only inside `[ ]` / `{ }` collection literals and call **argument lists** — NOT inside a grouping `( )` (`x = (1 +`⏎`2)` is Syntax Error `&h02`). The earlier "inside `() [] {}`" wording was too broad.
- Trailing commas in `[]`/`{}` literals — modeled permissively; runtime tolerance not documented.
- Reserved built-ins (`Eval`, `Run`, `Type`, `Box`, `GetGlobalAA`, `Line_Num`, …) — call signatures not fully spec'd.
- ~~`Dim` with `(…)` vs `[…]` bounds~~ — **RESOLVED (device, [DEVICE_FACTS.md](DEVICE_FACTS.md) #8)**: bracket bounds `dim a[n]` are required; the paren form `dim a(n)` is a Syntax Error (&h02). `DimBounds` keeps only the bracket form; the paren alternative is annotated device-rejected.
- ~~`for each` / `for` termination via `next`~~ — **RESOLVED (device, [DEVICE_FACTS.md](DEVICE_FACTS.md) #10)**: `next` and `next <var>` are device-valid (the channel compiled and ran with `next i`). `ForTerminator` keeps the `next Identifier?` form. NOTE bsc-vs-device drift: `bsc` wrongly rejects `next <var>` (see [BSC_DRIFT.md](BSC_DRIFT.md)).
- ~~Optional-chaining `?.`/`?[`/`?(` vs print `?` & statement-vs-expression~~ — **RESOLVED (device, [DEVICE_FACTS.md](DEVICE_FACTS.md) #9)**: the optional-call `?()` is valid only in **expression** position (`y = f?()`); a bare optional-call **statement** (`o.fn?()`) is a Syntax Error (&h02). `CallExpression` drops the `OC_PAREN` terminus; implementer note 15 records the disambiguation. (The `?`-vs-print spacing rule itself is still per the docs/note 3.)
- ~~Nested **named** function declarations~~ — **RESOLVED (device, [DEVICE_FACTS.md](DEVICE_FACTS.md) #5)**: a named `function`/`sub` declared inside another function body is a Syntax Error (&h02). Removed from the in-body `Statement` set (top-level only); anonymous function **values** inside a body remain valid.
- ~~`as interface` / `as <CustomType>` (e.g. `as roSGNode`)~~ — **RESOLVED (device, [DEVICE_FACTS.md](DEVICE_FACTS.md) #6, #7)**: only the intrinsic type set is valid in an `as` clause; `as interface` and any custom/component type name are compile errors (&ha7). `Type` keeps only the intrinsics device-valid; `interface`/`Identifier` annotated device-rejected. (Custom types in `as` are a BrighterScript transpile feature.)
- ~~Optional leading `let` on assignment~~ — **RESOLVED (device, see [DEVICE_FACTS.md](DEVICE_FACTS.md) #2)**: Roku OS 15.1.4 rejects `let x = 5` (Syntax Error &h02). `let` stays reserved but the LET-assignment form is unsupported; removed from `AssignmentStatement`.
- ~~Boolean operators (`and`/`or`/`not`) inside `#if`~~ — **RESOLVED (device, [DEVICE_FACTS.md](DEVICE_FACTS.md) #1)**: rejected (compile error &h93). `CCExpression` reduced to a single boolean/const; negation via `#else`, conjunction via nested `#if`.

**SceneGraph:**
- ~~`array` vs `roArray` spelling~~ — **RESOLVED (device, [DEVICE_FACTS.md](DEVICE_FACTS.md) #4)**: a valued `type="roArray"` field converts to an array exactly like `array` (a bogus type stays `Invalid`), so `roArray` is device-valid despite being absent from the XSD. Restored to `FieldType`; `check_scenegraph_xsd.py` allowlists it as a device-confirmed extra.
- **RESOLVED (device, [DEVICE_FACTS.md](DEVICE_FACTS.md) #3)**: a `stringarray` initial value needs quoted elements — `value='["a","b","c"]'`; `[a, b, c]` is rejected. (Array field-init values are validated only when a `value` is present.)
- ~~`type="str"` field-type alias~~ — **RESOLVED (device, [DEVICE_FACTS.md](DEVICE_FACTS.md) #11)**: `str` is NOT device-valid (a valued `type="str"` field reads `Invalid`), unlike the `int`/`bool` aliases which work; use `string`. `str` is kept in `FieldType` (it is in the XSD, so `check_scenegraph_xsd.py` would flag its removal) but annotated device-rejected.
- ~~bare (non-CDATA) inline `<script>` execution~~ — **RESOLVED (device, [DEVICE_FACTS.md](DEVICE_FACTS.md) #12)**: a bare inline script is tolerated (component loads) but NOT executed (`init()` never runs); CDATA or external `uri` scripts execute. Recorded in implementer note 3 / `ScriptText`.
- ~~scalar `rect2D` runtime shape~~ — **RESOLVED (device, [DEVICE_FACTS.md](DEVICE_FACTS.md) #13)**: a scalar `rect2D` deserializes to an `roAssociativeArray` `{x,y,width,height}`, not an `roArray`; a `rect2DArray`'s outer container IS an `roArray`. Recorded in implementer note 8.
- Color string formats beyond `0xRRGGBBAA` (e.g. `#RRGGBB`) — only `0xRRGGBBAA` confirmed.
- Node-reference attribute micro-syntax (e.g. `"dictionary:SomeId"`) — from an example, not a formal spec.
- `AnimationBase`/`ArrayGrid` in the `extends` enumeration — present in the XSD but base-ish; instantiability unverified.
- Strictness of child-element ordering in `<component>` — XSD mandates `interface? script* children?`; real tooling is often lenient. Grammar models the strict order with a relaxed alternative noted.
