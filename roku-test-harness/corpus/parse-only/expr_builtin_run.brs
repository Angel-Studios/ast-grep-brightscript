' coverage-id: expr.builtin.run
' expect: parse
' Valid call syntax (a reserved built-in), but not safely runtime-assertable in
' the harness: run("pkg:/...") compiles and executes a separate .brs file. Parses
' as a BuiltinCall; kept here as a positive-parse corpus item (running a real file
' would be a side effect, so it is not exercised on-device).
run("pkg:/source/x.brs")
