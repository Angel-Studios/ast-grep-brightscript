---
name: ast-grep-custom-language
description: Use when building or modifying a tree-sitter grammar and registering it as a custom language for ast-grep. Covers authoring a tree-sitter grammar (grammar.js DSL, fields, precedence, conflicts, external scanners), generating and building the parser dynamic library with the tree-sitter CLI, and registering it in ast-grep's sgconfig.yml customLanguages block so patterns and rules match against the grammar's node kinds and fields.
---

# Building a Custom Language for ast-grep (tree-sitter grammar + registration)

This skill is language-agnostic methodology. It teaches you the full pipeline for taking a programming
language with no built-in ast-grep support, authoring a tree-sitter grammar for it, compiling that grammar
to a dynamic library, and registering it with ast-grep. Follow it whenever you create or change a grammar
that ast-grep will consume.

## 1. Overview & mental model

The pipeline has four stages, and each downstream stage is constrained by decisions made upstream:

```
grammar.js  ──tree-sitter generate──▶  src/parser.c + src/node-types.json + src/grammar.json
                                                  │
                                       tree-sitter build
                                                  ▼
                                       <lang>.so / .dylib / .dll   (dynamic library)
                                                  │
                                      sgconfig.yml customLanguages
                                                  ▼
                              ast-grep loads the library and parses your files
                                                  │
                                                  ▼
                  patterns / `kind` rules / `field` selectors match tree-sitter nodes
```

The single most important thing to internalize: **what you name in the grammar is exactly what you can
match in ast-grep.** The grammar produces a *concrete syntax tree* (CST) containing a node for every
token, including punctuation and keywords. ast-grep matches against that CST:

