# Completeness Audit — ast-grep-brightscript vs. angel-roku

**Date:** 2026-07-17
**Auditor:** automated cross-reference (empirical parse + coverage taxonomy + bsc ground-truth)
**Question:** Does this repo *represent and validate* every BrightScript / BrighterScript /
SceneGraph syntax construct that the real **angel-roku** production app actually uses — and does it
exercise the entirety of the spec?

---

## 1. Verdict

**The parser is 98.96% complete against the real app, with exactly two genuine grammar gaps and one
spec-completeness hole.** angel-roku's construct usage is otherwise a strict **subset** of what this
repo already enumerates and validates.

| Layer | Files parsed | Parse-clean | Failing |
|---|---:|---:|---:|
| `.bs` (BrighterScript) | 130 | 129 | **1** |
| `.brs` (BrightScript) | 426 | 419 | **7** |
| `.xml` (SceneGraph) | 215 | 215 | **0** |
| **Total** | **771** | **763 (98.96%)** | **8** |

The 8 failures collapse to **2 root-cause constructs**. Both are **valid** BrightScript/BrighterScript
(confirmed by compiling them with `bsc` 0.67.4, the ground-truth compiler) — so they are grammar
**over-restrictions**, not app bugs:

1. **`#if` conditional-compilation wrapping top-level declarations** — 7 `.brs` files.
2. **`new` used as an ordinary identifier in `.bs`** — 1 `.bs` file.

A third finding is a **spec hole not exercised by angel-roku**: leading-dot enum references
(`x = .Member`) are absent at all validation levels and the grammar misparses them.

Everything else the app uses — including every "rare" construct (goto/label, `try/catch/throw` in
plain `.brs`, bitwise `<<`, prototype-OOP member assignment, `for … step -1`, all type suffixes,
`continue for`, `Library`, optional chaining `?.`/`?[`, `<customization>`, namespaced `xsi:`
attributes, the `<?rokuml?>` PI) — is already **represented in `coverage.json` and parses clean**.

---

## 2. Method (what "represented and validated" means)

A construct can be validated at four independent levels in this repo; the audit checked each:

1. **Grammar / EBNF** (`grammar/*.ebnf`) — is it in the spec.
2. **Coverage taxonomy** (`grammar/coverage.json`, 663 leaves) — is it enumerated as a dimension.
3. **Corpus golden test** (`tree-sitter-*/test/corpus/*.txt`) — does it have a pinned parse tree.
4. **Device validation** (`roku-test-harness/` on a real Roku + `grammar/DEVICE_FACTS.md`) — 501/501
   device-testable specs pass on Roku OS 15.1.4.

Audit inputs:
- **Empirical parse-audit** — ran this repo's three compiled tree-sitter parsers (`tree-sitter parse`,
  cwd pinned to each grammar dir) against **every** angel-roku source file (excluding
  `node_modules/ out/ build/`). A file fails iff its parse tree contains `ERROR` or `MISSING`.
- **Ground-truth confirmation** — every failing construct was compiled with angel-roku's own `bsc`
  0.67.4 to prove it is valid (a grammar gap), not invalid (an app bug).
