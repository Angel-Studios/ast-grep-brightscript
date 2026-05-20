' TestSuite.brs - aggregates every BrightScript test module's entry function.
'
' Module ids/kinds are keyed 1:1 to grammar/coverage.json (the single source of
' truth for the language taxonomy); grammar/check_coverage.py asserts parity.
' The SceneGraph module (test_scenegraph_all) is NOT listed here: it needs the
' live scene/showcase nodes, so source/main.brs invokes it directly after the
' scene is shown (see main.brs).

' Returns the ordered array of BrightScript test-case Function values to run.
' Each entry is a first-class function reference (the Function type) - passing
' functions as values, which the TestRunner invokes one by one.
function TestSuite_All() as Object
    return [
        test_lex_all
        test_decl_all
        test_cc_all
        test_stmt_all
        test_expr_ops_all
        test_expr_values_all
    ]
end function
