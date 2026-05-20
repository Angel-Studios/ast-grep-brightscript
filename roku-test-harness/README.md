# Roku BrightScript / SceneGraph Spec Harness

A runnable Roku SceneGraph channel that is simultaneously:

1. **A self-validating unit-test harness.** On launch `source/main.brs` runs an
   in-process BrightScript test suite (assert-based) in the Main/global scope,
   emits a structured `##SPEC##` result line per construct to the debug console
   (consumed by `../roku-listener/`), and hands the results to `MainScene`, which
   renders every assertion on screen as a GREEN (pass) or RED (fail) row with a
   `PASS n / FAIL n` header. It is meant to be sideloaded onto a real Roku device
   and read both off the TV and off the debug console.
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
`testResults` field for on-screen rendering.

Each construct group registers a stable dotted **id** and an EBNF rule **kind**
via `t.spec(id, kind, description)` in the test modules; every assertion made
while that spec is open rolls up into ONE result (PASS iff all its assertions
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

> NOTE: This channel was authored without access to Roku hardware. It is
> syntactically and structurally complete and reviewed against the grammars and
> Roku conventions, but it has **not been executed or verified on a device**.

## Directory layout

```
roku-test-harness/
├── manifest                         # Roku channel manifest (version, icons, splash, bs_const)
├── README.md                        # this file
├── images/
│   └── README.md                    # required artwork sizes (real PNGs must be supplied)
├── source/
│   ├── main.brs                     # sub Main(): RUNS the suite + emits ##SPEC##, then roSGScreen boilerplate + event loop
│   ├── framework/
│   │   └── TestRunner.brs           # assert/test framework + t.spec(id,kind) registration + ##SPEC## emission
│   └── tests/
│       ├── TestSuite.brs            # aggregates all test functions; 'library'; TestSuite_Run() runs + emits
│       ├── test_literals.brs        # every literal form
│       ├── test_operators.brs       # every operator + compound assign + ++/--
│       ├── test_controlflow.brs     # if/for/while/exit/continue/goto/stop/nesting
│       ├── test_functions.brs       # function/sub, typed/optional params, anon fns, HOFs
│       ├── test_collections.brs     # arrays, dim (multi-dim), assoc arrays
│       ├── test_types.brs           # Type/box/GetInterface/conversions/string fns
│       ├── test_exceptions.brs      # try/catch/throw
│       ├── test_conditional_compilation.brs  # #const, #if/#else if/#else/#end if
│       ├── test_objects.brs         # CreateObject, roDateTime, roDeviceInfo, m-dispatch
│       ├── test_print.brs           # print/?, ',' ';' separators, TAB/POS
│       └── test_misc.brs            # plain assignment, GetGlobalAA, optional chaining, @attr/?@
└── components/
    ├── MainScene.xml                # root Scene; testResults field; external + inline CDATA <script>; <children>
    ├── MainScene.brs                # RENDERS results from the testResults field (does NOT run the suite), key handling
    ├── ResultRow.xml                # custom MarkupList row component (per-row coloring)
    ├── ResultRow.brs                # colors each row GREEN (pass) / RED (fail) from its content
    ├── SpecShowcase.xml             # one <field> of EVERY field type; alias/onChange/function
    └── SpecShowcase.brs             # init + interface functions + onChange observer
```

## How to package & sideload

1. **Enable Developer Mode on the Roku.** On the device remote press:
   `Home Home Home Up Up Right Left Right Left Right`. Accept the agreement, set a
   developer password, and note the device IP shown on screen. The device now
   serves the **Development Application Installer** at `http://<roku-ip>`.

2. **Zip the channel so `manifest` is at the zip ROOT** (do not zip the parent
   folder — the `manifest` file must be the top-level entry):

   ```sh
   cd roku-test-harness
   zip -r ../spec-harness.zip . -x '*.git*'
   ```

3. **Upload it.** Either:
   - Browse to `http://<roku-ip>`, log in (user `rokudev`, your dev password),
     choose the zip under "Upload" / "Replace", and click **Install**; or
   - Use `curl` to form-upload:

     ```sh
     curl -s --user 'rokudev:<password>' --digest \
       -F 'mysubmit=Install' -F 'archive=@../spec-harness.zip' \
       http://<roku-ip>/plugin_install
     ```

4. **Watch the debug console** (optional) for `print` output:

   ```sh
   telnet <roku-ip> 8085
   ```

## Reading the results

When the channel launches, `source/main.brs` runs the suite (printing the
`##SPEC##` protocol to the debug console) and hands the results to `MainScene`,
which shows:

- A **header**: `PASS n / FAIL n  (total m)`. The header is GREEN when all tests
  pass and RED if any fail.
- A **scrolling list** of one row per assertion. Each row is colored GREEN when
  the assertion passed and RED when it failed (rendered by the `ResultRow`
  component); failed rows also show a `[detail]` message after the name. Scroll
  with the remote **Up/Down**; press **OK** to re-render the results.

Colors used: GREEN `0x00FF00FF`, RED `0xFF0000FF` (RGBA `0xRRGGBBAA`).

On the **debug console** (`telnet <roku-ip> 8085`), the same run prints the
machine-readable `##SPEC##` protocol described above, framed by `run-start` /
`run-end` events. That stream is the ground truth consumed by `../roku-listener/`.

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
match patterns against. See the construct-coverage summary at the end of the PR /
task description.
```
