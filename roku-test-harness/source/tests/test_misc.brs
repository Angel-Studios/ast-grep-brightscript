' test_misc.brs - exercises a few remaining reserved built-ins and forms.
'
' GetGlobalAA, the optional 'let' keyword on assignment, optional-chaining
' operators (?. ?@ ?[ ?( - Roku OS 11.0+), and a rem-style comment. roXMLElement
' is created so the '.@' attribute-access operator is exercised on real markup.

sub test_misc_all(t as Object)
    ' --- rem-style comment + plain assignment ------------------------------
    t.spec("lex.comment.rem", "Comment", "rem-style comment")
    rem this is a rem-style comment, exercised for the corpus
    ' 'let' is NOT supported on-device (Syntax Error &h02); plain assignment only.
    t.spec("stmt.assignment", "AssignmentStatement", "plain assignment (no leading 'let')")
    x = 5
    t.assertEqual("misc: plain assignment", x, 5)

    ' --- GetGlobalAA (returns the global associative array) ----------------
    t.spec("builtin.getglobalaa", "ReservedBuiltinName", "GetGlobalAA() returns the global AA")
    g = GetGlobalAA()
    t.assertNotInvalid("misc: GetGlobalAA non-invalid", g)

    ' --- Optional chaining (Roku OS 11.0+) ---------------------------------
    obj = { inner: { value: 99 }, list: [10, 20, 30] }

    ' ?. short-circuits to invalid when the left side is invalid.
    t.spec("expr.optchain.dot", "OptChainSuffix", "?. optional member access (short-circuits on invalid)")
    presentVal = obj?.inner?.value
    t.assertEqual("misc: ?. present chain", presentVal, 99)

    missing = invalid
    safeVal = missing?.inner?.value
    t.assertInvalid("misc: ?. on invalid -> invalid", safeVal)

    ' ?[ optional index.
    t.spec("expr.optchain.index", "OptChainSuffix", "?[ optional index access (short-circuits on invalid)")
    idxVal = obj?.list?[1]
    t.assertEqual("misc: ?[ optional index", idxVal, 20)
    missArr = invalid
    t.assertInvalid("misc: ?[ on invalid -> invalid", missArr?[0])

    ' ?( optional call: only invokes when the callee is non-invalid.
    t.spec("expr.optchain.call", "OptChainSuffix", "?( optional call (short-circuits on invalid)")
    fnAA = { run: function() as Integer
        return 7
    end function }
    t.assertEqual("misc: ?( optional call present", fnAA.run?(), 7)
    noFn = invalid
    t.assertInvalid("misc: ?( optional call on invalid", noFn?())

    ' --- roXMLElement '.@' and '?@' attribute access -----------------------
    t.spec("expr.attribute_suffix", "AttributeSuffix", "@attr XML attribute access on roXMLElement")
    xml = CreateObject("roXMLElement")
    parsed = xml.parse("<node attr=" + Chr(34) + "hello" + Chr(34) + "><child/></node>")
    t.assertTrue("misc: roXMLElement parse ok", parsed)
    ' '@name' reads an XML attribute (AttributeSuffix in the grammar).
    attrVal = xml@attr
    t.assertEqual("misc: .@ attribute access", attrVal, "hello")
    ' '?@' optional attribute access on invalid short-circuits.
    t.spec("expr.optchain.attribute", "OptChainSuffix", "?@ optional XML attribute access (short-circuits on invalid)")
    nada = invalid
    t.assertInvalid("misc: ?@ on invalid -> invalid", nada?@attr)
end sub
