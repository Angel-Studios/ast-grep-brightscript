# 01 — Expand harness coverage to the full taxonomy

## Goal
Implement every **device-testable** leaf in `grammar/coverage.json` as a
`##SPEC##`-emitting test (currently **97** of ~256 device leaves), and stand up a
**negative corpus** for the leaves that cannot run on-device.

## Context
- `grammar/coverage.json` — 308 leaves: `{id, kind, layer, dimension, snippet, device_testable, expect}`.
- `roku-test-harness/source/tests/*.brs` — the current 97 specs; each opens a spec
  with `t.spec(id, kind, desc)` then makes assertions. Framework:
  `roku-test-harness/source/framework/TestRunner.brs`.
- The dev installer **compiles the whole channel**; a single invalid construct
  fails the build (see `grammar/DEVICE_FACTS.md`). So device-invalid /
  ERROR-expecting cases must **not** be compiled into the channel.

## Steps
1. **Gap report.** Script the diff of implemented `t.spec` ids vs `coverage.json`
   ids where `device_testable=true`. Emit the missing ids grouped by layer/area.
2. **BrightScript leaves.** For each missing device leaf, add a spec to the
   matching `test_*.brs` (or a new module): exercise the `snippet`, assert
   `expect` (`value:X`). Keep `id`/`kind` **exactly** matching `coverage.json`.
3. **SceneGraph leaves (~70).** Extend `components/SpecShowcase.xml` so every
   `FieldType` has a **value** (types are only validated when valued —
   DEVICE_FACTS), plus component-creation / `role=` / `alias=` / `onChange` /
   `alwaysNotify` / inline-vs-uri `<script>` / `<children>` cases. Decide how SG
   results emit `##SPEC##` (e.g. `main.brs` inspects the created scene's
   nodes/fields and emits, or a component `callFunc` returns status to Main).
4. **Negative corpus.** Create `roku-test-harness/corpus/negative/` (NOT in the
   manifest `files`, NOT compiled) holding the device-rejected snippets
   (`#if and/or/not`, leading `let`, unquoted `stringarray`, …) — one file per
   negative leaf, tagged with its id — for plan 03 to assert ERROR nodes.
5. **Loop.** Per batch: add specs → `npm run roku:deploy` → listener → fix until
   `run-end` shows `fail=0`. Use the ECP screenshot to sanity-check the boot-log.
6. **Parity check.** Add `grammar/check_coverage.py`: assert every
   `device_testable` `coverage.json` id is implemented (scan `t.spec(...)` calls
   or a captured run). Wire it into the validation levels in `grammar/CLAUDE.md`.

## Acceptance
- Every `device_testable` id in `coverage.json` has an implemented spec; a device
  run reports them all PASS (`run-end fail=0`).
- `corpus/negative/` covers every `negative` / non-device leaf.
- `check_coverage.py` is green.

## Status: COMPLETE + STDLIB (device-validated on Roku OS 15.1.4)

**Latest: `run-end pass=468 fail=0`** — the harness now also covers the BrightScript
**standard library** (a `layer:"stdlib"` taxonomy in `coverage.json`, 191 leaves):
global string/math/utility/JSON functions, `roArray`/`roList`/`roByteArray`,
`roAssociativeArray` + boxed intrinsics, `roString`, `roDateTime`/`roTimespan`/
`roRegex`, and `roDeviceInfo`/`roAppInfo`/`roRegistry`/`roFileSystem`. Each stdlib
spec is `try/catch`-guarded so a device-rejected API FAILs only itself. The device
loop surfaced more facts (DEVICE_FACTS #14–#17): grouping-paren newline rejected;
`CreateObject("roInt",v)` ignores the value (use `box(v)`); the ifString `Mid`
method is 0-indexed (global `Mid()` is 1-indexed); `roTimespan.Mark()` returns void.
An **EBNF completeness audit** vs the official Roku docs found **no structural
grammar gaps** (only minor documentary nitpicks; BrighterScript-only constructs
correctly excluded). Totals: 468 device-testable specs, 37 non-device corpus leaves.

### Original language milestone (below) — also COMPLETE

- **Key drift eliminated.** The old divergent `t.spec` id scheme was dropped;
  every spec id/kind now matches `coverage.json` exactly. Test modules are keyed
  by coverage prefix: `test_lex / test_decl / test_cc / test_stmt /
  test_expr_ops / test_expr_values` (+ `test_scenegraph`).
- **Device run: `##SPEC## event=run-end pass=274 fail=0`** — all 274
  device-testable leaves PASS on hardware. (The full 280 found 6 constructs the
  device actually REJECTS; see below.)
- **SceneGraph** (56→55 device leaves): exercised via `SpecShowcase.xml` + helper
  components (`SpecHelperTask/Extends/InlineText.xml`); `main.brs` runs
  `test_scenegraph_all(t, scene, showcase)` against the live nodes after
  `screen.show()` and folds results into the one `##SPEC##` stream.
- **Negative corpus** (`roku-test-harness/corpus/`, excluded from the zip +
  bsconfig): 34 non-device leaves = 28 original + **6 newly device-rejected**
  found by the loop — `decl.function.nested`, `decl.type.interface`,
  `decl.type.custom`, `stmt.dim.paren`, `stmt.expr.optcall`,
  `sg.field.type.str_alias` (see `grammar/DEVICE_FACTS.md` #5–#13).
- **`grammar/check_coverage.py`** added and GREEN (parity of coverage.json ↔
  specs/corpus, incl. kind match); wired into `grammar/CLAUDE.md`'s validation
  levels.
- **bsc drift** captured in `grammar/BSC_DRIFT.md` (e.g. `next i` is device-valid
  but bsc rejects it; `o.fn?()` / `type="str"` are bsc-accepted but
  device-rejected).
