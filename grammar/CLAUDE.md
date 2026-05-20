# grammar/ — language specifications (EBNF)

This directory holds the **authoritative grammar specifications** that the BrightScript +
SceneGraph tree-sitter / ast-grep parser will be built from. These are *specs*, not code — no
parser is generated from them automatically. They are the human- and AI-readable source of truth.

## Files

| File | Describes | Source of authority |
|------|-----------|---------------------|
| `brightscript.ebnf` | The core BrightScript language: lexical tokens, declarations, statements, the precedence-layered expression grammar, the type system, conditional compilation, exception handling. | [Roku BrightScript Language Reference](https://developer.roku.com/dev/docs/brightscript-language-reference) |
| `scenegraph.ebnf` | Roku SceneGraph component **XML** files, in two layers: (1) a faithful well-formed-XML subset modeled on W3C XML 1.0, and (2) the SceneGraph constraints (`<component>`, `<interface>`/`<field>`/`<function>`, `<script>`, `<children>`, node elements). | [Roku SceneGraph docs](https://developer.roku.com/dev/docs/scenegraph) + the official [RokuSceneGraph.xsd](https://devtools.web.roku.com/schema/RokuSceneGraph.xsd) |

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
| 0 — internal consistency | `python3 grammar/check_ebnf.py` | every referenced rule is defined, no duplicates, reachability from the start symbol. |
| 2 — faithful to the XSD | `python3 grammar/check_scenegraph_xsd.py` | `scenegraph.ebnf`'s `FieldType` / `BuiltinNodeClass` / `<field>` attributes match the vendored `RokuSceneGraph.xsd` (`--url` refreshes it). |
| 4 — corpus is real code | `npm run check` | runs BrighterScript (`bsc`) over `../roku-test-harness/`. NOTE: currently trips on the open-question constructs below (`let`, `#if and/or/not`) — those are pending the device loop, not green yet. |

Levels 0 and 2 are green. Level 3 (build the tree-sitter grammar, parse the corpus) and the
device-as-ground-truth loop are tracked in `../roku-test-harness/`.

## ⚠️ Items flagged as unverified (confirm against a device / docs before relying on them)

These were called out by the spec authors as uncertain. Verify before treating as ground truth:

**BrightScript:**
- `Dim` with `(…)` vs `[…]` bounds — both allowed in the spec; confirm runtime acceptance.
- `for each` termination: docs say `end for` only (not `next`); legacy parsers tolerate `next`.
- Fused vs spaced keywords (`endwhile`/`end while`, `exitfor`/`exit for`) — fused `exitfor`/`endfor` are weakly documented.
- Line continuation: modeled as **none** (BrightScript has no continuation char; newlines are only non-significant inside `() [] {}`). Not stated in one canonical doc line.
- Trailing commas in `[]`/`{}` literals — modeled permissively; runtime tolerance not documented.
- Reserved built-ins (`Eval`, `Run`, `Type`, `Box`, `GetGlobalAA`, `Line_Num`, …) — call signatures not fully spec'd.
- Optional-chaining `?.`/`?[` vs print `?` disambiguation (space sensitivity) — validate against device behavior.
- Optional leading `let` on assignment — **OPEN** (annotated in `brightscript.ebnf`): BrighterScript rejects it (BS1081 "Unexpected token 'let'"), but `let` is a Roku reserved word. Confirm on a device.
- Boolean operators (`and`/`or`/`not`) inside `#if` conditional compilation — **OPEN** (annotated in `brightscript.ebnf`): BrighterScript rejects them (BS1091/BS1081); Roku may permit only a single `#const`/boolean, making `CCExpression` over-permissive. Confirm on a device.

**SceneGraph:**
- ~~`array` vs `roArray` spelling~~ — **RESOLVED**: the XSD enumerates only `array`; `roArray` removed from `FieldType`, enforced by `check_scenegraph_xsd.py`. (A device check could still confirm whether the runtime *also* tolerates `roArray`.)
- Color string formats beyond `0xRRGGBBAA` (e.g. `#RRGGBB`) — only `0xRRGGBBAA` confirmed.
- Node-reference attribute micro-syntax (e.g. `"dictionary:SomeId"`) — from an example, not a formal spec.
- `AnimationBase`/`ArrayGrid` in the `extends` enumeration — present in the XSD but base-ish; instantiability unverified.
- Strictness of child-element ordering in `<component>` — XSD mandates `interface? script* children?`; real tooling is often lenient. Grammar models the strict order with a relaxed alternative noted.
