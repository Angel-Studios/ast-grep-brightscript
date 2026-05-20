#!/usr/bin/env python3
"""Structural consistency checker for the W3C-style EBNF grammar specs.

This is Level 0 of the grammar validation strategy (see grammar/CLAUDE.md): it
does NOT check that the grammar describes real BrightScript/SceneGraph -- only
that the EBNF is internally sound and therefore safe to translate into a
tree-sitter grammar.js. It reports:

  * UNDEFINED references -- a rule RHS names a non-terminal that is never
    defined with `::=`. These are hard errors: a literal EBNF -> grammar.js
    translation would dangle here.  (exit 1)
  * DUPLICATE definitions -- the same rule defined twice.  (exit 1)
  * UNREACHABLE rules -- defined but not reachable from the start symbol.
    Reported as INFO, not an error: lexer `extra` tokens (WS), documentation
    inventories (ReservedWord), and XML-completeness rules are legitimately
    unreachable from the syntactic start symbol.

Usage:
    python3 check_ebnf.py                       # check the two bundled specs
    python3 check_ebnf.py FILE:Start[,Start2]   # check an explicit target
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

# (filename relative to this script, [start symbols]) for the default run.
DEFAULT_TARGETS = [
    ("brightscript.ebnf", ["SourceFile"]),
    ("scenegraph.ebnf", ["SGDocument", "document"]),
]


def strip_noise(text):
    """Remove everything that is not a rule reference so identifier scanning is
    accurate: (* block comments *), then char-classes and quoted terminals in
    ONE left-to-right pass (so the construct that opens first wins and "'" /
    '"' / [^"] are handled correctly), then standalone hex codes."""
    text = re.sub(r"\(\*.*?\*\)", " ", text, flags=re.S)
    text = re.sub(r"""\[[^\]]*\]|"[^"]*"|'[^']*'""", " ", text)
    text = re.sub(r"#x[0-9A-Fa-f]+", " ", text)
    return text


def analyze(path, starts):
    clean = strip_noise(open(path, encoding="utf-8").read())
    items = list(re.finditer(r"(?m)^\s*([A-Za-z_]\w*)\s*::=", clean))
    defs, dups, bodies = [], [], {}
    for i, m in enumerate(items):
        name = m.group(1)
        if name in defs:
            dups.append(name)
        defs.append(name)
        end = items[i + 1].start() if i + 1 < len(items) else len(clean)
        bodies[name] = clean[m.end():end]
    defined = set(defs)

    refs = set()
    for body in bodies.values():
        refs |= set(re.findall(r"[A-Za-z_]\w*", body))
    undefined = sorted(refs - defined)

    seen, stack = set(), [s for s in starts if s in defined]
    while stack:
        n = stack.pop()
        if n in seen:
            continue
        seen.add(n)
        stack += [r for r in re.findall(r"[A-Za-z_]\w*", bodies[n]) if r in defined]
    unreachable = sorted(defined - seen)

    return {
        "defined": len(defined),
        "undefined": undefined,
        "duplicates": sorted(set(dups)),
        "unreachable": unreachable,
        "missing_start": [s for s in starts if s not in defined],
    }


def report(path, starts, r):
    errors = bool(r["undefined"] or r["duplicates"] or r["missing_start"])
    mark = "FAIL" if errors else "ok"
    print(f"\n=== {os.path.relpath(path)}  [{mark}] ===")
    print(f"  defined rules : {r['defined']}   start: {', '.join(starts)}")
    if r["missing_start"]:
        print(f"  ERROR  start symbol(s) not defined: {r['missing_start']}")
    print(f"  ERROR  undefined references ({len(r['undefined'])}): "
          f"{r['undefined'] or 'none'}")
    print(f"  ERROR  duplicate definitions ({len(r['duplicates'])}): "
          f"{r['duplicates'] or 'none'}")
    print(f"  info   unreachable from start ({len(r['unreachable'])}): "
          f"{r['unreachable'] or 'none'}")
    return errors


def parse_target(arg):
    path, _, starts = arg.partition(":")
    return path, [s for s in starts.split(",") if s]


def main(argv):
    if argv:
        targets = [parse_target(a) for a in argv]
    else:
        targets = [(os.path.join(HERE, f), s) for f, s in DEFAULT_TARGETS]
    any_err = False
    for path, starts in targets:
        any_err |= report(path, starts, analyze(path, starts))
    print(f"\n{'FAIL: structural errors found.' if any_err else 'PASS: all specs internally consistent.'}")
    return 1 if any_err else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