- A **named rule** in `grammar.js` (e.g. `if_statement: $ => ...`) becomes a **named node** whose
  `type`/**kind** is `if_statement`. In ast-grep you select it with `kind: if_statement`.
- A **string/regex literal** in the grammar (e.g. `"if"`, `"+"`) becomes an **anonymous node**. Anonymous
  nodes have a kind equal to their literal text, are generally not selectable by `kind`, and require the
  `$$VAR` (double-dollar) form to capture as a meta-variable. Prefer giving structure a *named* rule if
  you want to match it cleanly.
- A **hidden rule** (name starts with `_`, e.g. `_expression`) does **not** appear as its own node in the
  tree; it is inlined into its parent. You cannot `kind`-match `_expression` directly. A `supertypes`
  entry records the abstract category in `node-types.json` (with its `subtypes`), but **do not assume
  ast-grep expands it to its subtypes** — verified caveat in §8.
- A `field("name", $.rule)` wrapper assigns a **field name** to a child. In ast-grep this surfaces as the
  `field:` parameter inside `has`/`inside` relational rules. Fields are how you say "the *name* child of
  this declaration" instead of "any child."

So: **named rules → `kind`; fields → `has/inside ... field:`; literal tokens → anonymous nodes / `$$VAR`;
supertypes → grouping in `node-types.json` (but match the concrete subtype in ast-grep, §8).** Design the
grammar with the matches you eventually want in mind.

Verify the exact kinds/fields you produced with `tree-sitter parse` (S-expression output) or by reading
`src/node-types.json`. Never guess a kind name — read it off the actual tree.

## 2. Prerequisites & toolchain

Tree-sitter grammars are written in JavaScript and compiled into C parsers, so you need:

1. **A JavaScript runtime** — Node.js is the default; the CLI uses it to interpret `grammar.js`.
2. **A C/C++ compiler** — required to run/compile parsers (`tree-sitter parse`, `tree-sitter test`,
   `tree-sitter build`). gcc/clang on Linux/macOS, MSVC/clang on Windows.
3. **The tree-sitter CLI.** Install one of:
   ```sh
   cargo install tree-sitter-cli --locked      # from crates.io (recommended, single binary)
   npm install -g tree-sitter-cli              # npm (limited platform support)
   # or download a prebuilt binary from the tree-sitter GitHub releases
   ```
4. **ast-grep** — install via your platform package manager / `cargo install ast-grep --locked` /
   `npm install -g @ast-grep/cli`. The binary is `ast-grep` (alias `sg` on some installs).

### Scaffold the project

Name the repo `tree-sitter-<language>` (lowercase). Inside it:

```sh
tree-sitter init
```

`tree-sitter init` generates the project skeleton, including the `grammar.js` template (placeholders for
parser name, description, author, license) and the configuration/binding files needed to use the parser
from multiple host languages. Standard layout after `init` + `generate`:

```
tree-sitter-<lang>/
├── grammar.js              # YOU author this — the grammar DSL
├── tree-sitter.json        # parser metadata/config (name, scope, file types, ABI hints)
├── package.json            # npm metadata + node bindings deps
├── src/
│   ├── parser.c            # GENERATED by `tree-sitter generate`
│   ├── grammar.json        # GENERATED — structured form of grammar.js
│   ├── node-types.json     # GENERATED — every node kind, named flag, fields, children
│   ├── scanner.c           # OPTIONAL — hand-written external scanner (if you add `externals`)
│   └── tree_sitter/        # GENERATED headers (parser.h, alloc.h, array.h, ...)
├── bindings/               # GENERATED language bindings (c, node, rust, python, ...)
└── test/
    └── corpus/             # YOU author — `.txt` corpus tests (S-expression fixtures)
```

You only edit `grammar.js`, `scanner.c` (if used), and `test/corpus/*`. Everything in `src/` except the
scanner is regenerated and should generally not be hand-edited.

## 3. Authoring the grammar (grammar.js / the DSL)

A grammar is a single `grammar({...})` call exported from `grammar.js`:

```js
module.exports = grammar({
  name: 'mylang',

  // Tokens allowed ANYWHERE without being mentioned in rules (whitespace, comments).
  extras: $ => [/\s/, $.comment],

  // The keyword/identifier token used for keyword extraction (see §4).
  word: $ => $.identifier,

  // Rules considered abstract supertypes — hidden but queryable; expand to subtypes.
  supertypes: $ => [$._statement, $._expression],

  // Rule names automatically removed/inlined from the grammar.
  inline: $ => [$._foo],

  // Named precedence levels (array of arrays of strings), referenced by prec(...).
  precedences: $ => [['multiplicative', 'additive', 'comparative']],

  // Intended LR(1) conflicts you want the GLR parser to explore (array of arrays of rule names).
  conflicts: $ => [[$.array, $.array_pattern]],

  // Token names produced by an external C scanner (see §5).
  externals: $ => [$.indent, $.dedent, $.string_content],

  rules: {
    // The FIRST rule is the grammar's start/root rule by convention.
    source_file: $ => repeat($._statement),

    _statement: $ => choice($.if_statement, $.assignment, $.expression_statement),

    if_statement: $ => seq(
      'if',
      field('condition', $._expression),
      field('consequence', $.block),
      optional(seq('else', field('alternative', $.block))),
    ),

    block: $ => seq('{', repeat($._statement), '}'),

    assignment: $ => seq(
      field('left', $.identifier),
      '=',
      field('right', $._expression),
    ),

    _expression: $ => choice($.identifier, $.number, $.binary_expression),

    binary_expression: $ => choice(
      prec.left('additive',       seq(field('left', $._expression), field('operator', '+'), field('right', $._expression))),
      prec.left('multiplicative', seq(field('left', $._expression), field('operator', '*'), field('right', $._expression))),
    ),

    identifier: $ => /[A-Za-z_][A-Za-z0-9_]*/,
    number: $ => /\d+/,
    comment: $ => token(seq('//', /.*/)),
  },
});
```

### `grammar({...})` top-level fields

| Field | Meaning |
| --- | --- |
| `name` | The grammar/parser name (used to derive the `tree_sitter_<name>` symbol). |
| `rules` | Object of rule definitions; the **first** rule is the root. |
| `extras` | "An array of tokens that may appear *anywhere* in the language" (whitespace, comments). |
| `inline` | "An array of rule names that should be automatically *removed* from the grammar" (inlined). |
| `conflicts` | "An array of arrays of rule names" — intended LR(1) conflicts the parser may explore. |
| `externals` | "An array of token names which can be returned by an *external scanner*." |
| `precedences` | "An array of arrays of strings" defining named precedence levels (highest first). |
| `word` | "The name of a token that will match keywords" — enables keyword extraction (§4). |
| `supertypes` | "An array of rule names which should be considered to be 'supertypes'." Hidden node types, but queryable; appear in `node-types.json` with a `subtypes` list. |
| `reserved` | "An object of reserved word sets associated with an array of reserved rules" — contextual reserved-word handling. |

### DSL functions

| Function | Behavior |
| --- | --- |
| `seq(a, b, ...)` | Match `a`, then `b`, ... in order. |
| `choice(a, b, ...)` | Match exactly **one** alternative. |
| `repeat(rule)` | Zero or more. |
| `repeat1(rule)` | One or more. |
| `optional(rule)` | Zero or one. |
| `prec(n, rule)` | Numeric (or named) parse precedence to resolve conflicts. |
| `prec.left([n], rule)` | Left-associative. |
| `prec.right([n], rule)` | Right-associative. |
| `prec.dynamic(n, rule)` | Precedence resolved at *parse time* (runtime) rather than generation time — last resort for genuine ambiguity. |
| `token(rule)` | "Marks the given rule as producing only a single token" — the whole sub-expression lexes as one atomic token (a leaf, no internal named children). |
| `token.immediate(rule)` | Matches the token only when there is **no preceding whitespace/extras** (e.g. string contents, `f"..."` prefixes). |
| `field(name, rule)` | "Assigns a *field name* to the child node(s)" — surfaces as `field:` in ast-grep. |
| `alias(rule, name)` | "Causes the given rule to *appear* with an alternative name" in the tree (rename a node; `alias($.x, $.y)` for a named node, `alias($.x, 'y')` for an anonymous one). |
| `reserved(wordset, rule)` | Override the global reserved-word set for a sub-rule. |
| `/regex/` | A regex literal — a terminal symbol (lexical rule). |
| `"string"` | A string literal — a terminal that produces an **anonymous** node. |

### Named vs hidden vs anonymous — the rule that governs matchability

- **Named rule** (`foo: $ => ...`) → visible named node, kind `foo`. ✅ `kind: foo` matchable.
- **Hidden rule** (`_foo: $ => ...`, leading underscore) → "hidden in the syntax tree," inlined into the
  parent. Useful for wrapper rules like `_expression` that just choose one child. ❌ not a `kind`, but
  still usable in queries through whatever concrete node it resolves to.
- **String/regex literal** → **anonymous node**: "named nodes correspond to named rules in the grammar,
  whereas anonymous nodes correspond to string literals." Anonymous nodes are present in the CST (it is a
  concrete tree with commas, parens, keywords) but are awkward to target — give recurring structure a
  named rule.
- **Supertype** → hidden abstract category recorded in `node-types.json` with a `subtypes` list. Good for
  grammar structure and for documenting an abstract category, but ❌ **not matchable as an ast-grep
  `kind`** — it is hidden (never in the CST) and ast-grep does not expand it to its subtypes (verified,
  §8). Match the concrete subtype instead.

### Why fields matter for ast-grep

Without `field(...)`, ast-grep can only say "this node *has* some child matching X." With fields you can
say "the child in the **condition** position" or "the **name** field of this declaration." Name every
child whose grammatical role you will want to match. Example downstream usage:

```yaml
# match if_statements whose `condition` field is a binary_expression
rule:
  kind: if_statement
  has:
    field: condition
    kind: binary_expression
