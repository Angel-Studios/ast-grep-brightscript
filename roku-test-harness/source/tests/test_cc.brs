' test_cc.brs - exercises every device-testable CONDITIONAL-COMPILATION leaf (cc.*).
'
' Ids/kinds match grammar/coverage.json EXACTLY (one t.spec per device-testable
' cc.* leaf). #const / #if / #else if / #else / #end if / #endif are compiler
' directives resolved at COMPILE time; they may appear inside a sub, and exactly
' one branch is included. We assert on the value the included branch produced.
'
' DEVICE-CONFIRMED (DEVICE_FACTS.md #1): a #if expression accepts only a single
' boolean literal or const name - no and/or/not/parens. Negation is expressed
' with #else, conjunction with a nested #if.
'
' The manifest declares bs_const=debug=false;enable_extra_tests=true. The file-
' scope #const below uses a unique name (cch_flag) to avoid colliding with the
' manifest's `debug` const.

#const cch_flag = true

sub test_cc_all(t as Object)
    ' --- #const NAME = true/false ------------------------------------------
    ' #const cch_flag = true was declared at file scope above; including its
    ' guarded branch proves the directive parsed and evaluated true.
    t.spec("cc.const.bool", "ConstDirective", "#const NAME = true/false")
    x = 0
    #if cch_flag
        x = 1
    #end if
    t.assertTrue("cc.const.bool: runs", true)
    t.assertEqual("cc.const.bool value", x, 1)

    ' --- #if <bool literal> ------------------------------------------------
    t.spec("cc.if.literal", "IfDirectiveBlock", "#if <bool literal>")
    x = 0
    #if true
        x = 1
    #end if
    t.assertEqual("cc.if.literal", x, 1)

    ' --- #if <CONST-NAME> --------------------------------------------------
    t.spec("cc.if.const", "CCExpression", "#if <CONST-NAME>")
    x = 0
    #if cch_flag
        x = 1
    #end if
    t.assertEqual("cc.if.const", x, 1)

    ' --- #else if branch ---------------------------------------------------
    t.spec("cc.if.elseif", "IfDirectiveBlock", "#else if branch")
    x = 0
    #if false
        x = 1
    #else if true
        x = 2
    #end if
    t.assertEqual("cc.if.elseif", x, 2)

    ' --- #else branch (used for negation) ----------------------------------
    t.spec("cc.if.else", "IfDirectiveBlock", "#else branch (used for negation)")
    x = 0
    #if false
        x = 1
    #else
        x = 2
    #end if
    t.assertEqual("cc.if.else", x, 2)

    ' --- nested #if (used for conjunction) ---------------------------------
    t.spec("cc.if.nested", "IfDirectiveBlock", "nested #if (used for conjunction)")
    x = 0
    #if true
        #if true
            x = 1
        #end if
    #end if
    t.assertEqual("cc.if.nested", x, 1)

    ' --- fused #endif terminator -------------------------------------------
    t.spec("cc.endif.fused", "EndIfDirective", "fused #endif terminator")
    x = 0
    #if true
        x = 1
    #endif
    t.assertEqual("cc.endif.fused", x, 1)

    ' --- #if on a manifest-defined bs_const (manifest: enable_extra_tests=true) -
    t.spec("cc.manifest_const", "CCExpression", "#if on a manifest-defined bs_const (enable_extra_tests)")
    x = 0
    #if enable_extra_tests
        x = 1
    #end if
    t.assertEqual("cc.manifest_const", x, 1)
end sub