- **Construct census** — three exhaustive sweeps of angel-roku (BrightScript/BrighterScript usage,
  SceneGraph/XML usage, and this repo's validation assets), cross-referenced construct-by-construct.

---

## 3. Findings

### GAP 1 — Conditional compilation around **top-level declarations** · severity HIGH

**What angel-roku does.** All 7 files in `source/xavier/` wrap their *entire* module body — every
module-scope `sub`/`function` declaration — in a single column-0 `#if xavier_instrumented … #end if`:

```brightscript
#if xavier_instrumented
function Xavier_ProtocolVersion() as string   ' <- col-0 decl INSIDE the cc block
  return "2.0.0"
end function
' … dozens more decls …
#end if
```

Files: `XavierFocus.brs`, `XavierEmit.brs`, `XavierVerbMap.brs`, `XavierSession.brs`,
`XavierFetch.brs`, `XavierFocusPath.brs`, `XavierInstall.brs`. (368 `#if` occurrences app-wide; ~361
sit inside function bodies and parse fine — it is specifically the **declaration-level** wrapping that
breaks.)

**Repo status — gap at 3 of 4 levels:**
- **Grammar:** BOTH `tree-sitter-brightscript` and `tree-sitter-brighterscript` emit `ERROR`. This is
  the root cause of **all 7 `.brs` parse failures.** `#if` *inside* a statement body works correctly.
- **Coverage:** all 9 `cc.*` leaves wrap **body statements** (`#if true\nx=1\n#end if`) — **none wraps
  a declaration.**
- **Corpus:** `conditional_compilation.txt` wraps `print` statements, not declarations.
- **Device:** cc-around-statements is device-validated; cc-around-declarations is not.

**Ground truth:** compiles clean under `bsc` (with `#const xavier_instrumented = true`, no errors).
Conditional compilation is a preprocessor pass, so `#if` may legally wrap *any* source span, including
whole declarations. **This is a genuine grammar gap.**

**Remediation:** allow cc directives (`#if / #else if / #else / #end if / #const / #error`) at the
declaration/module level, not just inside statement blocks. Add coverage leaves
(`cc.decl.if_wraps_function`, `cc.decl.if_wraps_sub`), a corpus case, and — since the device runs it —
a harness spec.

---

### GAP 2 — `new` as an ordinary identifier in `.bs` · severity MEDIUM

**What angel-roku does.** Uses `new` as a plain local variable name:

```brightscript
new = [{ id: "a2" }, { id: "b2" }]      ' source/logic/DiscoveryHubController.spec.bs
result = discoverHub_mergeFirstPageHubRails(old, new)
```

(Also 12× in `.brs` roca test files, which parse fine — see below.)

**Repo status — gap at 2 of 4 levels:**
- **Grammar:** `tree-sitter-brighterscript` reserves `new` → `ERROR`. This is the sole `.bs` parse
  failure. **`tree-sitter-brightscript` does *not* reserve `new`**, so the identical construct in
  `.brs` parses clean — the gap is specific to the **BrighterScript** grammar.
- **Coverage:** `bs.expr.new` covers the `new ClassName()` **keyword**; nothing covers `new` as an
  identifier. `negatives.txt` only has "new w/o class name."
- Corpus / device: n/a for the identifier use.

**Ground truth:** `new = [1,2,3]` compiles clean under `bsc` (only a harmless "file not referenced"
warning). In BrighterScript, `new` is contextually a keyword only in expression position before a
type name; as an assignment target it is a valid identifier. **This is a genuine grammar
over-restriction.**

**Remediation:** in the brighterscript grammar, treat `new` as a keyword only in expression/`new
Type(...)` position; permit it as an identifier / assignment target elsewhere. Add a coverage leaf
(`bs.ident.new_as_identifier`) + corpus case.

---

### GAP 3 — Leading-dot enum reference (`x = .Member`) · severity LOW-for-app / MEDIUM-for-spec

**Not used by angel-roku** (the app defines no enums; every `.Capitalized` token is a method call or
lives in a comment / `@it("…")` string). This is therefore **not an angel-roku gap** — but it *is* a
hole against the "exercise the entirety of the spec" goal.

**Repo status — absent at all 4 levels.** The BrighterScript grammar **misparses** it: `x = .Active`
becomes a `PostfixExpr` whose `object` is a **zero-width `BooleanLiteral`** followed by a
`MemberSuffix`; two leading-dot references in one file produce a hard `ERROR`. The only related leaf
is `lex.num.float.leading_dot` (for numeric `.5`).

**Remediation (spec-completeness, lower priority):** add a grammar production for a leading-dot enum
member reference, plus `bs.enum.leading_dot` coverage + corpus. Track as a spec-completeness item
rather than an angel-roku blocker.

---

## 4. What is already complete (the large green area)

### SceneGraph — zero gaps (strict superset)
angel-roku's SG usage is fully contained in the repo's coverage. Every field type it uses — including
the rare `longinteger` (2×) and `vector2d` (1×) — has a leaf, and the repo covers ~15 field types the
app never uses (`color`, `rect2d`, `time`, `uri`, `font`, and every `*array`). Every rare SG construct
the app uses already has a **dedicated** coverage leaf and/or parse-only corpus file:

| angel-roku construct | coverage leaf |
|---|---|
| `<customization suspendhandler/resumehandler>` (3×) | `sg.component.customization` |
| namespaced `xsi:` attributes (16 files) | `sg.component.attr_namespaced` |
| `<?rokuml?>` PI (2 files) | `sg.prolog.rokuml_pi` |
| `alias=` / `alwaysNotify=` / `onChange=` fields | `sg.field.attr.{alias,alwaysnotify,onchange}` |
| `<Animation>` / `FloatFieldInterpolator` / `Vector2DFieldInterpolator` | node/children leaves |
| external `uri=` scripts (948 `.brs`, 2 `.bs`) + 1 inline CDATA | `sg.script.{external_uri,external_uri_bs,…}` |

### BrightScript / BrighterScript — every used construct represented
Cross-referencing the app's 20 "notable/rare" constructs against the taxonomy: **all represented.**

| angel-roku rare construct | coverage leaf(s) | parses clean? |
|---|---|---|
| `goto` + colon label (2 pairs, production) | `stmt.goto.basic`, `stmt.label.in_loop` | ✅ |
| `try` / `catch e` / `end try` in plain `.brs` (10 files) | `stmt.try.basic`, `.endtry_fused` | ✅ |
| `throw "msg"` (2×) | `stmt.throw.string`, `.aa` | ✅ |
| bitwise `<<` with `&` longint operands | `expr.shift.shl`, `stmt.compound.shl` | ✅ |
| prototype-OOP `prototype.X = sub/function` (85×) | member access + `expr.anon.{function,sub}` | ✅ |
| `for … to 0 step -1` (8×) | `stmt.for.step`, `stmt.for.step_negative` | ✅ |
| type suffixes on idents/literals (`% ! # & $`) | `lex.ident.suffix.*`, `lex.num.longint.*` | ✅ |
| `continue for` (6×) | `stmt.continue.for` | ✅ |
| `Library "Roku_Ads.brs"` (3×) | `decl.library.basic` | ✅ |
| optional chain `?.` (3124×) / optional index `?[` (21×) | `expr.optchain.dot`, `.bracket` | ✅ |
| `hex &hNN` + bitwise `and` | `lex.num.int.hex` + and-expr | ✅ |
| anonymous `function`/`sub` expressions (184×) | `expr.anon.*` (6 leaves) | ✅ |

**Advanced BrighterScript features the app does NOT use** (so their coverage leaves exist for
spec-completeness but aren't exercised by angel-roku — not gaps): `import`, `const`, `enum`,
`interface`, ternary `?:`, null-coalescing `??`, typecast `as` expressions, typed arrays `T[]`, union
types, template/backtick strings, callfunc `@.`, `bs` regex literals, `new` construction, class
constructors, `dim`, `stop`, `rem`, `line_num`, `#const`, `#else`/`#else if`, `#error`. Notably, the
app's BrighterScript OOP (`namespace`/`class`/`override`/`private`/`protected`) lives **almost
entirely in the test layer** (rooibos `.spec.bs`); production logic is overwhelmingly plain `.brs`.

---

## 5. Minor / validation-depth notes (low priority)

- **`continue for` / `continue while`** have coverage leaves and device validation but **no dedicated
  golden corpus test.** angel-roku uses `continue for` 6×. Consider adding a corpus case.
- **Relative (scheme-less) script `uri=`** (~31 in angel-roku, e.g. `uri="VideoControls.brs"`): no
  dedicated leaf, but parses fine as an attribute value — non-issue.
- **Field-type case variants** (`String`, `int`, `assocArray`, `Boolean`): handled by the
  case-insensitive field-type leaf — non-issue.

---

## 6. Bonus — app-side lint-rule opportunities (found during the sweep)

These are **angel-roku** defects, not repo gaps — but since this repo exists to *lint* SceneGraph /
BrightScript with ast-grep, they are prime candidates for the (currently empty) `rules/` dir:

- **Wrong-case node elements** (SceneGraph is case-sensitive): `<poster>` should be `Poster`
  (`FeaturedLivestreamTile.xml:36`, `SideMenu.xml:104`); `<Rowlist>` should be `RowList`
  (`EndOfAsset.xml:86`, `LivestreamsView.xml:18`). A mis-cased built-in silently becomes an
  unrecognized/empty node — a high-value lint rule.
- **Malformed XML declaration**: `<?rokuml version=…?>` instead of `<?xml …?>` in
  `PlayerTask.xml:1` and `AdTask.xml:1` (the files then have *no* real XML declaration).

---

## 7. Prioritized remediation plan

| # | Item | Type | Effort | Priority |
|---|---|---|---|---|
| 1 | Allow cc directives around top-level declarations (both grammars) + coverage + corpus + harness spec | grammar + validation | M | **P0** (fixes 7 real files) |
| 2 | Permit `new` as an identifier in the brighterscript grammar + coverage + corpus | grammar + validation | S | **P1** (fixes 1 file) |
| 3 | Leading-dot enum reference production + coverage + corpus | grammar + validation | M | P2 (spec-completeness) |
| 4 | Dedicated corpus golden test for `continue for/while` | validation-depth | S | P3 |
| 5 | (Optional) Author `rules/` lint rules for wrong-case SG nodes & malformed XML decl | new rules | S–M | P3 |

**Suggested regression guard:** extend `grammar/check_realworld.py` (which already pins 5 OSS `.bs`
repos) with an angel-roku target — or add a sibling `check_angel_roku.py` — so the 98.96% → 100%
parse rate is pinned and cannot regress. After fixes 1–2 land, the app should reach **771/771 clean.**

---

## 8. Remediation status (2026-07-17)

All three findings are resolved; **angel-roku now parses 771/771 (100%)** with this repo's grammars.

| # | Finding | Resolution | Verification |
|---|---|---|---|
| GAP 1 | cc around top-level decls | `ccBlockBody()` added to both grammars (`IfDirectiveBlock` body admits function/sub/library decls); EBNF `BlockItemsCC` synced; coverage `cc.decl.if_function` + `cc.decl.if_sub`; corpus test | 7/7 xavier files clean; corpus green; `bsc` clean |
| GAP 2 | `new` as identifier (.bs) | brighterscript `newAsIdent()` admits `new` as identifier in AssignTarget + Primary, with `[NewExpression, Primary]` GLR conflict; `new Foo()` preserved; coverage `bs.ident.new_as_identifier`; corpus test | 1/1 `.bs` file clean; `new Foo()` still a NewExpression; `bsc` clean |
| GAP 3 | leading-dot enum | **Reclassified: NOT a language feature** — `bsc` rejects `= .Member` (BS1081) in every position. Recorded as a **negative** (`neg.bs.leading_dot_enum`): grammar emits MISSING; corpus `:error` test; `check_grammar` `BR_SYNTAX_ERROR_IDS` | grammar rejects (MISSING); corpus `:error` green; matches bsc |

**Gates:** all 6 green (`check_ebnf`, `check_coverage`, `check_grammar`, `check_parity`,
`check_scenegraph_xsd`, `check_reference`). **Corpus:** 61 brightscript + 50 brighterscript, 100%.
**bsc:** harness compiles clean (0 errors). **OSS regression:** 49/49 `.bs` clean (maestro repo URL
dead → not measured; pre-existing, unrelated). **Coverage:** 663 → 667 leaves.

**On-device confirmation: DONE ✅ (Roku Ultra, OS 15.2.4).** The harness was transpiled, sideloaded
(device compiled it clean on upload — no compile errors), and launched; the `##SPEC##` stream
self-reported **`event=run-end pass=504 fail=0`**. coverage.json now has exactly **504
`device_testable:true` leaves** (up from 501), each gate-enforced to have a harness `t.spec` — so 504
leaves = 504 device passes = every spec ran and passed, including the 3 new ones
(`cc.decl.if_function`, `cc.decl.if_sub`, `bs.ident.new_as_identifier`; the last directly observed
`status=PASS` in every capture). Recorded as DEVICE_FACTS.md #22–23. Device address was `192.168.1.40`
(the `.2.40` in the earlier prompt was a typo).

## Appendix — audit artifacts

- Empirical parse results: `scratchpad/audit_results.json` (per-file status + ERROR contexts).
- Construct censuses: `scratchpad/census_bs.md`, `scratchpad/census_sg.md`.
- Validation-asset index: `scratchpad/index_validation.md`.
- Corpus shape: angel-roku = 344 plain `.brs`, 82 roca `.test.brs`, 124 rooibos `.spec.bs`, 6 infra
  `.bs`; 213 SceneGraph `.xml` (+2 non-SG Charles Proxy configs, correctly out of scope).
