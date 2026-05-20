# 03 — SceneGraph XML rules

## Goal
Ship the SceneGraph (`language: scenegraph`) rules from CATALOG **E**. Several are backed by
`DEVICE_FACTS.md`, which makes them the most authoritative rules in the whole set.

## Scope (CATALOG ids)
- **Device-grounded (build first):** `inline-script-must-be-cdata` (DEVICE_FACTS #12 — bare inline
  script never executes), `stringarray-elements-must-be-quoted` (#3 — already in the negative
  corpus), `field-type-canonical-case` (#11 — `str` reads as Invalid).
- **Style / safety:** `script-uri-must-be-pkg-absolute`, `onchange-without-alwaysnotify`,
  `field-value-on-nonscalar-type`, `script-before-interface-ordering`, `color-init-hex-format`,
  `no-font-node-in-xml` (CATALOG A — XML, exclude `Typography.xml`), `no-visual-props-in-xml`
  (CATALOG A), `xsi-schema-namespace-consistency`.

Deferred to Phase 05 (relational/cross-language): `onchange-handler-must-exist`,
`animation-interpolator-target`, `component-name-matches-filename`, `<customization>`-handler-exists.

## Steps
1. Confirm the SceneGraph node fields from Phase 00.1 — especially `Field` attributes (`type`,
   `onChange`, `alwaysNotify`, `value`), `ScriptText` vs `ScriptCData`, `ScriptExternal` `uri`,
   `Component` attributes, `NodeAttribute` name/value. The CATALOG sketches assumed these.
2. Build the device-grounded three first; cross-link each rule's `note` to its `DEVICE_FACTS.md` #.
   Reuse the repo's existing negative corpus (`corpus/negative/sg_*`) as ready-made test cases.
3. `field-type-canonical-case`: detection + a rewrite that case-folds and maps `str`→`string`
   (the `str` fix is correctness, not style — call it out in the message).
4. `no-font-node-in-xml` / `no-visual-props-in-xml`: encode the Typography.xml allowlist via
   `files:`; prove the exception with a negative test.
5. Tier-1 tests use small XML component fragments; Tier-2 corpus adds realistic components mimicking
   angel-roku (e.g. a Task with relative-uri scripts, a field with `onChange` but no `alwaysNotify`).

## Acceptance
All in-scope rules have rules + Tier-1 tests + Tier-2 corpus, pass Level-6, and the device-grounded
rules cite their `DEVICE_FACTS.md` entry. Scanning angel-roku reproduces key counts
(`script-uri-must-be-pkg-absolute` ~122, `onchange-without-alwaysnotify` 39).

## Dependencies
Phase 00.
