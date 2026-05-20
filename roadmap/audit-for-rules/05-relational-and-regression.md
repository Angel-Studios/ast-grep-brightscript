# 05 — Relational / cross-language rules + regression scan + CI

## Goal
Handle the rules a single stock ast-grep pattern can't express (relational, cross-element,
cross-language, or arithmetic), then lock the whole rule set in as a standing regression against the
real `angel-roku` app and wire it into CI.

## Part A — Relational / advanced rules
These need ast-grep `utils`/`rewriters`, or a companion script over `sg scan --json` (and, for the
cross-language ones, the `<script>` injection that's already registered in `sgconfig.yml`).

| Rule (CATALOG id) | Why it's advanced | Approach |
|---|---|---|
| `onchange-handler-must-exist` (E) | XML `onChange="h"` → `h` must be a sub/function in the attached (sibling/injected) BrightScript | collect handler names from `scenegraph` matches; collect `FunctionDeclaration`/`SubDeclaration` names from injected + sibling `.brs`; diff |
| `component-name-matches-filename` (E) | needs the filename, not in-tree | capture `component name=`; companion script compares to basename (allowlist `datadogroku_*`) |
| `animation-interpolator-target` (E) | `fieldToInterp="id.field"` → `id` must exist in `<children>` | capture target id; resolve against sibling `NodeAttribute id="…"` |
| `observe-without-unobserve` (B) | per-component balance, not a single node | count `observeField*` vs `unobserveField*` per file |
| `network-response-success-check` (A) | `.parsed` read must be dominated by a `.success` guard | `inside`/`follows` an `if response.success` |
| `dimension-divisible-by-3` (A) | ast-grep has no `% 3` | capture dimension literal; companion script checks ÷3 (and can autofix to nearest) |
| `rooibos-duplicate-it-description` / `-it-outside-describe` / `-test-body-name-underscore` (F) | sibling-uniqueness / grouping over annotations | bs05 grammar + companion uniqueness/grouping check |

Decide per-rule: native `utils` if expressible, else a small `scripts/rules-relational.*` that
consumes `sg scan --json`. Each still gets Tier-1/Tier-2 cases and a Level-6 assertion.

## Part B — Regression scan over angel-roku
- A script (`scripts/scan-angel-roku.*`) runs the full rule set over `../angel-roku` and emits a
  per-rule match count + sample locations.
- Snapshot the expected counts from the CATALOG (the mined frequencies are the baseline) and assert
  the scan stays within tolerance — this is the real-world regression that catches grammar/rule
  drift far better than synthetic corpus alone. (Path to angel-roku is configurable / skipped
  gracefully when the peer repo isn't present, like the device gate.)

## Part C — CI integration
- Fold Level-6 (`ast-grep test` + corpus assertions) into the repo's CI alongside gates 0–5.
- Document the rule-authoring + testing workflow in `rules/README.md` and link it from
  `grammar/CLAUDE.md` and the root `CLAUDE.md` repository map.

## Acceptance
Every relational rule is implemented (native or companion-script) with tests; the angel-roku
regression scan reproduces the CATALOG baselines within tolerance and runs in CI; Level-6 is green
and part of the standard gate set; `rules/` is documented.

## Dependencies
Phases 01–04 (the rules being scanned); roadmap/05 for the BrighterScript relational rules.
