# Roku BrightScript / SceneGraph Spec Harness

A runnable Roku SceneGraph channel that is simultaneously:

1. **A self-validating unit-test harness.** On launch `source/main.brs` runs an
   in-process BrightScript test suite (assert-based) in the Main/global scope,
   emits a structured `##SPEC##` result line per construct to the debug console
   (consumed by `../roku-listener/`), and hands the results to `MainScene`, which
   renders them as a terse, server-boot-log style view — one
   `[ ok ]` / `[FAIL] <spec.id>` line per spec (green pass / red fail) in the
   bundled **Ubuntu Mono** font, packed into columns under an `n ok  n fail
   (m specs)` summary. Sideload it onto a real Roku and read the result both off
   the TV and off the debug console.
2. **A comprehensive language corpus.** The BrightScript and SceneGraph here are
   intentionally exhaustive: they exercise (nearly) every construct of the two
   sibling grammars in `../grammar/brightscript.ebnf` and
   `../grammar/scenegraph.ebnf` so the files can later drive **ast-grep** pattern
   testing (see `../.claude/skills/ast-grep-custom-language/SKILL.md`).

## The `##SPEC##` result protocol (debug console)

The suite is driven from `source/main.brs` (the Main scope), NOT from the
SceneGraph component scripts — SceneGraph component scripts cannot see
`pkg:/source/**` functions (`&h91 Function is not defined in component's
namespace`; see `../grammar/DEVICE_FACTS.md`). Main runs the suite, prints the
protocol, then shows the scene and passes it the pre-computed results via the
`specResults` field for on-screen rendering.

Each construct group registers a stable dotted **id** and an EBNF rule **kind**
via `t.spec(id, kind, description)` in the test modules; every assertion made
while that spec is open rolls up into ONE result (PASS if all its assertions
passed). The framework (`source/framework/TestRunner.brs`) prints, one per line:

```
##SPEC## event=run-start total=<N>
##SPEC## v=1 id=<dotted.id> kind=<EBNFRuleName> status=PASS
##SPEC## v=1 id=<dotted.id> kind=<EBNFRuleName> status=FAIL detail="<first failure>"
##SPEC## event=run-end pass=<N> fail=<N>
```

`detail` is only emitted on FAIL (double-quoted, with `\"`/`\\` escaped and
newlines flattened). This is the exact wire format parsed by
`../roku-listener/src/parser.ts`. Capture it with `telnet <roku-ip> 8085` or run
the listener.

> NOTE: This harness has been **run on real hardware** — Roku Streaming Stick 4K,
> Roku OS 15.1.4 — and currently reports **97/97 PASS**. Device-confirmed language
> facts (and the handful of constructs the device rejected) are logged in
> `../grammar/DEVICE_FACTS.md`.

## Directory layout

```
roku-test-harness/
├── manifest                  # Roku channel manifest (version, icons, splash, bs_const)
├── bsconfig.json             # brighterscript (bsc) config for `npm run check` (diagnostics, no packaging)
├── README.md                 # this file
├── fonts/
│   └── UbuntuMono-Regular.ttf  # bundled monospace font used by the boot-log UI
├── images/
│   └── README.md             # required artwork sizes (real PNGs must be supplied)
├── source/
│   ├── main.brs              # sub Main(): RUNS the suite + emits ##SPEC##, then roSGScreen + event loop
│   ├── framework/
│   │   └── TestRunner.brs    # assert/test framework, t.spec(id,kind) registration, ##SPEC## emission, box-aware ValuesEqual
│   └── tests/
│       ├── TestSuite.brs     # aggregates the test modules; TestSuite_Run() runs them all
│       └── test_*.brs        # one module per spec area (literals, operators, control flow, types, …)
└── components/
    ├── MainScene.xml / .brs      # root Scene: renders the boot-log from the `specResults` field; OK re-renders
    ├── SpecShowcase.xml / .brs   # one <field> of (nearly) every field type; alias/onChange/function
    ├── SpecHelper*.xml           # extra component shapes (Task / extends / inline-text) for XML coverage
    └── ResultRow.xml / .brs      # LEGACY (old MarkupList UI); unused by the current boot-log render
```

