import { describe, expect, test } from "bun:test";
import * as path from "node:path";
import { Effect, Stream } from "effect";
import { parseSpecLine } from "../src/parser.ts";
import { aggregate, isHealthy } from "../src/aggregator.ts";
import { toJsonReport } from "../src/report.ts";
import { fileLineSource } from "../src/lineSource.ts";
import type { SpecEvent } from "../src/protocol.ts";

const FIXTURE = path.resolve(
  import.meta.dir,
  "..",
  "fixtures",
  "sample-console.log",
);

/** Parse a multiline blob the way replay mode would (line by line). */
const eventsFromText = (text: string): SpecEvent[] =>
  text
    .split("\n")
    .map(parseSpecLine)
    .filter((e): e is SpecEvent => e !== null);

describe("aggregate", () => {
  test("counts statuses and computes missing from declared total", () => {
    const text = [
      "##SPEC## event=run-start total=4",
      "##SPEC## id=a kind=K status=PASS",
      "##SPEC## id=b kind=K status=FAIL detail=\"boom\"",
      "##SPEC## id=c kind=K status=PASS",
      // declared 4, reported 3 → missing 1
      "##SPEC## event=run-end pass=2 fail=1",
    ].join("\n");

    const report = aggregate(eventsFromText(text));
    expect(report.declaredTotal).toBe(4);
    expect(report.entries.length).toBe(3);
    expect(report.totals).toMatchObject({
      pass: 2,
      fail: 1,
      compile_error: 0,
      crash: 0,
      missing: 1,
    });
    expect(report.runEnd).toEqual({ pass: 2, fail: 1 });
    expect(isHealthy(report)).toBe(false);
  });

  test("later result for the same id overwrites the earlier one", () => {
    const text = [
      "##SPEC## id=x kind=K status=FAIL detail=\"first try\"",
      "##SPEC## id=x kind=K status=PASS",
    ].join("\n");
    const report = aggregate(eventsFromText(text));
    expect(report.entries.length).toBe(1);
    expect(report.entries[0]!.status).toBe("PASS");
    expect(report.totals.fail).toBe(0);
    expect(report.totals.pass).toBe(1);
  });

  test("collects raw failures separately and marks unhealthy", () => {
    const text = [
      "##SPEC## id=a kind=K status=PASS",
      "BACKTRACE:",
      "Brightscript Debugger>",
    ].join("\n");
    const report = aggregate(eventsFromText(text));
    expect(report.entries.length).toBe(1);
    expect(report.totals.pass).toBe(1);
    expect(report.rawFailures.length).toBe(2);
    expect(isHealthy(report)).toBe(false);
  });

  test("all-pass with no missing and no raw failures is healthy", () => {
    const text = [
      "##SPEC## event=run-start total=2",
      "##SPEC## id=a kind=K status=PASS",
      "##SPEC## id=b kind=K status=PASS",
      "##SPEC## event=run-end pass=2 fail=0",
    ].join("\n");
    const report = aggregate(eventsFromText(text));
    expect(report.totals.missing).toBe(0);
    expect(isHealthy(report)).toBe(true);
  });

  test("empty input is not healthy (nothing reported)", () => {
    expect(isHealthy(aggregate([]))).toBe(false);
  });
});

describe("replay over the fixture (end-to-end, no device)", () => {
  test("fileLineSource + parser + aggregator yields the expected report", async () => {
    const events = await Effect.runPromise(
      fileLineSource(FIXTURE).pipe(
        Stream.map(parseSpecLine),
        Stream.filter((e): e is SpecEvent => e !== null),
        Stream.runCollect,
      ),
    ).then((chunk) => Array.from(chunk));

    const report = aggregate(events);

    // 11 distinct ids reported, declared total 12 → 1 missing.
    expect(report.declaredTotal).toBe(12);
    expect(report.entries.length).toBe(11);
    expect(report.totals.missing).toBe(1);

    expect(report.totals.pass).toBe(8);
    expect(report.totals.fail).toBe(1);
    expect(report.totals.compile_error).toBe(1);
    expect(report.totals.crash).toBe(1);

    // run-end self-report from the fixture
    expect(report.runEnd).toEqual({ pass: 8, fail: 1 });

    // detail with escaped quotes round-trips
    const strLit = report.entries.find((e) => e.id === "literals.string");
    expect(strLit?.detail).toContain('"quoted"');

    // raw failure sequence (Syntax Error, runtime error, BACKTRACE, Debugger>)
    expect(report.rawFailures.length).toBeGreaterThanOrEqual(3);
    const signals = new Set(report.rawFailures.map((f) => f.signal));
    expect(signals.has("BACKTRACE")).toBe(true);
    expect(signals.has("Brightscript Debugger>")).toBe(true);

    expect(isHealthy(report)).toBe(false);

    // JSON report shape is stable
    const json = toJsonReport(report);
    expect(json.schema).toBe("roku-listener/report@1");
    expect(json.healthy).toBe(false);
    expect(json.reportedCount).toBe(11);
  });
});
