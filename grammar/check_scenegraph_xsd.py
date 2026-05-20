#!/usr/bin/env python3
"""Faithfulness checker: diff scenegraph.ebnf's enumerations against the
official RokuSceneGraph.xsd (Level 2 validation -- see grammar/CLAUDE.md).

The XSD is the normative source the SceneGraph grammar was derived from, so the
EBNF's hand-maintained enumerations must not drift from it. This tool mechanically
compares three things and exits non-zero on any mismatch:

  * FieldType            <->  the <field> `type` attribute enumeration
                              (compared case-insensitively; the docs say the
                              field `type` value is case-insensitive)
  * BuiltinNodeClass     <->  the `extends` attribute enumeration
                              (compared case-sensitively; PascalCase is canonical)
  * FieldAttribute names <->  the <field> element's attributes

A vendored copy of the schema lives next to this script
(grammar/RokuSceneGraph.xsd) so the diff is reproducible offline. Pass --url to
refresh it from devtools.web.roku.com.

Usage:
    python3 check_scenegraph_xsd.py                 # use vendored XSD
    python3 check_scenegraph_xsd.py --xsd PATH      # use a specific XSD
    python3 check_scenegraph_xsd.py --url           # fetch the canonical XSD
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
EBNF = os.path.join(HERE, "scenegraph.ebnf")
VENDORED_XSD = os.path.join(HERE, "RokuSceneGraph.xsd")
XSD_URL = "https://devtools.web.roku.com/schema/RokuSceneGraph.xsd"


# ---- EBNF side -------------------------------------------------------------

def ebnf_rule_body(text, name):
    """Raw RHS text of `name ::= ...` up to the next top-level `Rule ::=`."""
    m = re.search(rf"(?m)^\s*{name}\s*::=", text)
    if not m:
        raise SystemExit(f"ERROR: rule {name!r} not found in {EBNF}")
    rest = text[m.end():]
    nxt = re.search(r"(?m)^\s*[A-Za-z_]\w*\s*::=", rest)
    body = rest[: nxt.start()] if nxt else rest
    return re.sub(r"\(\*.*?\*\)", " ", body, flags=re.S)  # drop comments


def ebnf_literals(text, name):
    """Quoted terminals on the RHS of a rule (the enumeration members)."""
    body = ebnf_rule_body(text, name)
    return [m.group(1) or m.group(2)
            for m in re.finditer(r"'([^']*)'|\"([^\"]*)\"", body)]


# ---- XSD side --------------------------------------------------------------

def xsd_field_element(xsd):
    m = re.search(r'<xs:element\b[^>]*\bname="field"[^>]*>.*?</xs:element>',
                  xsd, re.S)
    return m.group(0) if m else ""


def xsd_field_type_enum(xsd):
    fld = xsd_field_element(xsd)
    attr = re.search(r'<xs:attribute name="type".*?</xs:attribute>', fld, re.S)
    raw = re.findall(r'enumeration value="([^"]*)"', attr.group(0)) if attr else []
    # XSD encodes aliases as one comma-joined token, e.g. "Boolean, bool".
    out = []
    for v in raw:
        out += [p.strip() for p in v.split(",")]
    return out


def xsd_extends_enum(xsd):
    m = re.search(r'name="extends".*?</xs:attribute>', xsd, re.S)
    return re.findall(r'enumeration value="([^"]*)"', m.group(0)) if m else []


def xsd_field_attrs(xsd):
    return re.findall(r'<xs:attribute name="([^"]+)"', xsd_field_element(xsd))


# ---- diff ------------------------------------------------------------------

def diff(label, ebnf_vals, xsd_vals, fold=False):
    key = (lambda s: s.lower()) if fold else (lambda s: s)
    e = {key(v): v for v in ebnf_vals}
    x = {key(v): v for v in xsd_vals}
    missing = sorted(x[k] for k in x.keys() - e.keys())   # in XSD, not in EBNF
    extra = sorted(e[k] for k in e.keys() - x.keys())     # in EBNF, not in XSD
    ok = not missing and not extra
    print(f"\n=== {label}  [{'ok' if ok else 'MISMATCH'}] ===")
    print(f"  EBNF {len(e)} members  vs  XSD {len(x)} members"
          f"  ({'case-insensitive' if fold else 'case-sensitive'})")
    if missing:
        print(f"  MISSING from EBNF (present in XSD): {missing}")
    if extra:
        print(f"  EXTRA in EBNF (absent from XSD):    {extra}")
    return ok


def load_xsd(argv):
    if "--url" in argv:
        import urllib.request
        print(f"fetching {XSD_URL} ...")
        data = urllib.request.urlopen(XSD_URL, timeout=30).read()
        open(VENDORED_XSD, "wb").write(data)
        return data.decode("utf-8")
    if "--xsd" in argv:
        path = argv[argv.index("--xsd") + 1]
    elif os.path.exists(VENDORED_XSD):
        path = VENDORED_XSD
    else:
        raise SystemExit(
            f"ERROR: no XSD found at {VENDORED_XSD}.\n"
            f"       run with --url to fetch it, or pass --xsd PATH.")
    return open(path, encoding="utf-8").read()


def main(argv):
    xsd = load_xsd(argv)
    ebnf = open(EBNF, encoding="utf-8").read()
    ok = True
    ok &= diff("FieldType vs <field> type enum",
               ebnf_literals(ebnf, "FieldType"), xsd_field_type_enum(xsd),
               fold=True)
    ok &= diff("BuiltinNodeClass vs extends enum",
               ebnf_literals(ebnf, "BuiltinNodeClass"), xsd_extends_enum(xsd))
    ok &= diff("FieldAttribute names vs <field> attributes",
               ebnf_literals(ebnf, "FieldAttribute"), xsd_field_attrs(xsd))
    print(f"\n{'PASS: scenegraph.ebnf matches the XSD.' if ok else 'FAIL: enumerations drifted from the XSD.'}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
