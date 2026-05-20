# 04 — Housekeeping

Small accuracy/doc fixes that have accumulated.

## Items
1. **`grammar/DEVICE_FACTS.md` — log the boxing observation.** Container access
   (index `a[i]`, member `aa.k`, optional chaining `?.`/`?[`, `@attr`, and
   CreateObject components) returns **boxed** scalars (`roInteger`/`roString`/
   `roBoolean`), not intrinsics; equality against an intrinsic literal must unbox
   first. The harness `ValuesEqual` now compares by numeric/string/bool kind
   across the box boundary — this produced 10 false-FAILs before the fix
   (the constructs themselves were correct). Record as a runtime observation
   (not a grammar fact).
2. **`roku-test-harness/README.md` — refresh.** It still describes the old
   green/red MarkupList UI and manual sideloading. Update to: the terse
   Ubuntu-Mono boot-log display, `npm run roku:deploy` (package → digest-auth
   sideload → ECP launch), the `##SPEC##` protocol + `roku-listener/`, and the
   ECP screenshot trick (`/plugin_inspect` Screenshot → `/pkgs/dev.jpg`).
3. **Root `CLAUDE.md` repo map — update.** Add what landed since groundwork:
   `roku-listener/`, `scripts/roku-deploy.ts`, `grammar/check_ebnf.py` +
   `check_scenegraph_xsd.py`, `grammar/RokuSceneGraph.xsd`,
   `grammar/DEVICE_FACTS.md`, `grammar/COVERAGE.md` + `coverage.json`,
   `roadmap/`, `.env(.example)`, and the deploy/listen workflow.
4. **`.gitignore`** — add `.playwright-mcp/` (stray tool scratch). Decide on
   `docs/pipeline.svg` (an architecture diagram of unknown provenance — keep
   under `docs/` or drop).

## Acceptance
Docs match reality; a newcomer can follow `README.md` + `CLAUDE.md` to deploy and
read results without surprises.
