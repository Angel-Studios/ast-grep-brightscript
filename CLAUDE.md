# ast-grep-brightscript

The goal of this repository is a **full ast-grep parser for BrightScript** (and Roku SceneGraph),
delivered as a custom tree-sitter grammar registered with ast-grep so that BrightScript `.brs` and
SceneGraph `.xml` files can be searched, linted, and rewritten with ast-grep patterns and rules.

## Current status: GROUNDWORK

The parser is **not written yet** — this is deliberate. What exists now is the foundation that lets
the parser be authored well (by a human or an AI agent):

1. A reusable **skill** that teaches the full method for building a tree-sitter grammar and
   registering it as an ast-grep custom language.
2. **Authoritative EBNF grammars** for BrightScript and SceneGraph, derived from the official Roku
   docs (and the SceneGraph XSD).
3. A runnable **Roku test-harness app** that exercises every construct in those grammars — it both
   self-validates on a real device and serves as the ast-grep test corpus.

When you build the parser, do not start from scratch — start from these specs and the skill.

## Repository map

```
ast-grep-brightscript/
├── CLAUDE.md                                  ← you are here (orientation)
├── README.md
├── .claude/
│   └── skills/
│       └── ast-grep-custom-language/
│           └── SKILL.md                       ← HOW to build the parser (tree-sitter → ast-grep)
├── grammar/
│   ├── CLAUDE.md                              ← guide to the grammar specs
│   ├── brightscript.ebnf                      ← WHAT to parse: BrightScript language spec
│   └── scenegraph.ebnf                        ← WHAT to parse: SceneGraph XML (embeds BrightScript)
└── roku-test-harness/                         ← runnable Roku app: spec exerciser + ast-grep corpus
    └── README.md                              ← how to package/sideload & read the green/red results
```

Not yet present (the work this groundwork enables):
- `tree-sitter-brightscript/` — the tree-sitter grammar project (`grammar.js`, `src/`, `test/corpus/`, the compiled `.so`).
- `sgconfig.yml` — the ast-grep config registering the compiled grammar under `customLanguages`.

## The intended pipeline

```
grammar/brightscript.ebnf ─┐
                           ├─► tree-sitter grammar.js ─► generated C parser ─► .so ─► ast-grep customLanguage
grammar/scenegraph.ebnf  ──┘   (+ BrightScript injected into SceneGraph <script> CDATA)
                                              ▲
                                              └── validated against roku-test-harness/ source as the corpus
```

`scenegraph.ebnf` embeds `brightscript.ebnf` (BrightScript lives in `<script>` CDATA and external
`uri` scripts); in tree-sitter terms this is **language injection**.

## How to work in this repo

- **Building or changing the parser?** Read `.claude/skills/ast-grep-custom-language/SKILL.md` first
  — it is the methodology (toolchain, `grammar.js` DSL, precedence/conflicts, external scanners,
  build, corpus testing, `sgconfig.yml` registration, the recommended incremental workflow loop).
  The skill auto-triggers when you work on a tree-sitter grammar / ast-grep custom language.
- **What syntax to support?** `grammar/` is the source of truth. See `grammar/CLAUDE.md`. Translate
  the EBNF into `grammar.js`; the expression-precedence cascade maps onto tree-sitter `prec` levels.
  Several grammar items are flagged as unverified — see the warning section in `grammar/CLAUDE.md`
  and confirm them before relying on them.
- **Validating the parser?** Use `roku-test-harness/` as real-world input — it is intentionally
  exhaustive over the specs. Parse those files, inspect the S-expression trees, and write
  `test/corpus/` cases from them. The harness can also be sideloaded onto a Roku to confirm the
  BrightScript/SceneGraph itself is valid (green = pass, red = fail).
- **Keep specs, harness, and (eventual) grammar in sync.** A construct added in one should be
  reflected in the others.

## Conventions

- BrightScript is **case-insensitive** and has **significant newlines** (no line-continuation
  character); SceneGraph XML is case-sensitive. These and other lexer-level quirks are documented in
  the "Notes for the tree-sitter implementer" sections of the EBNF files — honor them in `grammar.js`.
- Pin compatible versions of `tree-sitter-cli` and ast-grep (ABI mismatch is a common failure — see
  the skill's pitfalls section).
- This file and the per-directory `CLAUDE.md`s are the orientation layer; keep them current as the
  repo grows past groundwork.
```
