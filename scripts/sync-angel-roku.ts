#!/usr/bin/env bun
/**
 * sync-angel-roku.ts
 *
 * Embeds this repo's BrightScript agent tooling — the `bsc` validation hook and
 * the freshly generated reference.md — into a peer Roku app. Default target is
 * the sibling `../angel-roku`.
 *
 * The reference.md is the device-validated syntax knowledge layer; in the peer
 * app it lives inside that app's own `brightscript-expertise` skill (which merges
 * this syntax layer with the app's channel-architecture content). This repo owns
 * the generated reference.md; the app owns its brightscript-expertise/SKILL.md.
 * That's why the sync only refreshes reference.md and never writes the SKILL.md.
 *
 *   bun scripts/sync-angel-roku.ts [targetDir] [--dry-run]
 *   ANGEL_ROKU_DIR=/path/to/app bun scripts/sync-angel-roku.ts
 *
 * What it does (idempotent):
 *   1. (real run) regenerate reference.md from the grammar/ ledgers
 *   2. copy .claude/hooks/bsc-validate.sh → <target>/.claude/hooks/
 *   3. copy this repo's generated reference.md →
 *      <target>/.claude/skills/brightscript-expertise/reference.md
 *      (the target must already have that skill's SKILL.md — see the guard below)
 *   4. merge the PostToolUse hook into <target>/.claude/settings.json (shared,
 *      committed; matched by command string so re-runs never duplicate)
 *
 * The hook references "$CLAUDE_PROJECT_DIR/.claude/hooks/bsc-validate.sh", so it
 * binds to the target app's own bsconfig + node_modules bsc at runtime.
 */
import {
  cpSync,
  existsSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
} from "node:fs";
import { dirname, join, resolve } from "node:path";
import { spawnSync } from "node:child_process";

const REPO = resolve(import.meta.dir, "..");
const args = process.argv.slice(2);
const dryRun = args.includes("--dry-run");
const targetArg = args.find((a) => !a.startsWith("-"));
const TARGET = resolve(
  targetArg || process.env.ANGEL_ROKU_DIR || join(REPO, "..", "angel-roku"),
);

const HOOK_REL = ".claude/hooks/bsc-validate.sh";
// Source skill in THIS repo (canonical "write valid BrightScript" skill; the gen
// step writes its reference.md). The peer app merges this knowledge into its own
// broader `brightscript-expertise` skill, so source and destination skill names
// intentionally differ — only the generated reference.md crosses over.
const SRC_SKILL_REL = ".claude/skills/write-brightscript";
const DST_SKILL_REL = ".claude/skills/brightscript-expertise";
const SRC_REF_REL = `${SRC_SKILL_REL}/reference.md`;
const DST_REF_REL = `${DST_SKILL_REL}/reference.md`;
const HOOK_CMD = 'bash "$CLAUDE_PROJECT_DIR/.claude/hooks/bsc-validate.sh"';
const HOOK_MATCHER = "Write|Edit|MultiEdit";

const log = (s: string) => console.log(s);
const fail = (s: string) => {
  console.error(`✖ ${s}`);
  process.exit(1);
};

// --- validate target ---------------------------------------------------------
if (!existsSync(TARGET)) fail(`target not found: ${TARGET}`);
if (!existsSync(join(TARGET, "bsconfig.json"))) {
  fail(
    `${TARGET} has no root bsconfig.json — doesn't look like a BrightScript app.\n` +
      `  Pass the app dir explicitly: bun scripts/sync-angel-roku.ts <dir>`,
  );
}
// The merged brightscript-expertise skill (with its app-specific channel content)
// is owned by the target app; sync only refreshes its generated reference.md and
// will not bootstrap the skill. Require its SKILL.md to already exist.
if (!existsSync(join(TARGET, DST_SKILL_REL, "SKILL.md"))) {
  fail(
    `${TARGET} has no ${DST_SKILL_REL}/SKILL.md.\n` +
      `  This sync refreshes that skill's generated reference.md; it does not create the\n` +
      `  skill. Create ${DST_SKILL_REL}/SKILL.md in the target first (it carries the\n` +
      `  app's channel-architecture content), then re-run.`,
  );
}
log(`→ target: ${TARGET}${dryRun ? "  (dry run)" : ""}`);

// --- 1. (re)generate the reference so we ship the current language facts ------
if (dryRun) {
  const check = spawnSync(
    "python3",
    [join(REPO, "grammar", "check_reference.py")],
    { encoding: "utf8" },
  );
  process.stdout.write(check.stdout || "");
  if (check.status !== 0)
    log("  (dry run) reference.md is stale — a real run regenerates it first");
} else {
  log("→ regenerating reference.md from grammar/ ledgers …");
  const gen = spawnSync(
    "bun",
    [join(REPO, "scripts", "gen-brightscript-reference.ts")],
    { encoding: "utf8", cwd: REPO },
  );
  process.stdout.write(gen.stdout || "");
  if (gen.status !== 0) {
    process.stderr.write(gen.stderr || "");
    fail("reference generation failed");
  }
}

// --- 2 + 3. copy hook + generated reference.md -------------------------------
const copies: Array<[string, string]> = [
  [HOOK_REL, HOOK_REL],
  [SRC_REF_REL, DST_REF_REL],
];
for (const [src, dst] of copies) {
  const from = join(REPO, src);
  const to = join(TARGET, dst);
  if (!existsSync(from)) fail(`missing source: ${src} (run the build first)`);
  log(`${dryRun ? "would copy" : "copy"}  ${src}  →  ${dst}`);
  if (!dryRun) {
    mkdirSync(dirname(to), { recursive: true });
    cpSync(from, to, { recursive: true });
  }
}

// --- 4. merge the hook into the target's settings.json -----------------------
const settingsPath = join(TARGET, ".claude", "settings.json");
let settings: any = {};
if (existsSync(settingsPath)) {
  try {
    settings = JSON.parse(readFileSync(settingsPath, "utf8"));
  } catch (e) {
    fail(`could not parse ${settingsPath}: ${(e as Error).message}`);
  }
}
settings.hooks ??= {};
settings.hooks.PostToolUse ??= [];
const already = settings.hooks.PostToolUse.some((entry: any) =>
  (entry?.hooks ?? []).some((h: any) => h?.command === HOOK_CMD),
);
if (already) {
  log("settings.json  →  PostToolUse hook already present (no change)");
} else {
  log(`${dryRun ? "would add" : "add"}  PostToolUse hook  →  .claude/settings.json`);
  if (!dryRun) {
    settings.hooks.PostToolUse.push({
      matcher: HOOK_MATCHER,
      hooks: [{ type: "command", command: HOOK_CMD }],
    });
    mkdirSync(dirname(settingsPath), { recursive: true });
    writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + "\n");
  }
}

log(
  dryRun
    ? "\n✓ dry run complete — no files written."
    : "\n✓ synced. The bsc hook + brightscript-expertise/reference.md are now refreshed in the target app.",
);
if (!dryRun)
  log(
    `  Verify in the target: ls .claude/hooks/bsc-validate.sh ${DST_SKILL_REL}/reference.md && cat .claude/settings.json`,
  );
