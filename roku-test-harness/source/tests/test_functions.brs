' test_functions.brs - exercises function / sub declaration surface.
'
' function vs sub, typed params (as Type), optional params with defaults, return
' types, recursion, anonymous / inline function values, passing functions as
' values, and a variadic-ish (array-of-args) pattern.

sub test_functions_all(t as Object)
    ' --- Typed params + return type ----------------------------------------
    t.spec("decl.function.typed", "FunctionDeclaration", "function with typed params and 'as' return type")
    t.assertEqual("fn: typed add", add(3, 4), 7)
    t.assertType("fn: typed return type", add(1, 1), "Integer")

    ' --- Optional params with defaults -------------------------------------
    t.spec("decl.parameter.optional", "Parameter", "optional parameters with default values")
    t.assertEqual("fn: default both args", greet(), "Hello, World")
    t.assertEqual("fn: default second arg", greet("Hi"), "Hi, World")
    t.assertEqual("fn: both args supplied", greet("Hey", "Roku"), "Hey, Roku")

    ' --- Recursion ---------------------------------------------------------
    t.spec("decl.function.recursion", "FunctionDeclaration", "recursive function calls")
    t.assertEqual("fn: factorial recursion", factorial(5), 120)
    t.assertEqual("fn: fib recursion", fib(10), 55)

    ' --- Anonymous / inline function value ---------------------------------
    t.spec("expr.anon_function", "AnonFunctionExpr", "anonymous function expression value")
    square = function(n as Integer) as Integer
        return n * n
    end function
    t.assertEqual("fn: anonymous function value", square(9), 81)

    ' Anonymous sub value (Void return).
    t.spec("expr.anon_sub", "AnonSubExpr", "anonymous sub expression value")
    sideEffect = []
    appender = sub(arr as Object, v as Dynamic)
        arr.push(v)
    end sub
    appender(sideEffect, "x")
    t.assertEqual("fn: anonymous sub value", sideEffect.count(), 1)

    ' --- Passing functions as values (higher-order) ------------------------
    t.spec("decl.function.higher_order", "FunctionDeclaration", "functions passed as first-class values")
    nums = [1, 2, 3, 4]
    doubled = mapArray(nums, function(v as Integer) as Integer
        return v * 2
    end function)
    t.assertEqual("fn: map with function arg", doubled, [2, 4, 6, 8])

    ' Pass a named function by reference.
    t.assertEqual("fn: map with named fn ref", mapArray([1, 2, 3], negate), [-1, -2, -3])

    ' --- Variadic-ish: collect args into an array --------------------------
    t.spec("decl.sub", "SubDeclaration", "sub declaration with array parameter")
    t.assertEqual("fn: sumAll variadic-ish", sumAll([10, 20, 30, 40]), 100)

    ' --- Function type check -----------------------------------------------
    ' Type() of a function value reports "Function" or "roFunction" depending on
    ' boxing; accept either spelling.
    t.spec("type.function_value", "ReturnType", "Type() of a function value")
    fnVal = add
    fnType = Type(fnVal)
    t.assertTrue("fn: function value type", fnType = "Function" or fnType = "roFunction")
end sub

function add(a as Integer, b as Integer) as Integer
    return a + b
end function

' Optional parameters with default values (defaults must trail required params).
function greet(salutation = "Hello" as String, name = "World" as String) as String
    return salutation + ", " + name
end function

function factorial(n as Integer) as Integer
    if n <= 1 then return 1
    return n * factorial(n - 1)
end function

function fib(n as Integer) as Integer
    if n < 2 then return n
    return fib(n - 1) + fib(n - 2)
end function

function negate(v as Integer) as Integer
    return -v
end function

' Higher-order: applies a Function value to each element.
function mapArray(arr as Object, fn as Function) as Object
    out = []
    for each el in arr
        out.push(fn(el))
    end for
    return out
end function

' Variadic-ish: a single array parameter stands in for varargs.
function sumAll(args as Object) as Integer
    total = 0
    for each a in args
        total = total + a
    end for
    return total
end function