```

## 4. Lexing vs parsing, precedence & conflict resolution

Tree-sitter runs **two phases**: a lexer groups characters into tokens, then the GLR parser applies
grammar rules to those tokens. The class it works most efficiently with is **LR(1)** grammars; design
toward that.

### Lexer token-conflict resolution (priority order)

When more than one token could match the same characters, tree-sitter chooses by:

1. **Context validity** — is the token valid at this parse position?
2. **Explicit lexical precedence** — `token(prec(n, ...))`.
3. **Longest match** — the longer character sequence wins.
4. **Specificity** — a string literal is preferred over a regexp.
5. **Rule order** — earlier-defined rule wins ties.

Note the distinction: **lexical precedence** decides which *token* is chosen; **parse precedence**
(`prec`) decides which *rule* is chosen and is applied at a different (higher) level.

### Keyword extraction (`word`)

Set `word: $ => $.identifier` (or your identifier token). Tree-sitter then matches keywords through the
identifier token first, so `instanceofX` lexes as one identifier, not `instanceof` + `X`. It also produces
a smaller, faster lexer. Keywords must appear as **string literals** in your rules to be extracted.

### Expression precedence & associativity

Don't replicate a language spec's 20-level precedence ladder with 20 nested rules. Use a flatter set of
rules and `prec` / `prec.left` / `prec.right`:

```js
binary_expression: $ => choice(
  prec.left(2, seq($._expr, '*', $._expr)),   // binds tighter
  prec.left(1, seq($._expr, '+', $._expr)),   // binds looser
),
```

Higher number = binds tighter. `prec.left` makes `a - b - c` parse as `(a - b) - c`; `prec.right` makes
`a = b = c` parse as `a = (b = c)`.

### Resolving `tree-sitter generate` conflict errors

`tree-sitter generate` fails with a conflict report when it cannot decide between rules at some parse
state. Read it carefully — it lists the conflicting rules and a possible input. Resolution strategy:

1. **If one interpretation should always win** → add `prec`/`prec.left`/`prec.right` to make it
   unambiguous. This is the preferred fix.
2. **If both interpretations are genuinely valid** and you want the GLR parser to keep both alive until
   later tokens disambiguate (e.g. `[a, b]` as array literal *or* destructuring pattern) → add the rule
   pair to the `conflicts` array.
3. **Only as a last resort**, when ambiguity cannot be resolved statically, use `prec.dynamic`.

Prefer `prec` over `conflicts`; only declare a conflict when the ambiguity is real and must be deferred.

## 5. External scanners (optional — avoid if you can)

You need a hand-written C scanner when a token cannot be described by a regular expression or needs
stateful/contextual lexing. Canonical cases: **significant indentation** (Python-style indent/dedent),
**heredocs** (Bash/Ruby), **percent strings / contextual delimiters**, **CDATA-like raw regions**, and
**line continuations**. If your language has none of these, you do **not** need an external scanner —
many languages (likely including a typical line-oriented BASIC dialect, modulo line-continuation handling)
can be expressed entirely in `grammar.js`.

Declare the externally-scanned tokens:

```js
externals: $ => [$.indent, $.dedent, $.newline, $.string_content],
```

The scanner must live at **`src/scanner.c`** (the CLI looks for exactly that path) and define an enum
whose order matches the `externals` array. The required C function set (all named
`tree_sitter_<LANG>_external_scanner_<fn>`):

| Function | Role |
| --- | --- |
| `_create()` | Allocate and return scanner state (or `NULL`). |
| `_destroy(void *payload)` | Free state allocated by `_create`. |
| `_serialize(void *payload, char *buffer)` | Copy state into `buffer`, return bytes written. Bounded by `TREE_SITTER_SERIALIZATION_BUFFER_SIZE`. |
| `_deserialize(void *payload, const char *buffer, unsigned length)` | Restore state from `buffer`. |
| `_scan(void *payload, TSLexer *lexer, const bool *valid_symbols)` | Recognize a token; set `lexer->result_symbol`; return `true` if one was produced. |

The `TSLexer` you drive in `_scan` exposes (key members): `int32_t lookahead` (current code point),
`TSSymbol result_symbol`, `void (*advance)(TSLexer*, bool skip)`, `void (*mark_end)(TSLexer*)`,
`uint32_t (*get_column)(TSLexer*)`, `bool (*is_at_included_range_start)(const TSLexer*)`, and
`bool (*eof)(const TSLexer*)`.

Discipline: use `ts_malloc`/`ts_calloc`/`ts_realloc`/`ts_free` from `tree_sitter/alloc.h` (not libc) and
the array macros from `tree_sitter/array.h`. Always check `eof` inside scan loops, and be extremely
careful emitting zero-width tokens (they can cause infinite loops). External scanners run **before** the
normal lexer and take priority. The `valid_symbols` array tells you which externals are valid at the
current position — respect it.

## 6. Build & generate

```sh
tree-sitter generate          # grammar.js -> src/parser.c, src/node-types.json, src/grammar.json
```

- Writes into `src/` by default (override with `-o/--output <dir>`).
- ABI: the CLI generates the **latest** ABI by default (currently **ABI 15**, supported by tree-sitter
  0.25+). Older ABIs (e.g. 14) are selectable with `--abi <VERSION>`. ABI matters for ast-grep
  compatibility — see §10.
- After editing `grammar.js` you must re-run `generate` before `parse`/`test`/`build` reflect the change.

```sh
tree-sitter build                 # compile parser into a dynamic library (.so/.dylib/.dll)
tree-sitter build --output mylang.so   # explicit artifact name/path (relative or absolute)
tree-sitter build --wasm          # compile to a .wasm module instead
```

- Output extension is platform-native: `.so` (Linux), `.dylib` (macOS), `.dll` (Windows). With `--wasm`,
  `.wasm`.
- Without `-o/--output`, the CLI derives the library name from the parent directory; if it can't, it
  defaults to `parser.so`/`parser.wasm` in the cwd. **Always pass `--output` for a predictable path** that
  your `sgconfig.yml` can reference.
- Override the compiler with the `CC` env var (may wrap `ccache`/`sccache`); add flags via `CFLAGS`.
- `tree-sitter build` compiles `src/parser.c` **and** `src/scanner.c` if present.

`src/node-types.json` is your machine-readable map of every node kind: `type`, `named` (bool),
`fields` (object of field-name → child-type spec), `children`, and `subtypes` (for supertypes). It is the
authoritative reference for which `kind`s and `field`s ast-grep can target.

## 7. Testing & iteration

### Inspect the real tree

```sh
tree-sitter parse path/to/sample.ext      # prints the S-expression CST with kinds + byte/row,col ranges
tree-sitter parse -c sample.ext           # pretty-printed CST
tree-sitter parse -x sample.ext           # XML form
tree-sitter parse -d sample.ext           # lexer/parser debug logs to stderr
```

`tree-sitter parse` exits non-zero if there were parse errors (look for `ERROR`/`MISSING` nodes). The
S-expression output is exactly how you discover the **node kinds and field names** you will reference from
ast-grep. Field-bearing children print as `field_name: (node ...)`:

```
(if_statement
  condition: (binary_expression
    left: (identifier)
    operator: "+"
    right: (number))
  consequence: (block))
