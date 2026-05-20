' test_exceptions.brs - exercises try / catch / throw.
'
' throwing a String message, throwing an associative-array error object with
' { number, message } fields, inspecting the caught error, and confirming a
' non-throwing try block runs its full body.

sub test_exceptions_all(t as Object)
    ' --- throw a String, catch it ------------------------------------------
    t.spec("stmt.throw.string", "ThrowStatement", "throw a String message, catch it")
    caught = ""
    try
        throw "boom"
    catch e
        caught = e.message
    end try
    t.assertEqual("exc: throw string -> e.message", caught, "boom")

    ' --- throw an AA error object with number + message --------------------
    t.spec("stmt.throw.aa", "ThrowStatement", "throw an AA error object with number + message")
    errNumber = 0
    errMessage = ""
    try
        throw { number: 42, message: "custom failure" }
    catch e
        errNumber = e.number
        errMessage = e.message
    end try
    t.assertEqual("exc: AA throw -> e.number", errNumber, 42)
    t.assertEqual("exc: AA throw -> e.message", errMessage, "custom failure")

    ' --- runtime error is catchable (divide by zero etc.) ------------------
    ' Force a runtime error by indexing invalid; confirm catch fires.
    t.spec("stmt.try.runtime_error", "TryStatement", "try/catch catches a runtime error")
    rtCaught = false
    try
        obj = invalid
        bad = obj.someField   ' dereferencing invalid raises a runtime error
        bad = bad + 1
    catch e
        rtCaught = true
    end try
    t.assertTrue("exc: runtime error caught", rtCaught)

    ' --- non-throwing try block runs to completion -------------------------
    t.spec("stmt.try.no_throw", "TryStatement", "try body completes when nothing throws")
    ran = false
    try
        ran = true
    catch e
        ran = false
    end try
    t.assertTrue("exc: try body completes when no throw", ran)

    ' --- nested try / catch ------------------------------------------------
    t.spec("stmt.try.nested", "TryStatement", "nested try/catch with rethrow")
    inner = ""
    outer = ""
    try
        try
            throw "inner-error"
        catch ie
            inner = ie.message
            throw "outer-error"
        end try
    catch oe
        outer = oe.message
    end try
    t.assertEqual("exc: nested inner caught", inner, "inner-error")
    t.assertEqual("exc: nested rethrow caught", outer, "outer-error")

    ' --- caught error is an associative array -------------------------------
    t.spec("stmt.try.error_object", "TryStatement", "caught error is an roAssociativeArray")
    isAA = false
    try
        throw "inspect-me"
    catch e
        isAA = (Type(e) = "roAssociativeArray")
    end try
    t.assertTrue("exc: caught error is AA", isAA)
end sub
