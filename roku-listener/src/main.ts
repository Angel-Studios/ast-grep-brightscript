import {
  Console,
  Duration,
  Effect,
  Ref,
  Schedule,
  Stream,
} from "effect";
import * as path from "node:path";
import { RokuConfig } from "./config.ts";
import {
  connectLineSource,
  fileLineSource,
  SocketError,
  FileReadError,
} from "./lineSource.ts";
import { parseSpecLine } from "./parser.ts";
import type { SpecEvent } from "./protocol.ts";
import { aggregate, isHealthy } from "./aggregator.ts";
import { renderHumanSummary, toJsonReport } from "./report.ts";

const OUT_DIR = path.resolve(import.meta.dir, "..", "out");
const REPORT_PATH = path.join(OUT_DIR, "report.json");

/**
 * Turn a `Stream<string>` of console lines into a `Stream<SpecEvent>` by parsing
 * each line and dropping non-signal lines. Pure transformation — same for both
 * modes.
 */
const toEvents = <E, R>(
  lines: Stream.Stream<string, E, R>,
): Stream.Stream<SpecEvent, E, R> =>
  lines.pipe(
    Stream.map(parseSpecLine),
    Stream.filter((ev): ev is SpecEvent => ev !== null),
  );

/**
 * Collect events from a source into an array, stopping after the run-end event
 * (inclusive) if one is observed. Also echoes a terse live trace to stderr so
 * the operator can see progress.
 */
const collectEvents = <E, R>(
  events: Stream.Stream<SpecEvent, E, R>,
  opts: { readonly trace: boolean },
): Effect.Effect<ReadonlyArray<SpecEvent>, E, R> =>
  Effect.gen(function* () {
    const acc = yield* Ref.make<SpecEvent[]>([]);

    // takeUntil includes the matching element, so we stop AFTER run-end.
    const bounded = events.pipe(
      Stream.takeUntil((ev) => ev._tag === "RunEnd"),
    );

    yield* bounded.pipe(
      Stream.tap((ev) =>
        Effect.gen(function* () {
          yield* Ref.update(acc, (xs) => {
            xs.push(ev);
            return xs;
          });
          if (opts.trace) yield* traceEvent(ev);
        }),
      ),
      Stream.runDrain,
    );

    return yield* Ref.get(acc);
  });

const traceEvent = (ev: SpecEvent): Effect.Effect<void> => {
  switch (ev._tag) {
    case "RunStart":
      return Console.error(`  · run-start (total=${ev.total})`);
    case "RunEnd":
      return Console.error(
        `  · run-end (pass=${ev.pass} fail=${ev.fail})`,
      );
    case "Result":
      return ev.status === "PASS"
        ? Effect.void // keep PASS quiet in the live trace
        : Console.error(
            `  · ${ev.status} ${ev.id} ${ev.detail ? `— ${ev.detail}` : ""}`,
          );
    case "RawFailure":
      return Console.error(`  · [raw] ${ev.signal}`);
  }
};

/** Finalize: build report, write JSON, print summary, return healthy flag. */
const finalize = (
  events: ReadonlyArray<SpecEvent>,
): Effect.Effect<boolean> =>
  Effect.gen(function* () {
    const report = aggregate(events);
    const json = toJsonReport(report);

    yield* Effect.tryPromise({
      try: async () => {
        await Bun.write(REPORT_PATH, JSON.stringify(json, null, 2) + "\n");
      },
      catch: (e) => e,
    }).pipe(
      Effect.catchAll((e) =>
        Console.error(`WARN: could not write ${REPORT_PATH}: ${String(e)}`),
      ),
    );

    yield* Console.log("");
    yield* Console.log(renderHumanSummary(report));
    yield* Console.log(`\nJSON report written to: ${REPORT_PATH}`);

    return isHealthy(report);
  });

/** ----- live mode --------------------------------------------------------- */

