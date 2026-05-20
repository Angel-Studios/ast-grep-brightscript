' test_lib_global.brs - STANDARD-LIBRARY coverage of BrightScript GLOBAL
' (intrinsic) functions: the built-in String / Math / Utility / JSON functions
' callable from any scope without an object (the "ifGlobal" / global functions).
'
' These are the stdlib LEAVES (layer:"stdlib") of the future tree-sitter grammar
' corpus: each is exercised as a CallExpression and asserted against its
' device-observed result. Unlike the language-construct modules, the leaves here
' live in grammar/coverage_frags/global.json (a fragment the orchestrator merges
' into coverage.json after device validation).
'
' Each t.spec id/kind matches global.json VERBATIM. Every spec's exercise is
' wrapped in try/catch: the harness runs the whole suite in one pass, so an
' uncaught runtime error (a wrong API name/signature) would abort everything.
' Wrapping turns a bad call into a single FAIL, not a crash, and lets the
' orchestrator see exactly which leaf diverged.
'
' Determinism: deterministic results use assertEqual / assertTrue / assertInvalid
' (expect:"value:X"). Nondeterministic results (Rnd random, UpTime device clock)
' assert only a range / NotInvalid / type (expect:"parse").

sub test_lib_global_all(t as Object)
    ' =====================================================================
    ' STRING FUNCTIONS
    ' =====================================================================

    t.spec("lib.global.len", "CallExpression", "Len(s) string length")
    try
        r = Len("hello")
        t.assertEqual("lib.global.len", r, 5)
    catch e
        t.assertTrue("lib.global.len: runtime error", false)
    end try

    t.spec("lib.global.mid2", "CallExpression", "Mid(s,start) substring to end (1-based)")
    try
        r = Mid("hello", 2)
        t.assertEqual("lib.global.mid2", r, "ello")
    catch e
        t.assertTrue("lib.global.mid2: runtime error", false)
    end try

    t.spec("lib.global.mid3", "CallExpression", "Mid(s,start,len) substring (1-based)")
    try
        r = Mid("hello", 2, 3)
        t.assertEqual("lib.global.mid3", r, "ell")
    catch e
        t.assertTrue("lib.global.mid3: runtime error", false)
    end try

    t.spec("lib.global.left", "CallExpression", "Left(s,n) leftmost n chars")
    try
        r = Left("hello", 2)
        t.assertEqual("lib.global.left", r, "he")
    catch e
        t.assertTrue("lib.global.left: runtime error", false)
    end try

    t.spec("lib.global.right", "CallExpression", "Right(s,n) rightmost n chars")
    try
        r = Right("hello", 2)
        t.assertEqual("lib.global.right", r, "lo")
    catch e
        t.assertTrue("lib.global.right: runtime error", false)
    end try

    t.spec("lib.global.instr", "CallExpression", "Instr(s,sub) 1-based index of substring")
    try
        r = Instr("hello", "ll")
        t.assertEqual("lib.global.instr", r, 3)
    catch e
        t.assertTrue("lib.global.instr: runtime error", false)
    end try

    t.spec("lib.global.instr_start", "CallExpression", "Instr(start,s,sub) search from index")
    try
        r = Instr(4, "hellollo", "llo")
        t.assertEqual("lib.global.instr_start", r, 6)
    catch e
        t.assertTrue("lib.global.instr_start: runtime error", false)
    end try

    t.spec("lib.global.chr", "CallExpression", "Chr(code) char from ASCII code")
    try
        r = Chr(65)
        t.assertEqual("lib.global.chr", r, "A")
    catch e
        t.assertTrue("lib.global.chr: runtime error", false)
    end try

    t.spec("lib.global.asc", "CallExpression", "Asc(s) ASCII code of first char")
    try
        r = Asc("A")
        t.assertEqual("lib.global.asc", r, 65)
    catch e
        t.assertTrue("lib.global.asc: runtime error", false)
    end try

    t.spec("lib.global.ucase", "CallExpression", "UCase(s) uppercase")
    try
        r = UCase("abc")
        t.assertEqual("lib.global.ucase", r, "ABC")
    catch e
        t.assertTrue("lib.global.ucase: runtime error", false)
    end try

    t.spec("lib.global.lcase", "CallExpression", "LCase(s) lowercase")
    try
        r = LCase("ABC")
        t.assertEqual("lib.global.lcase", r, "abc")
    catch e
        t.assertTrue("lib.global.lcase: runtime error", false)
    end try

    ' Str() prepends a leading space for non-negative numbers (sign placeholder).
    t.spec("lib.global.str", "CallExpression", "Str(n) number to string (leading space for sign)")
    try
        r = Str(42)
        t.assertEqual("lib.global.str", r.Trim(), "42")
    catch e
        t.assertTrue("lib.global.str: runtime error", false)
    end try

    ' StrI() is the integer-to-string variant; also has a sign placeholder.
    t.spec("lib.global.stri", "CallExpression", "StrI(n) integer to string")
    try
        r = StrI(42)
        t.assertEqual("lib.global.stri", r.Trim(), "42")
    catch e
        t.assertTrue("lib.global.stri: runtime error", false)
    end try

    t.spec("lib.global.val", "CallExpression", "Val(s) parse string to float")
    try
        r = Val("3.5")
        t.assertEqual("lib.global.val", r, 3.5)
    catch e
        t.assertTrue("lib.global.val: runtime error", false)
    end try

    ' Val(s, radix) parses an integer in the given base (radix 16 = hex).
    t.spec("lib.global.val_radix", "CallExpression", "Val(s,radix) parse integer in base")
    try
        r = Val("FF", 16)
        t.assertEqual("lib.global.val_radix", r, 255)
    catch e
        t.assertTrue("lib.global.val_radix: runtime error", false)
    end try

    ' =====================================================================
    ' MATH FUNCTIONS
    ' =====================================================================

    t.spec("lib.global.abs", "CallExpression", "Abs(n) absolute value")
    try
        r = Abs(-5.0)
        t.assertEqual("lib.global.abs", r, 5.0)
    catch e
        t.assertTrue("lib.global.abs: runtime error", false)
    end try

    ' Atn(1) = pi/4 ~ 0.785398; check a tight tolerance band.
    t.spec("lib.global.atn", "CallExpression", "Atn(n) arctangent (radians)")
    try
        r = Atn(1.0)
        t.assertTrue("lib.global.atn", r > 0.78 and r < 0.79)
    catch e
        t.assertTrue("lib.global.atn: runtime error", false)
    end try

    t.spec("lib.global.cos", "CallExpression", "Cos(n) cosine (radians)")
    try
        r = Cos(0.0)
        t.assertEqual("lib.global.cos", r, 1.0)
    catch e
        t.assertTrue("lib.global.cos: runtime error", false)
    end try

    t.spec("lib.global.sin", "CallExpression", "Sin(n) sine (radians)")
    try
        r = Sin(0.0)
        t.assertEqual("lib.global.sin", r, 0.0)
    catch e
        t.assertTrue("lib.global.sin: runtime error", false)
    end try

    t.spec("lib.global.tan", "CallExpression", "Tan(n) tangent (radians)")
    try
        r = Tan(0.0)
        t.assertEqual("lib.global.tan", r, 0.0)
    catch e
        t.assertTrue("lib.global.tan: runtime error", false)
    end try

    ' Exp(0) = 1.
    t.spec("lib.global.exp", "CallExpression", "Exp(n) e^n")
    try
        r = Exp(0.0)
        t.assertEqual("lib.global.exp", r, 1.0)
    catch e
        t.assertTrue("lib.global.exp: runtime error", false)
    end try

    ' Log(1) = 0 (natural log).
    t.spec("lib.global.log", "CallExpression", "Log(n) natural logarithm")
    try
        r = Log(1.0)
        t.assertEqual("lib.global.log", r, 0.0)
    catch e
        t.assertTrue("lib.global.log: runtime error", false)
    end try

    t.spec("lib.global.sqr", "CallExpression", "Sqr(n) square root")
    try
        r = Sqr(9.0)
        t.assertEqual("lib.global.sqr", r, 3.0)
    catch e
        t.assertTrue("lib.global.sqr: runtime error", false)
    end try

    ' Int() truncates toward negative infinity (floor) per Roku docs.
    t.spec("lib.global.int", "CallExpression", "Int(n) integer floor")
    try
        r = Int(3.7)
        t.assertEqual("lib.global.int", r, 3)
    catch e
        t.assertTrue("lib.global.int: runtime error", false)
    end try

    ' Cint() rounds to the nearest integer.
    t.spec("lib.global.cint", "CallExpression", "Cint(n) round to nearest integer")
    try
        r = Cint(3.6)
        t.assertEqual("lib.global.cint", r, 4)
    catch e
        t.assertTrue("lib.global.cint: runtime error", false)
    end try

    ' Csng() converts to single-precision float.
    t.spec("lib.global.csng", "CallExpression", "Csng(n) convert to single float")
    try
        r = Csng(3)
        t.assertEqual("lib.global.csng", r, 3.0)
    catch e
        t.assertTrue("lib.global.csng: runtime error", false)
    end try

    ' Cdbl() converts to double-precision float.
    t.spec("lib.global.cdbl", "CallExpression", "Cdbl(n) convert to double")
    try
        r = Cdbl(3)
        t.assertEqual("lib.global.cdbl", r, 3.0)
    catch e
        t.assertTrue("lib.global.cdbl: runtime error", false)
    end try

    ' Fix() truncates toward zero (differs from Int for negatives).
    t.spec("lib.global.fix", "CallExpression", "Fix(n) truncate toward zero")
    try
        r = Fix(-3.7)
        t.assertEqual("lib.global.fix", r, -3)
    catch e
        t.assertTrue("lib.global.fix: runtime error", false)
    end try

    ' Sgn() returns the sign: -1, 0, or 1.
    t.spec("lib.global.sgn", "CallExpression", "Sgn(n) sign of number")
    try
        r = Sgn(-7)
        t.assertEqual("lib.global.sgn", r, -1)
    catch e
        t.assertTrue("lib.global.sgn: runtime error", false)
    end try

    ' Rnd(0) returns a random Float in [0,1); nondeterministic so range-assert.
    t.spec("lib.global.rnd_float", "CallExpression", "Rnd(0) random float in [0,1)")
    try
        r = Rnd(0)
        t.assertTrue("lib.global.rnd_float", r >= 0.0 and r < 1.0)
    catch e
        t.assertTrue("lib.global.rnd_float: runtime error", false)
    end try

    ' Rnd(n) for n>=1 returns a random Integer in [1,n]; range-assert.
    t.spec("lib.global.rnd_int", "CallExpression", "Rnd(n) random integer in [1,n]")
    try
        r = Rnd(6)
        t.assertTrue("lib.global.rnd_int", r >= 1 and r <= 6)
    catch e
        t.assertTrue("lib.global.rnd_int: runtime error", false)
    end try

    ' =====================================================================
    ' UTILITY FUNCTIONS
    ' =====================================================================

    t.spec("lib.global.type", "BuiltinCall", "Type(v) runtime type name")
    try
        r = Type(1)
        t.assertEqual("lib.global.type", r, "Integer")
    catch e
        t.assertTrue("lib.global.type: runtime error", false)
    end try

    ' GetGlobalAA() returns the global associative array (m at global scope).
    t.spec("lib.global.getglobalaa", "BuiltinCall", "GetGlobalAA() global AA")
    try
        r = GetGlobalAA()
        t.assertTrue("lib.global.getglobalaa", Type(r) = "roAssociativeArray")
    catch e
        t.assertTrue("lib.global.getglobalaa: runtime error", false)
    end try

    ' Box() wraps an intrinsic scalar in its boxed (ro*) object form.
    t.spec("lib.global.box", "BuiltinCall", "Box(v) wrap intrinsic in boxed object")
    try
        r = Box(1)
        t.assertNotInvalid("lib.global.box", r)
    catch e
        t.assertTrue("lib.global.box: runtime error", false)
    end try

    ' GetInterface(obj, ifname) returns the named interface or invalid.
    t.spec("lib.global.getinterface", "CallExpression", "GetInterface(obj,ifname) reflect interface")
    try
        r = GetInterface("s", "ifString")
        t.assertNotInvalid("lib.global.getinterface", r)
    catch e
        t.assertTrue("lib.global.getinterface: runtime error", false)
    end try

    ' RunGarbageCollector() forces a GC pass and returns a stats AA.
    t.spec("lib.global.rungarbagecollector", "CallExpression", "RunGarbageCollector() force GC, returns stats AA")
    try
        r = RunGarbageCollector()
        t.assertTrue("lib.global.rungarbagecollector", Type(r) = "roAssociativeArray")
    catch e
        t.assertTrue("lib.global.rungarbagecollector: runtime error", false)
    end try

    ' UpTime(0) returns seconds since boot as a Float; nondeterministic, type-assert.
    t.spec("lib.global.uptime", "CallExpression", "UpTime(0) seconds since boot (float)")
    try
        r = UpTime(0)
        t.assertTrue("lib.global.uptime", r >= 0.0)
    catch e
        t.assertTrue("lib.global.uptime: runtime error", false)
    end try

    ' =====================================================================
    ' JSON FUNCTIONS
    ' =====================================================================

    ' FormatJSON(aa) serializes an AA/array to a JSON string.
    t.spec("lib.global.formatjson", "CallExpression", "FormatJSON(v) serialize to JSON string")
    try
        r = FormatJSON({ a: 1 })
        t.assertEqual("lib.global.formatjson", r, "{""a"":1}")
    catch e
        t.assertTrue("lib.global.formatjson: runtime error", false)
    end try

    ' ParseJSON(s) deserializes a JSON string to an AA/array.
    t.spec("lib.global.parsejson", "CallExpression", "ParseJSON(s) deserialize JSON string")
    try
        r = ParseJSON("{""a"":1}")
        t.assertTrue("lib.global.parsejson: is AA", Type(r) = "roAssociativeArray")
        t.assertEqual("lib.global.parsejson: a", r.a, 1)
    catch e
        t.assertTrue("lib.global.parsejson: runtime error", false)
    end try
end sub
