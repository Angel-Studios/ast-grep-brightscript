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
