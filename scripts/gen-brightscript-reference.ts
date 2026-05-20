#!/usr/bin/env bun
/**
 * gen-brightscript-reference.ts
 *
 * Generates the agent-facing BrightScript / BrighterScript syntax reference that
 * the `write-brightscript` skill bundles, from this repo's source-of-truth
 * ledgers. This is how the skill (and, after a sync, the copy embedded in peer
 * apps) is kept current with the language as validated here.
 *
 *   Sources →  grammar/DEVICE_FACTS.md   (device-confirmed verdicts / gotchas)
 *              grammar/BSC_DRIFT.md       (where bsc disagrees with the device)
 *              grammar/coverage.json      (the construct taxonomy + valid snippets)
 *   Output  →  .claude/skills/write-brightscript/reference.md
 *
 * The output carries a provenance header stamped with the sha256 of each source;
 * grammar/check_reference.py fails if those drift (i.e. you changed a ledger but
 * forgot to re-run this). Run: `npm run gen:reference`.
 */
import { createHash } from "node:crypto";
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join, dirname } from "node:path";

const REPO = join(import.meta.dir, "..");
const SOURCES = [
  "grammar/DEVICE_FACTS.md",
  "grammar/BSC_DRIFT.md",
  "grammar/coverage.json",
  "grammar/brightscript.ebnf",
  "grammar/brighterscript.ebnf",
];
const OUT = ".claude/skills/write-brightscript/reference.md";

const read = (rel: string) => readFileSync(join(REPO, rel), "utf8");
const sha = (rel: string) =>
  createHash("sha256").update(readFileSync(join(REPO, rel))).digest("hex");

function bscVersion(): string {
  try {
    return JSON.parse(read("node_modules/brighterscript/package.json")).version;
  } catch {
    return "unknown";
  }
}

/** Strip markdown links/emphasis/code-fences down to plain text. */
function plain(s: string): string {
  return s
    .replace(/\[([^\]]+)\]\([^)]*\)/g, "$1") // [text](url) -> text
    .replace(/[`*]/g, "")
    .replace(/\\\|/g, "|")
    .replace(/\s+/g, " ")
    .trim();
}

const firstSentence = (s: string) => {
  const m = s.match(/^.*?[.;](?:\s|$)/);
  return plain(m ? m[0] : s).replace(/[.;]\s*$/, "");
};

/** Parse a GitHub-style markdown table that follows a heading. */
function tableRows(md: string, headingRe: RegExp): string[][] {
  const lines = md.split("\n");
  let i = lines.findIndex((l) => headingRe.test(l));
  if (i < 0) return [];
  while (i < lines.length && !/^\s*\|/.test(lines[i])) i++;
  const rows: string[][] = [];
  let started = false;
  for (let j = i; j < lines.length; j++) {
    const l = lines[j];
    if (!/^\s*\|/.test(l)) {
      if (started) break;
      continue;
    }
    const cells = l
      .trim()
      .replace(/^\|/, "")
      .replace(/\|$/, "")
      .split(/(?<!\\)\|/)
      .map((c) => c.trim());
    if (cells.every((c) => /^:?-+:?$/.test(c))) {
      started = true; // separator row → data follows
      continue;
    }
    if (!started) continue; // header row, before the separator
    rows.push(cells);
  }
  return rows;
}

// --- 1. Device-confirmed gotchas (DEVICE_FACTS.md "## Confirmed") ------------
function deviceGotchas(): string {
  const rows = tableRows(read("grammar/DEVICE_FACTS.md"), /^##\s+Confirmed/);
  const out: string[] = [];
  for (const r of rows) {
    const [, layer, construct, verdict, , action] = r; // [#, Layer, Construct, Verdict, Evidence, Action]
    if (!construct) continue;
    const invalid = /INVALID/i.test(verdict);
    const mark = invalid ? "❌" : "⚠️";
    out.push(
      `- ${mark} **${plain(construct)}** — _${plain(verdict)}_ (${plain(
        layer,
      )}). ${firstSentence(action)}.`,
    );
  }
  return out.join("\n");
}

// --- 2. bsc ↔ device drift (BSC_DRIFT.md "## Drift table") -------------------
function bscDrift(): { strict: string; lenient: string; runtime: string } {
  const rows = tableRows(read("grammar/BSC_DRIFT.md"), /^##\s+Drift table/);
  const strict: string[] = [];
  const lenient: string[] = [];
  const runtime: string[] = [];
  for (const r of rows) {
    const [construct, id, bscSays, devSays, drift, recon] = r;
    const line = `- **${plain(construct)}** \`${plain(id)}\` — bsc: ${plain(
      bscSays,
    )}; device: ${plain(devSays)}. ${firstSentence(recon)}.`;
    if (/strict/i.test(drift)) strict.push(line);
    else if (/lenient/i.test(drift)) lenient.push(line);
    else runtime.push(line);
  }
  return {
    strict: strict.join("\n"),
    lenient: lenient.join("\n"),
    runtime: runtime.join("\n"),
  };
}

