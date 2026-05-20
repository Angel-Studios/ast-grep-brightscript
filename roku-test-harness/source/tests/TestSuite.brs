' TestSuite.brs - aggregates every test module's entry function.
'
' The 'library' statement below imports a Roku-provided BrightScript library so
' the LibraryStatement construct appears in the corpus. v30/bslCore.brs ships
' with the firmware and provides bslBrightScriptErrorCodes() etc.
library "v30/bslCore.brs"

' Returns the ordered array of test-case Function values to run. Each entry is a
' first-class function reference (the Function type) - passing functions as
' values, which the TestRunner invokes one by one.
function TestSuite_All() as Object
    return [
        test_literals_all,
        test_operators_all,
        test_controlflow_all,
        test_functions_all,
        test_collections_all,
        test_types_all,
        test_exceptions_all,
        test_conditional_compilation_all,
        test_objects_all,
        test_print_all,
        test_misc_all
    ]
end function

' Convenience: build a runner, run the whole suite, and return both the raw
' results array and the summary AA.
'
' IMPORTANT (scope): this and all pkg:/source/** functions live in the GLOBAL /
' Main scope. SceneGraph component scripts (e.g. MainScene.brs) do NOT see them
' (DEVICE_FACTS.md #harness-wiring: "&h91 Function is not defined in component's
' namespace"). The suite is therefore driven from source/main.brs (the Main
' scope), which CAN see everything here; MainScene only renders the results that
' Main hands it via a scene field.
function TestSuite_Run() as Object
    runner = TestRunner_Create()
    results = runner.runAll(TestSuite_All())
    summary = runner.summarize(results)
    ' Emit the ##SPEC## protocol (run-start framing, one line per registered
    ' spec, run-end framing) to the debug console from the Main scope.
    runner.emitSpecLines()
    return { results: results, summary: summary, specs: runner.specs }
end function
