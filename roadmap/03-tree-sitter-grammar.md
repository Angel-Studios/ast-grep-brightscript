# 03 — Tree-sitter grammar + ast-grep custom language (the end goal)

## Goal
Author `tree-sitter-brightscript/` from the EBNF, build the parser, validate it
against the harness corpus + `coverage.json`, and register it as an **ast-grep
custom language** so `.brs` / SceneGraph `.xml` are searchable, lintable, and
rewritable with ast-grep.

## Context
- **Methodology:** `.claude/skills/ast-grep-custom-language/SKILL.md` — READ FIRST.
- **Spec:** `grammar/brightscript.ebnf` + `grammar/scenegraph.ebnf` (already
  device-corrected; see `grammar/DEVICE_FACTS.md`).
- **Target node kinds:** the `kind`s in `grammar/coverage.json` (136 distinct) —
  these must appear as tree-sitter node types.
- **Corpus:** `roku-test-harness/**/*.brs` + the `<script>` CDATA in `*.xml`;
  negatives from `roku-test-harness/corpus/negative/` (plan 01).

## Steps
1. **Scaffold** `tree-sitter-brightscript/` (grammar.js, binding, package.json).
   Pin compatible `tree-sitter-cli` vs ast-grep ABI (skill pitfalls).
2. **Translate `brightscript.ebnf` → grammar.js:**
   - Lexical: case-insensitive keywords, identifier type-suffixes (`$ % ! # &`),
     numeric literal forms, the `""` string escape, comments (`'` and `rem`) as `extra`.
   - Expression cascade → `prec.left`/`prec.right` per Part 5 — preserve
     associativity: `^` right-assoc and **tighter** than unary minus (`-2^2 = -4`);
     `and`/`or` short-circuit; comparison non-chaining.
   - Statements, blocks, declarations; `field(...)` the selectable parts.
   - Conditional compilation (`#const` / `#if` / `#error`) — `CCExpression` is a
     single bool/const only (DEVICE_FACTS #1).
3. **External scanner (C)** for what EBNF can't express: significant newlines /
   `EOS` at bracket-depth 0; `?`-print vs `?.`/`?[`/`?(` optional-chaining (space
   rule); block-if vs single-line-if; fused/spaced `end x`; bare `end`.
4. **`scenegraph.ebnf` → XML grammar + LANGUAGE INJECTION** of BrightScript into
   `<script>` CDATA and external `uri` scripts.
5. **`test/corpus/`** generated from the harness + `coverage.json` snippets;
   negatives assert ERROR.
6. **Build** the `.so`; add `sgconfig.yml` registering it under `customLanguages`.
7. **Validate:** parse the whole harness with **zero ERROR nodes**; every
   `coverage.json` `kind` is present in `node-types.json`; ast-grep patterns match
   the expected kinds; negatives produce ERROR.
8. **Parity check (new validation level):** EBNF rule names ↔ `node-types.json`,
   so the EBNF can't silently drift from the grammar.

## Acceptance
ast-grep matches BrightScript + SceneGraph patterns via the custom language; the
harness corpus parses clean; all coverage `kind`s are represented; the parity
check is green.
