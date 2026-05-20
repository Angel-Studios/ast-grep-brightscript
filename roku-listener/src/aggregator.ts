import type { SpecEvent, SpecStatus } from "./protocol.ts";

/** A single reported construct in the final report. */
export interface ReportEntry {
  readonly id: string;
  readonly kind: string;
  readonly status: SpecStatus;
  readonly detail?: string;
}

/** A generic Roku failure signal surfaced during the run. */
export interface RawFailureEntry {
  readonly signal: string;
  readonly raw: string;
}

export interface ReportTotals {
  readonly pass: number;
  readonly fail: number;
  readonly compile_error: number;
  readonly crash: number;
  /** Statuses that were not one of the known four (defensive; should be 0). */
  readonly unknown: number;
  /** Count of ids declared in run-start total but never reported. */
  readonly missing: number;
}

export interface Report {
  /** Protocol version observed (from result lines), or null if none seen. */
  readonly protocolVersion: number | null;
  /** Did we observe a run-start event, and what total did it declare? */
  readonly declaredTotal: number | null;
  /** Did the run finish (run-end seen) and the pass/fail it self-reported? */
  readonly runEnd: { readonly pass: number; readonly fail: number } | null;
  readonly totals: ReportTotals;
  /** All reported results, in first-seen order. Last status for an id wins. */
  readonly entries: ReadonlyArray<ReportEntry>;
  /**
   * Ids the harness declared via run-start `total` but never reported. We can
   * only know specific ids if run-start enumerated them; the plain protocol only
   * gives a COUNT, so `missing` here is derived as a count and the id list is
   * best-effort (empty unless a future protocol enumerates ids).
   */
  readonly missingIds: ReadonlyArray<string>;
  /** Generic Roku failure signals seen in the raw stream. */
  readonly rawFailures: ReadonlyArray<RawFailureEntry>;
}

const statusKey = (s: SpecStatus): keyof Omit<ReportTotals, "missing"> => {
  switch (s) {
    case "PASS":
      return "pass";
    case "FAIL":
      return "fail";
    case "COMPILE_ERROR":
      return "compile_error";
    case "CRASH":
      return "crash";
    default:
      return "unknown";
  }
};

/**
 * Fold a sequence of {@link SpecEvent}s into a {@link Report}.
 *
 * Pure: deterministic given its input, no I/O. The same function backs both live
 * and replay modes, so they cannot diverge.
 *
 * Semantics:
 *  - Result lines are keyed by `id`; a later result for the same id REPLACES the
 *    earlier one (a re-run / retry wins).
 *  - `declaredTotal` comes from the last run-start event.
 *  - `missing` = max(0, declaredTotal - distinctReportedIds) once we know the
 *    declared total. If no run-start was seen, missing = 0.
 *  - RawFailures are collected separately and do NOT count toward id totals, but
 *    they DO make the run unhealthy (see `isHealthy`).
 */
export const aggregate = (events: Iterable<SpecEvent>): Report => {
  // Preserve first-seen order while letting later results overwrite.
  const order: string[] = [];
  const byId = new Map<string, ReportEntry>();
  const rawFailures: RawFailureEntry[] = [];

  let protocolVersion: number | null = null;
  let declaredTotal: number | null = null;
  let runEnd: { pass: number; fail: number } | null = null;

  for (const ev of events) {
    switch (ev._tag) {
      case "Result": {
        if (protocolVersion === null) protocolVersion = ev.v;
        if (!byId.has(ev.id)) order.push(ev.id);
        byId.set(ev.id, {
          id: ev.id,
          kind: ev.kind,
          status: ev.status,
          ...(ev.detail !== undefined ? { detail: ev.detail } : {}),
        });
        break;
      }
      case "RunStart": {
        declaredTotal = ev.total;
        break;
      }
      case "RunEnd": {
        runEnd = { pass: ev.pass, fail: ev.fail };
        break;
      }
      case "RawFailure": {
        rawFailures.push({ signal: ev.signal, raw: ev.raw });
        break;
      }
    }
  }

  const entries: ReportEntry[] = order.map((id) => byId.get(id)!);

  const counts = {
    pass: 0,
    fail: 0,
    compile_error: 0,
    crash: 0,
    unknown: 0,
  };
  for (const e of entries) {
    counts[statusKey(e.status)]++;
  }

  const reportedCount = entries.length;
  const missing =
    declaredTotal === null ? 0 : Math.max(0, declaredTotal - reportedCount);

  const totals: ReportTotals = {
    ...counts,
    missing,
  };

  return {
    protocolVersion,
    declaredTotal,
    runEnd,
    totals,
    entries,
    missingIds: [], // plain protocol only enumerates a count; reserved for future
    rawFailures,
  };
};

/**
 * A run is healthy iff:
 *  - at least one result was reported,
 *  - every reported result is PASS,
 *  - nothing is missing,
 *  - and no generic Roku failure signal fired.
 */
export const isHealthy = (report: Report): boolean => {
  const t = report.totals;
  const anyReported = report.entries.length > 0;
  const allPass =
    t.fail === 0 && t.compile_error === 0 && t.crash === 0 && t.unknown === 0;
  return (
    anyReported &&
    allPass &&
    t.missing === 0 &&
    report.rawFailures.length === 0
  );
};
