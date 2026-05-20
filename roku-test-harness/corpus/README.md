# Non-device-testable corpus

This directory holds the language leaves from `grammar/coverage.json` that are flagged
`device_testable: false` — one file per leaf. These constructs **cannot** live in `source/`
because the Roku dev installer compiles the *whole* channel on upload: a leaf the device
rejects would fail the build, and a leaf that produces no observable runtime signal can't be
asserted by the on-device harness. So they live here as a static parse corpus instead.

There are 34 such leaves (14 in `negative/`, 20 in `parse-only/`). The future tree-sitter
grammar (plan 03) consumes this corpus to prove the parser handles syntax the device itself can
never exercise in a running channel.

## Layout

```
corpus/
├── negative/     leaves with expect: "error" — the device REJECTS these
└── parse-only/   leaves with expect: "parse" — VALID syntax, just not runtime-observable here
```

### `negative/` (expect: "error") — the device REJECTS these

The device rejects each of these — but for **two different reasons**, which the parser must
treat differently. Each file's leading `coverage-id:` / `expect:` tag plus its comment states
which kind it is.

**(a) Syntax-rejected — a malformed parse.** The device fails these at the *syntax* level
(typically compile error **&h02**, "Syntax Error"). A correct tree-sitter grammar should
produce **ERROR node(s)** when parsing them (plan 03 asserts the presence of ERROR nodes).
Examples: leading `let` on an assignment (&h02), `#if` with boolean operators / parens
(compile error &h93), a nested **named** function declaration (&h02,
[DEVICE_FACTS.md](../../grammar/DEVICE_FACTS.md) #5), `dim a(n)` paren bounds (&h02, #8), an
optional-call as a bare statement `o.fn?()` (&h02, #9), the `#error` directive, no
line-continuation across a newline, and an unquoted `stringarray` field value.

**(b) Semantically rejected but well-formed — a clean parse the *parser* should NOT flag.**
These are syntactically valid (they PARSE with **no ERROR nodes**) but the device rejects them
*semantically* — they are type/name errors, not grammar errors. The tree-sitter grammar parses
them cleanly; they must instead be caught by a **lint rule in plan 03**, not by an ERROR node.
Examples: `as interface` and `as roSGNode` (a custom/component type in an `as` clause) — both
compile error **&ha7** ([DEVICE_FACTS.md](../../grammar/DEVICE_FACTS.md) #6, #7) — and the
SceneGraph `type="str"` field-type alias (a valued field reads back `Invalid`, #11). For these
files plan 03 asserts a clean parse **and** that the corresponding lint rule fires.

### `parse-only/` (expect: "parse") — 20 leaves

These are perfectly valid syntax; they are simply not observable as a runtime assertion on
this device (e.g. `stop`/`end` control flow, `@attr` / `?@attr` XML-attribute access,
`CreateObject("roSGNode", ...)`, the reserved `eval()` builtin, and the full set of XML
prolog / comment / CDATA / PI / entity / element-shape leaves). A correct tree-sitter
grammar should parse each of these **cleanly, with no ERROR nodes** (plan 03 asserts a clean
parse).

## File conventions

- **One file per leaf.** The filename is the leaf `id` with dots replaced by underscores,
  plus the extension implied by the leaf `layer`:
  - `layer: brightscript` → `.brs`
  - `layer: scenegraph`   → `.xml`

  e.g. `neg.assign.let` → `negative/neg_assign_let.brs`,
  `sg.xml.cdata` → `parse-only/sg_xml_cdata.xml`.

- **`coverage-id:` tagging.** Each file begins with a tag line that maps the file back to its
  coverage leaf and records the expected parse outcome, so tooling can join file → leaf:
  - `.brs` files — two leading comment lines:
    ```
    ' coverage-id: <id>
    ' expect: <error|parse>
    ```
  - `.xml` files — one leading comment line:
    ```
    <!-- coverage-id: <id> expect: <error|parse> -->
    ```

  After the tag line(s) comes the leaf's `snippet` verbatim (real, unescaped newlines).

## Excluded from the channel build

This corpus is **intentionally not part of the Roku channel**. It is not referenced by the
`manifest`, is not under `source/`, and is never compiled by the dev installer. The deploy
orchestrator excludes `corpus/` from both the deploy zip and the `bsconfig` file set, so
nothing in here can break a sideload. These files exist purely as parser input for plan 03.
