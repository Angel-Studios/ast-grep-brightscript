import { Effect, Stream } from "effect";
import * as net from "node:net";
import type { RokuConfig } from "./config.ts";

/**
 * Split a stream of raw string fragments into a stream of complete lines,
 * buffering an incomplete tail across fragments. The trailing line (one lacking
 * a terminating newline) IS emitted when the source ends.
 *
 * Roku consoles emit \r\n and bare \n; we normalize by trimming a trailing \r.
 *
 * Implementation: a stateful `mapAccum` carries the partial tail between
 * fragments and emits the complete lines from each fragment. To flush the final
 * tail we append a sentinel newline fragment to the END of the source, then
 * drop the single empty string it produces.
 */
export const splitLines = <E, R>(
  source: Stream.Stream<string, E, R>,
): Stream.Stream<string, E, R> =>
  source.pipe(
    // Append a sentinel newline so a final unterminated line is flushed.
    (s) => Stream.concat(s, Stream.make("\n")),
    Stream.mapAccum("", (carry: string, fragment: string) => {
      const combined = carry + fragment;
      const parts = combined.split("\n");
      // The last element is the (possibly empty) incomplete tail.
      const tail = parts.pop() ?? "";
      const lines = parts.map((l) => (l.endsWith("\r") ? l.slice(0, -1) : l));
      return [tail, lines] as const;
    }),
    Stream.flattenIterables,
  );

/**
 * A live line source: connects to the Roku debug console over raw TCP and
 * streams console lines. The socket is wrapped with `Stream.async`, whose
 * register callback returns a cleanup `Effect` — so the socket is destroyed when
 * the stream's scope closes (including on interruption / Ctrl-C).
 *
 * Connection errors (ECONNREFUSED etc.) and unexpected closes surface as a
 * `SocketError` in the stream's error channel so callers can retry with a
 * Schedule.
 */
export class SocketError {
  readonly _tag = "SocketError";
  constructor(
    readonly reason: string,
    readonly code?: string | undefined,
    readonly cause?: unknown,
  ) {}
}

export const connectLineSource = (
  config: RokuConfig,
): Stream.Stream<string, SocketError> => {
  const raw = Stream.async<string, SocketError>((emit) => {
    let settled = false;

    const socket = net.createConnection({
      host: config.host,
      port: config.port,
    });

    socket.setEncoding("utf8");

    socket.on("connect", () => {
      settled = true;
    });

    socket.on("data", (data: string) => {
      // emit a single value (Effect wraps it in a chunk for us)
      void emit.single(data);
    });

    socket.on("error", (err: NodeJS.ErrnoException) => {
      void emit.fail(new SocketError(friendlyConnError(err, config), err.code, err));
    });

    socket.on("close", (hadError: boolean) => {
      if (hadError) return; // an 'error' was already emitted
      if (!settled) {
        // Closed before ever connecting and without a distinct error event.
        void emit.fail(
          new SocketError(
            `Connection to ${config.host}:${config.port} closed before it was established. ` +
              "Confirm Developer Mode is enabled and no other debugger is attached.",
          ),
        );
        return;
      }
      // Normal end of stream after the device dropped the console.
      void emit.end();
    });

    // Cleanup finalizer: runs on scope close / interruption / completion.
    return Effect.sync(() => {
      socket.removeAllListeners();
      socket.destroy();
    });
  });

  return splitLines(raw);
};

const friendlyConnError = (
  err: NodeJS.ErrnoException,
  config: RokuConfig,
): string => {
  const where = `${config.host}:${config.port}`;
  switch (err.code) {
    case "ECONNREFUSED":
      return (
        `Connection refused to ${where}. ` +
        `The Roku debug console allows only ONE connection at a time — ` +
        `another debugger/listener (e.g. a 'telnet' session) may be attached. ` +
        `Also confirm Developer Mode is ENABLED on the device.`
      );
    case "EHOSTUNREACH":
    case "ENETUNREACH":
      return `Host unreachable: ${where}. Check the device is on and on the same network.`;
    case "ETIMEDOUT":
      return `Connection to ${where} timed out.`;
    case "ECONNRESET":
      return `Connection to ${where} was reset by the device.`;
    default:
      return `Failed to connect to ${where}: ${err.message}`;
  }
};

/**
 * A replay line source: reads a captured console log file and streams its lines
 * through the SAME splitLines pipeline. Lets the whole tool be exercised without
 * a device.
 */
export const fileLineSource = (
  path: string,
): Stream.Stream<string, FileReadError> => {
  const read = Effect.tryPromise({
    try: () => Bun.file(path).text(),
    catch: (e) => new FileReadError(path, e),
  });

  return splitLines(Stream.fromEffect(read));
};

export class FileReadError {
  readonly _tag = "FileReadError";
  constructor(
    readonly path: string,
    readonly cause: unknown,
  ) {}
}
