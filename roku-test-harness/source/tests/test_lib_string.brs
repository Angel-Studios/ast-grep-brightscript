' test_lib_string.brs - STANDARD-LIBRARY coverage of the roString component's
' ifString / ifStringOps method set, exercised in the Main scope.
'
' This is the "stdlib" layer of the coverage taxonomy: every leaf invokes a real
' Roku string method as a CallExpression and asserts the concrete device result,
' so the device is the oracle for the future tree-sitter grammar's understanding
' of method-call shapes on a boxed/intrinsic string.
'
' AUTO-BOXING: an intrinsic string literal auto-boxes to roString when a method
' is called on it (e.g. "abc".Len()), so ifString methods can be called directly
' on string values. GetString/SetString require an explicit roString object
' (CreateObject("roString")), which the relevant specs construct.
'
' DEFENSIVE PATTERN: an uncaught runtime error aborts the WHOLE suite, so every
' spec body is wrapped in try/catch; the catch records a FAIL for that spec only.
'
' Each t.spec id/kind is mirrored in grammar/coverage_frags/string.json.

sub test_lib_string_all(t as Object)
    ' =====================================================================
    ' LENGTH / SUBSTRING EXTRACTION (ifString / ifStringOps)
    ' =====================================================================

    ' Len() - character count of the string.
    t.spec("lib.string.len", "CallExpression", "roString Len")
    try
        n = "hello".Len()
        t.assertEqual("lib.string.len", n, 5)
    catch e
        t.assertTrue("lib.string.len: runtime error", false)
    end try

    ' Left(n) - leftmost n characters.
    t.spec("lib.string.left", "CallExpression", "roString Left")
    try
        s = "hello".Left(3)
        t.assertEqual("lib.string.left", s, "hel")
    catch e
        t.assertTrue("lib.string.left: runtime error", false)
    end try

    ' Right(n) - rightmost n characters.
    t.spec("lib.string.right", "CallExpression", "roString Right")
    try
        s = "hello".Right(2)
        t.assertEqual("lib.string.right", s, "lo")
    catch e
        t.assertTrue("lib.string.right: runtime error", false)
    end try

    ' DEVICE FACT (#16): the ifString Mid METHOD is 0-INDEXED (the GLOBAL Mid()
    ' function is 1-indexed). "hello".Mid(2) -> "llo".
    t.spec("lib.string.mid2", "CallExpression", "roString Mid (2-arg: start to end, 0-indexed)")
    try
        s = "hello".Mid(2)
        t.assertEqual("lib.string.mid2", s, "llo")
    catch e
        t.assertTrue("lib.string.mid2: runtime error", false)
    end try

    ' Mid(start, len) - 0-indexed substring of length len. "hello".Mid(2,3) -> "llo".
    t.spec("lib.string.mid3", "CallExpression", "roString Mid (3-arg: start, length, 0-indexed)")
    try
        s = "hello".Mid(2, 3)
        t.assertEqual("lib.string.mid3", s, "llo")
    catch e
        t.assertTrue("lib.string.mid3: runtime error", false)
    end try

    ' =====================================================================
    ' SEARCH (Instr) - 0-indexed, -1 when not found
    ' =====================================================================

    ' Instr(substring) - index of first occurrence (0-indexed).
    t.spec("lib.string.instr", "CallExpression", "roString Instr (find substring, 0-indexed)")
    try
        i = "hello".Instr("ll")
        t.assertEqual("lib.string.instr", i, 2)
    catch e
        t.assertTrue("lib.string.instr: runtime error", false)
    end try

    ' Instr(startIndex, substring) - search starting at startIndex.
    t.spec("lib.string.instr_start", "CallExpression", "roString Instr with start index")
    try
        i = "abcabc".Instr(3, "bc")
        t.assertEqual("lib.string.instr_start", i, 4)
    catch e
        t.assertTrue("lib.string.instr_start: runtime error", false)
    end try

    ' Instr() not found returns -1.
    t.spec("lib.string.instr_notfound", "CallExpression", "roString Instr returns -1 when absent")
    try
        i = "hello".Instr("z")
        t.assertEqual("lib.string.instr_notfound", i, -1)
    catch e
        t.assertTrue("lib.string.instr_notfound: runtime error", false)
    end try

    ' =====================================================================
    ' EXPLICIT roString OBJECT: GetString / SetString / AppendString
    ' =====================================================================

    ' GetString() - read back the value of a boxed roString. DEVICE FACT (#15):
    ' CreateObject("roString","abc") ignores the value arg; box("abc") boxes it.
    t.spec("lib.string.getstring", "CallExpression", "roString GetString (on box(string))")
    try
        ro = box("abc")
        s = ro.GetString()
        t.assertEqual("lib.string.getstring", s, "abc")
    catch e
        t.assertTrue("lib.string.getstring: runtime error", false)
    end try

    ' SetString(s) - overwrite the value; read back via GetString.
    t.spec("lib.string.setstring", "CallExpression", "roString SetString")
    try
        ro = CreateObject("roString")
        ro.SetString("xyz")
        t.assertEqual("lib.string.setstring", ro.GetString(), "xyz")
    catch e
        t.assertTrue("lib.string.setstring: runtime error", false)
    end try

    ' AppendString(s, len) - append the first len chars of s. Seed the base via
    ' SetString (CreateObject("roString","foo") would ignore the value - fact #15).
    t.spec("lib.string.appendstring", "CallExpression", "roString AppendString (first len chars)")
    try
        ro = CreateObject("roString")
        ro.SetString("foo")
        ro.AppendString("barbaz", 3)
        t.assertEqual("lib.string.appendstring", ro.GetString(), "foobar")
    catch e
        t.assertTrue("lib.string.appendstring: runtime error", false)
    end try

    ' =====================================================================
    ' TRANSFORMS: Replace / Trim
    ' =====================================================================

    ' Replace(from, to) - replace all occurrences.
    t.spec("lib.string.replace", "CallExpression", "roString Replace (all occurrences)")
    try
        s = "a-b-c".Replace("-", "_")
        t.assertEqual("lib.string.replace", s, "a_b_c")
    catch e
        t.assertTrue("lib.string.replace: runtime error", false)
    end try

    ' Trim() - strip leading and trailing whitespace.
    t.spec("lib.string.trim", "CallExpression", "roString Trim (strip surrounding whitespace)")
    try
        s = "  hi  ".Trim()
        t.assertEqual("lib.string.trim", s, "hi")
    catch e
        t.assertTrue("lib.string.trim: runtime error", false)
    end try

    ' =====================================================================
    ' NUMERIC PARSE: ToInt / ToFloat
    ' =====================================================================

    ' ToInt() - parse the leading integer.
    t.spec("lib.string.toint", "CallExpression", "roString ToInt")
    try
        n = "42".ToInt()
        t.assertEqual("lib.string.toint", n, 42)
    catch e
        t.assertTrue("lib.string.toint: runtime error", false)
    end try

    ' ToFloat() - parse a floating-point value.
    t.spec("lib.string.tofloat", "CallExpression", "roString ToFloat")
    try
        f = "3.5".ToFloat()
        t.assertEqual("lib.string.tofloat", f, 3.5)
    catch e
        t.assertTrue("lib.string.tofloat: runtime error", false)
    end try

    ' =====================================================================
    ' SPLITTING: Tokenize (skips empties, roList) / Split (keeps empties, roArray)
    ' =====================================================================

    ' Tokenize(delim) - split into a roList on any char in delim; empty tokens
    ' are skipped (collapses runs of delimiters).
    t.spec("lib.string.tokenize", "CallExpression", "roString Tokenize (roList, skips empties)")
    try
        parts = "a,b,c".Tokenize(",")
        t.assertEqual("lib.string.tokenize", parts.Count(), 3)
    catch e
        t.assertTrue("lib.string.tokenize: runtime error", false)
    end try

    ' Split(delim) - split into a roArray on the literal delimiter; empty tokens
    ' between adjacent delimiters are kept.
    t.spec("lib.string.split", "CallExpression", "roString Split (roArray, keeps empties)")
    try
        parts = "a,,b".Split(",")
        t.assertEqual("lib.string.split", parts.Count(), 3)
    catch e
        t.assertTrue("lib.string.split: runtime error", false)
    end try

    ' Split element access - the array elements are the substrings.
    t.spec("lib.string.split_elem", "CallExpression", "roString Split element access")
    try
        parts = "a,b,c".Split(",")
        t.assertEqual("lib.string.split_elem", parts[1], "b")
    catch e
        t.assertTrue("lib.string.split_elem: runtime error", false)
    end try

    ' =====================================================================
    ' PREFIX / SUFFIX TESTS: StartsWith / EndsWith
    ' =====================================================================

    ' StartsWith(s) - true when the string begins with s.
    t.spec("lib.string.startswith", "CallExpression", "roString StartsWith")
    try
        b = "hello".StartsWith("he")
        t.assertTrue("lib.string.startswith", b)
    catch e
        t.assertTrue("lib.string.startswith: runtime error", false)
    end try

    ' StartsWith(s, offset) - test the prefix beginning at offset.
    t.spec("lib.string.startswith_offset", "CallExpression", "roString StartsWith with offset")
    try
        b = "hello".StartsWith("llo", 2)
        t.assertTrue("lib.string.startswith_offset", b)
    catch e
        t.assertTrue("lib.string.startswith_offset: runtime error", false)
    end try

    ' EndsWith(s) - true when the string ends with s.
    t.spec("lib.string.endswith", "CallExpression", "roString EndsWith")
    try
        b = "hello".EndsWith("lo")
        t.assertTrue("lib.string.endswith", b)
    catch e
        t.assertTrue("lib.string.endswith: runtime error", false)
    end try

    ' EndsWith(s, len) - test the suffix as if the string were truncated to len.
    t.spec("lib.string.endswith_len", "CallExpression", "roString EndsWith with length")
    try
        b = "hello".EndsWith("ell", 4)
        t.assertTrue("lib.string.endswith_len", b)
    catch e
        t.assertTrue("lib.string.endswith_len: runtime error", false)
    end try

    ' =====================================================================
    ' URI / ESCAPE ENCODING (ifStringOps)
    ' =====================================================================

    ' Escape() - percent-encode reserved characters (a space -> %20).
    t.spec("lib.string.escape", "CallExpression", "roString Escape (percent-encode)")
    try
        s = "a b".Escape()
        t.assertEqual("lib.string.escape", s, "a%20b")
    catch e
        t.assertTrue("lib.string.escape: runtime error", false)
    end try

    ' Unescape() - reverse of Escape().
    t.spec("lib.string.unescape", "CallExpression", "roString Unescape")
    try
        s = "a%20b".Unescape()
        t.assertEqual("lib.string.unescape", s, "a b")
    catch e
        t.assertTrue("lib.string.unescape: runtime error", false)
    end try

    ' EncodeUri() - encode a URI, leaving URI-structural chars intact.
    t.spec("lib.string.encodeuri", "CallExpression", "roString EncodeUri")
    try
        s = "http://x.com/a b".EncodeUri()
        t.assertEqual("lib.string.encodeuri", s, "http://x.com/a%20b")
    catch e
        t.assertTrue("lib.string.encodeuri: runtime error", false)
    end try

    ' DecodeUri() - reverse of EncodeUri().
    t.spec("lib.string.decodeuri", "CallExpression", "roString DecodeUri")
    try
        s = "http://x.com/a%20b".DecodeUri()
        t.assertEqual("lib.string.decodeuri", s, "http://x.com/a b")
    catch e
        t.assertTrue("lib.string.decodeuri: runtime error", false)
    end try

    ' EncodeUriComponent() - encode a component, also escaping URI delimiters.
    t.spec("lib.string.encodeuricomponent", "CallExpression", "roString EncodeUriComponent")
    try
        s = "a/b".EncodeUriComponent()
        t.assertEqual("lib.string.encodeuricomponent", s, "a%2Fb")
    catch e
        t.assertTrue("lib.string.encodeuricomponent: runtime error", false)
    end try

    ' DecodeUriComponent() - reverse of EncodeUriComponent().
    t.spec("lib.string.decodeuricomponent", "CallExpression", "roString DecodeUriComponent")
    try
        s = "a%2Fb".DecodeUriComponent()
        t.assertEqual("lib.string.decodeuricomponent", s, "a/b")
    catch e
        t.assertTrue("lib.string.decodeuricomponent: runtime error", false)
    end try

    ' =====================================================================
    ' EMPTINESS (ifStringOps)
    ' =====================================================================

    ' IsEmpty() - true for the empty string.
    t.spec("lib.string.isempty_true", "CallExpression", "roString IsEmpty (empty string)")
    try
        b = "".IsEmpty()
        t.assertTrue("lib.string.isempty_true", b)
    catch e
        t.assertTrue("lib.string.isempty_true: runtime error", false)
    end try

    ' IsEmpty() - false for a non-empty string.
    t.spec("lib.string.isempty_false", "CallExpression", "roString IsEmpty (non-empty string)")
    try
        b = "x".IsEmpty()
        t.assertFalse("lib.string.isempty_false", b)
    catch e
        t.assertTrue("lib.string.isempty_false: runtime error", false)
    end try
end sub
