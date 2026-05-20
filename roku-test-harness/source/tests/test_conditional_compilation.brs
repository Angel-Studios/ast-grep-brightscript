' test_conditional_compilation.brs - exercises #const and #if/#else if/#else/#end if.
'
' These directives are resolved at COMPILE time over boolean #const flags (and
' the manifest's bs_const). The goal here is that they compile cleanly and that
' exactly one branch is included and runs. We assert on the value the included
' branch produced.

' File-scope compile-time constants.
#const LOCAL_FEATURE_A = true
#const LOCAL_FEATURE_B = false

sub test_conditional_compilation_all(t as Object)
    ' --- #const file-scope constants (declared at top of file) -------------
    ' #const LOCAL_FEATURE_A/B were resolved at compile time; including the
    ' const-guarded branch below proves the directive parsed and evaluated.
    t.spec("cc.const", "ConstDirective", "#const file-scope boolean constants")
    constSeen = "no"
    #if LOCAL_FEATURE_A
        constSeen = "yes"
    #end if
    t.assertEqual("cc: #const LOCAL_FEATURE_A evaluated true", constSeen, "yes")

    ' --- #if / #else if / #else / #end if ----------------------------------
    t.spec("cc.if_block", "IfDirectiveBlock", "#if / #else if / #else / #end if branch selection")
    branch = ""
    #if LOCAL_FEATURE_A
        branch = "A"
    #else if LOCAL_FEATURE_B
        branch = "B"
    #else
        branch = "none"
    #end if
    t.assertEqual("cc: #if selected feature A branch", branch, "A")

    ' --- #if false -> #else path -------------------------------------------
    t.spec("cc.if_else", "IfDirectiveBlock", "#if false falls through to #else")
    fallback = ""
    #if LOCAL_FEATURE_B
        fallback = "B-included"
    #else
        fallback = "else-included"
    #end if
    t.assertEqual("cc: #if false uses #else", fallback, "else-included")

    ' --- negation: #if has NO boolean operators; express via #else ----------
    ' DEVICE-CONFIRMED: Roku #if accepts only (True | False | <CONST-NAME>);
    ' 'not'/'and'/'or' are a compile error (&h93). Negate with #else instead.
    t.spec("cc.negation_via_else", "CCExpression", "negation expressed via #else (no boolean ops in #if)")
    inverted = ""
    #if LOCAL_FEATURE_B
        inverted = "B"
    #else
        inverted = "not-B"
    #end if
    t.assertEqual("cc: negation via #else (B is false)", inverted, "not-B")

    ' --- conjunction: express "A and not B" via nested #if ------------------
    t.spec("cc.conjunction_via_nested", "CCExpression", "conjunction expressed via nested #if (no boolean ops)")
    combined = ""
    #if LOCAL_FEATURE_A
        #if LOCAL_FEATURE_B
            combined = "A and B"
        #else
            combined = "A and not B"
        #end if
    #end if
    t.assertEqual("cc: conjunction via nested #if", combined, "A and not B")

    ' --- manifest bs_const flag (enable_extra_tests=true) ------------------
    ' The manifest declares bs_const=debug=false;enable_extra_tests=true.
    t.spec("cc.manifest_const.enabled", "CCExpression", "manifest bs_const flag (enable_extra_tests=true)")
    extra = "skipped"
    #if enable_extra_tests
        extra = "ran"
    #end if
    t.assertEqual("cc: manifest bs_const enable_extra_tests", extra, "ran")

    ' --- manifest debug flag is false: confirm #else path ------------------
    t.spec("cc.manifest_const.disabled", "CCExpression", "manifest bs_const flag (debug=false) takes #else")
    dbg = ""
    #if debug
        dbg = "debug-on"
    #else
        dbg = "debug-off"
    #end if
    t.assertEqual("cc: manifest bs_const debug=false", dbg, "debug-off")
end sub
