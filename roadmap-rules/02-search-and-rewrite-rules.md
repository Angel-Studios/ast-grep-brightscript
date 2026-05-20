# 02 — Search & rewrite rules (idioms + codemods)

## Goal
Ship the BrightScript **search** rules (codebase navigation / safe-usage; CATALOG **B**) and the
**rewrite/codemod** rules with autofix (CATALOG **C**). Both run on the built BrightScript grammar.
The rewrites are the flagship demonstration that the project can *rewrite* real Roku code.

## Scope (CATALOG ids)
- **B (search):** `find-node-by-id`, `create-sgnode`, `observe-field-with-handler`,
  `callfunc-invocation`, `task-node-setup`, `message-port-busy-wait`, `create-message-port`,
  `global-addfields`, `event-getdata`, `url-transfer-no-cert`, `create-child`, `deviceinfo-query`
  (+ honorable mentions: registry write/Flush, timespan duration).
- **C (rewrite, autofix):** `createobject-rosgnode-to-create`, `findnode-to-find`,
  `isvalid-empty-to-isemptystring`, `invalid-compare-to-isvalid`, `cloudinary-unsharp-mask`,
  `strip-ages-prefix`, `getglobalaa-to-mglobal`, and (case-permitting) `createobject-case-normalize`,
  `parsejson-case-normalize`.
- **C structural search (no fix):** `network-request-run-idiom`, `contentnode-createchild-update`,
  `requestbuilder-pure-aa-shape`, `getpropertyvalue-default`.

## Steps
1. **Rewrites first, by confidence.** Begin with the two historical migrations
   (`cloudinary-unsharp-mask`, `strip-ages-prefix`) — exact before/after is known from git, so the
   Tier-1 `invalid → fixed` snapshot is unambiguous. Then the helper-adoption rewrites
   (`createobject-rosgnode-to-create`, `findnode-to-find`, `isvalid-empty-to-isemptystring`).
2. **Guard the dangerous fixes.** `invalid-compare-to-isvalid` must be scoped to comparison/condition
   context so it never rewrites a default-arg `= invalid as dynamic`; `isvalid-empty-to-isemptystring`
   must bind the same `$X` on both sides; case-fold `and`/`AND`. Prove with negative tests.
3. **Resolve the case-normalization caveat** (from Phase 00.1): only ship
   `createobject-case-normalize` / `parsejson-case-normalize` if the grammar exposes the raw token /
   a callee-text regex constraint. If not, document them as blocked and move on.
4. **Search rules** are mostly single `pattern` + a `StringLiteral` arg constraint — build a shared
   "first/second arg is a string literal" snippet and reuse across `find-node-by-id`,
   `observe-field-with-handler`, `task-node-setup`, `callfunc-invocation`, `create-child`.
5. Every rewrite ships a Tier-1 fix snapshot AND a Tier-2 before/after corpus pair. Run autofixes
   over a *copy* of angel-roku and eyeball the diff as an integration check (don't commit it).

## Acceptance
Search rules in scope match their CATALOG frequencies on angel-roku (spot-check `find-node-by-id`
~420, `observe-field-with-handler` 342). Rewrite rules pass fix snapshots, leave negatives
untouched, and produce a clean diff on the angel-roku copy. All green under Level-6.

## Dependencies
Phase 00 (esp. 0.1 caveats — sigil + raw-token decide several rewrites).
