# 04 — BrighterScript / rooibos rules

## Goal
Ship the `.bs` rules from CATALOG **F** — rooibos test-hygiene and BrighterScript-specific lints.
Most of these need the BrighterScript ast-grep language, so this phase is **gated on
`roadmap/05`** (BrighterScript support) reaching Phases 5–6 (grammar built + registered + injected).

## Scope (CATALOG ids)
- **Runnable on transpiled `.brs` TODAY (no roadmap/05 needed):** `rooibos-assert-true-equality`
  (autofix), `rooibos-assert-eq-invalid`, and the `m.$FN(...)` half of `bs-namespaced-call-reference`.
  Ship these early as `language: brightscript` rules against the transpiled `out/` form.
- **Need the BrighterScript grammar (roadmap/05 Ph.5–6):** `rooibos-focus-skip-leak` (annotations),
  `bs-missing-field-type-annotation`, `rooibos-suite-required`, `bs-test-suite-extends-project-base`,
  `bs-lifecycle-hook-must-call-super`, and the `tests.$FN(...)` half of `bs-namespaced-call-reference`.
- **Need grammar AND relational logic (also touches Phase 05):** `rooibos-duplicate-it-description`,
  `rooibos-it-outside-describe`, `rooibos-test-body-name-underscore`.

## Steps
1. Ship the transpiled-`.brs`-today subset first (assertion-misuse rewrites) to deliver value before
   roadmap/05 lands; tag them so they can be re-pointed at `language: brighterscript` later.
2. When roadmap/05 Phase 5–6 completes, confirm the BrighterScript node kinds exist
   (`Annotation` w/ string-arg capture, `Class`/`extends`/dotted-name, `field_declaration` +`as`
   slot, method `override`, `super`) — these are exactly roadmap/05's Phase-1 subset.
3. Author the annotation/class/field/override rules as `language: brighterscript`; scope by `extends`
   target (`tests.*` vs `rooibos.*`) to respect the real architectural split (avoids false positives
   on `bs-lifecycle-hook-must-call-super` / `bs-test-suite-extends-project-base`).
4. Tier-2 corpus: reuse the `.bs` exemplars roadmap/05 Phase 3 adds to the harness (namespace/class/
   annotation shapes) so the rule corpus and the grammar corpus share files.

## Acceptance
The transpiled-today subset ships and passes Level-6 independent of roadmap/05. Once roadmap/05
Ph.5–6 is green, the remaining `.bs` rules ship as `language: brighterscript`, with Tier-1 tests +
Tier-2 corpus, and reproduce CATALOG counts on angel-roku's `.bs` (e.g.
`bs-missing-field-type-annotation` 28/28, `rooibos-focus-skip-leak` catches the `CarouselMeta.spec.bs:3`
`fixme`).

## Dependencies
Phase 00; **roadmap/05 Phases 5–6** for the BrighterScript-grammar subset.
