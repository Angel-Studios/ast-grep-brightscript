#!/usr/bin/env bun
/**
 * Roku sideload automation for roku-test-harness/.
 *
 * Steps (the full `deploy`):
 *   1. package  roku-test-harness/  ->  out/harness.zip  (manifest at zip root)
 *   2. sideload via the dev Application Installer  (HTTP digest auth)
 *   3. launch the installed dev channel via ECP
 *
 * Config (via .env, auto-loaded by Bun -- copy .env.example to .env):
 *   ROKU_HOST      default 192.168.1.240
 *   ROKU_DEV_USER  default rokudev
 *   ROKU_DEV_PASS  required: the developer web-installer password
 *
 * Usage:  bun scripts/roku-deploy.ts [deploy|zip|install|launch|delete]
 *         (npm run roku:deploy  == full deploy)
 *
 * Note: the installer COMPILES the channel on upload, so a sideload failure
 * here is real ground-truth feedback (e.g. a construct the device rejects).
 */
import { resolve } from "node:path";

const HOST = process.env.ROKU_HOST ?? "192.168.1.240";
const USER = process.env.ROKU_DEV_USER ?? "rokudev";
const PASS = process.env.ROKU_DEV_PASS ?? "";
const ROOT = process.cwd();
const HARNESS = resolve(ROOT, "roku-test-harness");
const ZIP = resolve(ROOT, "out/harness.zip");

const log = (m: string) => console.log(m);
const die = (m: string): never => {
  console.error(`\n✗ ${m}`);
  process.exit(1);
};

async function run(cmd: string[], cwd?: string) {
  const p = Bun.spawn(cmd, { cwd, stdout: "pipe", stderr: "pipe" });
  const [out, err] = await Promise.all([
    new Response(p.stdout).text(),
    new Response(p.stderr).text(),
  ]);
  return { code: await p.exited, out, err };
}

async function preflight() {
  if (!PASS)
    die("ROKU_DEV_PASS is not set. Copy .env.example to .env and set the dev password.");
  const reachable = await fetch(`http://${HOST}/`)
    .then((r) => r.ok || r.status === 401)
    .catch(() => false);
  if (!reachable)
    die(`Dev installer not reachable at http://${HOST}/ -- is Developer Mode enabled and the device online?`);
}

async function zip() {
  await run(["mkdir", "-p", resolve(ROOT, "out")]);
  await run(["rm", "-f", ZIP]);
  const { code, err } = await run(
    // corpus/ holds device-REJECTED + non-runnable snippets (negative corpus);
    // it must never be packaged or the dev installer would try to compile it.
    ["zip", "-qr", ZIP, ".", "-x", "bsconfig.json", "-x", "README.md", "-x", "*.zip", "-x", "out/*", "-x", "corpus/*"],
    HARNESS,
  );
  if (code !== 0) die(`zip failed: ${err.trim()}`);
  const size = Bun.file(ZIP).size;
  if (!size) die("zip produced an empty archive");
  log(`✓ packaged out/harness.zip (${(size / 1024).toFixed(1)} KiB)`);
}

async function install() {
  log(`→ sideloading to http://${HOST}/plugin_install …`);
  const { code, out, err } = await run([
    "curl", "-sS", "--connect-timeout", "10", "--max-time", "90",
    "--user", `${USER}:${PASS}`, "--digest",
    "-F", "mysubmit=Replace",
    "-F", `archive=@${ZIP};type=application/zip`,
    `http://${HOST}/plugin_install`,
  ]);
  if (code !== 0) die(`curl failed (${code}): ${err.trim() || out.trim()}`);
  const text = out.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();
  const ok = /Install Success|Identical to previous|Application Received|Received\b/i.test(text);
  if (ok) {
    const m = text.match(/(Install Success|Identical to previous[^.]*|Application Received)/i);
    log(`✓ device: ${m?.[1]?.trim() ?? "install accepted"}`);
  } else {
    log(`\n--- installer response (trimmed) ---\n${text.slice(0, 1800)}\n------------------------------------`);
    die("device did not report install success (see response above -- often a compile error in the harness).");
  }
}

async function launch() {
  log(`→ launching dev channel via ECP …`);
  const r = await fetch(`http://${HOST}:8060/launch/dev`, { method: "POST" }).catch(() => null);
  if (!r) die(`ECP launch failed (http://${HOST}:8060/launch/dev)`);
  log(`✓ launch requested (ECP ${r.status})`);
}

async function del() {
  log(`→ deleting dev channel …`);
  const { code } = await run([
    "curl", "-sS", "--user", `${USER}:${PASS}`, "--digest",
    "-F", "mysubmit=Delete", "-F", "archive=",
    `http://${HOST}/plugin_install`,
  ]);
  if (code !== 0) die("delete failed");
  log("✓ delete requested");
}

const cmd = (process.argv[2] ?? "deploy").toLowerCase();
await preflight();
switch (cmd) {
  case "zip": await zip(); break;
  case "install": await zip(); await install(); break;
  case "launch": await launch(); break;
  case "delete": await del(); break;
  case "deploy": await zip(); await install(); await launch(); break;
  default: die(`unknown command '${cmd}'. use: deploy | zip | install | launch | delete`);
}
log("\n✓ done.");
