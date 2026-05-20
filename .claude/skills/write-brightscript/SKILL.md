---
name: write-brightscript
description: Use whenever writing, editing, or reviewing BrightScript (.brs) or BrighterScript (.bs) source — including SceneGraph <script> bodies. Provides device-validated syntax rules, the .brs/.bs dialect boundary, and the bsc validation loop that guarantees the code you leave on disk compiles. Pull this in BEFORE writing BrightScript so output is valid by construction, not by luck.
---

# Writing valid BrightScript / BrighterScript

This skill governs **syntactic and compile validity** of BrightScript (`.brs`) and
BrighterScript (`.bs`). Its job is simple: code you write must *compile*, and you
must not blur the line between the two dialects.

> Scope: this skill owns "is it valid syntax / will it compile." For *channel
> architecture* patterns (threading, focus, memory, resilience, component shape),
> defer to a `brightscript-expertise` skill or `CLAUDE.md` if the project has one.

## How to use it (the loop that makes "can't mess up" true)

1. **Read `reference.md`** (next to this file) before writing. It is the distilled,
   device-validated rule set: hard lexer rules, the `.brs` vs `.bs` boundary,
   device-confirmed gotchas, and where the `bsc` checker lies. Knowledge first —
   it keeps you from making the mistake at all.
2. **Write for the file's extension.** `.brs` = BrightScript (what the device runs).
   `.bs` = BrighterScript (a superset bsc transpiles down). BrighterScript-only
   constructs (`class`, `namespace`, `enum`, `const`, ternary `?:`, `??`, template
   strings, `new`, typed/custom annotations, `@annotation`) are **compile errors in
   `.brs`**. Check the extension before reaching for them.
3. **Let the gate catch the rest.** A `PostToolUse` hook
   (`.claude/hooks/bsc-validate.sh`) runs `bsc` on the edited file's project after
   every Write/Edit and feeds error-level diagnostics back to you. You can also run
   it yourself: `bsc --project <bsconfig.json> --create-package false --copy-to-staging false`
   (or the project's `npm run check`/`lint`). Iterate until clean.
4. **Reconcile bsc with the device.** bsc is a fast pre-flight gate, **not** ground
   truth. Some valid-on-device constructs are bsc false positives (e.g. `next i`) —
   suppress with `' bs:disable-next-line`, don't delete the construct. Some
   bsc-passing constructs the *device* rejects — never ship them. `reference.md` lists
   both; the authority order is **device > bsc > reference > model priors.**

## Why bsc, not the tree-sitter parser

The tree-sitter grammar in this repo answers "does this fit my grammar?" — it's an
approximation built for structural search (ast-grep), and as a *validity gate* it
would false-reject valid code where the grammar lags the real compiler. `bsc` is the
actual BrighterScript compiler: authoritative, covers both dialects, a strict
superset of a parse check. So the gate is bsc; tree-sitter stays in its lane.

## Maintenance — how this stays current with the language

`reference.md` is **generated**, not hand-written, so it tracks the language as
validated in this repo:

```
grammar/DEVICE_FACTS.md  (device verdicts) ┐
grammar/BSC_DRIFT.md     (bsc vs device)   ├─ npm run gen:reference ─► reference.md
grammar/coverage.json    (valid taxonomy)  ┘            │
                                              npm run check:reference (CI gate: fails if stale)
                                                         │
                                              npm run sync:angel-roku (regen + push to peer apps)
```

When the device teaches us something new, it lands in a `grammar/` ledger; regenerate
and re-sync. Do **not** edit `reference.md` by hand — the freshness gate will flag it.
