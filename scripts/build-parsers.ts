#!/usr/bin/env bun
/**
 * Build the three tree-sitter grammars into loadable dynamic libraries for THIS
 * platform, under `dist/parsers/<platform>-<arch>/<lang>.so` (e.g. `linux-x64/`,
 * `darwin-arm64/`) — artifacts built on DIFFERENT machines coexist side by
 * side, so downstream vendoring can ship per-platform parser sets.
 * project-xavier's `nav-protocol-roku-instrumentation/scripts/vendor-parsers.ts`
 * consumes exactly this layout. The artifact is platform-NATIVE (ELF on Linux,
 * Mach-O on macOS); the `.so` name is a stable label — dlopen does not care
 * about the extension.
 *
 * With `--in-place`, ALSO refresh `<grammar-dir>/<lang>.so` — the paths
 * `sgconfig.yml` registers for local ast-grep use on this machine. Opt-in
 * because `tree-sitter-brighterscript/brighterscript.so` is git-TRACKED (the
 * other two are scaffold-gitignored): a default in-place build on macOS would
 * silently swap a committed ELF artifact for a Mach-O one.
 *
 * `tree-sitter build` compiles the COMMITTED `src/parser.c` (+ scanner); it
 * never regenerates the grammar, so the ABI (15) is pinned by what is checked
 * in, not by the machine that compiles. Every artifact is smoke-parsed via
 * `tree-sitter parse --lib-path` before the script reports success — a build
 * that compiles but cannot load or parse is a failure here, never a green.
 *
 * With `--wasm`, ALSO build each grammar to WebAssembly at
 * `dist/parsers/wasm/<lang>.wasm`. A `.wasm` parser is architecture-INDEPENDENT,
 * so it sits beside the per-platform directories rather than inside one. It is
 * opt-in because the first `--wasm` build downloads a wasi-sdk (~113MB, once,
 * network required); the default build stays offline-capable.
 *
 * A Wasm parser may only import a fixed set of libc symbols, so an external
 * scanner that calls anything else (`tolower` did) cannot build. The CLI reports
 * that and exits 1 — but it WRITES the output file BEFORE it validates, and the
 * rejected artifact still LOADS in web-tree-sitter, failing only at parse with an
 * error naming no symbol. Presence of a `.wasm` therefore proves nothing. This
 * script gates on the exit code, DELETES a rejected artifact, and then re-checks
 * the module's own function imports against the permitted set.
 *
 *   npm run build:parsers            # dist/parsers/<platform>-<arch>/ only
 *   npm run build:parsers -- --in-place   # also refresh <grammar-dir>/<lang>.so
 *   npm run build:parsers:wasm       # also dist/parsers/wasm/<lang>.wasm
 */

import { spawnSync } from 'node:child_process';
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(HERE, '..');
const TREE_SITTER = join(REPO_ROOT, 'node_modules', '.bin', 'tree-sitter');
const PLATFORM_KEY = `${process.platform}-${process.arch}`;
const DIST_DIR = join(REPO_ROOT, 'dist', 'parsers', PLATFORM_KEY);
const WASM_DIR = join(REPO_ROOT, 'dist', 'parsers', 'wasm');

/**
 * The libc symbols a tree-sitter Wasm parser is allowed to import. This is the
 * list the CLI itself prints when it rejects a scanner; anything else must be
 * written out by hand in the scanner (see the `ascii_lower` helpers).
 */
const WASM_ALLOWED_IMPORTS: ReadonlySet<string> = new Set([
  'calloc', 'free', 'iswalnum', 'iswalpha', 'iswblank', 'iswdigit', 'iswlower',
  'iswspace', 'iswupper', 'iswxdigit', 'malloc', 'memchr', 'memcmp', 'memcpy',
  'memmove', 'memset', 'realloc', 'strcmp', 'strlen', 'strncat', 'strncmp',
  'strncpy', 'towlower', 'towupper',
]);

type Grammar = {
  readonly dir: string;
  readonly lang: string;
  /** Minimal valid source proving the built artifact loads and parses. */
  readonly smoke: { readonly ext: string; readonly src: string };
};

const GRAMMARS: readonly Grammar[] = [
  {
    dir: 'tree-sitter-brightscript',
    lang: 'brightscript',
    smoke: { ext: 'brs', src: 'sub Main()\n    print "ok"\nend sub\n' },
  },
  {
    dir: 'tree-sitter-brighterscript',
    lang: 'brighterscript',
    smoke: { ext: 'bs', src: 'sub Main()\n    print "ok"\nend sub\n' },
  },
  {
    dir: 'tree-sitter-scenegraph',
    lang: 'scenegraph',
    smoke: {
      ext: 'xml',
      src: '<?xml version="1.0" encoding="utf-8" ?>\n<component name="Smoke" extends="Group">\n</component>\n',
    },
  },
];

