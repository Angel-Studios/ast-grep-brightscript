# ast-grep-brightscript

A full [ast-grep](https://ast-grep.github.io/) parser for **Roku BrightScript** and **SceneGraph** —
so you can structurally search, lint, and rewrite `.brs` and SceneGraph `.xml` files with ast-grep
patterns and rules.

> **Status: parser built.** Both tree-sitter grammars (BrightScript + SceneGraph) are authored from
> the EBNF, compiled, validated against the device-corrected harness, and registered as ast-grep
> custom languages — with BrightScript injected into SceneGraph `<script>` bodies. The foundation
> that made this possible (build methodology, language specifications, runnable test corpus) remains.
> See [`CLAUDE.md`](./CLAUDE.md) for the full orientation.

## What's here

| Path | What it is |
|------|-----------|
| [`.claude/skills/ast-grep-custom-language/`](./.claude/skills/ast-grep-custom-language/SKILL.md) | A deep, reusable guide to building a tree-sitter grammar and registering it as an ast-grep custom language (toolchain, grammar DSL, precedence/conflicts, external scanners, build, corpus tests, `sgconfig.yml`). |
| [`grammar/brightscript.ebnf`](./grammar/brightscript.ebnf) | Authoritative EBNF spec for the BrightScript language, from the official Roku reference. |
| [`grammar/scenegraph.ebnf`](./grammar/scenegraph.ebnf) | Authoritative EBNF spec for SceneGraph component XML (embeds BrightScript via `<script>`), from the Roku docs + the official XSD. |
| [`roku-test-harness/`](./roku-test-harness/) | A runnable Roku app that exercises every construct in the specs, self-reporting pass/fail (green/red) on a real device — and serving as the ast-grep test corpus. |
| [`tree-sitter-brightscript/`](./tree-sitter-brightscript/) · [`tree-sitter-scenegraph/`](./tree-sitter-scenegraph/) | The built tree-sitter grammars (`grammar.js`, `src/`, `test/corpus/`, compiled `.so`) for BrightScript and SceneGraph. |
| [`sgconfig.yml`](./sgconfig.yml) | The ast-grep config that registers both grammars under `customLanguages` and injects BrightScript into SceneGraph `<script>` bodies via `languageInjections`. |

## The pipeline

![ast-grep-brightscript — how the parser is built: EBNF specs → tree-sitter grammar → C parser → .so → ast-grep custom language, with a Roku-device feedback loop validating the specs](docs/pipeline.svg)

```
grammar/*.ebnf  ─►  tree-sitter grammar.js  ─►  C parser  ─►  .so  ─►  ast-grep customLanguage
                    (BrightScript injected into SceneGraph <script> CDATA)
```

This pipeline is now built end to end: the BrightScript injection into SceneGraph `<script>` bodies
is implemented in `sgconfig.yml` (`languageInjections`) and verified. The device-as-ground-truth
loop (sideload the harness → read its `##SPEC##` results → record confirmed facts) is the validation
feedback shown in the diagram above.

## How the parser was built

1. Read the [skill](./.claude/skills/ast-grep-custom-language/SKILL.md) — it's the method.
2. Translate [`grammar/`](./grammar/) into the `tree-sitter-brightscript/` + `tree-sitter-scenegraph/`
   grammar projects.
3. Validate against [`roku-test-harness/`](./roku-test-harness/) source; capture `test/corpus/` cases.
4. Build the dynamic libraries and register them in `sgconfig.yml` under `customLanguages`.

## References

- Roku BrightScript Language Reference — https://developer.roku.com/dev/docs/brightscript-language-reference
- Roku SceneGraph — https://developer.roku.com/dev/docs/scenegraph
- tree-sitter — https://tree-sitter.github.io/tree-sitter/
- ast-grep custom languages — https://ast-grep.github.io/advanced/custom-language.html
