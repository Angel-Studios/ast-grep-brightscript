#!/usr/bin/env python3
"""Real-world full-surface gate — the BrighterScript grammar vs shipping libraries.

This is the standing regression form of the ad-hoc "full-surface parse rate"
measurement from `roadmap/brighterscript/06-grammar-fidelity.md`. It pins five
real-world `.bs` repositories, parses every source `.bs` file in them with the
BRIGHTERSCRIPT tree-sitter grammar, and asserts the clean-parse rate has not
regressed below a recorded threshold.

The corpus = 5 pinned repos cloned into /tmp/<name>-test (cloned here if missing):

    maestro  b1f7f35   rooibos 1fe183b   promises 7acd59a
    bslib    089e8b1   ropm    62c0522

For every `*.bs` under each repo EXCEPT paths containing /node_modules/, /out/,
/build/, /dist/, /.roku-deploy/ or `.maestro-templates` (R7: 14 `$NAME$`
scaffolding stubs that are invalid BrightScript and correctly rejected — NOT
bugs), the file is parsed with `tree-sitter parse`. A file is a FAILURE iff the
parse output contains "ERROR" or "MISSING".

  ⚠  GOTCHA: `tree-sitter parse` MUST run with cwd = tree-sitter-brighterscript/
     or it silently uses the wrong parser (or none) and reports bogus "clean"
     results. This script always sets cwd to BR_DIR.

Acceptance: PASS iff clean >= MIN_CLEAN and total == EXPECTED_TOTAL. The single
expected failure is a GENUINE SOURCE TYPO (`@it("…")n`) in maestro
StyleManager.spec.bs — correctly rejected, not a grammar bug. Bump MIN_CLEAN /
EXPECTED_TOTAL (and the comment) only when the grammar's reach legitimately
changes or the pinned SHAs are re-pinned.

Run from the repo root:

    python3 grammar/check_realworld.py                 # the gate
    python3 grammar/check_realworld.py --list-failures  # also list failing paths

Exit status is non-zero if the rate regressed, the total changed, or no repo
could be measured (offline + nothing cloned).
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TS = ROOT / "node_modules" / ".bin" / "tree-sitter"
BR_DIR = ROOT / "tree-sitter-brighterscript"

# --- threshold (the recorded non-regressing state) -------------------------
# 245 of 246 source .bs files parse clean. The 1 known failure is NOT a grammar
# bug: maestro src/source/view/StyleManager.spec.bs has a genuine source typo
# (`@it("…")n` — a stray trailing `n`) that is correctly rejected. Removing the
# stray `n` makes it parse clean. See roadmap/brighterscript/06-grammar-fidelity.md.
MIN_CLEAN = 245
EXPECTED_TOTAL = 246
KNOWN_NONBUG = "StyleManager.spec.bs @it(\"…\")n typo"

# --- the pinned corpus -----------------------------------------------------
# (local dir, clone url, pinned short SHA). maestro is pinned via an explicit
# `git fetch --depth 1 origin <sha>` because its default-branch tip drifts; the
# others are recorded for provenance / re-pin reference (we accept their shallow
# default-branch clone, matching the roadmap measurement procedure).
REPOS = [
    ("/tmp/maestro-test",  "https://github.com/georgejecook/maestro",  "b1f7f35"),
    ("/tmp/rooibos-test",  "https://github.com/rokucommunity/rooibos",  "1fe183b"),
    ("/tmp/promises-test", "https://github.com/rokucommunity/promises", "7acd59a"),
    ("/tmp/bslib-test",    "https://github.com/rokucommunity/bslib",    "089e8b1"),
    ("/tmp/ropm-test",     "https://github.com/rokucommunity/ropm",     "62c0522"),
]

# path fragments that exclude a file from the measurement
EXCLUDE_DIRS = ("/node_modules/", "/out/", "/build/", "/dist/", "/.roku-deploy/")
EXCLUDE_SCAFFOLD = ".maestro-templates"  # R7 — invalid scaffolding stubs, not bugs


def ensure_repo(local: str, url: str, sha: str) -> str | None:
    """Clone the repo into `local` if absent. Return None on success, else a
    one-line reason string (offline + not present)."""
    d = Path(local)
    if (d / ".git").is_dir():
        return None  # already cloned — use as-is (matches the roadmap procedure)
    clone = subprocess.run(
        ["git", "clone", "--depth", "1", url, local],
        capture_output=True, text=True,
    )
    if clone.returncode != 0:
        if d.exists():
            # directory exists but isn't a usable git checkout
            return f"{local}: present but not a git checkout, and re-clone failed"
        return f"{local}: clone of {url} failed (offline?): {clone.stderr.strip().splitlines()[-1] if clone.stderr.strip() else 'unknown error'}"
    # maestro: pin the recorded SHA (best-effort; tolerate a fetch failure).
    if "maestro" in url:
        subprocess.run(
            ["git", "-C", local, "fetch", "--depth", "1", "origin", sha],
            capture_output=True, text=True,
        )
    return None


def bs_files(repo: str) -> list[Path]:
    """All measurable *.bs files under `repo` (exclusions applied)."""
    out: list[Path] = []
    for f in Path(repo).rglob("*.bs"):
        p = str(f)
        if any(frag in p for frag in EXCLUDE_DIRS):
            continue
        if EXCLUDE_SCAFFOLD in p:
            continue
        out.append(f)
    return out


def parses_clean(path: Path) -> bool:
    """True iff `tree-sitter parse` of `path` has no ERROR/MISSING node.

    cwd is pinned to BR_DIR so the correct (brighterscript) parser is used.
    """
    r = subprocess.run(
        [str(TS), "parse", str(path)],
        cwd=BR_DIR, capture_output=True, text=True,
    )
    out = r.stdout + r.stderr
    return ("ERROR" not in out) and ("MISSING" not in out)


def main() -> int:
    ap = argparse.ArgumentParser(description="BrighterScript real-world full-surface regression gate")
    ap.add_argument("--list-failures", action="store_true",
                    help="print the path of every file that failed to parse clean")
    args = ap.parse_args()

    if not TS.exists():
        print(f"✗ real-world gate: tree-sitter CLI not found at {TS}")
        return 1
    if not (BR_DIR / "brighterscript.so").exists():
        print(f"✗ real-world gate: brighterscript.so not built ({BR_DIR / 'brighterscript.so'})")
        return 1

    skips: list[str] = []
    measured_repos = 0
    total = 0
    clean = 0
    failures: list[str] = []

    for local, url, sha in REPOS:
        reason = ensure_repo(local, url, sha)
        if reason is not None:
            skips.append(reason)
            continue
        measured_repos += 1
        for f in bs_files(local):
            total += 1
            if parses_clean(f):
                clean += 1
            else:
                failures.append(str(f))

    # ---- report -----------------------------------------------------------
    print(f"pinned repos: {len(REPOS)}   measured: {measured_repos}   "
          f"files parsed: {total}   clean: {clean}   failed: {len(failures)}")
    if skips:
        print(f"\n⚠ {len(skips)} repo(s) could not be measured:")
        for s in skips:
            print("  - " + s)

    # An offline run that measured nothing can't certify a non-regression.
    if measured_repos == 0:
        print("\n✗ real-world gate: SKIPPED (no corpus available — offline and "
              "nothing cloned). Cannot certify non-regression.")
        return 1

    # If repos are missing the total can't equal EXPECTED_TOTAL; surface that
    # rather than silently passing a partial measurement.
    if skips:
        print(f"\n✗ real-world gate: PARTIAL ({measured_repos}/{len(REPOS)} repos) "
              f"— full surface needs all {len(REPOS)} repos cloned.")
        if args.list_failures and failures:
            print("\nfailing files:")
            for p in failures:
                print("  " + p)
        return 1

    # known new failures = anything beyond the recorded budget
    regressed = clean < MIN_CLEAN
    total_changed = total != EXPECTED_TOTAL

    if args.list_failures and failures:
        print("\nfailing files:")
        for p in failures:
            print("  " + p)

    if regressed or total_changed:
        if total_changed:
            print(f"\n✗ real-world gate: total changed ({total} ≠ expected {EXPECTED_TOTAL}). "
                  f"The corpus surface moved — re-pin SHAs / re-check exclusions, then "
                  f"update EXPECTED_TOTAL/MIN_CLEAN.")
        if regressed:
            print(f"\n✗ real-world gate: RED — clean {clean} < MIN_CLEAN {MIN_CLEAN} "
                  f"({len(failures)} file(s) failed; budget allows "
                  f"{EXPECTED_TOTAL - MIN_CLEAN}).")
            if not args.list_failures:
                print("  failing files:")
                for p in failures:
                    print("    " + p)
            print("  Investigate each new failure: a real construct the grammar wrongly "
                  "rejects is a bug to fix; a genuine source typo can be allowlisted by "
                  "bumping MIN_CLEAN with a comment.")
        return 1

    extra = clean - MIN_CLEAN
    headroom = (f"; +{extra} over budget — consider bumping MIN_CLEAN to {clean}"
                if extra > 0 else "")
    print(f"\n✓ real-world gate: GREEN ({clean}/{total} clean; "
          f"{len(failures)} known non-bug: {KNOWN_NONBUG}){headroom}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
