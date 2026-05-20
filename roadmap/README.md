# Roadmap

Plans for taking **ast-grep-brightscript** from "device-validated groundwork" to a
working tree-sitter grammar + ast-grep custom language. Each file is a
self-contained, executable plan: **goal · context · steps · acceptance**.

## Where we are now

The self-improving loop is operational:
- **EBNF specs** (`grammar/brightscript.ebnf`, `grammar/scenegraph.ebnf`), device-corrected.
- **Coverage taxonomy** (`grammar/coverage.json` + `COVERAGE.md`) — 308 leaves, exhaustive over each construct's *dimensionality*; every leaf has an `id` + `kind` (the EBNF rule name).
- **Runnable Roku harness** emitting the `##SPEC##` protocol — 97 specs, **97/97 PASS** on Roku OS 15.1.4 — rendered as a terse Ubuntu-Mono boot-log.
- **One-command deploy** (`npm run roku:deploy`) and a **Bun+Effect listener** (`roku-listener/`).
- Four device facts confirmed in `grammar/DEVICE_FACTS.md`.

## Plans

| # | Plan | Effort | Depends on | Why |
|---|------|--------|-----------|-----|
| 01 | [Expand harness coverage](01-expand-coverage.md) | large | `coverage.json` | exhaustive device truth; builds 03's corpus |
| 02 | [Resolve roArray](02-resolve-roarray.md) | ✅ done | — | resolved: roArray is device-valid (DEVICE_FACTS #4) |
| 03 | [Tree-sitter grammar + ast-grep](03-tree-sitter-grammar.md) | large | 01, EBNF | the actual end goal |
| 04 | [Housekeeping](04-housekeeping.md) | small | — | doc accuracy |

**Suggested order:** 02 (quick win) → 04 (cheap) → 01 (build the corpus) → 03 (the goal).
01 and the early scaffolding of 03 can proceed in parallel.