```

`tree-sitter playground` opens an interactive browser playground (build a wasm parser first) to explore
the tree and write queries live.

### Corpus tests (`test/corpus/`)

Tests are plain text files in `test/corpus/`. Each test:

1. A **name** between two lines of only `=` characters.
2. Optional **attributes** (each on its own line, starting with `:`).
3. The **input source code**.
4. A divider line of **three or more `-`** characters.
5. The **expected output** as an S-expression.

```
==================
if statement with else
==================

if x { y } else { z }

---

(source_file
  (if_statement
    condition: (identifier)
    consequence: (block (expression_statement (identifier)))
    alternative: (block (expression_statement (identifier)))))
```

Run and update:

```sh
tree-sitter test                 # run all corpus tests
tree-sitter test -i 'some name'  # run only tests matching this regex
tree-sitter test -u              # UPDATE expected trees to current parser output (use deliberately)
```

Useful test attributes: `:skip` (skip without deleting), `:error` (assert the tree contains an ERROR),
`:fail-fast`, `:language(LANG)` (pick a parser in a multi-parser repo), `:platform(PLATFORM)`,
`:cst` (emit CST instead of S-expression). If your language's syntax collides with the `=`/`-` separators,
append an identical arbitrary suffix (e.g. `|||`) to both the header and divider lines; if the body
contains `---`, the **longest** matching dashed line is used as the divider.

Treat corpus tests as the parser's spec/regression suite: write one per construct as you add it, and run
`tree-sitter test` after every grammar change.

## 8. Registering with ast-grep

Once you have a built dynamic library:

1. **Build the library** (from §6):
   ```sh
   tree-sitter build --output mylang.so
   ```
   (Or compile manually if needed — the canonical fallback the docs give is:
   `gcc -shared -fPIC -fno-exceptions -g -I {header_path} -o {lib_path} -O2 {scanner_path} -xc {parser_path} {other_flags}`.)

2. **Add a `customLanguages` entry to `sgconfig.yml`.** The doc's verbatim example:
   ```yaml
   # sgconfig.yml
   ruleDirs: ["./rules"]
   customLanguages:
     mojo:
         libraryPath: mojo.so     # path to dynamic library
         extensions: [mojo, 🔥]   # file extensions for this language
         expandoChar: _           # optional char to replace $ in your pattern
   ```

   Exact field semantics (from the sgconfig.yml reference):

   | Field | Type | Required | Meaning |
   | --- | --- | --- | --- |
   | *(map key)* | string | yes | The language name. ast-grep uses it as `-l <name>` and to derive the default load symbol `tree_sitter_<name>`. |
   | `libraryPath` | `String` or `HashMap<String,String>` | yes | "The path to the tree-sitter dynamic library of the language." String form is interpreted **relative to the sgconfig.yml** (or an absolute path). The map form keys by target triple for per-platform libraries. |
   | `extensions` | `Array<String>` | yes | "The file extensions for this language." (No leading dot.) |
   | `expandoChar` | `String` | no | "An optional char to replace `$` in your pattern." Use this when `$VAR` would be invalid lexically in your language so meta-variables can still be written (e.g. `_VAR`). |
   | `languageSymbol` | `String` | no | "The dylib symbol to load ts-language, default is `tree_sitter_{name}`, e.g. `tree_sitter_mojo`." Set this only if the exported symbol differs from `tree_sitter_<key>` (e.g. your grammar `name` differs from the config key). |

   The map key, the grammar's `name` (which fixes the exported `tree_sitter_<name>` symbol), and
   `languageSymbol` must line up. Easiest: make the `customLanguages` key equal the grammar `name`, then
   `languageSymbol` can be omitted.

   **Meta-variables when `$` is a real token in your language.** ast-grep's default sigil is `$`, so a
   pattern `$X` must lex as an identifier. If your language already uses `$` (e.g. BrightScript's `$`
   String type-designator), `$X` lexes wrong and patterns ERROR. Two fixes, in order of preference:
   - **If you OWN the scanner (preferred): accept `$`-prefixed words as identifiers.** In the external
     scanner's IdentStart branch, also fire when the lookahead is `$`, consuming a leading run of `$`
     (so `$X` and `$$$ARGS` become one identifier word) — meta words skip the reserved-word check, and a
     *lone* `$` with no following ident char declines so a trailing type-suffix (`name$`) is unaffected.
     This keeps the **standard `$VAR` ergonomics** with zero collision (real code never starts a word with
     `$`). VERIFIED on this repo's brightscript/brighterscript scanners (2026-05-21): `$X = $Y` matches and
     captures, `name$` still parses Identifier+TypeSuffix, corpus stayed green. Rebuild surgically without
     regenerating (`gcc … -O2 src/scanner.c -xc src/parser.c`) so `parser.c` is provably unchanged.
   - **`expandoChar` (fallback, when you can't change the grammar).** Pick a char that IS a valid
     identifier char and write meta-vars with it (`_VAR` for `expandoChar: _`). Downsides: non-standard
     ergonomics and it collides with any real identifier that starts with that char — bad for a language
     whose idiom uses leading `_`. Prefer the scanner fix when the grammar is yours.

   Two more issues independent of `$`, both seen + fixed in the SceneGraph (XML) grammar:
   - **Attribute-value meta-vars need a visible text node.** If the attr value is one opaque token
     (`AttValue` whose text is `"$ID"`, quotes included), `id="$ID"` keeps `$ID` buried — ast-grep finds
     no meta-var node, so it matches but captures nothing. FIX: expose the value's literal text run as its
     OWN visible node (e.g. `AttText`, via `alias($._chunk, $.AttText)`); then `"$ID"` parses as
     `AttValue(AttText "$ID")` and `$ID` binds. VERIFIED: after exposing `AttText`, `<field id="$ID"
     type="$T" value="$V"/>` captured `{ID,T,V}`. Several free-text value bodies can ALIAS to the SAME
     `AttText` node (`alias($._alias_body, $.AttText)`, `alias($._role_body, $.AttText)`, …) so meta-vars
     bind uniformly across them. Any value matched by a RESTRICTIVE token (SceneGraph's `FieldType` =
     `/[A-Za-z][A-Za-z0-9]*/`, or a `BoolText` of just `true|false`) also needs that token broadened to
     admit `$NAME` (add a `\$+[A-Za-z_]\w*` alternative) or the meta-var won't lex there. If a value is a
     `choice(SemanticKind, FreeText)` (SceneGraph `extends` = `BuiltinNodeClass | AttText`), a meta-var
     only matches the branch it parses to — capture EITHER branch with `{kind: ExtendsValue, has: {pattern:
     $BASE}}` rather than pinning the child kind.
   - **Context-sensitive element kinds** (`<field>` is a `Field` only inside `<interface>` inside
     `<component>`; standalone it's a `GenericElement`). A flat pattern `<field/>` parses as the wrong
     kind. FIX: use ast-grep's contextual pattern — `pattern: {context: '<component
     name="C"><interface><field id="$ID"/></interface></component>', selector: Field}` — the context must
     be a COMPLETE valid nesting down to the target. For elements with a variable attribute set (UI
     nodes), exact patterns over-constrain; use a relational `kind:` rule instead, e.g.
     `{kind: NodeAttribute, all: [{has: {field: name, regex: '^id$'}}, {has: {field: value, has: {kind:
     AttText, pattern: $V}}}]}` to capture one attribute's value across all nodes.

   Use language injection (above) for embedded code regions regardless.

3. **Verify.** Run a pattern scan against the new language:
   ```sh
   ast-grep -p "print" -l mylang            # CLI pattern search, -l selects your language
   ```
   Or via a rule file (the `language` field must be your registered name):
   ```yaml
   id: my-first-rule
   language: mylang
   severity: hint
   rule:
     pattern: print
   ```
   `ast-grep --debug-query <...>` prints how ast-grep parsed your pattern into a tree — invaluable for
   confirming a pattern resolves to the kinds you expect. Cross-check kinds with `tree-sitter parse` on
   the same snippet; they must agree.

How grammar concepts surface in ast-grep rules:
- named rule  → `kind: <rule_name>` and patterns that parse to that node;
- field        → `has:`/`inside:` with `field: <field_name>`;
- anonymous token → captured only with `$$VAR`; not reliably `kind`-matchable;
- supertype    → present in `node-types.json`, accepted as a known kind WITHOUT error, but **NOT expanded
  to its subtypes when matching** (VERIFIED on ast-grep 0.42.3: `kind: <supertype>` matched 0 nodes on a
  file full of its subtypes, while `kind: <concrete-subtype>` matched). A supertype node is hidden, so it
  never appears in the actual CST for ast-grep to compare against. **Match the concrete subtype kind.**
  Keep supertypes for grammar structure / `node-types.json` grouping, but point real queries (and any
  coverage/test taxonomy) at the concrete subtype kinds.

## 9. Workflow loop (recommended order of operations)

Build incrementally. Do **not** write the whole grammar then debug — validate every slice against real
source files.

1. **Spec a slice.** Pick one construct (or a small group). Sketch its EBNF / grammar shape, including
   which children deserve `field` names.
2. **Translate to `grammar.js`.** Add the named rule(s); name fields; choose precedence/associativity.
3. **`tree-sitter generate`.** Fix any conflict errors now (`prec` first, `conflicts` only if real).
4. **`tree-sitter parse` real sample files.** Confirm zero `ERROR`/`MISSING` nodes and that the tree
   shape matches intent.
5. **Read the kinds/fields off the S-expression** (or `node-types.json`) — these are your ast-grep
   selectors.
6. **Write corpus tests** for the slice in `test/corpus/`; run `tree-sitter test`.
7. **Expand** to the next construct; repeat 1–6. Keep the test suite green.
8. **`tree-sitter build --output <lang>.so`** once the grammar covers what you need (rebuild after every
   grammar change you want ast-grep to see).
9. **Register in `sgconfig.yml`** (`customLanguages`) with correct `libraryPath`, `extensions`, and
   (if needed) `expandoChar` / `languageSymbol`.
10. **Validate ast-grep patterns** with `ast-grep -p ... -l <lang>` and `--debug-query`, checking real
    files. Iterate on grammar → regenerate → rebuild → re-register path if it moved.

## 10. Common pitfalls

- **Conflict errors on generate.** Reach for `prec`/`prec.left`/`prec.right` first; add to `conflicts`
  only for genuine, must-be-deferred ambiguity; `prec.dynamic` is a last resort.
- **Hidden rules erase nodes you wanted.** A `_`-prefixed rule won't appear in the tree, so you can't
  `kind`-match it. If you need it queryable, give it a real name or add it to `supertypes`.
- **Anonymous tokens aren't `kind`-matchable.** String/regex literals become anonymous nodes; in ast-grep
  they need `$$VAR`. Wrap meaningful structure in a named rule instead of relying on bare literals.
- **Forgotten fields.** Without `field(...)`, `has`/`inside ... field:` can't target a child by role. Name
  every grammatically-significant child up front; adding fields later changes downstream rules.
- **Keyword-extraction surprises.** Forgetting `word` (or not listing keywords as string literals) can let
  identifiers swallow keywords or vice-versa. Set `word` to your identifier token and verify with
  `tree-sitter parse -d`.
- **`token()` flattens internal structure.** Anything inside `token(...)` becomes one leaf with no named
  children — don't wrap structure you want to match individually.
- **ABI / version mismatch.** ast-grep can only load a parser whose ABI it supports. Symptom:
  `Incompatible language version ... Compatible range: 13 - 13. Got: 12` (or similar). Causes: a stale
  `tree-sitter-cli` (or an old one shadowed in `node_modules`) generating an outdated ABI, or an ast-grep
  build older than your parser's ABI. Fix: use a single, current `tree-sitter-cli`; regenerate
  (`tree-sitter generate`, optionally `--abi <N>` to target a supported version) and rebuild; ensure
  ast-grep is recent enough.
- **Dynamic-library path issues.** `libraryPath` is resolved relative to `sgconfig.yml` (or absolute). If
  you `tree-sitter build` without `--output`, the artifact name may not be what `sgconfig.yml` expects.
  Always build with `--output` and point `libraryPath` at that exact file. Rebuild after every grammar
  change — ast-grep loads the compiled `.so`, not `grammar.js`.
- **Symbol-name mismatch.** ast-grep loads `tree_sitter_<key>` by default. If your grammar `name` differs
  from the `customLanguages` key, set `languageSymbol` to the actual exported symbol.
- **Forgetting to regenerate.** `tree-sitter parse`/`test`/`build` all reflect the **last `generate`**.
  Edit `grammar.js` → `generate` → (test) → `build` → re-point/rebuild for ast-grep.
- **Playground vs CLI drift.** The web playground's parser can lag the CLI; trust your locally built
  parser (`tree-sitter parse`) over the online playground for exact kinds.

## 11. References

- Tree-sitter overview: https://tree-sitter.github.io/tree-sitter/index.html
- Creating Parsers (index): https://tree-sitter.github.io/tree-sitter/creating-parsers/index.html
- Getting Started: https://tree-sitter.github.io/tree-sitter/creating-parsers/1-getting-started.html
- The Grammar DSL: https://tree-sitter.github.io/tree-sitter/creating-parsers/2-the-grammar-dsl.html
- Writing the Grammar: https://tree-sitter.github.io/tree-sitter/creating-parsers/3-writing-the-grammar.html
- External Scanners: https://tree-sitter.github.io/tree-sitter/creating-parsers/4-external-scanners.html
- Writing Tests: https://tree-sitter.github.io/tree-sitter/creating-parsers/5-writing-tests.html
- Using Parsers (index): https://tree-sitter.github.io/tree-sitter/using-parsers/index.html
- Static Node Types (node-types.json): https://tree-sitter.github.io/tree-sitter/using-parsers/6-static-node-types
- ABI Versions: https://tree-sitter.github.io/tree-sitter/using-parsers/7-abi-versions.html
- CLI (index): https://tree-sitter.github.io/tree-sitter/cli/index.html
- CLI generate: https://tree-sitter.github.io/tree-sitter/cli/generate.html
- CLI build: https://tree-sitter.github.io/tree-sitter/cli/build.html
- CLI parse: https://tree-sitter.github.io/tree-sitter/cli/parse.html
- CLI test: https://tree-sitter.github.io/tree-sitter/cli/test.html
- ast-grep Custom Language: https://ast-grep.github.io/advanced/custom-language.html
- ast-grep sgconfig.yml reference: https://ast-grep.github.io/reference/sgconfig.html
- ast-grep Language Injection: https://ast-grep.github.io/advanced/language-injection.html
- ast-grep Pattern Syntax: https://ast-grep.github.io/guide/pattern-syntax.html
- ast-grep Atomic Rules (kind/pattern): https://ast-grep.github.io/guide/rule-config/atomic-rule.html
- ast-grep Relational Rules (has/inside + field): https://ast-grep.github.io/guide/rule-config/relational-rule.html
