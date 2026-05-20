# roku-listener

A **Roku debug-console listening layer** for the `ast-grep-brightscript` project.

A Roku device runs the BrightScript / SceneGraph **spec harness** (see
`../roku-test-harness/`). As it exercises each language construct it prints a
structured `##SPEC##` result line to its BrightScript debug console, which the
device exposes over **raw TCP (telnet)** on port **8085** (SceneGraph debug is on
8087). This tool connects to that console, parses the result lines out of the
otherwise-noisy stream, and produces both a **machine-readable JSON report** and
a **human summary**.

This closes a self-improving loop: the device's output is the **ground truth**
for validating the tree-sitter grammar being built in this repo.

Built with **Bun** + **TypeScript** (strict) and the **Effect** library.

## The result protocol

The harness prints, one per line, embedded in boot noise / `print` output:

```
##SPEC## v=1 id=<dotted.id> kind=<EBNFRuleName> status=<PASS|FAIL|COMPILE_ERROR|CRASH> detail="<optional, may contain spaces>"
```

Plus run-framing events:

```
##SPEC## event=run-start total=<int>
##SPEC## event=run-end pass=<int> fail=<int>
```

Parsing rules (all handled by `parseSpecLine`, in `src/parser.ts`):

- Lines are space-separated `key=value` pairs after the `##SPEC##` prefix.
- `detail` is double-quoted and may contain spaces and `=`; `\"` and `\\` are
  unescaped.
- **Keys may appear in any order.** Later duplicates win.
- `##SPEC##` may appear anywhere in the line (timestamps / tags before it are OK).
- Any line **without** the `##SPEC##` prefix is ignored, **except** generic Roku
  failure signals, which are surfaced as `RawFailure` events even when no
  `##SPEC##` line was emitted (e.g. a crash before the harness could report):
  `Syntax Error`, `Compile error`, `runtime error`, `BACKTRACE`, and the prompt
  `Brightscript Debugger>` (matched case-insensitively).

Defensive defaults: missing `kind` → `"unknown"`, unparseable `v` → `1`, an
unrecognized `status` → `CRASH`.

## Architecture (Effect idioms)

- The console line source is modeled as a `Stream<string>` of complete lines.
  - **live**: `node:net` socket wrapped as a **scoped** Effect resource
    (`Stream.acquireRelease`) so the socket is destroyed on scope close /
    interruption. Partial reads are buffered and split on `\n` (trailing `\r`
    trimmed) via a stateful `Stream.mapAccum`.
  - **replay**: the captured log file is read and pushed through the **same**
    `splitLines` pipeline, so the two modes cannot diverge.
- `parseSpecLine` is a **pure** function `string -> SpecEvent | null`
  (`Result | RunStart | RunEnd | RawFailure`) — fully unit-tested.
- `aggregate` is a **pure** reducer folding `SpecEvent`s into a `Report`
  (per-id status, totals, missing count, raw failures).
- `Config` provides env-driven connection settings; `Schedule` provides the
  live-mode reconnect backoff.

```
src/
├── protocol.ts     # types + protocol constants (SpecEvent union, statuses, signals)
├── parser.ts       # parseSpecLine + tokenizeKv + detectRawFailure  (pure)
├── aggregator.ts   # aggregate + isHealthy                          (pure)
├── report.ts       # toJsonReport + renderHumanSummary
├── config.ts       # Effect Config: ROKU_HOST / ROKU_PORT
├── lineSource.ts   # Stream<string> sources: connectLineSource (TCP), fileLineSource
└── main.ts         # CLI: live / replay, backoff, finalize, exit codes
```

## Environment variables

| Var         | Default         | Meaning                                   |
| ----------- | --------------- | ----------------------------------------- |
| `ROKU_HOST` | `192.168.1.240` | Device IP / hostname                      |
| `ROKU_PORT` | `8085`          | Debug console port (BrightScript). 8087 = SceneGraph |

## Install

```sh
bun install
```

(Dependencies are intentionally minimal: just `effect`, plus `@types/bun` for dev.)

## Usage

### live — connect to a device

```sh
# uses ROKU_HOST=192.168.1.240 ROKU_PORT=8085 by default
bun run listen

# override the target
ROKU_HOST=10.0.0.50 ROKU_PORT=8085 bun run listen

# equivalent explicit forms
bun run src/main.ts live
bun run src/main.ts --mode=live
```

Live mode connects, streams lines, prints non-PASS results to stderr as they
arrive, and **finishes automatically** when the `run-end` event is seen (or on
Ctrl-C). On connection failure it **retries with exponential backoff** (1s,
2s, 4s, … capped at 30s).

### replay — run a captured log (no device needed)

```sh
bun run replay fixtures/sample-console.log

# equivalent explicit forms
bun run src/main.ts replay fixtures/sample-console.log
bun run src/main.ts --mode=replay fixtures/sample-console.log
```

Replay feeds a captured console log through the exact same parser/aggregator,
making the whole tool testable without hardware.

### Output

Both modes:

- Write a JSON report to **`out/report.json`** (the dir is created).
- Print a concise human summary table to stdout (counts + every
  `FAIL`/`COMPILE_ERROR`/`CRASH` row with its detail + any raw failure signals).
- **Exit code 0** iff all reported results are `PASS`, nothing is missing, and no
  raw failure signal fired; **non-zero** otherwise (`1` unhealthy, `2` bad CLI
  args).

## Caveats — single connection & developer mode

> **The Roku debug console allows only ONE connection at a time.** If the
> connection is **refused**, another debugger/listener (a stray `telnet 8085`
> session, an IDE, or another copy of this tool) is probably already attached —
> disconnect it first. A refusal can also mean **Developer Mode is not enabled**
> on the device. live mode prints exactly this hint on `ECONNREFUSED`.

To enable Developer Mode: on the remote press
`Home Home Home Up Up Right Left Right Left Right`, accept the agreement, set a
dev password, and note the device IP. See `../roku-test-harness/README.md` for
sideloading the harness itself.

## Tests

```sh
bun test
```

Tests cover `parseSpecLine` / `tokenizeKv` / `detectRawFailure` and the
`aggregate` reducer, plus an end-to-end **replay** over
`fixtures/sample-console.log` (which contains boot noise, PASS/FAIL/COMPILE_ERROR
lines, a `BACKTRACE` + `Brightscript Debugger>` crash sequence, and run-start /
run-end framing).

## Notes on Effect version

Targets **Effect 3.x** (single unified `effect` package). APIs used:
`Stream.acquireRelease`, `Stream.mapAccum`, `Stream.flattenIterables`,
`Stream.flattenChunks`, `Stream.fromQueue`, `Stream.takeUntil`,
`Effect.async`, `Effect.retry`, `Schedule.exponential` / `.either` / `.spaced`
/ `.tapInput`, and `Config.all` / `Config.withDefault`.
