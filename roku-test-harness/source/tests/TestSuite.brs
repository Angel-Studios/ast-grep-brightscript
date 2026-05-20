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
        ' Standard-library coverage (layer="stdlib" in coverage.json). These run in
        ' the Main scope (CreateObject for roArray/roAA/roString/roDateTime/roRegex/
        ' roDeviceInfo/roRegistry/roFileSystem works without a screen). Each spec is
        ' internally try/catch-guarded so a device-rejected API FAILs only itself.
        test_lib_global_all
        test_lib_array_all
        test_lib_aa_all
        test_lib_string_all
        test_lib_time_regex_all
        test_lib_device_storage_all
        ' BrighterScript layer (layer="brighterscript" in coverage.json). Authored
        ' in source/tests/test_bs.bs and TRANSPILED to .brs by the deploy build
        ' (bsconfig.deploy.json); the lowered global `test_bs_all` runs here in the
        ' Main scope like any other module -- the on-device proof that the modeled
        ' BrighterScript constructs transpile and execute.
        test_bs_all
    ]
end function
