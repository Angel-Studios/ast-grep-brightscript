' coverage-id: stmt.expr.optcall
' expect: error
' Device-confirmed REJECTED: an optional-call `?()` as a bare expression-STATEMENT
' -> compile error &h02 (Syntax Error) on Roku OS 15.1.4. Optional chaining with
' `?()` is accepted in EXPRESSION position (e.g. `y = f?()`), but a trailing
' optional-call used as a standalone statement is not. See grammar/DEVICE_FACTS.md.
m.fn?()
