# CATALOG — angel-roku patterns worth ast-grep rules

The output of the 2026-05-20 pattern-mining pass over `../angel-roku` (6 parallel agents:
team-codified conventions, Roku SDK idioms, codemod/architecture, anti-patterns, SceneGraph XML,
BrighterScript/rooibos). Deduped into ~60 rules across 6 categories. Frequencies are grep-confirmed
on the production tree (`source/`, `components/`, `tests/`; `out/`/`build/` excluded).

**Authoring notes apply to every entry — read [README.md](README.md) "Cross-cutting caveats" first**
(metavariable sigil, case-insensitivity for rewrites, no arithmetic, relational needs, confirm node
fields). `kind`s referenced are from `grammar/coverage.json`. Each rule becomes one
`rules/<id>.yml` plus rule-tests and a mimicking-corpus snippet.

Legend — **Cat**: lint / search / rewrite. **Sev**: error / warn / info. **Needs**: today (runs on
built grammar) · rel (relational/companion-script) · bs05 (needs BrighterScript grammar, roadmap/05).

---

## A. Team-codified rules (bslint.json + .cursor/rules + brightscript-expertise skill)

Most defensible — the team already enforces these (or codified them). bslint's `ignores`
(`source/**`, `components/datadog/**`, `components/app/tasks/**`, `components/purchases/**`,
`components/app/controllers/IAP/**`, `**/*.spec.bs`) are where violations concentrate.

| id | Cat | Sev | Matches | Evidence (freq) | Sketch / Needs |
|----|-----|-----|---------|-----------------|----------------|
| `no-stop` | lint | error | bare `stop` statement | 0 live (guard); covers bslint-ignored trees | `kind: StopStatement` · today |
| `condition-style-no-group` | rewrite | warn | `if`/`while` whose **whole** condition is a single `ParenExpr` | 104 (datadog) e.g. `WriterTask.brs:31 while (true)` | `kind: IfStatement, has:{field:condition, kind:ParenExpr}` → unwrap · today |
| `block-if-no-trailing-then` | rewrite | warn | multi-line `if` ending in `then` | 58 e.g. `PurchasesTask.brs:2` | strip trailing `then` from `BlockIf` · today |
| `inline-if-requires-then` | rewrite | warn | single-line `if` missing `then` | 0 live (guard) | `kind: SingleLineIf` w/o `then` token · today |
| `param-missing-type-annotation` | lint | error | `Parameter` with no `as Type` | `SegmentAnalyticsTask.brs:53 sub handleEvent(data)` | `kind:Parameter, not:{has:{kind:Type}}` · today (bslint `type-annotations:all`) |
| `no-manual-font-node` | rewrite | warn | `CreateObject("roSGNode","Font")` | 0 live (skill anti-pattern) | `CreateObject("roSGNode","Font")` → `fontToken(...)` · today |
| `no-font-node-in-xml` | lint | warn | `<Font>` element outside `Typography.xml` | 29, all in Typography.xml (the sanctioned exception) | scenegraph `NodeName ^Font$`; exclude Typography.xml via `files:` |
| `no-visual-props-in-xml` | lint | warn | `width`/`height`/`color`/`translation`/`opacity` attr on XML node | `TheaterGrid.xml:17`, `CarouselTile.xml:17` (2 left) | scenegraph `NodeAttribute name ∈ {…}` |
| `dimension-divisible-by-3` | rewrite | warn | dimension literal (`width`/`height`/`loadWidth`…) not ÷3 | **124** e.g. `DiscoveryOptimizedController.brs:102 width:1280` | AAEntry key∈dims + `IntegerLiteral`; **÷3 needs companion script** · rel |
| `no-alpha-suffix-hex-color` | lint | warn | 8-digit `"0xRRGGBBAA"` color on CTAButton | 72 e.g. `PlanUpdateController.brs:102` | `StringLiteral regex ^"0x[0-9a-fA-F]{8}"$`; scope to CTAButton · today |
| `no-parsejson-in-controller` | lint | warn | `ParseJson(...)` inside controller/view | 5 e.g. `CreateAccountController.brs:375` | `pattern: ParseJson($X)` + `files: controllers/views` · today |
| `network-response-success-check` | lint | warn | `response.parsed` read not guarded by `response.success` | clean pattern at `WatchlistController.brs:123-128` | `MemberSuffix .parsed` not `inside` success-guard · rel |
| `no-raw-string-state-comparison` | lint | warn | `m.state = "literal"` instead of `m.states.*` | 0 live (guard) | `pattern: m.state = $S` + `$S:{kind:StringLiteral}` · today |
| `setfocus-outside-setstate` | search | info | `.setFocus(true)` not inside `setState()` | many (ForgotPasswordController 5, …) | `$X.setFocus(true)` + `not inside setState` · today (best-effort) |
| `unsafe-iterator-mutation` | lint | error | mutating the collection inside `for each` over it | concentrated in ignored `tasks/` | `ForEachStatement($C)` has `$C.push/.delete` · today (bslint `unsafe-iterators`) |

