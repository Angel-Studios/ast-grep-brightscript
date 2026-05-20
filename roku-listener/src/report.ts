import type { Report, ReportEntry } from "./aggregator.ts";
import { isHealthy } from "./aggregator.ts";

/** The JSON shape we persist to out/report.json. Stable, machine-readable. */
export interface JsonReport {
  readonly schema: "roku-listener/report@1";
  readonly generatedAt: string;
  readonly healthy: boolean;
  readonly protocolVersion: number | null;
  readonly declaredTotal: number | null;
  readonly runEnd: Report["runEnd"];
  readonly totals: Report["totals"];
  readonly reportedCount: number;
  readonly entries: ReadonlyArray<ReportEntry>;
  readonly missingIds: ReadonlyArray<string>;
  readonly rawFailures: Report["rawFailures"];
}

export const toJsonReport = (report: Report): JsonReport => ({
  schema: "roku-listener/report@1",
  generatedAt: new Date().toISOString(),
  healthy: isHealthy(report),
  protocolVersion: report.protocolVersion,
  declaredTotal: report.declaredTotal,
  runEnd: report.runEnd,
  totals: report.totals,
  reportedCount: report.entries.length,
  entries: report.entries,
  missingIds: report.missingIds,
  rawFailures: report.rawFailures,
});

const PROBLEM_STATUSES = new Set(["FAIL", "COMPILE_ERROR", "CRASH"]);

/**
 * Render a concise, plain-text human summary suitable for stdout. No ANSI color
 * (logs are often captured to files); uses [ok]/[X] markers instead.
 */
export const renderHumanSummary = (report: Report): string => {
  const t = report.totals;
  const lines: string[] = [];

  lines.push("==================== Roku Spec Run Summary ====================");
  if (report.protocolVersion !== null) {
    lines.push(`protocol v${report.protocolVersion}`);
  }
  if (report.declaredTotal !== null) {
    lines.push(`declared total : ${report.declaredTotal}`);
  }
  lines.push(`reported       : ${report.entries.length}`);
  lines.push(
    `  PASS=${t.pass}  FAIL=${t.fail}  COMPILE_ERROR=${t.compile_error}  CRASH=${t.crash}` +
      (t.unknown > 0 ? `  UNKNOWN=${t.unknown}` : ""),
  );
  lines.push(`missing        : ${t.missing}`);
  if (report.runEnd !== null) {
    lines.push(
      `run-end self-report : pass=${report.runEnd.pass} fail=${report.runEnd.fail}`,
    );
  } else {
    lines.push("run-end self-report : (none — run did not finish cleanly)");
  }

  const problems = report.entries.filter((e) => PROBLEM_STATUSES.has(e.status));
  if (problems.length > 0) {
    lines.push("");
    lines.push("--- Problem rows ---------------------------------------------");
    const idW = Math.max(2, ...problems.map((p) => p.id.length));
    const kindW = Math.max(4, ...problems.map((p) => p.kind.length));
    for (const p of problems) {
      const detail = p.detail ? `  ${p.detail}` : "";
      lines.push(
        `[X] ${p.status.padEnd(13)} ${p.id.padEnd(idW)}  ${p.kind.padEnd(kindW)}${detail}`,
      );
    }
  }

  if (report.rawFailures.length > 0) {
    lines.push("");
    lines.push("--- Raw failure signals (no ##SPEC## line) -------------------");
    for (const f of report.rawFailures) {
      lines.push(`[!] ${f.signal}: ${truncate(f.raw.trim(), 100)}`);
    }
  }

  lines.push("");
  const healthy = isHealthy(report);
  lines.push(
    healthy
      ? "RESULT: [ok] HEALTHY — all reported PASS, nothing missing, no raw failures."
      : "RESULT: [X] UNHEALTHY — see problems above.",
  );
  lines.push("===============================================================");

  return lines.join("\n");
};

const truncate = (s: string, max: number): string =>
  s.length <= max ? s : s.slice(0, max - 1) + "…";
