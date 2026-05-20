#!/usr/bin/env python3
"""Grammar gate (validation Level 3) — the tree-sitter grammars vs coverage.json.

Two assertions:

  A. EVERY `coverage.json` `kind` (all layers) is a real node kind in the
     corresponding generated `node-types.json` (brightscript/stdlib ->
     tree-sitter-brightscript, scenegraph -> tree-sitter-scenegraph). This is the
     "all coverage kinds are represented" acceptance criterion.

  B. For every brightscript/stdlib leaf whose snippet is a standalone program,
     `tree-sitter parse` of that snippet:
       * positive leaf  -> ZERO ERROR/MISSING, and the leaf's `kind` appears in
         the parse tree (so ast-grep `kind:` can match it);
       * syntax-negative -> at least one ERROR (device-rejected *syntax*).
     (SceneGraph snippets are XML fragments, not whole documents, so they are not
     parsed standalone here — their kinds are covered by assertion A and by
     tree-sitter-scenegraph/test/corpus.)

Run from the repo root:  python3 grammar/check_grammar.py
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COVERAGE = ROOT / "grammar" / "coverage.json"
TS = ROOT / "node_modules" / ".bin" / "tree-sitter"
BS_DIR = ROOT / "tree-sitter-brightscript"
SG_DIR = ROOT / "tree-sitter-scenegraph"

# Leaves whose snippet is a SYNTAX rejection: tree-sitter must produce an ERROR.
# (Device-rejected SEMANTIC cases — as interface/custom, type="str", #error — are
# well-formed syntax and must parse CLEAN; they are flagged by lint rules.)
SYNTAX_ERROR_IDS = {
    "neg.assign.let",
    "neg.cc.if_and", "neg.cc.if_or", "neg.cc.if_not", "neg.cc.if_paren",
    "decl.function.nested",
    "stmt.dim.paren",
    "stmt.expr.optcall",
    "lex.eos.depth0_paren",
    "lex.eos.no_continuation",
}


def node_kinds(node_types: Path) -> set[str]:
    return {t["type"] for t in json.loads(node_types.read_text())}


def ts_parse(grammar_dir: Path, source: str) -> str:
    """Return the S-expression parse (stderr CLI banner stripped)."""
    with tempfile.NamedTemporaryFile("w", suffix=".brs", dir="/tmp", delete=False) as f:
        f.write(source)
        path = f.name
    out = subprocess.run([str(TS), "parse", path], cwd=grammar_dir,
                         capture_output=True, text=True)
    Path(path).unlink(missing_ok=True)
    return out.stdout


def main() -> int:
    cov = json.loads(COVERAGE.read_text())
    bs_kinds = node_kinds(BS_DIR / "src" / "node-types.json")
    sg_kinds = node_kinds(SG_DIR / "src" / "node-types.json")

    problems: list[str] = []

    # ---- A. all coverage kinds present in node-types.json --------------------
    for layer, kinds in (("brightscript", bs_kinds), ("stdlib", bs_kinds),
                         ("scenegraph", sg_kinds)):
        for leaf in cov:
            if leaf.get("layer") == layer and leaf["kind"] not in kinds:
                problems.append(f"[A] kind {leaf['kind']!r} ({leaf['id']}) absent from {layer} node-types.json")

    # ---- B. snippet parse + kind presence (brightscript / stdlib) -----------
    checked = 0
    for leaf in cov:
        if leaf.get("layer") not in ("brightscript", "stdlib"):
            continue
        sid, kind, snippet = leaf["id"], leaf["kind"], leaf["snippet"]
        tree = ts_parse(BS_DIR, snippet)
        has_error = ("ERROR" in tree) or ("MISSING" in tree)
        checked += 1
        if sid in SYNTAX_ERROR_IDS:
            if not has_error:
                problems.append(f"[B] {sid}: expected a parse ERROR (syntax-negative) but parsed clean")
        else:
            if has_error:
                problems.append(f"[B] {sid}: snippet {snippet!r} produced ERROR/MISSING")
            elif not re.search(rf"\b{re.escape(kind)}\b", tree):
                problems.append(f"[B] {sid}: kind {kind!r} not found in parse of {snippet!r}")

    # ---- report -------------------------------------------------------------
    n = len(cov)
    print(f"coverage leaves: {n}   brightscript+stdlib snippets parsed: {checked}")
    print(f"node kinds: brightscript={len(bs_kinds)}  scenegraph={len(sg_kinds)}")
    if problems:
        print(f"\n✗ {len(problems)} problem(s):")
        for p in problems[:60]:
            print("  " + p)
        if len(problems) > 60:
            print(f"  ... and {len(problems) - 60} more")
        print("\n✗ grammar gate: RED")
        return 1
    print("\n✓ grammar gate: GREEN (all coverage kinds present; snippets parse as expected)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
