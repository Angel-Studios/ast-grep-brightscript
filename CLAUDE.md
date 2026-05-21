# ast-grep-brightscript

The goal of this repository is a **full ast-grep parser for BrightScript** (and Roku SceneGraph),
delivered as a custom tree-sitter grammar registered with ast-grep so that BrightScript `.brs` and
SceneGraph `.xml` files can be searched, linted, and rewritten with ast-grep patterns and rules.

## Current status: PARSER BUILT

The parser is **built, validated, and registered**. Three tree-sitter grammars
(`tree-sitter-brightscript/`, `tree-sitter-scenegraph/`, `tree-sitter-brighterscript/`) are authored
from the EBNF, compiled to `.so`, and registered as ast-grep custom languages in `sgconfig.yml` —
with BrightScript injected into SceneGraph `<script>` bodies (CDATA and bare inline). The
**BrighterScript (`.bs`) superset** grammar EXTENDS the BrightScript grammar via tree-sitter grammar
inheritance, and its `.bs` is device-validated by transpiling to `.brs` and running on a real Roku
(roadmap/05; DEVICE_FACTS #18). The foundation that made this possible remains in place and is still
the source of truth:

1. A reusable **skill** that teaches the full method for building a tree-sitter grammar and
   registering it as an ast-grep custom language.
2. **Authoritative EBNF grammars** for BrightScript and SceneGraph, derived from the official Roku
   docs (and the SceneGraph XSD).
3. A runnable **Roku test-harness app** that exercises every construct in those grammars — it both
   self-validates on a real device and serves as the ast-grep test corpus.

When you change the parser, do not start from scratch — work from these specs and the skill.

The **BrighterScript (`.bs`) initiative (`roadmap/05`) is at Phase 7** (grow the runnable/device-
validated subset). If you're picking that up, start at [`start_here.md`](start_here.md) — it has the
green-check, the per-feature loop, and the hard-won grammar/device gotchas.

## Repository map

```
ast-grep-brightscript/
├── CLAUDE.md                                  ← you are here (orientation)
├── README.md                                  ← project overview + the architecture diagram
├── package.json                               ← npm scripts: check/lint (bsc) + roku:deploy/zip/install/launch/delete
├── sgconfig.yml                               ← ast-grep config: registers the customLanguages + languageInjections
├── .env.example                               ← Roku device config template (copy to .env; .env is gitignored)
├── docs/
│   └── pipeline.svg                           ← architecture diagram (embedded in README.md)
├── .claude/
│   └── skills/
│       └── ast-grep-custom-language/
│           └── SKILL.md                       ← HOW to build the parser (tree-sitter → ast-grep)
├── grammar/                                   ← language specs + their validators (source of truth)
│   ├── CLAUDE.md                              ← guide to the grammar specs
│   ├── brightscript.ebnf                      ← WHAT to parse: BrightScript language spec
│   ├── scenegraph.ebnf                        ← WHAT to parse: SceneGraph XML (embeds BrightScript)
│   ├── RokuSceneGraph.xsd                     ← vendored official SceneGraph XSD (authority for the SG enums)
│   ├── check_ebnf.py                          ← validator: EBNF internal consistency (rules defined + reachable)
│   ├── check_scenegraph_xsd.py               ← validator: scenegraph.ebnf enums vs the XSD
│   ├── COVERAGE.md + coverage.json            ← construct-coverage taxonomy + per-rule status
│   └── DEVICE_FACTS.md                        ← device-confirmed language facts (the ground-truth ledger)
├── tree-sitter-brightscript/                  ← BrightScript tree-sitter grammar (grammar.js, src/, test/corpus/, compiled .so)
├── tree-sitter-scenegraph/                    ← SceneGraph tree-sitter grammar (grammar.js, src/, test/corpus/, compiled .so)
├── tree-sitter-brighterscript/                ← BrighterScript (.bs) grammar — EXTENDS tree-sitter-brightscript via grammar inheritance (superset)
├── rules/                                      ← ast-grep lint rules (ruleDirs in sgconfig.yml; currently empty)
├── roku-test-harness/                         ← runnable Roku app: spec exerciser + ast-grep corpus
│   └── README.md                              ← deploy (npm run roku:deploy) & read the boot-log results
├── roku-listener/                             ← Bun/TS tool: parses the device's ##SPEC## debug stream → JSON report
│   └── README.md                              ← the ##SPEC## protocol + live/replay usage
├── scripts/
│   └── roku-deploy.ts                         ← package → digest-auth sideload → ECP launch automation
└── roadmap/                                   ← next-step plans (expand coverage, roArray, tree-sitter, housekeeping)
    └── README.md
```

## The pipeline

```
grammar/brightscript.ebnf ─┐
                           ├─► tree-sitter grammar.js ─► generated C parser ─► .so ─► ast-grep customLanguage
grammar/scenegraph.ebnf  ──┘   (+ BrightScript injected into SceneGraph <script> CDATA)
                                              ▲
                                              └── validated against roku-test-harness/ source as the corpus
```

`scenegraph.ebnf` embeds `brightscript.ebnf` (BrightScript lives in `<script>` CDATA and external
`uri` scripts); in tree-sitter terms this is **language injection** — now implemented and verified:
`sgconfig.yml` injects the BrightScript parser into SceneGraph `<script>` bodies (CDATA and bare
inline), so ast-grep's BrightScript rules match inside `.xml` `<script>` content.

For the same pipeline drawn out — including the device-as-ground-truth feedback loop — see the
architecture diagram [`docs/pipeline.svg`](docs/pipeline.svg) (also embedded in `README.md`).

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
  exhaustive over the specs. Parse those files, inspect the S-expression trees, and extend the
  `test/corpus/` cases (already present under each `tree-sitter-*/test/corpus/`) from them.
- **Validating against the device (ground truth)?** `npm run roku:deploy` packages the harness,
  sideloads it (the dev installer compiles on upload, so rejects are immediate), and launches it;
  the harness emits a `##SPEC##` result line per construct on the debug console (telnet 8085), which
  `roku-listener/` parses into a pass/fail report. Whatever the device decides is authoritative —
  record confirmed facts in `grammar/DEVICE_FACTS.md`. See `roku-test-harness/README.md` and
  `roku-listener/README.md`.
- **Keep specs, harness, validators, and grammar in sync.** A construct added in one should be
  reflected in the others; keep all validation gates green (`grammar/check_ebnf.py`,
  `check_coverage.py`, `check_scenegraph_xsd.py`, `check_grammar.py`, `check_parity.py`).

## Conventions

- BrightScript is **case-insensitive** and has **significant newlines** (no line-continuation
  character); SceneGraph XML is case-sensitive. These and other lexer-level quirks are documented in
  the "Notes for the tree-sitter implementer" sections of the EBNF files — honor them in `grammar.js`.
- Pin compatible versions of `tree-sitter-cli` and ast-grep (ABI mismatch is a common failure — see
  the skill's pitfalls section).
- This file and the per-directory `CLAUDE.md`s are the orientation layer; keep them current as the
  repo grows past groundwork.
```