// --- 3. Valid construct index (coverage.json) -------------------------------
type Cov = {
  id: string;
  kind: string;
  layer: string;
  dimension: string;
  snippet: string;
  device_testable: boolean;
  expect: string;
};
function validIndex(): string {
  const cov: Cov[] = JSON.parse(read("grammar/coverage.json"));
  const valid = cov.filter((c) => c.expect !== "error" && c.snippet);
  // group by "<layer>/<top-segment>"
  const groups = new Map<string, Cov[]>();
  for (const c of valid) {
    const key = `${c.layer}/${(c.id.split(".")[0] || "misc")}`;
    (groups.get(key) ?? groups.set(key, []).get(key)!).push(c);
  }
  const lines = [
    "| layer · group | constructs | example (valid) |",
    "| --- | --: | --- |",
  ];
  for (const key of [...groups.keys()].sort()) {
    const items = groups.get(key)!;
    // pick the shortest device-confirmed snippet as the canonical example
    const example = [...items]
      .sort(
        (a, b) =>
          Number(a.snippet.includes("`")) - Number(b.snippet.includes("`")) ||
          Number(b.device_testable) - Number(a.device_testable) ||
          a.snippet.length - b.snippet.length,
      )[0];
    const snip = example.snippet.replace(/\n/g, " ⏎ ").replace(/\|/g, "\\|");
    lines.push(`| \`${key}\` | ${items.length} | \`${snip}\` |`);
  }
  return `${lines.join("\n")}\n\n_Total valid constructs catalogued: ${
    valid.length
  } (full taxonomy: \`grammar/coverage.json\`)._`;
}

