' coverage-id: stmt.dim.paren
' expect: error
' Device-confirmed REJECTED: `dim a(n)` paren bounds -> compile error &h02
' (Syntax Error) on Roku OS 15.1.4. Dim requires square-bracket bounds:
' `dim a[n]`. The paren form (classic BASIC) is not accepted. See
' grammar/DEVICE_FACTS.md.
dim a(3) : a[0]=1
