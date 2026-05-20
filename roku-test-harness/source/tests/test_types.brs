' test_types.brs - exercises the type system and conversion / string built-ins.
'
' Type(), GetInterface, boxing/unboxing (roInt / roString), Invalid, Dynamic,
' conversions (Str, Val, Int, Cint), and string functions (Mid, Left, Right, Len,
' Instr, UCase, LCase).

sub test_types_all(t as Object)
    ' --- Type() ------------------------------------------------------------
    t.spec("type.type_call", "Type", "Type() runtime type names across the scalar/collection types")
    t.assertType("type: integer", 5, "Integer")
    t.assertType("type: float", 5.0, "Float")
    t.assertType("type: string", "x", "String")
    t.assertType("type: boolean", true, "Boolean")
    t.assertType("type: array", [1], "roArray")
    t.assertType("type: assocarray", {}, "roAssociativeArray")

    ' --- Boxing / unboxing -------------------------------------------------
    t.spec("type.box", "BuiltinCall", "box() boxing of Integer/String to roInt/roString")
    boxedInt = box(5)
    t.assertType("type: box(Integer) -> roInt", boxedInt, "roInt")
    t.assertEqual("type: boxed value compares equal", boxedInt, 5)

    boxedStr = box("hi")
    t.assertType("type: box(String) -> roString", boxedStr, "roString")

    ' Explicit boxed object via CreateObject, then read back its value.
    t.spec("type.createobject.roint", "CreateObjectCall", "CreateObject(roInt) boxed object")
    roi = CreateObject("roInt")
    roi.SetInt(99)
    t.assertEqual("type: roInt GetInt", roi.GetInt(), 99)

    ' --- GetInterface ------------------------------------------------------
    t.spec("type.get_interface", "BuiltinCall", "GetInterface(value, ifName)")
    s = "hello"
    boxed = box(s)
    iface = GetInterface(boxed, "ifString")
    t.assertNotInvalid("type: GetInterface ifString", iface)

    ' --- Invalid and Dynamic -----------------------------------------------
    t.spec("type.dynamic", "Type", "Dynamic return type may hold differently-typed values")
    d = pickDynamic(true)
    t.assertEqual("type: dynamic returns string branch", d, "string-branch")
    d2 = pickDynamic(false)
    t.assertEqual("type: dynamic returns integer branch", d2, 42)

    ' --- Numeric conversions -----------------------------------------------
    t.spec("builtin.numeric_conversions", "BuiltinCall", "Str/Val/Int/Cint/Fix/Abs numeric conversions")
    t.assertEqual("conv: Str(int) trimmed", Str(42).Trim(), "42")
    t.assertEqual("conv: Val parses float", Val("3.5"), 3.5)
    t.assertEqual("conv: Val with base 16", Val("FF", 16), 255)
    t.assertEqual("conv: Int truncates", Int(3.9), 3)
    t.assertEqual("conv: Cint rounds", Cint(3.6), 4)
    t.assertEqual("conv: Fix toward zero", Fix(-3.7), -3)
    t.assertEqual("conv: Abs", Abs(-7.5), 7.5)

    ' --- String functions --------------------------------------------------
    t.spec("builtin.string_functions", "BuiltinCall", "Len/Left/Right/Mid/Instr/UCase/LCase string functions")
    word = "BrightScript"
    t.assertEqual("str: Len", Len(word), 12)
    t.assertEqual("str: Left", Left(word, 6), "Bright")
    t.assertEqual("str: Right", Right(word, 6), "Script")
    t.assertEqual("str: Mid (1-based start)", Mid(word, 7, 6), "Script")
    t.assertEqual("str: Instr finds substring", Instr(1, word, "Script"), 7)
    t.assertEqual("str: Instr not found", Instr(1, word, "zzz"), 0)
    t.assertEqual("str: UCase", UCase("abc"), "ABC")
    t.assertEqual("str: LCase", LCase("ABC"), "abc")

    ' Method-style string interface calls (ifString / ifStringOps).
    t.spec("expr.member_suffix.string_methods", "MemberSuffix", "method-style string interface calls (.Mid/.Replace/.Tokenize)")
    t.assertEqual("str: .Mid method", word.Mid(0, 6), "Bright")
    t.assertEqual("str: .Replace method", "a-b-c".Replace("-", "+"), "a+b+c")
    t.assertEqual("str: .Tokenize method count", "a,b,c".Tokenize(",").count(), 3)
    t.assertEqual("str: Chr/Asc round-trip", Chr(Asc("A")), "A")
end sub

' Return type Dynamic: the runtime value may be String or Integer.
function pickDynamic(wantString as Boolean) as Dynamic
    if wantString then
        return "string-branch"
    else
        return 42
    end if
end function