function fail(msg: string): never {
  process.stderr.write(`build-parsers: ${msg}\n`);
  process.exit(1);
}

function build(g: Grammar, outPath: string): string {
  const grammarDir = join(REPO_ROOT, g.dir);
  const res = spawnSync(TREE_SITTER, ['build', '--output', outPath], {
    cwd: grammarDir,
    encoding: 'utf8',
  });
  if (res.error !== undefined || res.status !== 0) {
    fail(`tree-sitter build failed for ${g.lang}: ${res.error?.message ?? res.stderr}`);
  }
  return outPath;
}

function smokeParse(g: Grammar, libPath: string): void {
  const tmp = mkdtempSync(join(tmpdir(), 'ts-smoke-'));
  try {
    const smokeFile = join(tmp, `smoke.${g.smoke.ext}`);
    writeFileSync(smokeFile, g.smoke.src);
    const res = spawnSync(TREE_SITTER, ['parse', '--lib-path', libPath, '--lang-name', g.lang, smokeFile], {
      encoding: 'utf8',
    });
    // The CLI warns about unconfigured parser directories on stderr and still
    // parses via --lib-path; a real failure is a non-zero exit with empty
    // stdout, or an ERROR node on source this trivial.
    const parsed = (res.stdout ?? '').trim();
    if (res.error !== undefined || parsed.length === 0) {
      fail(`smoke parse failed for ${g.lang}: ${res.error?.message ?? res.stderr}`);
    }
    if (parsed.includes('ERROR')) {
      fail(`smoke parse for ${g.lang} produced an ERROR node:\n${parsed}`);
    }
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}

function buildWasm(g: Grammar, outPath: string): void {
  const grammarDir = join(REPO_ROOT, g.dir);
  const res = spawnSync(TREE_SITTER, ['build', '--wasm', '--output', outPath, '.'], {
    cwd: grammarDir,
    encoding: 'utf8',
  });
  if (res.error !== undefined || res.status !== 0) {
    // The CLI writes the artifact BEFORE it validates, so a rejected build leaves
    // a plausible file behind. Remove it: a later step must not read it as green.
    rmSync(outPath, { force: true });
    fail(`tree-sitter build --wasm failed for ${g.lang}: ${res.error?.message ?? res.stderr}`);
  }
}

function verifyWasmImports(g: Grammar, outPath: string): void {
  let mod: WebAssembly.Module;
  try {
    mod = new WebAssembly.Module(readFileSync(outPath));
  } catch (err) {
    fail(`${g.lang}.wasm is not a loadable WebAssembly module: ${String(err)}`);
  }
  const forbidden = WebAssembly.Module.imports(mod)
    .filter((i) => i.kind === 'function' && !WASM_ALLOWED_IMPORTS.has(i.name))
    .map((i) => `${i.module}.${i.name}`);
  if (forbidden.length > 0) {
    rmSync(outPath, { force: true });
    fail(
      `${g.lang}.wasm imports symbols a Wasm parser may not use: ${forbidden.join(', ')}. ` +
        `Write the operation out in the external scanner instead.`,
    );
  }
}

function main(): void {
  if (!existsSync(TREE_SITTER)) {
    fail(`tree-sitter CLI not found at ${TREE_SITTER} — run npm install first`);
  }
  const inPlace = process.argv.includes('--in-place');
  const wantWasm = process.argv.includes('--wasm');
  mkdirSync(DIST_DIR, { recursive: true });
  if (wantWasm) {
    mkdirSync(WASM_DIR, { recursive: true });
  }
  for (const g of GRAMMARS) {
    const distPath = join(DIST_DIR, `${g.lang}.so`);
    build(g, distPath);
    smokeParse(g, distPath);
    if (inPlace) {
      copyFileSync(distPath, join(REPO_ROOT, g.dir, `${g.lang}.so`));
    }
    process.stdout.write(`built + smoke-parsed ${g.lang}.so → ${distPath}\n`);
    if (wantWasm) {
      const wasmPath = join(WASM_DIR, `${g.lang}.wasm`);
      buildWasm(g, wasmPath);
      verifyWasmImports(g, wasmPath);
      process.stdout.write(`built + import-checked ${g.lang}.wasm → ${wasmPath}\n`);
    }
  }
  process.stdout.write(
    `done: ${GRAMMARS.length} parsers for ${PLATFORM_KEY}${inPlace ? ' (+ in-place grammar-dir copies)' : ''}${wantWasm ? ' (+ wasm)' : ''}\n`,
  );
}

main();
