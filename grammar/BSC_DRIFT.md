# BrighterScript ↔ device drift ledger

Two compilers judge the harness, and they do **not** agree:

- **The Roku device** (`npm run roku:deploy` → the dev installer compiles the
  whole channel; runtime over telnet 8085). This is **ground truth** — see
  [DEVICE_FACTS.md](DEVICE_FACTS.md).
- **BrighterScript** (`bsc`, `npm run check`) — a fast static checker we use as a
  pre-flight gate. It is convenient but **not authoritative**: it is both
  *stricter* (rejects valid device constructs) and *looser* (accepts
  device-rejected ones) than the device.

This file tracks every construct where the two disagree, so a red `bsc` line is
never mistaken for a real device failure (and vice-versa). When you add a
construct and `bsc` and the device disagree, add a row here.

## Drift table

| Construct | coverage id | `bsc` says | Device says | Drift | Reconciliation |
|-----------|-------------|-----------|-------------|-------|----------------|
| `next i` — `next` + counter variable | `stmt.for.next_var` | **REJECT** (BS1039 "Expected newline or ':'", BS1066) | **ACCEPT** (runs; spec PASS) | `bsc` too **strict** | Construct kept (device-valid). `bsc` false-positive suppressed in-source with `' bs:disable-next-line` above the `next i`. |
| `o.fn?()` — optional-call as a bare **statement** | `stmt.expr.optcall` | **ACCEPT** | **REJECT** (compile `&h02`) | `bsc` too **lenient** | Construct is device-invalid → moved to `corpus/negative/`; `coverage.json` `device_testable:false`. (The `?()` call IS valid in *expression* position — `expr.optchain.paren` — which both accept.) |
| `type="str"` — SceneGraph field-type alias | `sg.field.type.str_alias` | **ACCEPT** (no SG field-type semantic check) | **REJECT** (valued `str` field reads `Invalid`) | `bsc` too **lenient** | Device-invalid → `corpus/negative/`; `device_testable:false`. Use `string`. |
| bare (non-CDATA) inline `<script>` execution | `sg.script.inline_text` | **ACCEPT** (cannot model SG runtime) | **TOLERATE but DON'T EXECUTE** (`init()` never runs) | `bsc` can't see runtime | Spec asserts the device-true behaviour (tolerated, body does not run). CDATA / external `uri` scripts DO execute. |

## Not drift (both reject — `bsc` agrees with the device)

These are device-rejected AND `bsc`-rejected, so `bsc` happens to be a correct
early-warning here. They live in `corpus/negative/`; listed so the agreement is
on record (do not "fix" them back into the channel):

- `decl.function.nested` — nested **named** function (device `&h02`, `bsc` BS1136).
- `decl.type.interface` — `as interface` (device `&ha7`, `bsc` BS1044 "invalid type").
- `decl.type.custom` — `as roSGNode` / component type in `as` (device `&ha7`, `bsc` BS1044).
- `stmt.dim.paren` — `dim a(n)` paren bounds (device `&h02`, `bsc` BS1119/BS1120).

## How to read the gates

| Gate | Command | Authority |
|------|---------|-----------|
| static pre-flight | `npm run check` (`bsc`) | advisory — cross-check against this ledger before trusting a red line |
| coverage parity | `python3 grammar/check_coverage.py` | every `coverage.json` leaf has a spec (device) or corpus file (non-device) |
| **ground truth** | `npm run roku:deploy` + `roku-listener` → `##SPEC## … run-end fail=0` | **authoritative** |

Rule of thumb: if `bsc` and the device disagree, **the device wins** and the
disagreement gets a row above. `bsc` green is necessary for a tidy pre-flight but
neither sufficient nor authoritative.
