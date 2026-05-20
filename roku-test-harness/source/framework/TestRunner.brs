' TestRunner.brs - a minimal assert / test framework with ##SPEC## emission.
'
' This module is itself a corpus exercise: it uses associative arrays, first-class
' function values (the Function type), anonymous helpers, m-style dispatch, and
' typed parameters / return types throughout.
'
' SPEC PROTOCOL
' -------------
' The harness emits, to the debug console, one structured line per registered
' spec it exercises (parsed by roku-listener/src/parser.ts):
'
'   ##SPEC## v=1 id=<dotted.id> kind=<EBNFRuleName> status=<PASS|FAIL> detail="..."
'
' with run framing:
'
'   ##SPEC## event=run-start total=<N>
'   ##SPEC## event=run-end pass=<N> fail=<N>
'
' A "spec" is a named unit of coverage with a stable dotted id and an EBNF rule
' name (kind). A test module opens a spec with t.spec(id, kind, description) and
' then makes one or more assertions; all assertions made while that spec is open
' roll up into ONE ##SPEC## result (PASS iff every assertion passed; otherwise
' FAIL carrying the first failure's detail). detail is only emitted on FAIL.
'
' Result record shape (one per assertion, retained for on-screen rendering):
'   { name as String, passed as Boolean, detail as String }
' Spec record shape (one per registered spec, drives ##SPEC## emission):
'   { id as String, kind as String, description as String,
'     passed as Boolean, detail as String }
'
' Usage:
'   runner = TestRunner_Create()
'   results = runner.runAll(TestSuite_All())
'   summary = runner.summarize(results)       ' { total, passed, failed }
'   runner.emitSpecLines()                    ' prints all ##SPEC## lines + framing

' Construct a test runner. Returns an roAssociativeArray with bound function
' references (function values stored as AA members and invoked via m-dispatch).
function TestRunner_Create() as Object
    runner = {}

    ' Accumulator for the assertion records produced during a run.
    runner.results = []
    ' Accumulator for the registered specs (id/kind units) produced during a run.
    runner.specs = []
    ' The spec currently being filled (invalid when no spec is open).
    runner.currentSpec = invalid

    ' --- Bind framework functions as first-class values on the instance -----
    runner.runAll = TestRunner_runAll
    runner.summarize = TestRunner_summarize
    runner.record = TestRunner_record
    runner.spec = TestRunner_spec
    runner.emitSpecLines = TestRunner_emitSpecLines

    ' Assertion helpers, all bound so tests can call m.runner.assertX(...) or be
    ' handed the runner explicitly.
    runner.assertTrue = TestRunner_assertTrue
    runner.assertFalse = TestRunner_assertFalse
    runner.assertEqual = TestRunner_assertEqual
    runner.assertNotEqual = TestRunner_assertNotEqual
    runner.assertInvalid = TestRunner_assertInvalid
    runner.assertNotInvalid = TestRunner_assertNotInvalid
    runner.assertType = TestRunner_assertType
    runner.assertAA = TestRunner_assertAA

    return runner
end function

' Execute an array of test-case function values. Each test case is a Function
' that takes the runner and appends records via the assertion helpers. Returns
' the aggregated results array.
function TestRunner_runAll(suite as Object) as Object
    m.results = []
    m.specs = []
    m.currentSpec = invalid
    for each testCase in suite
        ' testCase is a first-class Function value. Guard against bad entries.
        if Type(testCase) = "roFunction" or Type(testCase) = "Function" then
            testCase(m)
        else
            m.record("<invalid test case>", false, "suite entry was not a Function")
        end if
    end for
    ' Close any spec the final module left open.
    m.currentSpec = invalid
    return m.results
end function

' Open a new spec (a stable id + EBNF kind coverage unit). All assertions made
' after this call - until the next spec() call - roll up into this one spec's
' ##SPEC## result. Returns invalid (used for its side effect).
sub TestRunner_spec(id as String, kind as String, description = "" as String)
    rec = {
        id: id,
        kind: kind,
        description: description,
        passed: true,
        detail: ""
    }
    m.specs.push(rec)
    m.currentSpec = rec
end sub

' Append a single assertion result to the accumulator, fold it into the open
' spec, and echo the human line to the console (NOT a ##SPEC## line).
sub TestRunner_record(name as String, passed as Boolean, detail = "" as String)
    rec = { name: name, passed: passed, detail: detail }
    m.results.push(rec)

    ' Fold into the currently-open spec, if any.
    if m.currentSpec <> invalid then
        if not passed then
            m.currentSpec.passed = false
            ' Keep the FIRST failure's detail for the spec line.
            if m.currentSpec.detail = "" then
                m.currentSpec.detail = name + ": " + detail
            end if
        end if
    end if

end sub

' Emit the ##SPEC## protocol to the debug console: a run-start framing line with
' the total spec count, one result line per registered spec, then a run-end
' framing line with the pass/fail tallies.
sub TestRunner_emitSpecLines()
    total% = m.specs.count()
    print "##SPEC## event=run-start total=" + total%.ToStr()

    pass% = 0
    fail% = 0
    for each sp in m.specs
        if sp.passed then
            pass% = pass% + 1
            print "##SPEC## v=1 id=" + sp.id + " kind=" + sp.kind + " status=PASS"
        else
            fail% = fail% + 1
            print "##SPEC## v=1 id=" + sp.id + " kind=" + sp.kind + " status=FAIL detail=" + Chr(34) + SpecEscape(sp.detail) + Chr(34)
        end if
    end for

    print "##SPEC## event=run-end pass=" + pass%.ToStr() + " fail=" + fail%.ToStr()
