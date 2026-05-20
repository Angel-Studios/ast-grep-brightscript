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

General rule learned: a SceneGraph field's **type is validated only when a
`value` is present** (the device attempts the string→type conversion then).

## Resolved follow-ups

- **`roArray` field type** — RESOLVED, see Confirmed #4 (the valued-field probe
  settled the earlier inconclusive valueless test).
- **Harness wiring** (was `&h91` "not defined in component's namespace") — RESOLVED:
  the suite now runs in the Main scope (`source/main.brs`) and hands results to
  `MainScene` via a field, so component scripts no longer call `pkg:/source/`
  functions.

## Pipeline status
deploy automation · console capture · `.brs` compile · SceneGraph component load ·
`main` run — all **WORKING**. Reaching the test runner is blocked only by the
harness-wiring item above.
