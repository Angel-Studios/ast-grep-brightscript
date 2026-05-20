# ast-grep-brightscript

A full [ast-grep](https://ast-grep.github.io/) parser for **Roku BrightScript** and **SceneGraph** —
so you can structurally search, lint, and rewrite `.brs` and SceneGraph `.xml` files with ast-grep
patterns and rules.

> **Status: groundwork.** The parser itself is not written yet. This repo currently contains the
> foundation needed to author it well: the build methodology, the language specifications, and a
> runnable test corpus. See [`CLAUDE.md`](./CLAUDE.md) for the full orientation.

## What's here

| Path | What it is |
|------|-----------|
| [`.claude/skills/ast-grep-custom-language/`](./.claude/skills/ast-grep-custom-language/SKILL.md) | A deep, reusable guide to building a tree-sitter grammar and registering it as an ast-grep custom language (toolchain, grammar DSL, precedence/conflicts, external scanners, build, corpus tests, `sgconfig.yml`). |
| [`grammar/brightscript.ebnf`](./grammar/brightscript.ebnf) | Authoritative EBNF spec for the BrightScript language, from the official Roku reference. |
| [`grammar/scenegraph.ebnf`](./grammar/scenegraph.ebnf) | Authoritative EBNF spec for SceneGraph component XML (embeds BrightScript via `<script>`), from the Roku docs + the official XSD. |
| [`roku-test-harness/`](./roku-test-harness/) | A runnable Roku app that exercises every construct in the specs, self-reporting pass/fail (green/red) on a real device — and serving as the ast-grep test corpus. |

## The pipeline

```
grammar/*.ebnf  ─►  tree-sitter grammar.js  ─►  C parser  ─►  .so  ─►  ast-grep customLanguage
                    (BrightScript injected into SceneGraph <script> CDATA)
```

## Building the parser (next steps)

1. Read the [skill](./.claude/skills/ast-grep-custom-language/SKILL.md) — it's the method.
2. Translate [`grammar/`](./grammar/) into a `tree-sitter-brightscript/` grammar project.
3. Validate against [`roku-test-harness/`](./roku-test-harness/) source; capture `test/corpus/` cases.
4. Build the dynamic library and register it in `sgconfig.yml` under `customLanguages`.

## References

- Roku BrightScript Language Reference — https://developer.roku.com/dev/docs/brightscript-language-reference
- Roku SceneGraph — https://developer.roku.com/dev/docs/scenegraph
- tree-sitter — https://tree-sitter.github.io/tree-sitter/
- ast-grep custom languages — https://ast-grep.github.io/advanced/custom-language.html