end sub

' Escape a detail string for the double-quoted ##SPEC## detail field: backslash
' and double-quote are backslash-escaped; newlines are flattened to spaces so the
' value stays on one line (the listener splits the stream on newlines).
function SpecEscape(s as String) as String
    if s = invalid then return ""
    out = ""
    for i = 0 to Len(s) - 1
        ch = Mid(s, i + 1, 1)
        if ch = "\" then
            out = out + "\\"
        else if ch = Chr(34) then
            out = out + "\" + Chr(34)
        else if ch = Chr(10) or ch = Chr(13) then
            out = out + " "
        else
            out = out + ch
        end if
    end for
    return out
end function

' Summarize an assertion results array into { total, passed, failed }.
function TestRunner_summarize(results as Object) as Object
    total% = results.count()
    passed% = 0
    for each rec in results
        if rec.passed then passed% = passed% + 1
    end for
    return { total: total%, passed: passed%, failed: total% - passed% }
end function

' ---------------------------------------------------------------------------
' Assertions. Each returns the Boolean outcome AND records it.
' ---------------------------------------------------------------------------

function TestRunner_assertTrue(name as String, cond as Dynamic) as Boolean
    ok = (cond = true)
    m.record(name, ok, "expected true, got " + AsString(cond))
    return ok
end function

function TestRunner_assertFalse(name as String, cond as Dynamic) as Boolean
    ok = (cond = false)
    m.record(name, ok, "expected false, got " + AsString(cond))
    return ok
end function

function TestRunner_assertEqual(name as String, actual as Dynamic, expected as Dynamic) as Boolean
    ok = ValuesEqual(actual, expected)
    m.record(name, ok, "expected " + AsString(expected) + ", got " + AsString(actual))
    return ok
end function

function TestRunner_assertNotEqual(name as String, actual as Dynamic, expected as Dynamic) as Boolean
    ok = not ValuesEqual(actual, expected)
    m.record(name, ok, "expected != " + AsString(expected) + ", got " + AsString(actual))
    return ok
end function

function TestRunner_assertInvalid(name as String, value as Dynamic) as Boolean
    ok = (value = invalid)
    m.record(name, ok, "expected invalid, got " + AsString(value))
    return ok
end function

function TestRunner_assertNotInvalid(name as String, value as Dynamic) as Boolean
    ok = (value <> invalid)
    m.record(name, ok, "expected non-invalid")
    return ok
end function

function TestRunner_assertType(name as String, value as Dynamic, expectedType as String) as Boolean
    actualType = Type(value)
    ok = (LCase(actualType) = LCase(expectedType))
    m.record(name, ok, "expected type " + expectedType + ", got " + actualType)
    return ok
end function

function TestRunner_assertAA(name as String, value as Dynamic) as Boolean
    ok = (value <> invalid and Type(value) = "roAssociativeArray")
    m.record(name, ok, "expected roAssociativeArray")
    return ok
end function

' ---------------------------------------------------------------------------
' Free helpers (module-level functions, used as plain function values).
' ---------------------------------------------------------------------------

' Loose value equality that handles the common scalar + collection cases used
' by the tests. Exercises GetInterface / Type-based dispatch.
function ValuesEqual(a as Dynamic, b as Dynamic) as Boolean
    if a = invalid and b = invalid then return true
    if a = invalid or b = invalid then return false

    ta = Type(a)
    tb = Type(b)

    ' Scalar comparisons must cross the boxed/intrinsic boundary: container
    ' access (index, member, ?., @attr, CreateObject) returns BOXED scalars
    ' (roInteger / roString / roBoolean) while literals are intrinsic.
    if IsNumeric(a) and IsNumeric(b) then return a = b
    if IsStringVal(a) and IsStringVal(b) then return a = b
    if IsBoolVal(a) and IsBoolVal(b) then return a = b

    if ta <> tb then return false

    if ta = "roArray" then
        if a.count() <> b.count() then return false
        for i = 0 to a.count() - 1
            if not ValuesEqual(a[i], b[i]) then return false
        end for
        return true
    end if

    if ta = "roAssociativeArray" then
        if a.count() <> b.count() then return false
        for each key in a
            if not ValuesEqual(a[key], b[key]) then return false
        end for
        return true
    end if

    return a = b
end function

function IsNumeric(v as Dynamic) as Boolean
    t = Type(v)
    return t = "Integer" or t = "roInteger" or t = "roInt" or t = "Float" or t = "roFloat" or t = "Double" or t = "roDouble" or t = "LongInteger" or t = "roLongInteger"
end function

function IsStringVal(v as Dynamic) as Boolean
    t = Type(v)
    return t = "String" or t = "roString"
end function

function IsBoolVal(v as Dynamic) as Boolean
    t = Type(v)
    return t = "Boolean" or t = "roBoolean"
end function

' Best-effort stringification for assertion detail messages. Demonstrates a
' single-line if and a chain of type checks.
function AsString(v as Dynamic) as String
    if v = invalid then return "invalid"
    t = Type(v)
    if t = "String" or t = "roString" then return v
    if t = "Boolean" or t = "roBoolean" then
        if v then return "true" else return "false"
    end if
    if IsNumeric(v) then return v.ToStr()
    if t = "roArray" then return "[array:" + StrI(v.count()).Trim() + "]"
    if t = "roAssociativeArray" then return "{aa:" + StrI(v.count()).Trim() + "}"
    return "<" + t + ">"
end function