// --- Curated, slow-changing rules (the always-true core) ---------------------
const HARD_RULES = `## Hard rules — internalize these (they cause the most agent mistakes)

- **Case-insensitive identifiers & keywords.** \`myVar\`, \`MyVar\`, \`MYVAR\` are the
  same symbol; \`function\`/\`Function\`/\`FUNCTION\` are equivalent. Don't rely on case.
- **Significant newlines, NO line-continuation character.** A statement ends at the
  newline; there is no \`_\`/\`\\\` continuation. Break long lines only *inside* an open
  \`[ ]\` / \`{ }\` collection literal or a call argument list — **not** inside a grouping
  \`( )\` (device rejects a newline there).
- **Type-designator suffixes** on identifiers: \`$\`=String, \`%\`=Integer, \`!\`=Float,
  \`#\`=Double, \`&\`=LongInteger (e.g. \`name$\`, \`count%\`).
- **No \`let\`** keyword on assignment — write \`x = 5\`, not \`let x = 5\`.
- **\`as\` type annotations accept only intrinsic types** in plain BrightScript
  (\`integer\`, \`float\`, \`string\`, \`object\`, \`boolean\`, \`function\`, \`dynamic\`, \`void\`,
  …). Custom/component/interface types in \`as\` are a **BrighterScript** feature.
- **Comments** are \`'\` or \`REM\`. **Conditional compilation** is \`#const\` / \`#if\` /
  \`#else if\` / \`#else\` / \`#end if\`, and \`#if\` conditions are \`true|false|<CONST>\`
  only — no \`and\`/\`or\`/\`not\`.

## Dialect boundary — \`.brs\` vs \`.bs\` (the line agents blur most)

\`.brs\` = **BrightScript** (what the Roku device runs). \`.bs\` = **BrighterScript**
(a superset that bsc *transpiles down* to \`.brs\`).

**BrighterScript-only — VALID in \`.bs\`, INVALID in \`.brs\`:** \`class\` (with
\`extends\`/\`super()\`/\`override\`/access modifiers/typed fields), \`namespace\`, \`enum\`,
\`const\`, \`import\`, ternary \`a ? b : c\`, null-coalescing \`??\`, template strings with
\`\${...}\`, \`new\`, computed AA keys, typed params/assignments with custom & union types,
regex literals, and \`@annotation\`s.

When you edit a file, **pick syntax for that file's extension.** Putting any of the
above in a \`.brs\` file is a compile error unless the project sets
\`allowBrighterScriptInBrightScript\`.`;

// --- Assemble ---------------------------------------------------------------
const drift = bscDrift();
const provenance = [
  "<!-- GENERATED by scripts/gen-brightscript-reference.ts — DO NOT EDIT BY HAND.",
  "  Regenerate: npm run gen:reference   ·   Freshness gate: npm run check:reference",
  `  generated_at: ${new Date().toISOString().slice(0, 10)}`,
  `  brighterscript: ${bscVersion()}`,
  "  sources:",
  ...SOURCES.map((s) => `    ${s}: sha256:${sha(s)}`),
  "-->",
].join("\n");

const body = `${provenance}

# BrightScript / BrighterScript syntax reference (for codegen)

> Distilled from this repo's device-validated ledgers so an agent writes only
> valid syntax. **This is the knowledge layer; the \`bsc\` hook is the gate** —
> read this before writing, then let the validator catch the rest. Authority
> order when sources conflict: **Roku device > bsc > this doc > model priors.**

${HARD_RULES}

## Device-confirmed gotchas

Empirically checked on real hardware (see \`grammar/DEVICE_FACTS.md\`). ❌ = will
not run; ⚠️ = valid but behaves surprisingly.

${deviceGotchas()}

## Trusting (and distrusting) the bsc gate

bsc is the pre-flight checker the hook runs. It is **not** the device, so reconcile
its verdicts with these known divergences (\`grammar/BSC_DRIFT.md\`):

**bsc is too STRICT here — the construct is VALID on device.** A red line for one
of these is a false positive; keep the construct and suppress with
\`' bs:disable-next-line\`, do not "fix" it away:

${drift.strict || "- _(none recorded)_"}

**bsc is too LENIENT here — it passes, but the DEVICE REJECTS. Never ship these:**

${drift.lenient || "- _(none recorded)_"}
${
  drift.runtime
    ? `\n**bsc can't see runtime here — trust the device behaviour:**\n\n${drift.runtime}\n`
    : ""
}
## Valid construct index

Every group below is catalogued and (where \`device_testable\`) confirmed. The
example is a known-valid snippet for that group.

${validIndex()}

---

_Maintenance: this file is generated. To change it, edit the ledgers in
\`grammar/\` (or the curated section in \`scripts/gen-brightscript-reference.ts\`)
and run \`npm run gen:reference\`. \`npm run check:reference\` fails if it drifts.
\`npm run sync:angel-roku\` regenerates and pushes it to peer apps._
`;

const outPath = join(REPO, OUT);
mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, body);
console.log(`✓ wrote ${OUT} (${body.length} bytes, bsc ${bscVersion()})`);
