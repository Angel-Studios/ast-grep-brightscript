# Device-confirmed facts — the loop's ground-truth ledger

Ground truth = the Roku test device. Each entry records what the device actually
did, the error code, and the resulting spec/harness change. This is the "device"
side of the self-improving loop (see `grammar/CLAUDE.md` and the project memory
`self-improving-loop`). EBNF rules changed because of a fact carry a
`DEVICE-CONFIRMED` comment pointing back here.

**Device:** Roku Streaming Stick 4K (model 3820RW2), Roku OS **15.1.4**, build
E6G.14E03321A.
**Method:** `npm run roku:deploy` sideloads `roku-test-harness/`. The dev
installer COMPILES on upload, so compile errors return immediately; runtime
errors appear on the BrightScript debug console (telnet 8085, captured by
`roku-listener/`).

## Confirmed

| # | Layer | Construct | Verdict | Device evidence | Action taken |
|---|-------|-----------|---------|-----------------|--------------|
| 1 | BrightScript | `#if not/and/or` (boolean operators in conditional compilation) | **INVALID** | compile error `&h93` — "Invalid #If/#ElseIf expression (True \| False \| <CONST-NAME>)" | `CCExpression ::= BooleanLiteral \| Identifier`; harness expresses negation via `#else`, conjunction via nested `#if` |
| 2 | BrightScript | leading `let` on assignment (`let x = 5`) | **INVALID** | `Syntax Error` `&h02` | `AssignmentStatement` drops the optional `let`; `let` stays a reserved word (not a usable statement keyword) |
| 3 | SceneGraph | `stringarray` field init written as `[a, b, c]` | **INVALID** | runtime: "Cannot convert initial value string \"[a, b, c]\" to field type stringarray" | quote the elements: `value='["a","b","c"]'` (single-quote the XML attr, double-quote the strings) |
| 4 | SceneGraph | `roArray` field type (valued, e.g. `value='[1,2,3]'`) | **VALID** | probe: a valued `roArray` field's runtime `Type()` is `roArray`, identical to the known-valid `array`; a control `type="notatype"` field stays `Invalid` (its value is not converted) | restored to `scenegraph.ebnf` `FieldType` as a device-confirmed extra (not in the XSD); `check_scenegraph_xsd.py` allowlists it |
| 5 | BrightScript | nested **named** function (`function g()` declared inside another function) | **INVALID** | compile error `&h02` (Syntax Error) in `test_decl.brs` | `decl.function.nested` → `device_testable:false`, `expect:error`; moved to `corpus/negative/decl_function_nested.brs`. (Anonymous function *values* assigned to vars inside a function remain valid.) |
| 6 | BrightScript | `as interface` type annotation | **INVALID** | compile error `&ha7` in `test_decl.brs` | `decl.type.interface` → non-device; `corpus/negative/decl_type_interface.brs`. Only the intrinsic type set is valid in `as` clauses. |
| 7 | BrightScript | `as <ComponentType>` (e.g. `as roSGNode`) — a non-intrinsic/custom type name in an `as` clause | **INVALID** | compile error `&ha7` in `test_decl.brs` | `decl.type.custom` → non-device; `corpus/negative/decl_type_custom.brs`. Custom/component types in `as` are a BrighterScript transpile feature, not device BrightScript. |
| 8 | BrightScript | `dim a(n)` paren array bounds | **INVALID** | compile error `&h02` (Syntax Error) in `test_stmt.brs` | `stmt.dim.paren` → non-device; `corpus/negative/stmt_dim_paren.brs`. Dim requires `[bracket]` bounds (`stmt.dim.bracket` is valid). |
| 9 | BrightScript | optional-call `?()` used as a bare expression-**STATEMENT** (`o.fn?()`) | **INVALID** | compile error `&h02` (Syntax Error) in `test_stmt.brs` | `stmt.expr.optcall` → non-device; `corpus/negative/stmt_expr_optcall.brs`. The `?()` optional-call is VALID in **expression** position (`expr.optchain.paren`, `y = f?()`, device-confirmed PASS). |
| 10 | BrightScript | `next i` (the `next` terminator followed by the counter variable) | **VALID** | the channel compiled and ran with `next i` present; `stmt.for.next_var` PASSED on device | kept device-valid. NOTE: BrighterScript (`bsc`) rejects it (BS1039/BS1066) — a tracked **bsc drift** ([BSC_DRIFT.md](BSC_DRIFT.md)); suppressed in-source with `' bs:disable-next-line`. |
| 11 | SceneGraph | `type="str"` field-type alias | **INVALID** | runtime: a valued `type="str"` field reads back `Invalid`, while the `type="int"` and `type="bool"` aliases convert correctly and `type="string"` works | `sg.field.type.str_alias` → non-device; `corpus/negative/sg_field_type_str_alias.xml`. `str` is not a recognized spelling; use `string`. |
| 12 | SceneGraph | bare (non-CDATA) inline `<script>…</script>` | **TOLERATED, NOT EXECUTED** | a component with a bare inline script *loads* (instantiates without error), but its `init()` never runs (the field it would set stays `false`); the identical body wrapped in `<![CDATA[…]]>` *does* execute (probe-confirmed) | `sg.script.inline_text` stays device-testable, but the spec now asserts the construct is **tolerated** and that the bare body did **not** run. Inline BrightScript must be in CDATA (or an external `uri`) to execute. |
| 13 | SceneGraph | scalar `rect2D` field runtime shape | **roAssociativeArray** | a valued `type="rect2D"` field deserializes to an `roAssociativeArray` (`{x,y,width,height}`), NOT an `roArray`; a `rect2DArray`'s OUTER container IS an `roArray` | `sg.field.type.rect2d` spec asserts `roAssociativeArray` (key count 4); `sg.field.type.rect2darray` asserts the outer `roArray`. |
| 14 | BrightScript | newline inside a grouping `( )` (e.g. `x = (1 +`⏎`2)`) | **INVALID** | compile error `&h02` (Syntax Error) in `test_lex.brs` | `lex.eos.depth0_paren` → non-device; `corpus/negative/lex_eos_depth0_paren.brs`. Newline-suppression at depth>0 applies to `[ ]` / `{ }` collection literals (and call argument lists) but **not** to a grouping parenthesised expression. |
| 15 | BrightScript (stdlib) | `CreateObject("roInt"/"roFloat"/"roString"/"roBoolean"/"roLongInteger", value)` | value arg **IGNORED** | the boxed object is created with the default (0 / "" / false), not the passed value | box an intrinsic WITH its value via `box(v)` (`box(5).GetInt()=5`); `CreateObject("roString")` + `SetString(...)` also works. Harness boxed/string specs use `box()`. |
| 16 | BrightScript (stdlib) | the `ifString` **`Mid` method** index base | **0-indexed** | `"hello".Mid(2)` → `"llo"`, `"hello".Mid(2,3)` → `"llo"` | the ifString `Mid`/`Instr` METHODS are 0-based, whereas the GLOBAL `Mid()` function is 1-based — a genuine method-vs-global divergence. Harness asserts the 0-based results. |
| 17 | BrightScript (stdlib) | `roTimespan.Mark()` return | **void** (resets start) | `Mark()` returns nothing; it resets the timer origin | read elapsed time with `TotalMilliseconds()` / `TotalSeconds()`. `lib.timespan.mark` asserts `TotalMilliseconds()` is numeric after `Mark()`. |

