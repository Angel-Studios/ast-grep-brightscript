' test_lex.brs - exercises every device-testable LEXICAL leaf (lex.*).
'
' Ids/kinds match grammar/coverage.json EXACTLY (one t.spec per device-testable
' lex.* leaf). Each spec writes the construct in real BrightScript and asserts
' the value the snippet computes (expect:"value:X") or that it merely runs
' (expect:"parse"). The single non-device leaf lex.eos.no_continuation is a
' negative-corpus item and is deliberately omitted here.
'
' Helper functions in this file are prefixed lexh_ to avoid global-scope
' collisions with other test modules.

sub test_lex_all(t as Object)
    ' --- Identifiers -------------------------------------------------------
    t.spec("lex.ident.plain", "Identifier", "bare identifier, letters/digits/underscore")
    foo_1 = 1
    t.assertEqual("lex.ident.plain", foo_1, 1)

    t.spec("lex.ident.leading_underscore", "IdentStart", "identifier starting with underscore")
    _x = 2
    t.assertEqual("lex.ident.leading_underscore", _x, 2)

    t.spec("lex.ident.suffix.string", "TypeSuffix", "$ String designator suffix")
    s$ = "a"
    t.assertEqual("lex.ident.suffix.string", s$, "a")
    t.assertType("lex.ident.suffix.string type", s$, "String")

    t.spec("lex.ident.suffix.integer", "TypeSuffix", "% Integer designator suffix")
    n% = 3
    t.assertEqual("lex.ident.suffix.integer", n%, 3)
    t.assertType("lex.ident.suffix.integer type", n%, "Integer")

    t.spec("lex.ident.suffix.float", "TypeSuffix", "! Float designator suffix")
    f! = 1.5
    t.assertEqual("lex.ident.suffix.float", f!, 1.5)
    t.assertType("lex.ident.suffix.float type", f!, "Float")

    t.spec("lex.ident.suffix.double", "TypeSuffix", "# Double designator suffix")
    d# = 1.0
    t.assertEqual("lex.ident.suffix.double", d#, 1)
    t.assertType("lex.ident.suffix.double type", d#, "Double")

    t.spec("lex.ident.suffix.longint", "TypeSuffix", "& LongInteger designator suffix (OS 7.0+)")
    g& = 4
    t.assertEqual("lex.ident.suffix.longint", g&, 4)
    t.assertType("lex.ident.suffix.longint type", g&, "LongInteger")

    t.spec("lex.ident.case_insensitive", "Identifier", "same var, mixed case binds (case-insensitive)")
    Foo = 5
    x = fOO
    t.assertEqual("lex.ident.case_insensitive", x, 5)

    t.spec("lex.ident.m_keyword", "Primary", "the implicit instance AA m used as a primary")
    m.x = 6
    t.assertEqual("lex.ident.m_keyword", m.x, 6)

    ' --- Numeric literals: integer ----------------------------------------
    t.spec("lex.num.int.dec", "IntegerLiteral", "decimal integer")
    x = 42
    t.assertEqual("lex.num.int.dec", x, 42)

    t.spec("lex.num.int.hex", "HexLiteral", "&h hex integer")
    x = &hFF
    t.assertEqual("lex.num.int.hex", x, 255)

    t.spec("lex.num.int.hex_upper", "HexLiteral", "&H uppercase prefix")
    x = &H10
    t.assertEqual("lex.num.int.hex_upper", x, 16)

    ' --- Numeric literals: longinteger ------------------------------------
    t.spec("lex.num.longint.dec", "LongIntegerLiteral", "decimal with & suffix (OS 7.0+)")
    x = 5000000000&
    t.assertEqual("lex.num.longint.dec", x, 5000000000&)

    t.spec("lex.num.longint.hex", "LongIntegerLiteral", "hex with & suffix")
    x = &hFF&
    t.assertEqual("lex.num.longint.hex", x, 255)

    ' --- Numeric literals: float ------------------------------------------
    t.spec("lex.num.float.point", "FloatLiteral", "decimal point form")
    x = 3.14
    t.assertTrue("lex.num.float.point: runs", true)
    t.assertType("lex.num.float.point type", x, "Float")

    t.spec("lex.num.float.leading_dot", "FloatLiteral", "leading-dot form .5")
    x = .5
    t.assertEqual("lex.num.float.leading_dot", x, 0.5)

    t.spec("lex.num.float.exp", "FloatLiteral", "E exponent")
    x = 1e3
    t.assertEqual("lex.num.float.exp", x, 1000)

    t.spec("lex.num.float.suffix", "FloatLiteral", "! Float suffix on integer shape")
    x = 5!
    t.assertEqual("lex.num.float.suffix", x, 5)
    t.assertType("lex.num.float.suffix type", x, "Float")

    ' --- Numeric literals: double -----------------------------------------
    t.spec("lex.num.double.exp", "DoubleLiteral", "D exponent")
    x = 1d2
    t.assertEqual("lex.num.double.exp", x, 100)

    t.spec("lex.num.double.suffix", "DoubleLiteral", "# Double suffix")
    x = 5#
    t.assertEqual("lex.num.double.suffix", x, 5)
    t.assertType("lex.num.double.suffix type", x, "Double")

    t.spec("lex.num.double.tendigit", "DoubleLiteral", "10+ digit constant inferred Double")
    x = 1234567890.0
    t.assertTrue("lex.num.double.tendigit: runs", true)
    t.assertType("lex.num.double.tendigit type", x, "Double")

    t.spec("lex.num.maximal_munch", "NumericLiteral", "longest-match: &hFF& is one token not &hFF + &")
    x = &hFF&
    t.assertEqual("lex.num.maximal_munch", x, 255)
    t.assertType("lex.num.maximal_munch type", x, "LongInteger")

    ' --- String literals ---------------------------------------------------
    t.spec("lex.str.basic", "StringLiteral", "basic double-quoted string")
    s = "hello"
    t.assertEqual("lex.str.basic", s, "hello")

    t.spec("lex.str.empty", "StringLiteral", "empty string")
    s = ""
    t.assertEqual("lex.str.empty", s, "")

    t.spec("lex.str.escaped_quote", "EscapedQuote", "embedded "" is an escaped quote")
    s = "a""b"
    t.assertEqual("lex.str.escaped_quote", s, "a" + Chr(34) + "b")

    t.spec("lex.str.no_backslash_escape", "StringChar", "backslash is literal (no escape sequences)")
    s = "a\nb"
    t.assertTrue("lex.str.no_backslash_escape: runs", true)
    ' Backslash + n are two literal characters (no C-style escaping).
    t.assertEqual("lex.str.no_backslash_escape len", Len(s), 4)

    ' --- Boolean literals --------------------------------------------------
    t.spec("lex.bool.true", "BooleanLiteral", "true literal")
    b = true
    t.assertTrue("lex.bool.true", b)

    t.spec("lex.bool.false", "BooleanLiteral", "false literal")
    b = false
    t.assertFalse("lex.bool.false", b)

    t.spec("lex.bool.case_insensitive", "BooleanLiteral", "mixed-case True")
    b = True
    t.assertTrue("lex.bool.case_insensitive", b)

    ' --- Invalid literal ---------------------------------------------------
    t.spec("lex.invalid", "InvalidLiteral", "invalid literal")
    x = invalid
    t.assertInvalid("lex.invalid", x)

    ' --- LINE_NUM ----------------------------------------------------------
    t.spec("lex.line_num", "LINE_NUM_Literal", "line_num compiler substitution")
    n = line_num
    t.assertTrue("lex.line_num: runs", true)
    t.assertTrue("lex.line_num positive", n > 0)

    ' --- Comments ----------------------------------------------------------
    t.spec("lex.comment.apostrophe", "Comment", "apostrophe line comment")
    ' a comment
    t.assertTrue("lex.comment.apostrophe: runs", true)

    t.spec("lex.comment.rem", "Comment", "rem line comment")
    rem a comment
    t.assertTrue("lex.comment.rem: runs", true)

    t.spec("lex.comment.trailing", "Comment", "comment after a statement on same line")
    x = 1 ' note
    t.assertEqual("lex.comment.trailing", x, 1)

    ' --- End-of-statement separators ---------------------------------------
    t.spec("lex.eos.newline", "EOS", "newline terminates a statement")
    x = 1
    y = 2
    t.assertEqual("lex.eos.newline", y, 2)

    t.spec("lex.eos.colon", "EOS", "colon separates statements on one line")
    x = 1 : y = 2
    t.assertEqual("lex.eos.colon", y, 2)

    t.spec("lex.eos.collapse", "EOS", "runs of blank terminators collapse")
    x = 1



    y = 2
    t.assertEqual("lex.eos.collapse", y, 2)

    t.spec("lex.eos.depth0_only", "EOS", "newline NOT a terminator inside ( ) [ ] { }")
    x = [
1,
2]
    t.assertTrue("lex.eos.depth0_only: runs", true)
    t.assertEqual("lex.eos.depth0_only count", x.count(), 2)
end sub
