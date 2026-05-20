#!/usr/bin/env python3
"""EBNF <-> node-types parity gate (validation Level 5).

Keeps the authoritative EBNF specs in `grammar/` from silently drifting away
from the generated tree-sitter grammars. Both grammar.js files were authored so
that "grammar.js rule names mirror coverage kinds" and "EBNF rule names mirror
coverage kinds" -- so an EBNF production and the named tree-sitter node it
becomes should share a name. This script asserts that, per language:

  A. Every EBNF rule name (the LHS of a `Name ::= ...` production) is either
       * a named node `kind` in the corresponding generated node-types.json, OR
       * an allowlisted LEXICAL HELPER / supertype-grouping rule that, by design,
         is folded into a token or a hidden dispatch rule and is therefore NOT a
         standalone node (see EBNF_NON_NODE_* below -- each has a justification).

  B. Every named node `kind` is either
       * an EBNF rule of the same name, OR
       * an allowlisted RECONCILIATION kind: a concrete, ast-grep-matchable node
         deliberately introduced in grammar.js during coverage reconciliation
         that has no 1:1 EBNF production (see KIND_WITHOUT_EBNF_* below).

Anything outside those two escape hatches is unexplained drift: the script
prints a grouped report and exits non-zero. Run from the repo root:

    python3 grammar/check_parity.py

This is "Level 5" alongside check_coverage.py (Level 1) and check_grammar.py
(Level 3); keep all three GREEN.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BS_EBNF = ROOT / "grammar" / "brightscript.ebnf"
SG_EBNF = ROOT / "grammar" / "scenegraph.ebnf"
BS_NODES = ROOT / "tree-sitter-brightscript" / "src" / "node-types.json"
SG_NODES = ROOT / "tree-sitter-scenegraph" / "src" / "node-types.json"

# A production header:  Name ::= ...   (the LHS rule name; comments are stripped
# first so a `::=` inside a (* ... *) comment can never be mistaken for a rule).
RULE_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*::=")
# Block-comment form used by BOTH ebnf files: (* ... *) (the C-ish (*  *)).
COMMENT_RE = re.compile(r"\(\*.*?\*\)", re.S)
# UPPER_SNAKE = a documented lexical (token) rule. The brightscript.ebnf header
# states the convention explicitly: "UPPER_SNAKE = lexical (token) rules /
# terminals produced by the lexer (keywords, literals, punctuation)." These are
# folded into grammar.js tokens / string literals and are never their own node,
# so they are excluded wholesale rather than listed one operator at a time.
UPPER_SNAKE_RE = re.compile(r"^[A-Z][A-Z0-9_]*$")


# ---------------------------------------------------------------------------
# Allowlist 1 (EBNF side): rules that intentionally are NOT standalone nodes.
#
# Two genuine sub-categories, both verifiable in the matching grammar.js:
#   (a) LEXICAL FRAGMENT -- a sub-token piece folded into a single token regex
#       (e.g. a digit run inside a numeric token); never emitted on its own.
#   (b) GROUPING / DISPATCH SUPERTYPE -- an abstract "one of these" rule that in
#       grammar.js is a hidden `_X` choice (or is otherwise inlined), so the
#       concrete alternative shows up in the tree, not the grouping itself.
# UPPER_SNAKE token rules are handled separately (UPPER_SNAKE_RE above), so they
# are NOT repeated here.
# ---------------------------------------------------------------------------
EBNF_NON_NODE_BS = {
    # --- (a) lexical fragments (folded into a token regex) ---
    "Char":             "lexical fragment: 'any Unicode char'; never its own node.",
    "DecDigits":        "lexical fragment of the numeric tokens (a digit run).",
    "HexDigits":        "lexical fragment of HexLiteral (hex digit run).",
    "FloatExp":         "lexical fragment of FloatLiteral (the e/E exponent).",
    "DoubleExp":        "lexical fragment of DoubleLiteral (the d/D exponent).",
    "Sign":             "lexical fragment ('+'/'-') inside the exponent tokens.",
    "IdentCont":        "lexical fragment of Identifier (continuation char class).",
    "CommentText":      "lexical fragment of Comment (run to end-of-line).",
    "ErrorMessageText": "lexical fragment of ErrorDirective (#error message text).",
    # --- (b) grouping / dispatch supertypes (hidden `_X` choice in grammar.js) ---
    "TopLevelItem":     "dispatch grouping -> hidden _TopLevelItem choice in grammar.js.",
    "Statement":        "dispatch grouping -> hidden _Statement choice in grammar.js.",
    "BlockItem":        "dispatch grouping -> hidden _BlockItem choice in grammar.js.",
    "BlockItemsCC":     "grouping: #if block body, inlined as alias(blockBody,$.Block).",
    "ConditionalCompilation": "dispatch grouping -> hidden _ConditionalCompilation choice.",
    "PrintItem":        "dispatch grouping -> hidden _PrintItem choice in grammar.js.",
    "PostfixSuffix":    "grouping of the postfix suffixes; inlined into PostfixExpr's choice.",
    "Expression":       "dispatch grouping -> hidden _Expression precedence cascade.",
    "ReservedWord":     "lexical set: the reserved-word inventory (no node; see _reserved_word).",
    "ContextualKeyword":"lexical set: contextual/soft keywords (documentation only, no node).",
    "ReservedBuiltinName": "lexical set -> hidden _ReservedBuiltinName, aliased to Identifier.",
}

EBNF_NON_NODE_SG = {
    # --- (a) lexical fragments (folded into a token regex) ---
    "Char":          "lexical fragment: W3C XML Char class; never its own node.",
    "NameStartChar": "lexical fragment of Name (W3C XML NameStartChar class).",
    "NameChar":      "lexical fragment of Name (W3C XML NameChar class).",
    "CData":         "lexical fragment: CDATA body bytes (folded into CDSect/_cdata_body).",
    "CDStart":       "lexical fragment: the '<![CDATA[' delimiter (part of the CDSect token).",
    "CDEnd":         "lexical fragment: the ']]>' delimiter (part of the CDSect token).",
    "EncName":       "lexical fragment of EncodingDecl (the encoding name; inside AttValue).",
    "VersionNum":    "lexical fragment of VersionInfo (the version number; inside AttValue).",
    "PITarget":      "lexical fragment of PI (target name; folded into the _pi_rest token).",
    "PubidChar":     "lexical fragment of PubidLiteral (pubid char class).",
    "STag":          "tag fragment: generic XML start-tag, inlined as hidden _GenericSTag.",
    "ETag":          "tag fragment: generic XML end-tag, inlined as hidden _GenericETag.",
    # --- XML-1.0 completeness productions NOT used by SceneGraph (no node) ---
    # The generic-XML layer is a faithful W3C subset; these prolog/DTD/entity
    # productions exist for completeness but SceneGraph files never use them, so
    # grammar.js omits them entirely (note 6 of scenegraph.ebnf).
    "EntityValue":         "XML DTD completeness only; SceneGraph never uses it -> no node.",
    "SystemLiteral":       "XML DTD completeness only (ExternalID literal) -> no node.",
    "PubidLiteral":        "XML DTD completeness only (PUBLIC id literal) -> no node.",
    "ExternalID":          "XML DTD completeness only (SYSTEM/PUBLIC id) -> no node.",
    "doctypedecl":         "XML DOCTYPE completeness only; not used in SceneGraph -> no node.",
    "intSubset":           "XML DTD internal-subset completeness only -> no node.",
    "markupdecl":          "XML DTD markup-decl completeness only -> no node.",
    "PEReference":         "XML parameter-entity ref (DTD only); not used -> no node.",
    "PredefinedEntityRef": "documentation-only set of the 5 predefined entities (Reference covers them).",
    "Names":               "XML helper (whitespace-separated Name list); unused -> no node.",
    "Nmtoken":             "XML tokenized-attr helper; unused -> no node.",
    "Nmtokens":            "XML tokenized-attr helper; unused -> no node.",
    # --- grouping / dispatch + structural rules inlined in grammar.js ---
    "document":         "Layer-1 generic-XML document grouping; root is SGDocument.",
    "content":          "generic element content grouping -> hidden _GenericContent.",
    "Misc":             "grouping (Comment | PI | S); inlined wherever misc content is allowed.",
    "ScriptContent":    "grouping of inline-script content; inlined into _ScriptInline.",
    "ScriptInline":     "alternative of Script -> hidden _ScriptInline in grammar.js.",
    "ComponentContent": "grouping of <component> children -> hidden _ComponentContent choice.",
}


# ---------------------------------------------------------------------------
# Allowlist 2 (kind side): node kinds with no 1:1 EBNF production. These are the
# concrete, ast-grep-matchable nodes that coverage reconciliation introduced in
# grammar.js (roadmap/03-status.md "Coverage reconciliation"). Supertypes that
# ast-grep cannot match were reassigned to concrete subtypes -- but ALL of those
# subtypes (AnonFunctionExpr, OC_BRACKET, EOS, the *Literal kinds, ...) already
# exist as EBNF rules, so they reconcile by name and do NOT need listing here.
# The ONLY genuinely EBNF-less kind is the alias() node below.
# ---------------------------------------------------------------------------
KIND_WITHOUT_EBNF_BS: dict[str, str] = {
    # (none -- every BrightScript node kind has a same-named EBNF rule)
}

KIND_WITHOUT_EBNF_SG = {
    "ScriptType": "reconciliation: alias() node for the fixed 'text/brightscript' "
                  "literal inside ScriptTypeAttValue (grammar.js), so ast-grep can "
                  "match the type value; the EBNF only spells ScriptTypeAttValue.",
}


def ebnf_rule_names(path: Path) -> list[str]:
    """All LHS rule names in an EBNF file (comments stripped first)."""
    text = COMMENT_RE.sub("", path.read_text())
    names: list[str] = []
    for line in text.splitlines():
        m = RULE_RE.match(line)
        if m:
            names.append(m.group(1))
    return names


def named_kinds(path: Path) -> set[str]:
    return {t["type"] for t in json.loads(path.read_text()) if t.get("named")}


def check(lang: str, ebnf: Path, nodes: Path,
          ebnf_allow: dict[str, str], kind_allow: dict[str, str],
          problems: list[str]) -> tuple[int, int]:
    rule_list = ebnf_rule_names(ebnf)
    rules = set(rule_list)
    kinds = named_kinds(nodes)

    dupes = sorted({r for r in rules if rule_list.count(r) > 1})
    for d in dupes:
        problems.append(f"[{lang}] duplicate EBNF rule definition: {d!r}")

    # ---- A. every EBNF rule -> a kind, or an allowlisted non-node ----------
    rule_no_kind = rules - kinds
    drift_rules = sorted(
        r for r in rule_no_kind
        if not UPPER_SNAKE_RE.match(r) and r not in ebnf_allow
    )
    for r in drift_rules:
        problems.append(
            f"[{lang}] EBNF rule {r!r} has NO node kind and is not an "
            f"allowlisted lexical helper (possible spec->grammar drift)")

    # ---- B. every kind -> an EBNF rule, or an allowlisted reconciliation ---
    kind_no_rule = sorted((kinds - rules) - set(kind_allow))
    for k in kind_no_rule:
        problems.append(
            f"[{lang}] node kind {k!r} has NO EBNF rule and is not an "
            f"allowlisted reconciliation kind (possible grammar->spec drift)")

    # ---- allowlist hygiene: flag stale entries that no longer apply --------
    stale_ebnf = sorted(a for a in ebnf_allow if a not in rule_no_kind)
    for a in stale_ebnf:
        problems.append(
            f"[{lang}] stale EBNF allowlist entry {a!r}: it now maps to a node "
            f"kind (or is no longer a rule) -- remove it from the allowlist")
    stale_kind = sorted(a for a in kind_allow if a not in (kinds - rules))
    for a in stale_kind:
        problems.append(
            f"[{lang}] stale kind allowlist entry {a!r}: it now matches an EBNF "
            f"rule (or is no longer a kind) -- remove it from the allowlist")

    snake = sum(1 for r in rule_no_kind if UPPER_SNAKE_RE.match(r))
    matched = len(rules & kinds)
    print(f"{lang}: {len(rules)} EBNF rules, {len(kinds)} node kinds  "
          f"-> {matched} matched by name")
    print(f"  non-node EBNF rules: {snake} UPPER_SNAKE token rules + "
          f"{len(ebnf_allow)} allowlisted helpers")
    print(f"  reconciliation kinds (no EBNF rule): {len(kind_allow)}")
    return matched, len(drift_rules) + len(kind_no_rule)


def main() -> int:
    problems: list[str] = []
    print("EBNF <-> node-types parity (Level 5)\n")
    check("brightscript", BS_EBNF, BS_NODES,
          EBNF_NON_NODE_BS, KIND_WITHOUT_EBNF_BS, problems)
    print()
    check("scenegraph", SG_EBNF, SG_NODES,
          EBNF_NON_NODE_SG, KIND_WITHOUT_EBNF_SG, problems)

    if problems:
        print(f"\n✗ {len(problems)} parity problem(s):")
        for p in problems:
            print("  " + p)
        print("\n✗ parity gate: RED")
        return 1
    print("\n✓ parity gate: GREEN "
          "(every EBNF rule maps to a node kind or an allowlisted helper, "
          "and every kind maps to an EBNF rule or a reconciliation kind)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
