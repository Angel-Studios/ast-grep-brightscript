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

# (filename relative to this script, [start symbols], [imported ebnf files]) for
# the default run. The optional third element lists sibling .ebnf specs whose
# rule definitions this target may reference WITHOUT redefining them ("imports").
# A locally redefined rule SHADOWS the imported one (true grammar override) -- so
# brighterscript.ebnf layers onto brightscript.ebnf by redefining only the few
# "seam" productions it extends (Expression, Type, Primary, ...) and referencing
# everything else, mirroring how a superset language extends its base.
DEFAULT_TARGETS = [
    ("brightscript.ebnf", ["SourceFile"], []),
    ("scenegraph.ebnf", ["SGDocument", "document"], []),
    ("brighterscript.ebnf", ["BrighterScriptSourceFile"], ["brightscript.ebnf"]),
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


def parse_defs(path):
    """Return (defs list, duplicate names, {name: rhs body}) for one .ebnf file."""
    clean = strip_noise(open(path, encoding="utf-8").read())
    items = list(re.finditer(r"(?m)^\s*([A-Za-z_]\w*)\s*::=", clean))
    defs, dups, bodies = [], [], {}
    for i, m in enumerate(items):
        name = m.group(1)
        if name in bodies:
            dups.append(name)
        defs.append(name)
        end = items[i + 1].start() if i + 1 < len(items) else len(clean)
        bodies[name] = clean[m.end():end]
    return defs, dups, bodies


def analyze(path, starts, imports=()):
    defs, dups, bodies = parse_defs(path)
    defined = set(defs)

    # Imported specs contribute defined names + bodies, but a LOCAL definition
    # shadows an imported one (override). Imported rules are not re-validated
    # here (their own target does that); we only need them to resolve refs and
    # to follow reachability into the parts this spec reuses.
    import_defined, import_bodies = set(), {}
    for imp in imports:
        ipath = os.path.join(os.path.dirname(path), imp)
        idefs, _, ibodies = parse_defs(ipath)
        import_defined |= set(idefs)
        for k, v in ibodies.items():
            import_bodies.setdefault(k, v)
    known = defined | import_defined

    refs = set()
    for body in bodies.values():
        refs |= set(re.findall(r"[A-Za-z_]\w*", body))
    undefined = sorted(refs - known)

    resolve = {**import_bodies, **bodies}  # local wins -> shadowing
    seen, stack = set(), [s for s in starts if s in known]
    while stack:
        n = stack.pop()
        if n in seen:
            continue
        seen.add(n)
        stack += [r for r in re.findall(r"[A-Za-z_]\w*", resolve.get(n, "")) if r in known]
    unreachable = sorted(defined - seen)  # only this spec's own rules

    return {
        "defined": len(defined),
        "undefined": undefined,
        "duplicates": sorted(set(dups)),
        "unreachable": unreachable,
        "missing_start": [s for s in starts if s not in known],
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
    # FILE:Start1,Start2[:import1.ebnf,import2.ebnf]
    path, _, rest = arg.partition(":")
    starts_part, _, imports_part = rest.partition(":")
    starts = [s for s in starts_part.split(",") if s]
    imports = [i for i in imports_part.split(",") if i]
    return path, starts, imports


def main(argv):
    if argv:
        targets = [parse_target(a) for a in argv]
    else:
        targets = [(os.path.join(HERE, f), s, imp) for f, s, imp in DEFAULT_TARGETS]
    any_err = False
    for path, starts, imports in targets:
        any_err |= report(path, starts, analyze(path, starts, imports))
    print(f"\n{'FAIL: structural errors found.' if any_err else 'PASS: all specs internally consistent.'}")
    return 1 if any_err else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
