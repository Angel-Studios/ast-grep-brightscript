/**
 * The Roku spec-result protocol.
 *
 * The BrightScript test harness prints one structured line per construct it
 * exercises to its debug console. The console is otherwise full of boot noise,
 * `print` output, and (on failure) Roku's own diagnostics. We parse tolerantly.
 *
 * Result lines:
 *   ##SPEC## v=1 id=<dotted.id> kind=<EBNFRuleName> status=<PASS|FAIL|COMPILE_ERROR|CRASH> detail="<optional>"
 *
 * Run-framing events:
 *   ##SPEC## event=run-start total=<int>
 *   ##SPEC## event=run-end pass=<int> fail=<int>
 *
 * Generic Roku failure signals (no ##SPEC## prefix) we also surface as RawFailure:
 *   "Syntax Error", "Compile error", "runtime error", "BACKTRACE",
 *   and the debugger prompt "Brightscript Debugger>".
 */

export const SPEC_PREFIX = "##SPEC##";

/** The set of statuses a single spec result may report. */
export const STATUSES = ["PASS", "FAIL", "COMPILE_ERROR", "CRASH"] as const;
export type SpecStatus = (typeof STATUSES)[number];

export const isSpecStatus = (s: string): s is SpecStatus =>
  (STATUSES as readonly string[]).includes(s);

/** One construct's pass/fail result. */
export interface SpecResult {
  readonly _tag: "Result";
  /** Protocol version (default 1 if absent / unparseable). */
  readonly v: number;
  /** Dotted id, e.g. "expr.binary.add". */
  readonly id: string;
  /** The EBNF rule name the construct exercises, e.g. "BinaryExpression". */
  readonly kind: string;
  readonly status: SpecStatus;
  /** Optional human detail (quoted in the wire format, may contain spaces/=). */
  readonly detail?: string;
  /** The original raw line, preserved for diagnostics. */
  readonly raw: string;
}

/** `##SPEC## event=run-start total=N` */
export interface RunStart {
  readonly _tag: "RunStart";
  readonly total: number;
  readonly raw: string;
}

/** `##SPEC## event=run-end pass=N fail=N` */
export interface RunEnd {
  readonly _tag: "RunEnd";
  readonly pass: number;
  readonly fail: number;
  readonly raw: string;
}

/**
 * A generic Roku failure signal detected in the raw stream that did NOT carry a
 * ##SPEC## prefix (e.g. a compile error, runtime error, backtrace, or the
 * debugger prompt). These indicate a crash/compile failure even when the harness
 * never got a chance to emit a ##SPEC## line.
 */
export interface RawFailure {
  readonly _tag: "RawFailure";
  /** Which signal substring fired. */
  readonly signal: RawFailureSignal;
  readonly raw: string;
}

export type SpecEvent = SpecResult | RunStart | RunEnd | RawFailure;

/** Generic Roku failure substrings, matched case-insensitively. */
export const RAW_FAILURE_SIGNALS = [
  "Syntax Error",
  "Compile error",
  "runtime error",
  "BACKTRACE",
  "Brightscript Debugger>",
] as const;
export type RawFailureSignal = (typeof RAW_FAILURE_SIGNALS)[number];
