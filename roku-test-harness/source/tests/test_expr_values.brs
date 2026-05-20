' test_expr_values.brs - exercises the "value-bearing" expression leaves of the
' BrightScript grammar: postfix suffix chains (member / index / call), optional
' chaining (?. ?[ ?(), array and associative-array literals, anonymous function
' and sub expression values, literal primaries, CreateObject, the reserved
' builtin calls (type/box/getglobalaa), and argument lists.
'
' Each t.spec id/kind is taken VERBATIM from grammar/coverage.json (the single
' source of truth); the construct is exercised exactly as the leaf snippet
' prescribes and asserted against the leaf's expect.
'
' Coverage: every device_testable:true leaf under the expr.postfix. /
' expr.optchain. / expr.array. / expr.aa. / expr.anon. / expr.literal. /
' expr.createobject. / expr.builtin. / expr.args. prefixes, MINUS the four
' device_testable:false leaves (postfix.attribute, optchain.at,
' createobject.node, builtin.eval) which belong to the negative corpus.

sub test_expr_values_all(t as Object)
    ' =====================================================================
    ' POSTFIX SUFFIX CHAINS
    ' =====================================================================

    ' .member access (snippet: m.x = 1 : y = m.x -> value:1). Use a local AA so
    ' the test is self-contained and not entangled with the runner's m.
    t.spec("expr.postfix.member", "MemberSuffix", ".member access")
    pm = {}
    pm.x = 1
    y = pm.x
    t.assertEqual("expr.postfix.member", y, 1)

    ' chained .a.b (snippet: m.a = {b:2} : y = m.a.b -> value:2)
    t.spec("expr.postfix.member_chain", "MemberSuffix", "chained .a.b")
    pmc = {}
    pmc.a = { b: 2 }
    y = pmc.a.b
    t.assertEqual("expr.postfix.member_chain", y, 2)

    ' [i] index read (snippet: a=[7] : y = a[0] -> value:7)
    t.spec("expr.postfix.index", "IndexSuffix", "[i] index read")
    a = [7]
    y = a[0]
    t.assertEqual("expr.postfix.index", y, 7)

    ' multi-subscript a[i,j] after dim (snippet: dim a[2,2] : a[1,1]=8 : y=a[1,1] -> value:8)
    t.spec("expr.postfix.index_multisub", "IndexSuffix", "multi-subscript a[i,j] (after dim)")
    dim ams[2, 2]
    ams[1, 1] = 8
    y = ams[1, 1]
    t.assertEqual("expr.postfix.index_multisub", y, 8)

    ' (args) call suffix (snippet calls f(n) with one arg -> value:0; the helper
    ' echoes its argument, so pass 0). Uses module-level helper evh_echo.
    t.spec("expr.postfix.call", "CallSuffix", "(args) call suffix")
    y = evh_echo(0)
    t.assertEqual("expr.postfix.call", y, 0)

    ' () empty arg call (snippet: function f()\nreturn 1 -> value:1)
    t.spec("expr.postfix.call_noargs", "CallSuffix", "() empty arg call")
    y = evh_one()
    t.assertEqual("expr.postfix.call_noargs", y, 1)

    ' mixed suffix chain a[0].f() (snippet builds an array holding an AA whose f
    ' returns 3 -> value:3)
    t.spec("expr.postfix.mixed_chain", "CallExpression", "mixed suffix chain a[0].f()")
    mc = [{ f: function()
        return 3
    end function }]
    y = mc[0].f()
    t.assertEqual("expr.postfix.mixed_chain", y, 3)

    ' =====================================================================
    ' OPTIONAL CHAINING  (NO space before '?' or it means print)
    ' =====================================================================

    ' ?.member optional member (snippet: m.a = invalid : y = m.a?.b -> value:invalid)
    t.spec("expr.optchain.dot", "OC_DOT", "?.member optional member")
    ocd = {}
    ocd.a = invalid
    y = ocd.a?.b
    t.assertInvalid("expr.optchain.dot", y)

    ' ?[i] optional index (snippet: a = invalid : y = a?[0] -> value:invalid)
    t.spec("expr.optchain.bracket", "OC_BRACKET", "?[i] optional index")
    ocb = invalid
    y = ocb?[0]
    t.assertInvalid("expr.optchain.bracket", y)

    ' ?(args) optional call (snippet: f = invalid : y = f?() -> value:invalid)
    t.spec("expr.optchain.paren", "OC_PAREN", "?(args) optional call")
    ocp = invalid
    y = ocp?()
    t.assertInvalid("expr.optchain.paren", y)

    ' ?[ / ?( chaining requires no space (else ? = print). The optional-index
    ' suffix needs an integer subscript on an array (an AA would require a string
    ' key -> &h18). The point of the leaf is the no-space ?[ token.
    t.spec("expr.optchain.space_vs_print", "OC_BRACKET", "?[/?( chaining requires no space (else ? = print)")
    oci = [10, 11]
    y = oci?[0]
    t.assertEqual("expr.optchain.space_vs_print: runs", y, 10)

    ' =====================================================================
    ' ARRAY LITERALS
    ' =====================================================================

    ' empty [] literal (snippet: a = [] -> value:0 == count())
    t.spec("expr.array.empty", "ArrayLiteral", "empty [] literal")
    ae = []
    t.assertEqual("expr.array.empty", ae.count(), 0)

    ' [] with comma-separated elements (snippet: a = [1,2,3] -> value:3 == count())
    t.spec("expr.array.elements", "ArrayElement", "[] with comma-separated elements")
    ael = [1, 2, 3]
    t.assertEqual("expr.array.elements", ael.count(), 3)

    ' nested array literal (snippet: a = [[1],[2]] : y = a[1][0] -> value:2)
    t.spec("expr.array.nested", "ArrayLiteral", "nested array literal")
    an = [[1], [2]]
    y = an[1][0]
    t.assertEqual("expr.array.nested", y, 2)

    ' multiline literal (newline separates inside depth>0) (snippet a=[\n1,\n2\n]
    ' -> value:2). value:2 = last element / count() == 2; use count.
    t.spec("expr.array.multiline", "ElementSep", "multiline literal (newline separates, depth>0)")
    aml = [
        1,
        2
    ]
    t.assertEqual("expr.array.multiline", aml.count(), 2)

    ' trailing comma tolerated (snippet: a = [1,2,] -> value:2 == count())
    t.spec("expr.array.trailing_comma", "ElementSep", "trailing comma tolerated")
    atc = [1, 2,]
    t.assertEqual("expr.array.trailing_comma", atc.count(), 2)

    ' newline-only element separator, no comma (snippet a=[\n1\n2\n] -> value:2 == count())
    t.spec("expr.array.newline_sep", "ElementSep", "newline-only element separator (no comma)")
    ans = [
        1
        2
    ]
    t.assertEqual("expr.array.newline_sep", ans.count(), 2)

    ' array literal as a call argument (snippet: f(a) returns a.count() ; f([1,2]) -> value:2)
    t.spec("expr.array.as_arg", "ArgumentList", "array literal as a call argument")
    y = evh_count([1, 2])
    t.assertEqual("expr.array.as_arg", y, 2)

    ' array literal as a return value (snippet: f() returns [1,2] -> value:2 == count())
    t.spec("expr.array.as_return", "ReturnStatement", "array literal as a return value")
    y = evh_make_array()
    t.assertEqual("expr.array.as_return", y.count(), 2)

    ' array literal iterated by for each (snippet: for each v in [4,5] sum -> value:9)
    t.spec("expr.array.in_foreach", "ForEachStatement", "array literal iterated by for each")
    s = 0
    for each v in [4, 5]
        s = s + v
    end for
    t.assertEqual("expr.array.in_foreach", s, 9)

    ' =====================================================================
    ' ASSOCIATIVE-ARRAY LITERALS
    ' =====================================================================

    ' empty {} literal (snippet: a = {} -> value:0 == count())
    t.spec("expr.aa.empty", "AssocArrayLiteral", "empty {} literal")
    aae = {}
    t.assertEqual("expr.aa.empty", aae.count(), 0)

    ' {key: value} entries (snippet: a = {x:1, y:2} -> value:2 == count())
    t.spec("expr.aa.entries", "AAEntry", "{key: value} entries")
    aen = { x: 1, y: 2 }
    t.assertEqual("expr.aa.entries", aen.count(), 2)

    ' identifier key (snippet: a = {name:1} : y = a.name -> value:1)
    t.spec("expr.aa.key_ident", "AAKey", "identifier key")
    aki = { name: 1 }
    y = aki.name
    t.assertEqual("expr.aa.key_ident", y, 1)

    ' string-literal key (snippet: a = {"my key":1} : y = a["my key"] -> value:1)
    t.spec("expr.aa.key_string", "AAKey", "string-literal key")
    aks = { "my key": 1 }
    y = aks["my key"]
    t.assertEqual("expr.aa.key_string", y, 1)

    ' reserved word usable as an AA key (snippet: a = {type:1} : y = a.type -> value:1)
    t.spec("expr.aa.key_reserved", "AAKey", "reserved word usable as an AA key")
    akr = { type: 1 }
    y = akr.type
    t.assertEqual("expr.aa.key_reserved", y, 1)

    ' multiline AA (newline separates entries) (snippet a={\nx:1,\ny:2\n} -> value:2 == count())
    t.spec("expr.aa.multiline", "ElementSep", "multiline AA (newline separates entries)")
    aml2 = {
        x: 1,
        y: 2
    }
    t.assertEqual("expr.aa.multiline", aml2.count(), 2)

    ' trailing comma in AA (snippet: a = {x:1, y:2,} -> value:2 == count())
    t.spec("expr.aa.trailing_comma", "ElementSep", "trailing comma in AA")
    atc2 = { x: 1, y: 2, }
    t.assertEqual("expr.aa.trailing_comma", atc2.count(), 2)

    ' nested AA value (snippet: a = {p:{q:3}} : y = a.p.q -> value:3)
    t.spec("expr.aa.nested", "AssocArrayLiteral", "nested AA value")
    anv = { p: { q: 3 } }
    y = anv.p.q
    t.assertEqual("expr.aa.nested", y, 3)

    ' =====================================================================
    ' ANONYMOUS FUNCTION / SUB EXPRESSIONS
    ' =====================================================================

    ' function()...end function expression value (snippet: f = function()...; y = f() -> value:1)
    t.spec("expr.anon.function", "AnonFunctionExpr", "function()...end function expression value")
    f = function()
        return 1
    end function
    y = f()
    t.assertEqual("expr.anon.function", y, 1)

    ' sub()...end sub expression value (snippet: s = sub()\nend sub -> parse)
    t.spec("expr.anon.sub", "AnonSubExpr", "sub()...end sub expression value")
    anonSub = sub()
    end sub
    anonSub()
    t.assertTrue("expr.anon.sub: runs", true)

    ' anon function passed as a call argument (snippet: call(fn) returns fn();
    ' call(function()\nreturn 2\nend function) -> value:2)
    t.spec("expr.anon.as_arg", "AnonFunctionExpr", "anon function passed as a call argument")
    y = evh_call(function()
        return 2
    end function)
    t.assertEqual("expr.anon.as_arg", y, 2)

    ' anon function as an AA value / method (snippet: m.go = function()...; y = m.go() -> value:3)
    t.spec("expr.anon.in_aa", "AnonFunctionExpr", "anon function as an AA value (method)")
    obj = {}
    obj.go = function()
        return 3
    end function
    y = obj.go()
    t.assertEqual("expr.anon.in_aa", y, 3)

    ' =====================================================================
    ' LITERAL PRIMARIES
    ' =====================================================================

    ' numeric literal as primary (snippet: x = 42 -> value:42)
    t.spec("expr.literal.numeric", "IntegerLiteral", "numeric literal as primary")
    x = 42
    t.assertEqual("expr.literal.numeric", x, 42)

    ' string literal as primary (snippet: x = "s" -> value:s)
    t.spec("expr.literal.string", "StringLiteral", "string literal as primary")
    x = "s"
    t.assertEqual("expr.literal.string", x, "s")

    ' boolean literal as primary (snippet: x = true -> value:true)
    t.spec("expr.literal.boolean", "BooleanLiteral", "boolean literal as primary")
    x = true
    t.assertTrue("expr.literal.boolean", x)

    ' invalid literal as primary (snippet: x = invalid -> value:invalid)
    t.spec("expr.literal.invalid", "InvalidLiteral", "invalid literal as primary")
    x = invalid
    t.assertInvalid("expr.literal.invalid", x)

    ' =====================================================================
    ' CreateObject
    ' =====================================================================

    ' CreateObject("roArray", ...) (snippet: a = CreateObject("roArray", 4, true)
    ' : a.push(1) : y=a.count() -> value:1)
    t.spec("expr.createobject.basic", "CreateObjectCall", "CreateObject(""roArray"", ...)")
    co = CreateObject("roArray", 4, true)
    co.push(1)
    y = co.count()
    t.assertEqual("expr.createobject.basic", y, 1)

    ' =====================================================================
    ' RESERVED BUILTIN CALLS
    ' =====================================================================

    ' reserved type() builtin call (snippet: s = type(1) -> value:Integer)
    t.spec("expr.builtin.type", "BuiltinCall", "reserved type() builtin call")
    s = type(1)
    t.assertEqual("expr.builtin.type", s, "Integer")

    ' reserved box() builtin call (snippet: o = box(1) -> parse)
    t.spec("expr.builtin.box", "BuiltinCall", "reserved box() builtin call")
    o = box(1)
    t.assertTrue("expr.builtin.box: runs", true)

    ' reserved getglobalaa() builtin call (snippet: g = getglobalaa() -> parse)
    t.spec("expr.builtin.getglobalaa", "BuiltinCall", "reserved getglobalaa() builtin call")
    gaa = getglobalaa()
    t.assertTrue("expr.builtin.getglobalaa: runs", gaa <> invalid)

    ' reserved getlastruncompileerror() builtin (returns invalid when no Run() error)
    t.spec("expr.builtin.getlastruncompileerror", "BuiltinCall", "reserved getlastruncompileerror() builtin call")
    lce = getlastruncompileerror()
    t.assertTrue("expr.builtin.getlastruncompileerror: runs", true)

    ' reserved getlastrunruntimeerror() builtin (returns the last Run() error code)
    t.spec("expr.builtin.getlastrunruntimeerror", "BuiltinCall", "reserved getlastrunruntimeerror() builtin call")
    lre = getlastrunruntimeerror()
    t.assertTrue("expr.builtin.getlastrunruntimeerror: runs", true)

    ' =====================================================================
    ' ARGUMENT LISTS
    ' =====================================================================

    ' empty argument list (snippet: f() returns 0 ; y=f() -> value:0)
    t.spec("expr.args.empty", "CallSuffix", "empty argument list")
    y = evh_zero()
    t.assertEqual("expr.args.empty", y, 0)

    ' single argument (snippet: f(a) returns a ; y=f(5) -> value:5)
    t.spec("expr.args.single", "ArgumentList", "single argument")
    y = evh_echo(5)
    t.assertEqual("expr.args.single", y, 5)

    ' multiple arguments (snippet: f(a,b) returns a+b ; y=f(2,3) -> value:5)
    t.spec("expr.args.multiple", "ArgumentList", "multiple arguments")
    y = evh_add(2, 3)
    t.assertEqual("expr.args.multiple", y, 5)

    ' a compound expression as an argument (snippet: f(a) returns a ; y=f(1+2*3) -> value:7)
    t.spec("expr.args.expr_arg", "ArgumentList", "a compound expression as an argument")
    y = evh_echo(1 + 2 * 3)
    t.assertEqual("expr.args.expr_arg", y, 7)

    ' a call result as an argument / nested call (snippet: id(id(4)) -> value:4)
    t.spec("expr.args.call_as_arg", "ArgumentList", "a call result as an argument (nested call)")
    y = evh_echo(evh_echo(4))
    t.assertEqual("expr.args.call_as_arg", y, 4)
end sub

' ---------------------------------------------------------------------------
' Module-level helpers (uniquely named, evh_ prefix) used as the (args) call
' targets / argument-list exercises above.
' ---------------------------------------------------------------------------

' Echoes its single argument (used by expr.postfix.call, expr.args.single,
' expr.args.expr_arg, expr.args.call_as_arg).
function evh_echo(n as Dynamic) as Dynamic
    return n
end function

' Returns the integer 1 (expr.postfix.call_noargs).
function evh_one() as Integer
    return 1
end function

' Returns the integer 0 (expr.args.empty).
function evh_zero() as Integer
    return 0
end function

' Returns the count of an array argument (expr.array.as_arg).
function evh_count(arr as Object) as Integer
    return arr.count()
end function

' Returns a freshly built array literal (expr.array.as_return).
function evh_make_array() as Object
    return [1, 2]
end function

' Adds two arguments (expr.args.multiple).
function evh_add(a as Integer, b as Integer) as Integer
    return a + b
end function

' Calls a function value passed as an argument (expr.anon.as_arg).
function evh_call(fn as Function) as Dynamic
    return fn()
end function
