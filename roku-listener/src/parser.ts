import {
  SPEC_PREFIX,
  RAW_FAILURE_SIGNALS,
  isSpecStatus,
  type SpecEvent,
  type SpecResult,
  type RunStart,
  type RunEnd,
  type RawFailure,
  type RawFailureSignal,
} from "./protocol.ts";

/**
 * Tokenize the key=value pairs that follow the `##SPEC##` prefix.
 *
 * Rules:
 *  - pairs are separated by runs of whitespace;
 *  - a value may be double-quoted, in which case it may contain spaces and `=`;
 *  - quoted values support `\"` and `\\` escapes;
 *  - bare values run until the next whitespace;
 *  - keys may appear in any order; later duplicates win.
 *
 * Pure and allocation-light. Returns a plain record of string values.
 */
export const tokenizeKv = (body: string): Record<string, string> => {
  const out: Record<string, string> = {};
  let i = 0;
  const n = body.length;

  const isWs = (c: string) => c === " " || c === "\t" || c === "\r";

  while (i < n) {
    // skip leading whitespace
    while (i < n && isWs(body[i]!)) i++;
    if (i >= n) break;

    // read key (up to '=' or whitespace)
    let key = "";
    while (i < n && body[i] !== "=" && !isWs(body[i]!)) {
      key += body[i];
      i++;
    }

    // a bare token with no '=' is ignored (not a kv pair)
    if (i >= n || body[i] !== "=") {
      // skip to next whitespace boundary so we don't loop forever
      while (i < n && !isWs(body[i]!)) i++;
      continue;
    }

    // consume '='
    i++;

    let value = "";
    if (i < n && body[i] === '"') {
      // quoted value
      i++; // consume opening quote
      while (i < n) {
        const c = body[i]!;
        if (c === "\\" && i + 1 < n) {
          const next = body[i + 1]!;
          if (next === '"' || next === "\\") {
            value += next;
            i += 2;
            continue;
          }
        }
        if (c === '"') {
          i++; // consume closing quote
          break;
        }
        value += c;
        i++;
      }
    } else {
      // bare value: until whitespace
      while (i < n && !isWs(body[i]!)) {
        value += body[i];
        i++;
      }
    }

    if (key.length > 0) out[key] = value;
  }

  return out;
};

const toInt = (s: string | undefined, fallback: number): number => {
  if (s === undefined) return fallback;
  const n = Number.parseInt(s, 10);
  return Number.isFinite(n) ? n : fallback;
};

/**
 * Detect a generic Roku failure signal in a raw line (no ##SPEC## prefix).
 * Matched case-insensitively. Returns the canonical signal or null.
 */
export const detectRawFailure = (line: string): RawFailureSignal | null => {
  const lower = line.toLowerCase();
  for (const sig of RAW_FAILURE_SIGNALS) {
    if (lower.includes(sig.toLowerCase())) return sig;
  }
  return null;
};

/**
 * Parse a single console line into a typed {@link SpecEvent}, or `null` if the
 * line carries no meaningful signal.
 *
 * Pure: no I/O, no globals. The single source of truth for the wire protocol.
 */
export const parseSpecLine = (line: string): SpecEvent | null => {
  const idx = line.indexOf(SPEC_PREFIX);

  if (idx === -1) {
    // No ##SPEC## marker — still surface generic Roku failure signals.
    const signal = detectRawFailure(line);
    if (signal !== null) {
      return {
        _tag: "RawFailure",
        signal,
        raw: line,
      } satisfies RawFailure;
    }
    return null;
  }

  const body = line.slice(idx + SPEC_PREFIX.length);
  const kv = tokenizeKv(body);

  // Run-framing events are distinguished by the `event` key.
  const event = kv["event"];
  if (event === "run-start") {
    return {
      _tag: "RunStart",
      total: toInt(kv["total"], 0),
      raw: line,
    } satisfies RunStart;
  }
  if (event === "run-end") {
    return {
      _tag: "RunEnd",
      pass: toInt(kv["pass"], 0),
      fail: toInt(kv["fail"], 0),
      raw: line,
    } satisfies RunEnd;
  }

  // Otherwise it should be a result line. Require at least an id + status to be
  // meaningful; tolerate missing kind.
  const id = kv["id"];
  const statusRaw = kv["status"];
  if (id === undefined || statusRaw === undefined) {
    // Malformed ##SPEC## line we can't classify. Treat as a raw failure only if
    // it also matches a generic signal, else ignore.
    const signal = detectRawFailure(line);
    if (signal !== null) {
      return { _tag: "RawFailure", signal, raw: line } satisfies RawFailure;
    }
    return null;
  }

  const status = isSpecStatus(statusRaw) ? statusRaw : "CRASH";

  const result: SpecResult = {
    _tag: "Result",
    v: toInt(kv["v"], 1),
    id,
    kind: kv["kind"] ?? "unknown",
    status,
    raw: line,
    ...(kv["detail"] !== undefined ? { detail: kv["detail"] } : {}),
  };

  return result;
};
