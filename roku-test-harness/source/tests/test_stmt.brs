' test_stmt.brs - exercises every device-testable statement-layer leaf.
'
' One t.spec per coverage.json leaf whose id starts with "stmt." and is
' device_testable. The id and kind passed to t.spec EXACTLY match coverage.json.
' Each leaf runs the construct shown in its snippet and asserts per its expect:
'   - expect "value:X" -> compute and assertEqual / assertTrue / assertInvalid
'   - expect "parse"    -> execute (compiles + runs) then assertTrue(..., true)
'
' Skipped here (device_testable:false -> negative corpus): stmt.stop, stmt.end.
'
' Device: Roku OS 15.1.4 (compound assign, ++/--, try/catch, continue for/while
' all supported). BrightScript is case-insensitive with significant newlines;
' no leading "let" (device-rejected). Print output goes to the debug console and
' cannot be asserted on-device, so print leaves assert the path executed.

sub test_stmt_all(t as Object)
    ' ======================================================================
    ' assign
    ' ======================================================================
    t.spec("stmt.assign.var", "AssignmentStatement", "assign to a bare variable")
    x = 1
    t.assertEqual("stmt.assign.var: x", x, 1)

    t.spec("stmt.assign.member", "AssignTarget", "assign to .member target")
    m.count = 2
    t.assertEqual("stmt.assign.member: m.count", m.count, 2)

    t.spec("stmt.assign.index", "AssignTarget", "assign to [i] index target")
    a = [0]
    a[0] = 3
    t.assertEqual("stmt.assign.index: a[0]", a[0], 3)

    t.spec("stmt.assign.chain", "AssignTarget", "assign to deep member/index chain")
    m.list = [{}]
    m.list[0].name = "z"
    t.assertEqual("stmt.assign.chain: m.list[0].name", m.list[0].name, "z")

    t.spec("stmt.assign.no_let", "AssignmentStatement", "NO leading let (device-confirmed: let rejected)")
    x = 1
    t.assertEqual("stmt.assign.no_let: x (no let)", x, 1)

    ' ======================================================================
    ' compound assignment
    ' ======================================================================
    t.spec("stmt.compound.plus", "CompoundOp", "+= compound assign")
    x = 1
    x += 2
    t.assertEqual("stmt.compound.plus: x", x, 3)

    t.spec("stmt.compound.minus", "CompoundOp", "-= compound assign")
    x = 5
    x -= 2
    t.assertEqual("stmt.compound.minus: x", x, 3)

    t.spec("stmt.compound.star", "CompoundOp", "*= compound assign")
    x = 2
    x *= 3
    t.assertEqual("stmt.compound.star: x", x, 6)

    t.spec("stmt.compound.slash", "CompoundOp", "/= compound assign (float division)")
    x = 6
    x /= 2
    t.assertEqual("stmt.compound.slash: x", x, 3)

    t.spec("stmt.compound.backslash", "CompoundOp", "\\= compound assign (integer division)")
    x = 7
    x \= 2
    t.assertEqual("stmt.compound.backslash: x", x, 3)

    t.spec("stmt.compound.shl", "CompoundOp", "<<= compound assign (shift left)")
    x = 1
    x <<= 3
    t.assertEqual("stmt.compound.shl: x", x, 8)

    t.spec("stmt.compound.shr", "CompoundOp", ">>= compound assign (shift right)")
    x = 8
    x >>= 2
    t.assertEqual("stmt.compound.shr: x", x, 2)

    t.spec("stmt.compound.on_index", "CompoundAssignStatement", "compound op on an index target")
    a = [1]
    a[0] += 4
    t.assertEqual("stmt.compound.on_index: a[0]", a[0], 5)

    ' ======================================================================
    ' increment / decrement
    ' ======================================================================
    t.spec("stmt.incdec.incr_var", "IncDecStatement", "++ on a variable")
    x = 1
    x++
    t.assertEqual("stmt.incdec.incr_var: x", x, 2)

    t.spec("stmt.incdec.decr_var", "IncDecStatement", "-- on a variable")
    x = 2
    x--
    t.assertEqual("stmt.incdec.decr_var: x", x, 1)

    t.spec("stmt.incdec.on_index", "IncDecStatement", "++ on an index target")
    a = [1]
    a[0]++
    t.assertEqual("stmt.incdec.on_index: a[0]", a[0], 2)

    t.spec("stmt.incdec.on_member", "IncDecStatement", "++ on a member target")
    m.n = 1
    m.n++
    t.assertEqual("stmt.incdec.on_member: m.n", m.n, 2)

    ' ======================================================================
    ' print (output goes to console; assert the path ran)
    ' ======================================================================
    t.spec("stmt.print.keyword", "PrintStatement", "print keyword form")
    print "hi"
    t.assertTrue("stmt.print.keyword: runs", true)

    t.spec("stmt.print.question_alias", "QUESTION", "? shorthand for print")
    ? "hi"
    t.assertTrue("stmt.print.question_alias: runs", true)

    t.spec("stmt.print.empty", "PrintStatement", "empty print (just newline)")
    print
    t.assertTrue("stmt.print.empty: runs", true)

    t.spec("stmt.print.sep_comma", "PrintSep", ", separator (tab zone advance)")
    print "a", "b"
    t.assertTrue("stmt.print.sep_comma: runs", true)

    t.spec("stmt.print.sep_semi", "PrintSep", "; separator (no advance)")
    print "a"; "b"
    t.assertTrue("stmt.print.sep_semi: runs", true)

    t.spec("stmt.print.trailing_sep", "PrintItemList", "trailing separator suppresses newline")
    print "a";
    print "b"
    t.assertTrue("stmt.print.trailing_sep: runs", true)

    t.spec("stmt.print.tab", "TabItem", "tab(expr) positional item")
    print tab(5) "x"
    t.assertTrue("stmt.print.tab: runs", true)

    t.spec("stmt.print.pos", "PosItem", "pos(expr) positional item")
    print pos(0)
    t.assertTrue("stmt.print.pos: runs", true)

    ' ======================================================================
    ' if
    ' ======================================================================
    t.spec("stmt.if.block", "BlockIf", "multi-line block if/end if")
    x = 0
    if true
        x = 1
    end if
    t.assertEqual("stmt.if.block: x", x, 1)

    t.spec("stmt.if.block_then", "BlockIf", "optional then before newline")
    x = 0
    if true then
        x = 1
    end if
    t.assertEqual("stmt.if.block_then: x", x, 1)

    t.spec("stmt.if.endif_fused", "EndIf", "fused endif terminator")
    x = 0
    if true
        x = 1
    endif
    t.assertEqual("stmt.if.endif_fused: x", x, 1)

    t.spec("stmt.if.elseif", "ElseIfClause", "else if clause")
    x = 0
    if false
        x = 1
    else if true
        x = 2
    end if
    t.assertEqual("stmt.if.elseif: x", x, 2)

    t.spec("stmt.if.elseif_fused", "ElseIfClause", "fused elseif clause")
    x = 0
    if false
        x = 1
    elseif true
        x = 2
    end if
    t.assertEqual("stmt.if.elseif_fused: x", x, 2)

    t.spec("stmt.if.else", "ElseClause", "else clause in block if")
    x = 0
    if false
        x = 1
    else
        x = 2
    end if
    t.assertEqual("stmt.if.else: x", x, 2)

    t.spec("stmt.if.singleline", "SingleLineIf", "single-line if (statement after then, no newline)")
    x = 0
    if true then x = 1
    t.assertEqual("stmt.if.singleline: x", x, 1)

    t.spec("stmt.if.singleline_no_then", "SingleLineIf", "single-line if without then")
    x = 0
    if true x = 1
    t.assertEqual("stmt.if.singleline_no_then: x", x, 1)

    t.spec("stmt.if.singleline_else", "SingleLineIf", "single-line if with inline else")
    x = 0
    if false then x = 1 else x = 2
    t.assertEqual("stmt.if.singleline_else: x", x, 2)

    t.spec("stmt.if.singleline_colon", "InlineStatements", "multiple :-joined statements after then")
    x = 0
    y = 0
    if true then x = 1 : y = 2
    t.assertEqual("stmt.if.singleline_colon: y", y, 2)

    ' ======================================================================
    ' for
    ' ======================================================================
    t.spec("stmt.for.basic", "ForStatement", "for i = a to b")
    s = 0
    for i = 1 to 3
        s = s + i
    end for
    t.assertEqual("stmt.for.basic: s", s, 6)

    t.spec("stmt.for.step", "ForStatement", "step clause")
    s = 0
    for i = 0 to 4 step 2
        s = s + i
    end for
    t.assertEqual("stmt.for.step: s", s, 6)

    t.spec("stmt.for.step_negative", "ForStatement", "negative step (counts down)")
    s = 0
    for i = 3 to 1 step -1
        s = s + i
    end for
    t.assertEqual("stmt.for.step_negative: s", s, 6)

    t.spec("stmt.for.next", "ForTerminator", "legacy next terminator")
    s = 0
    for i = 1 to 3
        s = s + i
    next
    t.assertEqual("stmt.for.next: s", s, 6)

    ' DEVICE FACT: `next i` (next with a counter variable) is DEVICE-VALID on Roku
    ' OS 15.1.4, but BrighterScript (bsc) rejects it (BS1039/BS1066) - a tracked
    ' bsc-vs-device drift (grammar/BSC_DRIFT.md). Suppress the bsc false-positive.
    t.spec("stmt.for.next_var", "ForTerminator", "next with counter variable")
    s = 0
    for i = 1 to 3
        s = s + i
    ' bs:disable-next-line
    next i
    t.assertEqual("stmt.for.next_var: s", s, 6)

    t.spec("stmt.for.endfor_fused", "ForTerminator", "fused endfor terminator")
    s = 0
    for i = 1 to 3
        s = s + i
    endfor
    t.assertEqual("stmt.for.endfor_fused: s", s, 6)

    ' ======================================================================
    ' for each
    ' ======================================================================
    t.spec("stmt.foreach.array", "ForEachStatement", "iterate an array")
    s = 0
    for each v in [1, 2, 3]
        s = s + v
    end for
    t.assertEqual("stmt.foreach.array: s", s, 6)

    t.spec("stmt.foreach.aa", "ForEachStatement", "iterate AA keys")
    n = 0
    for each k in { a: 1, b: 2 }
        n = n + 1
    end for
    t.assertEqual("stmt.foreach.aa: n", n, 2)

    t.spec("stmt.foreach.endfor_fused", "ForEachStatement", "fused endfor terminator")
    s = 0
    for each v in [1, 2]
        s = s + v
    endfor
    t.assertEqual("stmt.foreach.endfor_fused: s", s, 3)

    ' ======================================================================
    ' while
    ' ======================================================================
    t.spec("stmt.while.basic", "WhileStatement", "while/end while")
    i = 0
    while i < 3
        i = i + 1
    end while
    t.assertEqual("stmt.while.basic: i", i, 3)

    t.spec("stmt.while.endwhile_fused", "EndWhile", "fused endwhile terminator")
    i = 0
    while i < 3
        i = i + 1
    endwhile
    t.assertEqual("stmt.while.endwhile_fused: i", i, 3)

    ' ======================================================================
    ' exit / continue
    ' ======================================================================
    t.spec("stmt.exit.for", "ExitStatement", "exit for breaks a numeric loop")
    r = 0
    for i = 1 to 9
        if i = 3 then exit for
        r = i
    end for
    t.assertEqual("stmt.exit.for: r", r, 2)

    t.spec("stmt.exit.while", "ExitStatement", "exit while breaks a while loop")
    i = 0
    while true
        i = i + 1
        if i = 2 then exit while
    end while
    t.assertEqual("stmt.exit.while: i", i, 2)

    t.spec("stmt.exit.exitwhile_fused", "ExitStatement", "legacy fused exitwhile")
    i = 0
    while true
        i = i + 1
        if i = 2 then exitwhile
    end while
    t.assertEqual("stmt.exit.exitwhile_fused: i", i, 2)

    t.spec("stmt.continue.for", "ContinueStatement", "continue for skips iteration")
    s = 0
    for i = 1 to 3
        if i = 2 then continue for
        s = s + i
    end for
    t.assertEqual("stmt.continue.for: s", s, 4)

    t.spec("stmt.continue.while", "ContinueStatement", "continue while skips iteration")
    i = 0
    s = 0
    while i < 3
        i = i + 1
        if i = 2 then continue while
        s = s + i
    end while
    t.assertEqual("stmt.continue.while: s", s, 4)

    ' ======================================================================
    ' return (via module-level helpers)
    ' ======================================================================
    t.spec("stmt.return.value", "ReturnStatement", "return with an expression")
    t.assertEqual("stmt.return.value: f()", sth_returns_nine(), 9)

    t.spec("stmt.return.bare", "ReturnStatement", "bare return (no expression, from a sub)")
    sth_bare_return()
    t.assertTrue("stmt.return.bare: runs", true)

    ' ======================================================================
    ' dim
    ' ======================================================================
    t.spec("stmt.dim.bracket", "DimBounds", "dim a[n] bracket bounds")
    dim ab[3]
    ab[0] = 1
    t.assertEqual("stmt.dim.bracket: ab[0]", ab[0], 1)

    ' NOTE: stmt.dim.paren (`dim a(n)` paren bounds) is DEVICE-REJECTED (compile
    ' error &h02 - Dim requires [bracket] bounds). Moved to corpus/negative/.
    ' See grammar/DEVICE_FACTS.md.

    t.spec("stmt.dim.multidim", "DimBounds", "multi-dimension bounds enables a[i,j]")
    dim am[2, 2]
    am[1, 1] = 5
    t.assertEqual("stmt.dim.multidim: am[1,1]", am[1, 1], 5)

    ' ======================================================================
    ' label / goto
    ' ======================================================================
    t.spec("stmt.label.def", "Label", "label definition (ident: alone on a line)")
    goto sth_after_label
    sth_after_label:
    t.assertTrue("stmt.label.def: runs", true)

    t.spec("stmt.goto.basic", "GotoStatement", "goto label jump")
    i = 0
    sth_goto_top:
    i = i + 1
    if i < 3 then goto sth_goto_top
    t.assertEqual("stmt.goto.basic: i", i, 3)

    ' ======================================================================
    ' try / catch / throw
    ' ======================================================================
    t.spec("stmt.try.basic", "TryStatement", "try/catch e/end try")
    caught = false
    try
        throw "x"
    catch e
        caught = true
    end try
    t.assertTrue("stmt.try.basic: caught", caught)

    t.spec("stmt.try.endtry_fused", "EndTry", "fused endtry terminator")
    try
        throw "x"
    catch e
    endtry
    t.assertTrue("stmt.try.endtry_fused: runs", true)

    t.spec("stmt.throw.string", "ThrowStatement", "throw a string message")
    try
        throw "boom"
    catch e
    end try
    t.assertTrue("stmt.throw.string: runs", true)

    t.spec("stmt.throw.aa", "ThrowStatement", "throw an AA with number/message")
    try
        throw { number: 1, message: "m" }
    catch e
    end try
    t.assertTrue("stmt.throw.aa: runs", true)

    ' ======================================================================
    ' expression statements
    ' ======================================================================
    t.spec("stmt.expr.call", "ExpressionStatement", "function-call statement")
    print("x")
    t.assertTrue("stmt.expr.call: runs", true)

    t.spec("stmt.expr.method_call", "CallExpression", "method-call statement (member then call)")
    o = {}
    o.doIt = sth_noop
    o.doIt()
    t.assertTrue("stmt.expr.method_call: runs", true)

    ' NOTE: stmt.expr.optcall (`o.fn?()` optional-call as a bare STATEMENT) is
    ' DEVICE-REJECTED (compile error &h02). The `?()` optional-call works in
    ' EXPRESSION position (see expr.optchain.paren). Moved to corpus/negative/.
    ' See grammar/DEVICE_FACTS.md.
end sub

' ---------------------------------------------------------------------------
' Module-level helpers for the leaves that need a function/sub context.
' Prefixed sth_ ("statement test helper") to stay uniquely named.
' ---------------------------------------------------------------------------

' stmt.return.value: a function whose body is a single `return <expr>`.
function sth_returns_nine() as Integer
    return 9
end function

' stmt.return.bare: a sub with a bare `return` (no expression).
sub sth_bare_return()
    return
end sub

' stmt.expr.method_call: a no-op function value installed on an AA and called
' via member dispatch (o.doIt()).
sub sth_noop()
end sub
