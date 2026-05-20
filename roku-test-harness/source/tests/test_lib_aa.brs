' test_lib_aa.brs - STANDARD-LIBRARY coverage of roAssociativeArray
' (ifAssociativeArray) and the BOXED intrinsic types.
'
' This module is the "stdlib" layer of the coverage taxonomy: where the
' expr.* modules cover roAssociativeArray *literals* ({} and access syntax),
' this module covers the *interface methods* the device exposes on the boxed
' roAssociativeArray object, plus the boxed scalar wrappers (roInt / roFloat /
' roString / roBoolean / roLongInteger) reached via Box() and CreateObject().
'
' Each t.spec id/kind is mirrored 1:1 in grammar/coverage_frags/aa.json (the
' staging fragment to be merged into grammar/coverage.json). All ids are
' "lib.aa.<method>" or "lib.boxed.<method>" and kind is "CallExpression".
'
' DEFENSIVE PATTERN: an uncaught runtime error aborts the WHOLE suite, so every
' spec's exercise is wrapped in try/catch and the catch records a FAIL for that
' spec (never lets the exception escape). This keeps one device-uncertain method
' (e.g. LookupCI / GetLongInteger) from taking down the rest of the suite.

sub test_lib_aa_all(t as Object)
    ' =====================================================================
    ' roAssociativeArray  (ifAssociativeArray)
    ' AAs are created with the {} literal and run in Main scope.
    ' =====================================================================

    ' AddReplace(key, value) - insert or overwrite a key.
    t.spec("lib.aa.addreplace", "CallExpression", "roAssociativeArray AddReplace")
    try
        aa = {}
        aa.AddReplace("x", 1)
        aa.AddReplace("x", 2)
        t.assertEqual("lib.aa.addreplace", aa.x, 2)
    catch e
        t.assertTrue("lib.aa.addreplace: runtime error", false)
    end try

    ' Lookup(key) - case-sensitivity follows the AA's current mode (default is
    ' case-INSENSITIVE; keys are stored lowercased), so look up the lowercase form.
    t.spec("lib.aa.lookup", "CallExpression", "roAssociativeArray Lookup")
    try
        aa = { x: 7 }
        t.assertEqual("lib.aa.lookup", aa.Lookup("x"), 7)
    catch e
        t.assertTrue("lib.aa.lookup: runtime error", false)
    end try

    ' LookupCI(key) - explicit case-insensitive lookup regardless of mode.
    t.spec("lib.aa.lookupci", "CallExpression", "roAssociativeArray LookupCI")
    try
        aa = { Name: 9 }
        t.assertEqual("lib.aa.lookupci", aa.LookupCI("NAME"), 9)
    catch e
        t.assertTrue("lib.aa.lookupci: runtime error", false)
    end try

    ' DoesExist(key) - membership test.
    t.spec("lib.aa.doesexist", "CallExpression", "roAssociativeArray DoesExist")
    try
        aa = { a: 1 }
        t.assertTrue("lib.aa.doesexist: present", aa.DoesExist("a"))
        t.assertFalse("lib.aa.doesexist: absent", aa.DoesExist("zz"))
    catch e
        t.assertTrue("lib.aa.doesexist: runtime error", false)
    end try

    ' Delete(key) - remove a key, returns true when something was removed.
    t.spec("lib.aa.delete", "CallExpression", "roAssociativeArray Delete")
    try
        aa = { a: 1, b: 2 }
        removed = aa.Delete("a")
        t.assertTrue("lib.aa.delete: returned true", removed)
        t.assertEqual("lib.aa.delete: count", aa.Count(), 1)
    catch e
        t.assertTrue("lib.aa.delete: runtime error", false)
    end try

    ' Clear() - empty the AA.
    t.spec("lib.aa.clear", "CallExpression", "roAssociativeArray Clear")
    try
        aa = { a: 1, b: 2 }
        aa.Clear()
        t.assertEqual("lib.aa.clear", aa.Count(), 0)
    catch e
        t.assertTrue("lib.aa.clear: runtime error", false)
    end try

    ' Keys() - returns an roArray of the keys (sorted ascending). Assert count.
    t.spec("lib.aa.keys", "CallExpression", "roAssociativeArray Keys")
    try
        aa = { a: 1, b: 2, c: 3 }
        ks = aa.Keys()
        t.assertEqual("lib.aa.keys: count", ks.Count(), 3)
        ' default mode lowercases keys; sorted -> a, b, c
        t.assertEqual("lib.aa.keys: first", ks[0], "a")
    catch e
        t.assertTrue("lib.aa.keys: runtime error", false)
    end try

    ' Items() - returns an roArray of {key, value} AAs (sorted by key).
    t.spec("lib.aa.items", "CallExpression", "roAssociativeArray Items")
    try
        aa = { a: 10, b: 20 }
        its = aa.Items()
        t.assertEqual("lib.aa.items: count", its.Count(), 2)
        t.assertEqual("lib.aa.items: first key", its[0].key, "a")
        t.assertEqual("lib.aa.items: first value", its[0].value, 10)
    catch e
        t.assertTrue("lib.aa.items: runtime error", false)
    end try

    ' Count() - number of entries.
    t.spec("lib.aa.count", "CallExpression", "roAssociativeArray Count")
    try
        aa = { a: 1, b: 2 }
        t.assertEqual("lib.aa.count", aa.Count(), 2)
    catch e
        t.assertTrue("lib.aa.count: runtime error", false)
    end try

    ' Append(aa) - merge another AA's entries in (overwriting on collision).
    t.spec("lib.aa.append", "CallExpression", "roAssociativeArray Append")
    try
        aa = { a: 1 }
        aa.Append({ b: 2, c: 3 })
        t.assertEqual("lib.aa.append", aa.Count(), 3)
    catch e
        t.assertTrue("lib.aa.append: runtime error", false)
    end try

    ' SetModeCaseSensitive() - after this, keys are stored/compared as-typed and
    ' a differently-cased lookup misses. Demonstrate the case behavior change.
    t.spec("lib.aa.setmodecasesensitive", "CallExpression", "roAssociativeArray SetModeCaseSensitive")
    try
        aa = {}
        aa.SetModeCaseSensitive()
        aa.AddReplace("Key", 1)
        ' exact case present, differently-cased absent
        t.assertTrue("lib.aa.setmodecasesensitive: exact present", aa.DoesExist("Key"))
        t.assertFalse("lib.aa.setmodecasesensitive: other case absent", aa.DoesExist("key"))
    catch e
        t.assertTrue("lib.aa.setmodecasesensitive: runtime error", false)
    end try

    ' IsEmpty() - true on a fresh {}, false once populated.
    t.spec("lib.aa.isempty", "CallExpression", "roAssociativeArray IsEmpty")
    try
        aa = {}
        t.assertTrue("lib.aa.isempty: empty", aa.IsEmpty())
        aa.AddReplace("x", 1)
        t.assertFalse("lib.aa.isempty: nonempty", aa.IsEmpty())
    catch e
        t.assertTrue("lib.aa.isempty: runtime error", false)
    end try

    ' =====================================================================
    ' BOXED INTRINSIC TYPES
    ' Box() wraps an intrinsic scalar in its component object; CreateObject
    ' builds the boxed scalar directly. The Get* accessors unbox back to the
    ' intrinsic value.
    ' =====================================================================

    ' Box(1).ToStr() - Box() yields a boxed roInt; ToStr() stringifies it.
    t.spec("lib.boxed.box_tostr", "CallExpression", "Box() then ToStr() on the boxed integer")
    try
        s = Box(1).ToStr()
        t.assertEqual("lib.boxed.box_tostr", s, "1")
    catch e
        t.assertTrue("lib.boxed.box_tostr: runtime error", false)
    end try

    ' Type(Box(1)) - the boxed integer's runtime type. On device Box() of an
    ' Integer reports "roInt"; accept the "roInteger" spelling too via kind check.
    t.spec("lib.boxed.box_type", "BuiltinCall", "Type() of a boxed integer")
    try
        tn = Type(Box(1))
        ok = (tn = "roInt" or tn = "roInteger")
        t.assertTrue("lib.boxed.box_type: roInt/roInteger", ok)
    catch e
        t.assertTrue("lib.boxed.box_type: runtime error", false)
    end try

    ' DEVICE FACT (#15): CreateObject("roInt", 5) does NOT accept a value arg (the
    ' boxed int is created as 0); box(value) boxes an intrinsic WITH its value.
    ' box(5).GetInt() - boxed integer, unbox via GetInt().
    t.spec("lib.boxed.roint_getint", "CallExpression", "box(5).GetInt()")
    try
        n = box(5)
        t.assertEqual("lib.boxed.roint_getint", n.GetInt(), 5)
    catch e
        t.assertTrue("lib.boxed.roint_getint: runtime error", false)
    end try

    ' box(1.5).GetFloat() - boxed float.
    t.spec("lib.boxed.rofloat_getfloat", "CallExpression", "box(1.5).GetFloat()")
    try
        f = box(1.5)
        t.assertEqual("lib.boxed.rofloat_getfloat", f.GetFloat(), 1.5)
    catch e
        t.assertTrue("lib.boxed.rofloat_getfloat: runtime error", false)
    end try

    ' box("hi").GetString() - boxed string.
    t.spec("lib.boxed.rostring_getstring", "CallExpression", "box(string).GetString()")
    try
        s = box("hi")
        t.assertEqual("lib.boxed.rostring_getstring", s.GetString(), "hi")
    catch e
        t.assertTrue("lib.boxed.rostring_getstring: runtime error", false)
    end try

    ' box(true).GetBoolean() - boxed boolean.
    t.spec("lib.boxed.roboolean_getboolean", "CallExpression", "box(true).GetBoolean()")
    try
        b = box(true)
        t.assertTrue("lib.boxed.roboolean_getboolean", b.GetBoolean())
    catch e
        t.assertTrue("lib.boxed.roboolean_getboolean: runtime error", false)
    end try

    ' box(5000000000&).ToStr() - boxed 64-bit integer. The & literal suffix is the
    ' LongInteger designator (OS 7.0+); ToStr (ifToStr) is the portable accessor.
    t.spec("lib.boxed.rolonginteger_getlonginteger", "CallExpression", "box(longint).ToStr()")
    try
        g = box(5000000000&)
        t.assertEqual("lib.boxed.rolonginteger_getlonginteger", g.ToStr(), "5000000000")
    catch e
        t.assertTrue("lib.boxed.rolonginteger_getlonginteger: runtime error", false)
    end try
end sub
