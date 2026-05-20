' coverage-id: lex.eos.depth0_paren
' expect: error
' Device-confirmed REJECTED (compile error &h02): a newline inside a grouping
' ( ) terminates the statement - newline-suppression at depth>0 applies to the
' [ ] and { } collection literals (and call argument lists), NOT to a grouping
' parenthesised expression. So `x = (1 +<newline>2)` is a Syntax Error.
' See grammar/DEVICE_FACTS.md.
x = (1 +
2)
