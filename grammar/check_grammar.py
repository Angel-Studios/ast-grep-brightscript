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
BR_DIR = ROOT / "tree-sitter-brighterscript"

# Leaves whose snippet is a SYNTAX rejection: tree-sitter must produce an ERROR.
# (Device-rejected SEMANTIC cases — as interface/custom, type="str", #error — are
# well-formed syntax and must parse CLEAN; they are flagged by lint rules.)
# Most are BrightScript/stdlib leaves; BR_SYNTAX_ERROR_IDS holds the
# brighterscript-layer syntax-negatives (parsed with the brighterscript grammar).
SYNTAX_ERROR_IDS = {
    "neg.assign.let",
    "neg.cc.if_and", "neg.cc.if_or", "neg.cc.if_not", "neg.cc.if_paren",
    "decl.function.nested",
    "stmt.dim.paren",
    "stmt.expr.optcall",
    "lex.eos.depth0_paren",
    "lex.eos.no_continuation",
}

# BrighterScript-layer syntax-negatives: the snippet must produce ERROR/MISSING
# when parsed with the BRIGHTERSCRIPT grammar (a construct that LOOKS like a bs
# feature but bsc rejects). leading-dot enum `= .Member` is bsc BS1081 (Unexpected
# token '.') — NOT a BrighterScript feature; the grammar emits a MISSING node.
BR_SYNTAX_ERROR_IDS = {
    "neg.bs.leading_dot_enum",
}

# ---------------------------------------------------------------------------
# brighterscript snippets that do NOT parse clean as a STANDALONE program with
# the BrighterScript grammar as currently built. These are EXPLICIT, justified
# exceptions (not silent skips): the grammar still DECLARES every brighterscript
# coverage kind, so assertion A passes for them; what fails is assertion B's
# "this exact snippet parses to a tree containing its kind" for the reason noted.
# Each is reported in the gate output (so they cannot be forgotten) and tracked
# here for human follow-up per the roadmap/05 grammar-completion work. Do NOT
# clear an entry by editing coverage.json or the grammar from this gate; an entry
# leaves this set only when the underlying grammar gap / snippet shape is fixed.
#
# The set is self-checking: if a listed snippet starts parsing clean WITH its
# kind present, the gate flags the entry as stale (remove it). Reason categories:
#   GRAMMAR GAP   -- a real, currently-unimplemented BrighterScript construct.
#   NEEDS WRAPPER -- the construct IS implemented but only in a sub-position
#                    (e.g. expression context), so the bare snippet is not a
#                    standalone program; reproduce by wrapping the snippet.
# (empty) — all BrighterScript coverage snippets now parse clean with their kind
# present. The three former gaps were fixed in the grammar: `.new`/keyword member
# names (AllowedProperties via the _reserved_word override), a bare callfunc call
# as an ExpressionStatement, and source literals lexed as BsSourceLiteral.
BR_PARSE_EXCEPTIONS = {}


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
    br_kinds = node_kinds(BR_DIR / "src" / "node-types.json")

    problems: list[str] = []

    # ---- A. all coverage kinds present in node-types.json --------------------
    # brighterscript is a SUPERSET grammar: its node-types.json contains the
    # inherited brightscript kinds plus the BrighterScript-only kinds, so every
    # `layer:"brighterscript"` leaf's kind must be present there.
    for layer, kinds in (("brightscript", bs_kinds), ("stdlib", bs_kinds),
                         ("scenegraph", sg_kinds),
                         ("brighterscript", br_kinds)):
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

    # ---- B (brighterscript). snippet parse + kind presence ------------------
    # All brighterscript leaves are POSITIVES (there are no brighterscript
    # syntax-negatives), so each snippet must parse with ZERO ERROR/MISSING using
    # the BRIGHTERSCRIPT grammar and its kind must appear in the tree -- EXCEPT
    # the explicitly-justified BR_PARSE_EXCEPTIONS, which are reported (not
    # silently skipped) and self-checked for staleness.
    br_checked = 0
    br_exception_hits: list[str] = []
    used_exceptions: set[str] = set()
    for leaf in cov:
        if leaf.get("layer") != "brighterscript":
            continue
        sid, kind, snippet = leaf["id"], leaf["kind"], leaf["snippet"]
        tree = ts_parse(BR_DIR, snippet)
        has_error = ("ERROR" in tree) or ("MISSING" in tree)
        kind_present = bool(re.search(rf"\b{re.escape(kind)}\b", tree))
        clean = (not has_error) and kind_present
        br_checked += 1
        if sid in BR_SYNTAX_ERROR_IDS:
            if not has_error:
                problems.append(f"[B-br] {sid}: expected a parse ERROR (syntax-negative) but parsed clean")
            continue
        if sid in BR_PARSE_EXCEPTIONS:
            used_exceptions.add(sid)
            if clean:
                # Stale exception: the snippet now parses clean with its kind.
                problems.append(
                    f"[B-br] stale BR_PARSE_EXCEPTIONS entry {sid!r}: snippet "
                    f"{snippet!r} now parses clean with kind {kind!r} present -- "
                    f"remove it from BR_PARSE_EXCEPTIONS")
            else:
                why = "ERROR/MISSING" if has_error else f"kind {kind!r} absent"
                br_exception_hits.append(
                    f"{sid} ({why}): {BR_PARSE_EXCEPTIONS[sid]}")
            continue
        if has_error:
            problems.append(f"[B-br] {sid}: snippet {snippet!r} produced ERROR/MISSING")
        elif not kind_present:
            problems.append(f"[B-br] {sid}: kind {kind!r} not found in parse of {snippet!r}")

    # exception hygiene: an entry that names a non-brighterscript / unknown leaf
    # id can never fire and is dead -- flag it so the allowlist stays honest.
    for sid in sorted(set(BR_PARSE_EXCEPTIONS) - used_exceptions):
        problems.append(
            f"[B-br] dead BR_PARSE_EXCEPTIONS entry {sid!r}: no brighterscript "
            f"coverage leaf has this id -- remove it from BR_PARSE_EXCEPTIONS")

    # ---- report -------------------------------------------------------------
    n = len(cov)
    print(f"coverage leaves: {n}   brightscript+stdlib snippets parsed: {checked}")
    print(f"brighterscript snippets parsed: {br_checked} "
          f"({len(br_exception_hits)} known-issue exception(s) reported)")
    print(f"node kinds: brightscript={len(bs_kinds)}  scenegraph={len(sg_kinds)}  "
          f"brighterscript={len(br_kinds)}")
    if br_exception_hits:
        print("\nbrighterscript known parse issues (reported for human follow-up, "
              "tracked in BR_PARSE_EXCEPTIONS):")
        for h in br_exception_hits:
            print("  - " + h)
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
