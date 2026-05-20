import { describe, expect, test } from "bun:test";
import {
  parseSpecLine,
  tokenizeKv,
  detectRawFailure,
} from "../src/parser.ts";

describe("tokenizeKv", () => {
  test("parses simple bare pairs", () => {
    expect(tokenizeKv(" a=1 b=two c=3 ")).toEqual({
      a: "1",
      b: "two",
      c: "3",
    });
  });

  test("parses quoted values containing spaces and =", () => {
    expect(tokenizeKv('id=x detail="hello world = ok"')).toEqual({
      id: "x",
      detail: "hello world = ok",
    });
  });

  test("handles escaped quotes and backslashes inside detail", () => {
    expect(
      tokenizeKv('detail="round-tripped \\"quoted\\" value"'),
    ).toEqual({ detail: 'round-tripped "quoted" value' });
  });

  test("later duplicate keys win", () => {
    expect(tokenizeKv("k=1 k=2")).toEqual({ k: "2" });
  });

  test("ignores bare tokens with no '='", () => {
    expect(tokenizeKv("event run-start total=5")).toEqual({ total: "5" });
  });

  test("is order independent", () => {
    expect(tokenizeKv("status=PASS id=a kind=K v=1")).toEqual({
      status: "PASS",
      id: "a",
      kind: "K",
      v: "1",
    });
  });
});

describe("parseSpecLine — results", () => {
  test("parses a PASS result", () => {
    const ev = parseSpecLine(
      "##SPEC## v=1 id=literals.integer kind=IntegerLiteral status=PASS",
    );
    expect(ev).toMatchObject({
      _tag: "Result",
      v: 1,
      id: "literals.integer",
      kind: "IntegerLiteral",
      status: "PASS",
    });
    expect((ev as any).detail).toBeUndefined();
  });

  test("parses a FAIL result with quoted detail (spaces and =)", () => {
    const ev = parseSpecLine(
      '##SPEC## v=1 id=operators.intdiv kind=BinaryExpression status=FAIL detail="expected 3 got 3.5 (= integer divide)"',
    );
    expect(ev).toMatchObject({
      _tag: "Result",
      id: "operators.intdiv",
      kind: "BinaryExpression",
      status: "FAIL",
      detail: "expected 3 got 3.5 (= integer divide)",
    });
  });

  test("parses COMPILE_ERROR", () => {
    const ev = parseSpecLine(
      '##SPEC## id=functions.anon kind=AnonymousFunction status=COMPILE_ERROR detail="x"',
    );
    expect((ev as any).status).toBe("COMPILE_ERROR");
  });

  test("tolerates ##SPEC## embedded in surrounding noise", () => {
    const ev = parseSpecLine(
      "12:33:01.123 [dev] ##SPEC## id=a kind=K status=PASS  trailing junk",
    );
    expect(ev).toMatchObject({ _tag: "Result", id: "a", status: "PASS" });
  });

  test("keys may appear in any order", () => {
    const ev = parseSpecLine(
      "##SPEC## status=PASS kind=K id=z v=1",
    );
    expect(ev).toMatchObject({ _tag: "Result", id: "z", status: "PASS" });
  });

  test("defaults kind to 'unknown' when absent", () => {
    const ev = parseSpecLine("##SPEC## id=a status=PASS");
    expect((ev as any).kind).toBe("unknown");
  });

  test("unknown status coerces to CRASH (defensive)", () => {
    const ev = parseSpecLine("##SPEC## id=a status=WEIRD");
    expect((ev as any).status).toBe("CRASH");
  });

  test("defaults v to 1 when absent or unparseable", () => {
    const ev = parseSpecLine("##SPEC## id=a status=PASS v=notanumber");
    expect((ev as any).v).toBe(1);
  });

  test("malformed ##SPEC## without id/status returns null", () => {
    expect(parseSpecLine("##SPEC## hello there")).toBeNull();
  });
});

describe("parseSpecLine — run framing", () => {
  test("parses run-start", () => {
    const ev = parseSpecLine("##SPEC## event=run-start total=12");
    expect(ev).toEqual({
      _tag: "RunStart",
      total: 12,
      raw: "##SPEC## event=run-start total=12",
    });
  });

  test("parses run-end", () => {
    const ev = parseSpecLine("##SPEC## event=run-end pass=8 fail=1");
    expect(ev).toMatchObject({ _tag: "RunEnd", pass: 8, fail: 1 });
  });
});

describe("parseSpecLine — raw failure signals", () => {
  test.each([
    ["Syntax Error", "'Syntax Error. (compile error &h02) in pkg:/x.brs(1)"],
    ["Compile error", "got a Compile error somewhere"],
    ["runtime error", "runtime error &h28: Invalid number of array elements"],
    ["BACKTRACE", "BACKTRACE:"],
    ["Brightscript Debugger>", "Brightscript Debugger> "],
  ])("detects %s", (signal, line) => {
    const ev = parseSpecLine(line);
    expect(ev).toMatchObject({ _tag: "RawFailure", signal });
  });

  test("detectRawFailure is case-insensitive", () => {
    expect(detectRawFailure("SYNTAX ERROR here")).toBe("Syntax Error");
    expect(detectRawFailure("nothing interesting")).toBeNull();
  });

  test("plain noise returns null", () => {
    expect(parseSpecLine("[beacon.signal] AppLaunchInitiate")).toBeNull();
    expect(parseSpecLine("?some print output")).toBeNull();
    expect(parseSpecLine("")).toBeNull();
  });
});