Reserved-word-as-identifier guard (`type`/`tab`/`step`/`line`…) is an honorable mention
(`kind:Parameter` name∈reserved-set; clean today, strong guard).

---

## B. Roku SDK / SceneGraph idiom search rules (navigation + safe-usage)

| id | Cat | Sev | Matches | Evidence (freq) | Sketch / Needs |
|----|-----|-----|---------|-----------------|----------------|
| `find-node-by-id` | search | hint | `m.top.findNode("id")` | **420** | `m.top.findNode($ID)`, `$ID:StringLiteral` · today |
| `create-sgnode` | search | hint | `CreateObject("roSGNode","X")` | 388 (ContentNode 48) | `kind:CreateObjectCall` has `"roSGNode"` · today |
| `observe-field-with-handler` | search/lint | warn | `observeField("f","handler")` (string handler) | 342 | `$N.observeField($F,$H)`, `$H:StringLiteral` (handler should exist → rel) |
| `observe-without-unobserve` | lint | warn | component observes with no matching unobserve | 475 obs vs 164 unobs | per-file balance · rel |
| `callfunc-invocation` | search | hint | `$node.callfunc("api",args)` | 38 | `$N.callfunc($NAME,$$$A)` · today (name exists → rel) |
| `task-node-setup` | search | hint | `m.top.functionName="loop"` + `m.top.control="RUN"` | 13 / 26 | `m.top.functionName=$FN` · today |
| `message-port-busy-wait` | lint | warn | `wait(0, port)` (busy poll) | 8 | `pattern: wait(0, $PORT)` · today |
| `create-message-port` | search | hint | `CreateObject("roMessagePort")` | 24 | `CreateObjectCall` has `"roMessagePort"` · today |
| `global-addfields` | search | hint | `m.global.addFields({...})` | 31 | `m.global.addFields($AA)` · today |
| `event-getdata` | search | hint | `event.getData()` in handlers | 27 | `$EVT.getData()` · today |
| `url-transfer-no-cert` | lint | warn | `roUrlTransfer` without `SetCertificatesFile` | 4+ files; correct at `NetworkClient.brs:32` | `$X=CreateObject("roUrlTransfer")` `not has` SetCertificatesFile · today |
| `create-child` | search | hint | `$parent.createChild("X")` | 50 | `$P.createChild($T)` · today |
| `deviceinfo-query` | search | hint | `roDeviceInfo` / `GetRandomUUID`/`GetRIDA` reads | 36 | any of CreateObject roDeviceInfo / `$D.GetRandomUUID()` · today |

Honorable mentions: `roRegistrySection` write-then-`Flush` balance (13); `roTimespan` `Mark()`→
`TotalMilliseconds()` duration idiom (7).

---

## C. Codemod / rewrite rules (autofix; several from real git history)

Highest-confidence rewrites first — house helpers already exist (`create`, `find`, `isEmptyString`,
`isValid` at `source/utils/utils.brs`).

