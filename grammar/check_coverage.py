#!/usr/bin/env python3
"""Coverage parity gate.

`grammar/coverage.json` is the single source of truth for the language taxonomy.
This script asserts the test-harness actually implements every leaf:

  * device_testable:true  -> a `t.spec("<id>", "<kind>", ...)` call exists in
    roku-test-harness/source/tests/*.brs OR *.bs, AND the kind matches
    coverage.json. (BrighterScript leaves, layer="brighterscript", are
    "device-testable VIA TRANSPILE": their t.spec lives in a `.bs` module that
    the build transpiles to `.brs` before sideloading; the lowered code runs on
    the device exactly like the plain-BrightScript specs.)
  * device_testable:false -> a corpus file under roku-test-harness/corpus/
    is tagged `coverage-id: <id>` (.brs/.bs/.xml; parse-only / bsc-syntax-only
    leaves that can't run on-device; plan 03/05's tree-sitter grammar asserts
    ERROR nodes / clean parses against them).

Exit status is non-zero (and a grouped report is printed) if anything is
missing, mis-keyed, or orphaned. Run from the repo root:

    python3 grammar/check_coverage.py
"""
from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COVERAGE = ROOT / "grammar" / "coverage.json"
TESTS_DIR = ROOT / "roku-test-harness" / "source" / "tests"
CORPUS_DIR = ROOT / "roku-test-harness" / "corpus"

# t.spec("id", "kind", "desc")  -> capture id (1) and kind (2)
SPEC_RE = re.compile(r'\bspec\(\s*"([^"]+)"\s*,\s*"([^"]+)"')
# corpus file tag:  ' coverage-id: <id>   or   <!-- coverage-id: <id> ... -->
CORPUS_ID_RE = re.compile(r"coverage-id:\s*(\S+)")


def load_leaves() -> list[dict]:
    return json.loads(COVERAGE.read_text())


def scan_specs() -> dict[str, str]:
    """Map every t.spec id found in the test modules to its declared kind.

    A duplicate id (same id opened twice) is reported by the caller via the
    `dupes` set; here last-wins for the kind lookup.
    """
    specs: dict[str, str] = {}
    dupes: set[str] = set()
    # .brs = plain-BrightScript spec modules; .bs = BrighterScript spec modules
    # (transpiled into the channel before sideload -> device-tested via transpile).
    test_files = sorted(TESTS_DIR.glob("*.brs")) + sorted(TESTS_DIR.glob("*.bs"))
    for brs in test_files:
        for sid, kind in SPEC_RE.findall(brs.read_text()):
            if sid in specs:
                dupes.add(sid)
            specs[sid] = kind
    scan_specs.dupes = dupes  # type: ignore[attr-defined]
    return specs


def scan_corpus() -> set[str]:
    ids: set[str] = set()
    if CORPUS_DIR.exists():
        for f in CORPUS_DIR.rglob("*"):
            if f.is_file() and f.suffix in (".brs", ".bs", ".xml"):
                for m in CORPUS_ID_RE.findall(f.read_text()):
                    ids.add(m)
    return ids


def main() -> int:
    leaves = load_leaves()
    specs = scan_specs()
    dupes: set[str] = getattr(scan_specs, "dupes", set())
    corpus_ids = scan_corpus()

    device_ids = {l["id"]: l for l in leaves if l.get("device_testable")}
    nondevice_ids = {l["id"]: l for l in leaves if not l.get("device_testable")}

    missing_device = sorted(set(device_ids) - set(specs))
    missing_corpus = sorted(set(nondevice_ids) - corpus_ids)
    kind_mismatch = sorted(
        (sid, device_ids[sid]["kind"], specs[sid])
        for sid in device_ids
        if sid in specs and specs[sid] != device_ids[sid]["kind"]
    )

    # Orphans: t.spec ids / corpus ids not present in coverage.json at all.
    all_ids = {l["id"] for l in leaves}
    orphan_specs = sorted(set(specs) - all_ids)
    orphan_corpus = sorted(corpus_ids - all_ids)

    ok = not (missing_device or missing_corpus or kind_mismatch
              or orphan_specs or orphan_corpus or dupes)

    # ---- report -----------------------------------------------------------
    print(f"coverage.json leaves: {len(leaves)} "
          f"({len(device_ids)} device-testable, {len(nondevice_ids)} non-device)")
    print(f"implemented t.spec ids: {len(specs)}   corpus-tagged ids: {len(corpus_ids)}")

    if missing_device:
        by_area: dict[str, list[str]] = defaultdict(list)
        for sid in missing_device:
            by_area[sid.split('.')[0]].append(sid)
        print(f"\n✗ {len(missing_device)} device-testable leaves WITHOUT a t.spec:")
        for area in sorted(by_area):
            print(f"  [{area}] " + ", ".join(by_area[area]))

    if kind_mismatch:
        print(f"\n✗ {len(kind_mismatch)} t.spec kind mismatches (coverage -> spec):")
        for sid, want, got in kind_mismatch:
            print(f"  {sid}: expected {want!r}, got {got!r}")

    if dupes:
        print(f"\n✗ {len(dupes)} duplicate t.spec ids: " + ", ".join(sorted(dupes)))

    if missing_corpus:
        print(f"\n✗ {len(missing_corpus)} non-device leaves WITHOUT a corpus file:")
        for sid in missing_corpus:
            print(f"  {sid}")

    if orphan_specs:
        print(f"\n✗ {len(orphan_specs)} t.spec ids not in coverage.json: "
              + ", ".join(orphan_specs))
    if orphan_corpus:
        print(f"\n✗ {len(orphan_corpus)} corpus ids not in coverage.json: "
              + ", ".join(orphan_corpus))

    print("\n" + ("✓ coverage parity: GREEN" if ok else "✗ coverage parity: RED"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