const liveMode = Effect.gen(function* () {
  const config = yield* RokuConfig;

  yield* Console.error(
    `Connecting to Roku debug console at ${config.host}:${config.port} …`,
  );
  yield* Console.error(
    "  (Ctrl-C to stop. The run ends automatically on the run-end event.)",
  );

  // Retry connection with exponential backoff. We rebuild the stream on each
  // attempt; a SocketError before any events triggers a retry.
  const backoff = Schedule.exponential(Duration.seconds(1), 2.0).pipe(
    Schedule.either(Schedule.spaced(Duration.seconds(30))), // cap the gap
    Schedule.tapInput((err: SocketError | FileReadError) =>
      Console.error(`  retrying after error: ${describeErr(err)}`),
    ),
  );

  const lines = connectLineSource(config);
  const events = toEvents(lines);

  const collected = yield* collectEvents(events, { trace: true }).pipe(
    Effect.retry(backoff),
    Effect.catchAll((err) =>
      // Backoff schedule never gives up by itself; this only fires if retry's
      // policy were finite. Surface the failure and finalize with what we have.
      Console.error(`Giving up: ${describeErr(err)}`).pipe(
        Effect.as([] as ReadonlyArray<SpecEvent>),
      ),
    ),
  );

  return yield* finalize(collected);
});

/** ----- replay mode ------------------------------------------------------- */

const replayMode = (filePath: string) =>
  Effect.gen(function* () {
    yield* Console.error(`Replaying captured console log: ${filePath}`);

    const lines = fileLineSource(filePath);
    const events = toEvents(lines);

    const collected = yield* collectEvents(events, { trace: false }).pipe(
      Effect.catchAll((err) =>
        Console.error(`Failed to read replay file: ${describeErr(err)}`).pipe(
          Effect.as([] as ReadonlyArray<SpecEvent>),
        ),
      ),
    );

    return yield* finalize(collected);
  });

const describeErr = (err: SocketError | FileReadError | unknown): string => {
  if (err instanceof SocketError) return err.reason;
  if (err instanceof FileReadError)
    return `${err.path}: ${String((err.cause as Error)?.message ?? err.cause)}`;
  return String(err);
};

/** ----- CLI --------------------------------------------------------------- */

interface Cli {
  readonly mode: "live" | "replay";
  readonly file?: string;
}

const parseArgv = (argv: ReadonlyArray<string>): Cli | { error: string } => {
  // Accept:  live | replay <file> | --mode=live | --mode replay <file>
  const args = [...argv];
  let mode: "live" | "replay" | undefined;
  let file: string | undefined;

  for (let i = 0; i < args.length; i++) {
    const a = args[i]!;
    if (a === "--mode") {
      mode = args[++i] as "live" | "replay" | undefined;
    } else if (a.startsWith("--mode=")) {
      mode = a.slice("--mode=".length) as "live" | "replay";
    } else if (a === "live" || a === "replay") {
      mode = a;
    } else if (!a.startsWith("-")) {
      file = a; // positional → replay file
    }
  }

  if (mode === undefined) {
    return {
      error:
        "Usage:\n  bun run listen                 (live mode)\n  bun run replay <logfile>       (replay mode)\n  bun run src/main.ts --mode=live\n  bun run src/main.ts --mode=replay <logfile>",
    };
  }
  if (mode === "replay" && file === undefined) {
    return { error: "replay mode requires a log file path argument" };
  }
  return file !== undefined ? { mode, file } : { mode };
};

const program = Effect.gen(function* () {
  const cli = parseArgv(process.argv.slice(2));
  if ("error" in cli) {
    yield* Console.error(cli.error);
    return 2;
  }

  const healthy =
    cli.mode === "live"
      ? yield* liveMode
      : yield* replayMode(cli.file!);

  return healthy ? 0 : 1;
});

// Run, mapping the returned exit code onto the process.
Effect.runPromise(program)
  .then((code) => {
    process.exitCode = code;
  })
  .catch((err) => {
    console.error("Fatal:", err);
    process.exitCode = 1;
  });

// Keep these exports so tests / external callers can reuse the wiring.
export { toEvents, collectEvents, finalize, parseArgv };
