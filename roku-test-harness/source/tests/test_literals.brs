' test_literals.brs - exercises every BrightScript literal form.
'
' Integer (decimal, hex &h, % suffix, & long suffix), LongInteger, Float (! and
' decimal/exponent forms), Double (# and D exponent), String (with "" escape),
' Boolean, and Invalid. Each construct group opens a ##SPEC## via t.spec(id,kind).

sub test_literals_all(t as Object)
    ' --- Integer literals --------------------------------------------------
    t.spec("literal.integer.decimal", "IntegerLiteral", "decimal integer literal")
    decInt = 42
    t.assertEqual("literal: decimal integer", decInt, 42)
    t.assertType("literal: decimal integer type", decInt, "Integer")

    ' Hex integer literal (&h / &H both legal).
    t.spec("literal.integer.hex", "HexLiteral", "hex integer literal &h / &H")
    hexLower = &hFF
    hexUpper = &HFF
    t.assertEqual("literal: hex &hFF == 255", hexLower, 255)
    t.assertEqual("literal: hex &HFF == 255", hexUpper, 255)
    t.assertEqual("literal: hex 0x10 == 16", &h10, 16)

    ' Integer type-designator suffix (% on a variable name declares Integer).
    t.spec("literal.integer.suffix", "TypeSuffix", "integer % type-designator suffix")
    count% = 7
    t.assertEqual("literal: %% suffix integer", count%, 7)
    t.assertType("literal: %% suffix type", count%, "Integer")

    ' --- LongInteger literals (& suffix, Roku OS 7.0+) ---------------------
    t.spec("literal.longinteger", "LongIntegerLiteral", "longinteger & suffix literal")
    bigLong& = 5000000000&
    t.assertType("literal: longinteger & suffix type", bigLong&, "LongInteger")
    t.assertEqual("literal: longinteger value", bigLong&, 5000000000&)
    hexLong = &hFFFFFFFF&
    t.assertType("literal: hex longinteger type", hexLong, "LongInteger")

    ' --- Float literals ----------------------------------------------------
    t.spec("literal.float", "FloatLiteral", "float literal: decimal, !, exponent, leading-dot")
    f1 = 3.14
    t.assertType("literal: float decimal type", f1, "Float")
    pi! = 3.14159!
    t.assertType("literal: float ! suffix type", pi!, "Float")
    fExp = 1.5e3
    t.assertEqual("literal: float exponent 1.5e3", fExp, 1500.0)
    fBang = 5!
    t.assertType("literal: integer-with-! is float", fBang, "Float")
    fLeadingDot = .25
    t.assertEqual("literal: leading-dot float .25", fLeadingDot, 0.25)

    ' --- Double literals ---------------------------------------------------
    t.spec("literal.double", "DoubleLiteral", "double literal: # suffix and D-exponent")
    d1# = 3.141592653589793#
    t.assertType("literal: double # suffix type", d1#, "Double")
    dExp = 1.0d2
    t.assertType("literal: double D-exponent type", dExp, "Double")
    t.assertEqual("literal: double D-exponent 1.0d2", dExp, 100.0#)

    ' --- String literals (with "" embedded-quote escape) -------------------
    t.spec("literal.string", "StringLiteral", "string literal incl. embedded-quote escape and $ suffix")
    s = "hello"
    t.assertEqual("literal: string", s, "hello")
    t.assertType("literal: string type", s, "String")
    quoted = "she said ""hi"" loudly"
    t.assertEqual("literal: embedded-quote escape", quoted, "she said " + Chr(34) + "hi" + Chr(34) + " loudly")
    empty$ = ""
    t.assertEqual("literal: empty string", empty$, "")
    t.assertType("literal: $ suffix string type", empty$, "String")

    ' --- Boolean literals --------------------------------------------------
    t.spec("literal.boolean", "BooleanLiteral", "true / false boolean literals")
    bt = true
    bf = false
    t.assertTrue("literal: true", bt)
    t.assertFalse("literal: false", bf)
    t.assertType("literal: boolean type", bt, "Boolean")

    ' --- Invalid literal ---------------------------------------------------
    t.spec("literal.invalid", "InvalidLiteral", "invalid literal")
    nothing = invalid
    t.assertInvalid("literal: invalid", nothing)

    ' --- LINE_NUM (compiler-substituted current line number) ---------------
    ' LINE_NUM is a numeric literal substituted at compile time; just confirm it
    ' is a positive integer so the construct is exercised.
    t.spec("literal.line_num", "NumericLiteral", "LINE_NUM compile-time numeric literal")
    ln = LINE_NUM
    t.assertTrue("literal: LINE_NUM is positive", ln > 0)
end sub