General rule learned: a SceneGraph field's **type is validated only when a
`value` is present** (the device attempts the string→type conversion then).

## Standard-library layer (device-validated)

`coverage.json` now carries a `layer:"stdlib"` taxonomy: **191 device-testable
leaves** exercising the BrightScript standard library — global string/math/utility/
JSON functions, `roArray`/`roList`/`roByteArray`, `roAssociativeArray` + boxed
intrinsics, `roString` (ifString/ifStringOps), `roDateTime`/`roTimespan`/`roRegex`,
and `roDeviceInfo`/`roAppInfo`/`roRegistry`/`roFileSystem`. Each stdlib spec is
internally `try/catch`-guarded so a device-rejected API FAILs only its own spec
(never aborts the run); facts 15–17 were found exactly this way. Full run:
**468/468 PASS** (`run-end fail=0`).

## Method note: whole-channel compile gating (how facts 5–13 were found)

The dev installer compiles the WHOLE channel; one device-invalid construct fails
the build and the device keeps the previously-installed channel — so the listener
captures a STALE run (e.g. an old `pass=97` while the new build never ran). When
adjudicating a batch of uncertain constructs, probe the raw `plugin_install` HTTP
response for `compile error &hXX) in pkg:/…(line)` — it names the first offending
file+line. Neutralize it, re-probe, repeat until `Install Success`; that
enumerates the full device-rejected set. Then a clean run
(`##SPEC## event=run-end … fail=0`) over telnet 8085 confirms the remaining
constructs both compile AND behave as specified (this surfaced facts 11–13 as
runtime FAILs, distinct from the compile rejections 5–9).

## Runtime observations (not grammar facts)

Device runtime *semantics* that changed the **harness**, not the EBNF. Recorded
here so the next person doesn't re-debug them.

- **Container access returns BOXED scalars.** Index (`a[i]`), member (`aa.k`),
  optional chaining (`?.` / `?[`), `@attr`, and CreateObject-component reads
  return **boxed** scalars (`roInteger` / `roString` / `roBoolean`), not the
  intrinsic `Integer` / `String` / `Boolean`. An `=` comparison against an
  intrinsic literal must therefore unbox first. The harness `ValuesEqual`
  (`roku-test-harness/source/framework/TestRunner.brs`) now compares by
  numeric / string / bool **kind** across the box boundary. This produced **10
  false-FAILs** before the fix — the constructs under test were correct; only
  the assertion's equality check was wrong.

## Resolved follow-ups

- **`roArray` field type** — RESOLVED, see Confirmed #4 (the valued-field probe
  settled the earlier inconclusive valueless test).
- **Harness wiring** (was `&h91` "not defined in component's namespace") — RESOLVED:
  the suite now runs in the Main scope (`source/main.brs`) and hands results to
  `MainScene` via a field, so component scripts no longer call `pkg:/source/`
  functions.

## Pipeline status
deploy automation · console capture · `.brs` compile · SceneGraph component load ·
`main` run · **test runner reached** — all **WORKING**, end to end. The harness
now exercises the full taxonomy INCLUDING the standard library: **468/468
device-testable specs PASS** (`##SPEC## event=run-end pass=468 fail=0`) on Roku
OS 15.1.4, with 37 non-device leaves (facts 5–14 reclassified there) held in
`roku-test-harness/corpus/`. `grammar/check_coverage.py` enforces parity between
`coverage.json` and the implemented specs/corpus.