| id | Cat | Matches → Fix | Evidence (freq) | Needs |
|----|-----|---------------|-----------------|-------|
| `createobject-rosgnode-to-create` | rewrite | `CreateObject("roSGNode",$N)` → `create($N)` | 419 raw vs 340 `create()` (`utils.brs:333`) | today |
| `findnode-to-find` | rewrite | `m.top.findNode($ID)` → `find($ID)` | 421 raw vs 781 `find()` (`utils.brs:340`) | today |
| `isvalid-empty-to-isemptystring` | rewrite | `isValid($X) and $X <> ""` → `not isEmptyString($X)` | **70** (`utils.brs:461`) | today (mind same-node `$X`, case-fold `and`) |
| `invalid-compare-to-isvalid` | rewrite | `$X <> invalid` → `isValid($X)` (correctness: also catches uninitialized) | 69 (28 on `.field`) | today; **gate to `IfStatement` context** (don't touch `= invalid as dynamic` defaults) |
| `cloudinary-unsharp-mask` | rewrite | `imageParams += "q_auto"` → `…"q_auto,e_unsharp_mask:100"` | real migration sha `19ca2069` (`utils.brs:130,219`) | today |
| `strip-ages-prefix` | rewrite | `$LBL.text = "Ages " + $R` → `$LBL.text = $R` | real migration sha `a4a3c046` | today |
| `createobject-case-normalize` | rewrite | `createObject(...)` → `CreateObject(...)` | 73 lowercase vs 518 | today **iff** raw token preserved (case caveat) |
| `parsejson-case-normalize` | rewrite | `ParseJSON`/`parseJson`/`parseJSON` → `ParseJson`; `formatjson`→`FormatJSON` | ParseJSON 22, parseJson 3…; formatjson 29 | today (case caveat) — one sibling rule per spelling |
| `getglobalaa-to-mglobal` | rewrite | `GetGlobalAA().global.$F` → `m.global.$F` | 22 | today (only where `m` in scope) |

Structural **search** companions (no fix; locate the shape): `network-request-run-idiom`
(`CreateObject("roSGNode","NetworkRequest")` … `.control="RUN"`, 83×, candidate to extract a
`api_fireRequest` helper); `contentnode-createchild-update` (`createChild("ContentNode")` then
`.update($D,true)`, 49×); `requestbuilder-pure-aa-shape` (`build*Request` returns a pure
`requestType/requestUrl/headers` AA — lint impurity: no `CreateObject`/`m.top`); `getpropertyvalue-default`
(`utils_getPropertyValue($O?.path, $D)`, **1892×** — the house safe-read; lint bare deep reads).

---

## D. Anti-pattern / bug-class lint rules

Big advantage of the AST approach: kind-based matching (`PrintStatement`, `StopStatement`,
`Comment`) avoids the false positives that plague grep (the word in strings/comments/identifiers),
and covers the trees bslint `ignores`.

| id | Cat | Sev | Matches | Evidence (freq) | Needs |
|----|-----|-----|---------|-----------------|-------|
| `no-leftover-print` | lint | warn | `print` / `?` debug statement in shipped code | **~299** (34 in render layer) | today (`kind:PrintStatement`; no autofix — single-line-if risk) |
| `unsafe-count-loop` | lint | warn | `for i=0 to $C.count()-1` without isValid guard | 90 | today (`ForStatement` has `$C.count()`, not inside isValid) |
| `stringly-typed-type-check` | lint | warn | `Type(x) = "roInt"` literal compare | 19 (smoking gun `KochavaSdkTask.brs:1202`) | today |
| `magic-hex-color` | lint | info | hex color literal (`0x…`/`"0x…"`) | 214 (`"0x000000"`×26) | today (supersedes/peers `no-alpha-suffix-hex-color`) |
| `invalid-compare-prefer-isvalid` | lint | info | `x <> invalid` / `x = invalid` in conditions | ~673 (excl. 473 defaults) | today (peer of rewrite `invalid-compare-to-isvalid`) |
| `stringly-findnode` | lint | info | `findNode("literalId")` | 453 | today (peer of `find-node-by-id`) |
| `parsejson-unguarded` | lint | warn | `ParseJson(...)` then deref without isValid/`?.` | 37 | today (`follows` guard) |
| `sleep-outside-task` | lint | error | `Sleep(ms)` outside a `*Task` file | 5 (all in Tasks today → guard) | today (+ `files:` exclude `*Task.brs`) |
| `dynamic-dispatch-unchecked` | lint | warn | `m[expr](...)` dynamic dispatch | 4 (`Purchases.brs:952`) | today |
| `magic-createobject-type` | lint | info | `CreateObject("…")` literal type | ~110 | today |
| `stringly-observefield` | lint | info | `observeField("f","cb")` string names | 344 | today (peer of `observe-field-with-handler`) |
| `deep-non-optional-chain` | lint | info | `a.b.c.d` (3+ members, no `?.`) | dozens (`ContentfulApiRequests.brs:13`) | today |
| `index-access-no-guard` | lint | warn | `arr[i].field` without isValid | ~90 (`ParseSearch.brs:21-24`) | today |
| `no-debug-marker-in-shipped` | lint | info | `TODO`/`FIXME`/`HACK`/`XXX` in a `Comment` | 46 | today (`kind:Comment` regex) |

Confirmed-clean (so build as **guards** only, with synthetic positives): no `eval(`, no `Run(`, no
bare `stop`, no empty `catch`.

---

## E. SceneGraph XML rules

| id | Cat | Sev | Matches | Evidence (freq) | Needs |
|----|-----|-----|---------|-----------------|-------|
| `field-type-canonical-case` | lint/rewrite | warn | `<field type="String"/Boolean/int/...>` non-canonical; `str` alias is a **bug** | 37 (DEVICE_FACTS #11) | today (`FieldTypeAttValue` regex; case-fold; `str`→`string`) |
| `script-uri-must-be-pkg-absolute` | lint/rewrite | warn | `<script uri="Foo.brs">` relative (no `pkg:/`) | 122 of 411 | today |
| `onchange-handler-must-exist` | lint | warn | `<field onChange="h">` where `h` not defined in attached scripts | 272 | **rel (cross-language)** |
| `onchange-without-alwaysnotify` | lint | info | `onChange=` without `alwaysNotify="true"` | 39 (vs 233 paired) | today |
| `field-value-on-nonscalar-type` | lint | warn | `value=` default on `assocarray`/`array`/`node` | 10 | today |
| `inline-script-must-be-cdata` | lint | error | bare inline `<script>` text (never executes) | DEVICE_FACTS #12 | today (`kind:ScriptText` vs `ScriptCData`) |
| `stringarray-elements-must-be-quoted` | lint | error | `stringarray` value `[a,b]` unquoted | guard (DEVICE_FACTS #3; in negative corpus) | today |
| `component-name-matches-filename` | lint | info | `<component name="X">` ≠ filename | 14 (allowlist `datadogroku_*`) | **rel (needs filename)** |
| `script-before-interface-ordering` | lint | info | `<interface>` before first `<script>` | 17 of 155 | today (`precedes`/`follows`) |
| `color-init-hex-format` | lint | warn | color attr `#RRGGBB` not `0x…` | guard (33/33 correct today) | today |
| `animation-interpolator-target` | search | hint | `fieldToInterp="id.field"` → id exists in `<children>` | 62 | **rel** |
| `xsi-schema-namespace-consistency` | lint | warn | `xsi:` attr without `xmlns:xsi` | 14 | today |

Secondary: `<customization>` Instant-Resume handlers (`MainScene.xml:101`, 1 file — matches as
`GenericElement`, handler-exists is rel); `alias=` (3, too rare); `initialFocus`/`role=` (0 — skip).

---

## F. BrighterScript / rooibos rules  (need roadmap/05 grammar unless noted)

| id | Cat | Sev | Matches | Evidence (freq) | Needs |
|----|-----|-----|---------|-----------------|-------|
| `rooibos-assert-true-equality` | rewrite | warn | `m.assertTrue($A = $B)` → `m.assertEqual($A,$B)` | 15+ (`SideMenuLogic.spec.bs:14`) | **today on transpiled .brs** |
| `rooibos-assert-eq-invalid` | rewrite | info | `m.assertEqual($X, invalid)` → `m.assertInvalid($X)` | rare | today on .brs |
| `bs-namespaced-call-reference` | search | — | `tests.$FN(...)` / `m.$FN(...)` qualified refs | building block | `tests.` form bs05; `m.` form today |
| `rooibos-focus-skip-leak` | lint | error | `@only`/`@ignore`/`@tags("fixme")` committed | 1 fixme (`CarouselMeta.spec.bs:3`) | bs05 (annotations stripped on transpile) |
| `bs-missing-field-type-annotation` | lint | warn | class field without `as Type` | 28/28 | bs05 |
| `rooibos-duplicate-it-description` | lint | warn | two `@it("X")` same text in a class | 12 files | bs05 + rel |
| `rooibos-it-outside-describe` | lint | warn | `@it` not under a `@describe` | guard (1757/1757) | bs05 + rel |
| `rooibos-suite-required` | lint | warn | `class … extends *.BaseTestSuite` w/o `@suite` | guard (46/46) | bs05 |
| `bs-test-suite-extends-project-base` | lint | info | `extends rooibos.BaseTestSuite` directly | 12 (`tests/specs/`) | bs05 |
| `bs-lifecycle-hook-must-call-super` | lint | warn | `override beforeEach()` without `super.beforeEach()` | 14/16 chain | bs05 |
| `rooibos-test-body-name-underscore` | lint | info | `@it` body not `function _()` | guard (1757/1757) | bs05 + rel |

Grammar kinds these assume `brighterscript.ebnf` will provide: `Annotation` (with string-arg
capture), `Class`/`extends`/dotted-name, `field_declaration` (+`as Type` slot), method modifiers +
`override`, `super` call. All are in roadmap/05's Phase-1 subset.

---

## Priority (build-first picks across categories)

1. **A (team-codified)** — `no-stop`, `param-missing-type-annotation`, `unsafe-iterator-mutation`,
   `condition-style-no-group`, `block-if-no-trailing-then` (defensible; the team already enforces).
2. **D high-frequency** — `no-leftover-print` (~299), `unsafe-count-loop` (90), `magic-hex-color`
   (214), `parsejson-unguarded`.
3. **C grounded rewrites** — `createobject-rosgnode-to-create`, `findnode-to-find`,
   `isvalid-empty-to-isemptystring` (70), the two historical migrations (`cloudinary-unsharp-mask`,
   `strip-ages-prefix`) — exact before/after known, perfect autofix demos.
4. **E device-grounded** — `inline-script-must-be-cdata`, `stringarray-elements-must-be-quoted`,
   `field-type-canonical-case` (`str`) — backed by DEVICE_FACTS.
5. **B search** — `find-node-by-id`, `observe-field-with-handler`, `create-sgnode` (codebase
   navigation; high frequency).
6. **F** after roadmap/05; **rel** rules last.
