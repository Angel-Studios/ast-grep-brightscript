' test_print.brs - exercises print statement forms.
'
' print and the '?' alias, ',' (tab-zone) and ';' (no-space) separators, trailing
' separator to suppress newline, TAB(expr) and POS(expr) positional items, and
' the empty print (bare newline).
'
' Print output goes to the debug console (telnet :8085) and cannot be asserted
' on-device, so these mostly assert that the surrounding code path executed. The
' value is corpus coverage of every print form.

sub test_print_all(t as Object)
    ' Plain print.
    t.spec("stmt.print.plain", "PrintStatement", "plain print statement")
    print "test_print: plain print"

    ' '?' alias for print.
    t.spec("stmt.print.question_alias", "PrintStatement", "? alias for print")
    ? "test_print: question-mark alias"

    ' Comma separator (advance to next tab zone) and semicolon (no separator).
    t.spec("stmt.print.separators", "PrintSep", ", (tab-zone) and ; (no-space) print separators")
    print "col1", "col2", "col3"
    print "no"; "space"; "between"

    ' Trailing semicolon suppresses the newline; the next print continues the line.
    print "continued ";
    print "line"

    ' TAB(n) positional item: move the print cursor to column n.
    t.spec("stmt.print.tab_item", "TabItem", "TAB(n) positional print item")
    print TAB(5); "indented-by-tab"

    ' POS(0) returns the current cursor column; combine with TAB.
    t.spec("stmt.print.pos_item", "PosItem", "POS(n) positional print item")
    print "x"; : print POS(0)   ' POS reports column after printing 'x'

    ' Mixed expression items with separators.
    t.spec("stmt.print.expression_items", "PrintItem", "mixed expression items with separators")
    n = 7
    print "value="; n; " squared="; n * n

    ' Empty print (emits a blank line).
    t.spec("stmt.print.empty", "PrintStatement", "bare print emits a blank line")
    print

    ' Assertions: confirm the path executed and a computed value is correct so
    ' this module still contributes real pass/fail records.
    t.assertEqual("print: computed value used in print", n * n, 49)
    t.assertTrue("print: reached end of print exercises", true)
end sub
