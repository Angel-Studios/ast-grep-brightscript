' test_controlflow.brs - exercises every control-flow construct.
'
' Block if / else if / else / end if, single-line if (+ inline else), for/to/step,
' for each/in, while, exit for, exit while, continue for/while, return, goto+label,
' a guarded stop, and nested control flow.

sub test_controlflow_all(t as Object)
    ' --- Block if / else if / else / end if --------------------------------
    t.spec("stmt.if.block", "BlockIf", "block if / else if / else / end if")
    grade = grade_for(85)
    t.assertEqual("cf: block if/elseif/else (B)", grade, "B")
    t.assertEqual("cf: block if (A)", grade_for(95), "A")
    t.assertEqual("cf: block else branch (F)", grade_for(10), "F")

    ' --- Single-line if (with then) and inline else ------------------------
    t.spec("stmt.if.single_line", "SingleLineIf", "single-line if/else and colon-separated inline statements")
    flag = ""
    if 1 < 2 then flag = "yes" else flag = "no"
    t.assertEqual("cf: single-line if/else", flag, "yes")
    ' Single-line if without then, multiple statements via ':'.
    total = 0
    if true then total = total + 1 : total = total + 2
    t.assertEqual("cf: single-line if with colon stmts", total, 3)

    ' --- for / to / step / end for -----------------------------------------
    t.spec("stmt.for", "ForStatement", "for / to / step / end for (incl. legacy 'next' terminator)")
    sum = 0
    for i = 1 to 5
        sum = sum + i
    end for
    t.assertEqual("cf: for 1 to 5 sum", sum, 15)

    ' for with step, terminated by legacy 'next'.
    acc = 0
    for j = 10 to 0 step -2
        acc = acc + j
    next
    t.assertEqual("cf: for step -2 sum", acc, 30)

    ' --- exit for ----------------------------------------------------------
    t.spec("stmt.exit.for", "ExitStatement", "exit for")
    found = -1
    for k = 0 to 100
        if k = 7 then
            found = k
            exit for
        end if
    end for
    t.assertEqual("cf: exit for", found, 7)

    ' --- continue for (Roku OS 7.1+): sum only even numbers ----------------
    t.spec("stmt.continue.for", "ContinueStatement", "continue for")
    evens = 0
    for n = 1 to 10
        if (n mod 2) <> 0 then continue for
        evens = evens + n
    end for
    t.assertEqual("cf: continue for evens", evens, 30)

    ' --- for each / in -----------------------------------------------------
    t.spec("stmt.for_each", "ForEachStatement", "for each / in")
    items = [10, 20, 30]
    eachSum = 0
    for each item in items
        eachSum = eachSum + item
    end for
    t.assertEqual("cf: for each sum", eachSum, 60)

    ' --- while / end while + exit while ------------------------------------
    t.spec("stmt.while", "WhileStatement", "while / end while")
    w = 0
    counter = 0
    while true
        counter = counter + 1
        w = w + counter
        if counter >= 4 then exit while
    end while
    t.assertEqual("cf: while + exit while", w, 10)

    t.spec("stmt.exit.while", "ExitStatement", "exit while")
    t.assertEqual("cf: exit while terminated loop", w, 10)

    ' --- continue while ----------------------------------------------------
    t.spec("stmt.continue.while", "ContinueStatement", "continue while")
    cw = 0
    idx = 0
    while idx < 6
        idx = idx + 1
        if (idx mod 2) = 0 then continue while
        cw = cw + idx
    end while
    t.assertEqual("cf: continue while odd sum", cw, 9)

    ' --- nested control flow -----------------------------------------------
    t.spec("stmt.for.nested", "ForStatement", "nested for loops")
    matrix = 0
    for r = 1 to 3
        for c = 1 to 3
            if r = c then matrix = matrix + (r * c)
        end for
    end for
    t.assertEqual("cf: nested for diagonal", matrix, 14)

    ' --- goto + label ------------------------------------------------------
    t.spec("stmt.goto", "GotoStatement", "goto + label")
    visited = false
    goto skipForward
    visited = true   ' should be jumped over
    skipForward:
    t.assertFalse("cf: goto skipped statement", visited)

    ' --- guarded stop (does not actually break the run) --------------------
    ' 'stop' invokes the debugger; we guard it behind a constant-false condition
    ' so the construct is present in the corpus but never executes on device.
    t.spec("stmt.stop", "StopStatement", "guarded stop (never reached on device)")
    debugBreak = false
    if debugBreak then stop
    t.assertTrue("cf: guarded stop not triggered", true)

    ' --- return value from a helper ----------------------------------------
    t.spec("stmt.return", "ReturnStatement", "return value from a function")
    t.assertEqual("cf: return value", doubler(21), 42)
end sub

' Block if / else if / else helper. Also demonstrates 'return' inside branches.
function grade_for(score as Integer) as String
    if score >= 90 then
        return "A"
    else if score >= 80 then
        return "B"
    else if score >= 70 then
        return "C"
    else
        return "F"
    end if
end function

function doubler(v as Integer) as Integer
    return v * 2
end function