## How to deploy

Deployment is automated by `../scripts/roku-deploy.ts` (Bun), run from the repo
root via the `roku:*` npm scripts. The full `deploy` packages the channel
(`manifest` at the zip root → `out/harness.zip`), sideloads it over the dev
installer with HTTP digest auth, and launches it via ECP.

1. **Enable Developer Mode on the Roku.** On the remote press
   `Home Home Home Up Up Right Left Right Left Right`, accept the agreement, set a
   developer password, and note the device IP. The device now serves the
   **Development Application Installer** at `http://<roku-ip>` and the BrightScript
   debug console on telnet **8085**.

2. **Configure the device** (once). From the repo root copy the env template and
   fill in your values:

   ```sh
   cp .env.example .env
   # ROKU_HOST=<roku-ip>   ROKU_DEV_USER=rokudev   ROKU_DEV_PASS=<dev-password>
   ```

3. **Deploy.** From the repo root:

   ```sh
   npm run roku:deploy      # package → sideload (Replace) → ECP launch (/launch/dev)
   ```

   The sub-steps are also exposed individually: `roku:zip`, `roku:install`,
   `roku:launch`, `roku:delete`. The dev installer **compiles on upload**, so a
   sideload failure here is real device feedback (a construct the device rejected),
   not just a packaging error — that is how the entries in
   `../grammar/DEVICE_FACTS.md` were found.

A compile-only check that needs **no device**: `npm run check` runs BrighterScript
(`bsc`) over the harness sources.

## Reading the results

**On the TV.** `MainScene` renders a terse boot-log: a title, an
`n ok  n fail  (m specs)` **summary** (green when all pass, red if any fail), and
one `[ ok ]` / `[FAIL] <spec.id>` row per spec laid out in columns that fill down
to the bottom of the screen and then wrap to a new column on the right. A failed
row appends its `detail` after the id. Press **OK** to re-render. Colors: green
`0x6FCF6FFF`, red `0xE05555FF` (RGBA `0xRRGGBBAA`).

**On the debug console.** The same run prints the machine-readable `##SPEC##`
protocol (above), framed by `run-start` / `run-end`. Capture it raw with
`telnet <roku-ip> 8085`, or — better — run the listener, which parses the stream
into a JSON report plus a human summary and exits non-zero on any failure:

```sh
bun run --cwd ../roku-listener listen     # live device; or `replay <logfile>` with no device
```

That stream is the ground truth consumed by `../roku-listener/` — see its
`README.md` for the protocol grammar and parsing rules.

**Screenshot the TV over the network (ECP).** To grab the rendered boot-log
without pointing a camera at the screen, ask the dev installer to capture a
screenshot (it writes `/pkgs/dev.jpg` on the device), then download it:

```sh
# 1) capture  → /pkgs/dev.jpg on the device
curl -s --user "rokudev:<dev-password>" --digest \
  -F 'mysubmit=Screenshot' -F 'archive=' -F 'passwd=' \
  "http://<roku-ip>/plugin_inspect"
# 2) download it
curl -s --user "rokudev:<dev-password>" --digest \
  "http://<roku-ip>/pkgs/dev.jpg" -o dev.jpg
```

## Images

The `manifest` references launcher icons and splash screens under `images/`.
Real PNG assets are NOT included (they cannot be generated here). See
`images/README.md` for the exact filenames and pixel sizes you must supply. The
channel will still install and run without them; only the launcher tile and
splash will be blank.

## Why the code looks exhaustive

This is deliberate. Every test module is organized by spec area and favors
**breadth of construct coverage** over deep functionality, while still making
genuine assertions that report real pass/fail. The SceneGraph components cover
the XML element/attribute/field-type surface. Together they form a corpus that an
ast-grep custom-language setup (built from the sibling tree-sitter grammar) can
match patterns against. The construct-coverage taxonomy and per-rule status live
in `../grammar/COVERAGE.md` (data in `../grammar/coverage.json`).
```
