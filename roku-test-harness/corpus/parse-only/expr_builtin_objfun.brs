' coverage-id: expr.builtin.objfun
' expect: parse
' Valid call syntax (a reserved built-in), but not safely runtime-assertable in
' the harness: objfun(object, functionName, ...) invokes a function value bound to
' an object. Parses as a BuiltinCall; kept here as a positive-parse corpus item.
r = objfun(o, "f")
