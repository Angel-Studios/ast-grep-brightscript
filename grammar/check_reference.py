#!/usr/bin/env python3
"""Freshness gate for the write-brightscript skill's generated reference.

The skill bundles `.claude/skills/write-brightscript/reference.md`, which is
generated from the grammar/ ledgers by `scripts/gen-brightscript-reference.ts`.
This gate fails if a ledger changed without the reference being regenerated, so
the agent-facing knowledge can never silently drift from the validated language.

    Run:        python3 grammar/check_reference.py   (exit 0 = in sync)
    Regenerate: npm run gen:reference

Mirrors the other grammar/check_*.py gates.
"""
import hashlib
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
REF = REPO / ".claude" / "skills" / "write-brightscript" / "reference.md"


def sha(rel: str) -> str:
    return hashlib.sha256((REPO / rel).read_bytes()).hexdigest()


def main() -> int:
    if not REF.exists():
        print("✖ reference.md missing — run: npm run gen:reference")
        return 1

    text = REF.read_text()
    block = re.search(r"sources:\n(.*?)-->", text, re.S)
    if not block:
        print("✖ no provenance block in reference.md — run: npm run gen:reference")
        return 1

    stale, checked = [], 0
    for line in block.group(1).splitlines():
        m = re.match(r"\s*(\S+):\s*sha256:([0-9a-f]{64})\s*$", line)
        if not m:
            continue
        rel, want = m.group(1), m.group(2)
        checked += 1
        if not (REPO / rel).exists():
            print(f"✖ source listed in reference.md no longer exists: {rel}")
            return 1
        if sha(rel) != want:
            stale.append(rel)

    if checked == 0:
        print("✖ provenance block had no source hashes — run: npm run gen:reference")
        return 1
    if stale:
        print("✖ reference.md is stale vs its sources:")
        for s in stale:
            print(f"    - {s}")
        print("  regenerate with: npm run gen:reference")
        return 1

    print(f"✓ reference.md is in sync with its {checked} sources")
    return 0


if __name__ == "__main__":
    sys.exit(main())
