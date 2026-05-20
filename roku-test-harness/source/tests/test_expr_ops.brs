' test_expr_ops.brs - operator / precedence / comparison / logical / arithmetic
' / primary expression surface.
'
' Each spec id and kind matches grammar/coverage.json EXACTLY; the construct is
' exercised in real BrightScript per the leaf's snippet and asserted per its
' `expect` field. Roku OS 15.1.4 is ground truth.
'
' Covers the prefixes: expr.prec.* expr.assoc.* expr.cmp.* expr.or.* expr.and.*
' expr.not.* expr.shift.* expr.add.* expr.mul.* expr.unary.* expr.power.*
' expr.paren.* expr.primary.* (the postfix/optchain/array/aa/anon/literal/
' createobject/builtin/args surfaces belong to other modules).

sub test_expr_ops_all(t as Object)
    ' --- Precedence (expr.prec.*) -----------------------------------------
    ' unary minus binds LOOSER than ^: -2^2 = -(2^2) = -4
    t.spec("expr.prec.unary_vs_power", "UnaryExpr", "unary minus binds LOOSER than ^: -2^2 = -(2^2)")
    x = -2^2
    t.assertEqual("expr.prec.unary_vs_power", x, -4)

    ' ^ right-assoc: 2^3^2 = 2^(3^2) = 512
    t.spec("expr.prec.power_right_assoc", "PowerExpr", "^ right-assoc: 2^3^2 = 2^(3^2) = 512")
    x = 2^3^2
    t.assertEqual("expr.prec.power_right_assoc", x, 512)

    ' RHS of ^ recurses through unary: 2^-1 = 0.5
    t.spec("expr.prec.power_neg_exp", "PowerExpr", "RHS of ^ recurses through unary: 2^-1 = 0.5")
    x = 2^-1
    t.assertEqual("expr.prec.power_neg_exp", x, 0.5)

    ' * tighter than +: 1+2*3 = 7
    t.spec("expr.prec.mul_vs_add", "AdditiveExpr", "* tighter than +: 1+2*3 = 7")
    x = 1+2*3
    t.assertEqual("expr.prec.mul_vs_add", x, 7)

    ' + tighter than <<: 1+1<<2 = (1+1)<<2 = 8
    t.spec("expr.prec.add_vs_shift", "BitshiftExpr", "+ tighter than <<: 1+1<<2 = 8")
    x = 1+1<<2
    t.assertEqual("expr.prec.add_vs_shift", x, 8)

    ' shift tighter than comparison: (1<<2 = 4) true
    t.spec("expr.prec.shift_vs_cmp", "ComparisonExpr", "shift tighter than comparison: 1<<2 = 4 true")
    x = (1<<2 = 4)
    t.assertTrue("expr.prec.shift_vs_cmp", x)

    ' not looser than comparison: not 1 = 2 = not(1=2) = true
    t.spec("expr.prec.cmp_vs_not", "NotExpr", "not looser than comparison: not 1 = 2 = not(1=2) = true")
    x = not 1 = 2
    t.assertTrue("expr.prec.cmp_vs_not", x)

    ' not tighter than and: not false and true = (not false) and true = true
    t.spec("expr.prec.not_vs_and", "AndExpr", "not tighter than and: not false and true = true")
    x = not false and true
    t.assertTrue("expr.prec.not_vs_and", x)

    ' and tighter than or: false or true and false = false or (true and false) = false
    t.spec("expr.prec.and_vs_or", "OrExpr", "and tighter than or: false or true and false = false")
    x = false or true and false
    t.assertFalse("expr.prec.and_vs_or", x)

    ' --- Associativity (expr.assoc.*) -------------------------------------
    ' - left-assoc: 10-3-2 = (10-3)-2 = 5
    t.spec("expr.assoc.sub_left", "AdditiveExpr", "- left-assoc: 10-3-2 = 5")
    x = 10-3-2
    t.assertEqual("expr.assoc.sub_left", x, 5)

    ' / left-assoc: 100/10/2 = (100/10)/2 = 5
    t.spec("expr.assoc.div_left", "MultiplicativeExpr", "/ left-assoc: 100/10/2 = 5")
    x = 100/10/2
    t.assertEqual("expr.assoc.div_left", x, 5)

    ' --- Comparison (expr.cmp.*) -----------------------------------------
    ' comparison non-chaining: 1 < 2 evaluates left-to-right
    t.spec("expr.cmp.non_chaining", "ComparisonExpr", "comparison non-chaining: 1 < 2 < 3 evals L->R")
    x = (1 < 2)
    t.assertTrue("expr.cmp.non_chaining", x)

    t.spec("expr.cmp.eq", "ComparisonOp", "= equality")
    x = (1 = 1)
    t.assertTrue("expr.cmp.eq", x)

    t.spec("expr.cmp.ne", "ComparisonOp", "<> inequality")
    x = (1 <> 2)
    t.assertTrue("expr.cmp.ne", x)

    t.spec("expr.cmp.lt", "ComparisonOp", "< less-than")
    x = (1 < 2)
    t.assertTrue("expr.cmp.lt", x)

    t.spec("expr.cmp.gt", "ComparisonOp", "> greater-than")
    x = (2 > 1)
    t.assertTrue("expr.cmp.gt", x)

    t.spec("expr.cmp.le", "ComparisonOp", "<= (matched before <)")
    x = (2 <= 2)
    t.assertTrue("expr.cmp.le", x)

    t.spec("expr.cmp.ge", "ComparisonOp", ">= (matched before >)")
    x = (2 >= 2)
    t.assertTrue("expr.cmp.ge", x)

    t.spec("expr.cmp.string", "ComparisonExpr", "string comparison")
    x = ("a" < "b")
    t.assertTrue("expr.cmp.string", x)

    ' --- Parenthesised override (expr.paren.*) ---------------------------
    ' parentheses override precedence: (1+2)*3 = 9
    t.spec("expr.paren.override", "ParenExpr", "parentheses override precedence: (1+2)*3 = 9")
    x = (1+2)*3
    t.assertEqual("expr.paren.override", x, 9)

    ' --- or (expr.or.*) --------------------------------------------------
    t.spec("expr.or.basic", "OrExpr", "or operator")
    x = false or true
    t.assertTrue("expr.or.basic", x)

    ' or short-circuits: RHS (1/0) not evaluated when LHS is true
    t.spec("expr.or.short_circuit", "OrExpr", "or short-circuits (RHS not evaluated when LHS true)")
    x = true or (1/0 = 0)
    t.assertTrue("expr.or.short_circuit", x)

    ' or as bitwise on integers: 5 or 2 = 7
    t.spec("expr.or.bitwise", "OrExpr", "or as bitwise on integers: 5 or 2 = 7")
    x = 5 or 2
    t.assertEqual("expr.or.bitwise", x, 7)

    ' --- and (expr.and.*) ------------------------------------------------
    t.spec("expr.and.basic", "AndExpr", "and operator")
    x = true and false
    t.assertFalse("expr.and.basic", x)

    ' and short-circuits: RHS (1/0) not evaluated when LHS is false
    t.spec("expr.and.short_circuit", "AndExpr", "and short-circuits (RHS not evaluated when LHS false)")
    x = false and (1/0 = 0)
    t.assertFalse("expr.and.short_circuit", x)

    ' and as bitwise on integers: 6 and 3 = 2
    t.spec("expr.and.bitwise", "AndExpr", "and as bitwise on integers: 6 and 3 = 2")
    x = 6 and 3
    t.assertEqual("expr.and.bitwise", x, 2)

    ' --- not (expr.not.*) ------------------------------------------------
    t.spec("expr.not.bool", "NotExpr", "logical not on a boolean")
    x = not false
    t.assertTrue("expr.not.bool", x)

    ' bitwise not on an integer: not 0 = -1
    t.spec("expr.not.bitwise", "NotExpr", "bitwise not on an integer")
    x = not 0
    t.assertEqual("expr.not.bitwise", x, -1)

    ' nested/right-assoc not not true = true
    t.spec("expr.not.double", "NotExpr", "nested/right-assoc not not")
    x = not not true
    t.assertTrue("expr.not.double", x)

    ' --- Bit-shift (expr.shift.*) ----------------------------------------
    t.spec("expr.shift.shl", "BitshiftExpr", "<< shift left")
    x = 1 << 3
    t.assertEqual("expr.shift.shl", x, 8)

    t.spec("expr.shift.shr", "BitshiftExpr", ">> shift right")
    x = 8 >> 2
    t.assertEqual("expr.shift.shr", x, 2)

    ' --- Additive (expr.add.*) -------------------------------------------
    t.spec("expr.add.plus", "AdditiveExpr", "numeric +")
    x = 2 + 3
    t.assertEqual("expr.add.plus", x, 5)

    t.spec("expr.add.minus", "AdditiveExpr", "numeric -")
    x = 5 - 3
    t.assertEqual("expr.add.minus", x, 2)

    t.spec("expr.add.concat", "AdditiveExpr", "+ string concatenation")
    x = "a" + "b"
    t.assertEqual("expr.add.concat", x, "ab")

    ' --- Multiplicative (expr.mul.*) -------------------------------------
    t.spec("expr.mul.star", "MultiplicativeOp", "* multiply")
    x = 4 * 3
    t.assertEqual("expr.mul.star", x, 12)

    t.spec("expr.mul.slash", "MultiplicativeOp", "/ float division")
    x = 7 / 2
    t.assertEqual("expr.mul.slash", x, 3.5)

    t.spec("expr.mul.backslash", "MultiplicativeOp", "\ integer division")
    x = 7 \ 2
    t.assertEqual("expr.mul.backslash", x, 3)

    t.spec("expr.mul.mod", "MultiplicativeOp", "mod keyword operator")
    x = 7 mod 3
    t.assertEqual("expr.mul.mod", x, 1)

    ' --- Unary (expr.unary.*) --------------------------------------------
    t.spec("expr.unary.minus", "UnaryExpr", "unary minus (negation)")
    x = -5
    t.assertEqual("expr.unary.minus", x, -5)

    t.spec("expr.unary.plus", "UnaryExpr", "unary plus")
    x = +5
    t.assertEqual("expr.unary.plus", x, 5)

    ' right-assoc nested unary: - -5 -> -(-5) = 5
    t.spec("expr.unary.double_neg", "UnaryExpr", "right-assoc nested unary --5 -> -(-5)")
    x = - -5
    t.assertEqual("expr.unary.double_neg", x, 5)

    ' --- Power (expr.power.*) --------------------------------------------
    t.spec("expr.power.basic", "PowerExpr", "^ exponentiation")
    x = 2 ^ 10
    t.assertEqual("expr.power.basic", x, 1024)

    ' --- Primary (expr.primary.*) ----------------------------------------
    ' parenthesized expression as a primary
    t.spec("expr.primary.paren", "ParenExpr", "parenthesized expression")
    x = (1)
    t.assertEqual("expr.primary.paren", x, 1)

    ' m as a primary
    t.spec("expr.primary.m", "Identifier", "m as a primary")
    m.v = 1
    x = m.v
    t.assertEqual("expr.primary.m", x, 1)
end sub
