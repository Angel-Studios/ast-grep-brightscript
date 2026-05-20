' test_operators.brs - exercises every BrightScript operator.
'
' Arithmetic (+ - * / \ ^ mod), comparison (= <> < > <= >=), logical
' (and or not), bitshift (<< >>), string concatenation, compound assignment
' (+= -= *= /= \= <<= >>=), and increment / decrement (++ / --).

sub test_operators_all(t as Object)
    ' --- Arithmetic --------------------------------------------------------
    t.spec("expr.additive", "AdditiveExpr", "+ and - binary arithmetic")
    t.assertEqual("op: addition", 2 + 3, 5)
    t.assertEqual("op: subtraction", 10 - 4, 6)

    t.spec("expr.multiplicative", "MultiplicativeExpr", "* / \\ mod operators")
    t.assertEqual("op: multiplication", 6 * 7, 42)
    t.assertEqual("op: float division", 7 / 2, 3.5)
    t.assertEqual("op: integer division", 7 \ 2, 3)
    t.assertEqual("op: mod", 17 mod 5, 2)

    t.spec("expr.power", "PowerExpr", "^ exponentiation (right-assoc, looser than unary minus)")
    t.assertEqual("op: exponentiation", 2 ^ 10, 1024)
    ' Exponentiation is right-associative and binds tighter than unary minus.
    t.assertEqual("op: -2^2 == -4 (unary looser than ^)", -2 ^ 2, -4)
    t.assertEqual("op: 2^3^2 right-assoc == 512", 2 ^ 3 ^ 2, 512)

    ' Unary +/-.
    t.spec("expr.unary", "UnaryExpr", "unary + and - prefix operators")
    x = 5
    t.assertEqual("op: unary minus", -x, -5)
    t.assertEqual("op: unary plus", +x, 5)

    ' --- Comparison --------------------------------------------------------
    t.spec("expr.comparison", "ComparisonExpr", "= <> < > <= >= comparison operators")
    t.assertTrue("op: equal", 3 = 3)
    t.assertTrue("op: not-equal", 3 <> 4)
    t.assertTrue("op: less-than", 2 < 3)
    t.assertTrue("op: greater-than", 5 > 1)
    t.assertTrue("op: less-equal", 3 <= 3)
    t.assertTrue("op: greater-equal", 4 >= 4)

    ' --- Logical -----------------------------------------------------------
    t.spec("expr.logical.or", "OrExpr", "or (boolean + bitwise)")
    t.assertTrue("op: or", false or true)
    t.assertEqual("op: bitwise or", 12 or 10, 14)

    t.spec("expr.logical.and", "AndExpr", "and (boolean + bitwise)")
    t.assertTrue("op: and", true and true)
    t.assertFalse("op: and false", true and false)
    t.assertEqual("op: bitwise and", 12 and 10, 8)

    t.spec("expr.logical.not", "NotExpr", "not (boolean negation)")
    t.assertTrue("op: not", not false)

    ' --- Bitshift ----------------------------------------------------------
    t.spec("expr.bitshift", "BitshiftExpr", "<< and >> bit-shift operators")
    t.assertEqual("op: shift left", 1 << 4, 16)
    t.assertEqual("op: shift right", 256 >> 2, 64)

    ' --- String concatenation ----------------------------------------------
    t.spec("expr.concat", "AdditiveExpr", "+ as string concatenation")
    t.assertEqual("op: string concat", "foo" + "bar", "foobar")

    ' --- Compound assignment (Roku OS 7.1+) --------------------------------
    t.spec("stmt.compound_assign", "CompoundAssignStatement", "+= -= *= /= \\= <<= >>= compound assignment")
    n = 10
    n += 5
    t.assertEqual("op: +=", n, 15)
    n -= 3
    t.assertEqual("op: -=", n, 12)
    n *= 2
    t.assertEqual("op: *=", n, 24)
    n /= 4
    t.assertEqual("op: /=", n, 6)
    m = 17
    m \= 5
    t.assertEqual("op: \\=", m, 3)
    bits = 1
    bits <<= 5
    t.assertEqual("op: <<=", bits, 32)
    bits >>= 2
    t.assertEqual("op: >>=", bits, 8)

    s = "a"
    s += "b"
    t.assertEqual("op: += string concat", s, "ab")

    ' --- Increment / decrement (Roku OS 7.1+) ------------------------------
    t.spec("stmt.incdec", "IncDecStatement", "++ and -- increment / decrement statements")
    c = 0
    c++
    c++
    t.assertEqual("op: ++ increment", c, 2)
    c--
    t.assertEqual("op: -- decrement", c, 1)

    ' --- Mixed precedence sanity ------------------------------------------
    t.spec("expr.precedence", "Expression", "operator precedence and parenthesised override")
    t.assertEqual("op: precedence 2+3*4", 2 + 3 * 4, 14)
    t.assertEqual("op: parens override (2+3)*4", (2 + 3) * 4, 20)
end sub
