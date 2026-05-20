' coverage-id: decl.function.nested
' expect: error
' Device-confirmed REJECTED: nested named function declaration -> compile error
' &h02 (Syntax Error) on Roku OS 15.1.4. BrightScript functions must be declared
' at the top level of a file; a function declared inside another function is a
' syntax error. See grammar/DEVICE_FACTS.md. (Anonymous function VALUES assigned
' to variables inside a function are fine; a nested NAMED declaration is not.)
function f()
function g()
return 2
end function
return g()
end function
