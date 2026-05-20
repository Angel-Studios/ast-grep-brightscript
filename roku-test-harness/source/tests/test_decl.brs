' test_decl.brs - exercises every device-testable DECLARATION leaf (decl.*).
'
' Ids/kinds match grammar/coverage.json EXACTLY (one t.spec per device-testable
' decl.* leaf). Each function/sub-declaring snippet is realized as a uniquely
' named module-level helper (prefixed declh_ to avoid global-scope collisions)
' and then called from the spec.
'
' decl.library.basic is realized by the file-scope `library` directive below;
' v30/bslCore.brs ships with the firmware (duplicate imports are harmless).

library "v30/bslCore.brs"

sub test_decl_all(t as Object)
    ' --- library statement -------------------------------------------------
    t.spec("decl.library.basic", "LibraryStatement", "library ""x.brs"" import")
    ' The file-scope `library "v30/bslCore.brs"` above parsed and loaded; calling
    ' a symbol it provides proves the import resolved.
    t.assertTrue("decl.library.basic: runs", true)
    t.assertNotInvalid("decl.library.basic: bslCore symbol", bslBrightScriptErrorCodes())

    ' --- function declarations ---------------------------------------------
    t.spec("decl.function.noargs", "FunctionDeclaration", "function with no params")
    t.assertEqual("decl.function.noargs", declh_noargs(), 1)

    t.spec("decl.function.endfunction_fused", "EndFunction", "fused endfunction terminator")
    t.assertEqual("decl.function.endfunction_fused", declh_endfunction_fused(), 1)

    t.spec("decl.function.returntype", "ReturnType", "as Type return annotation")
    t.assertEqual("decl.function.returntype", declh_returntype(), 1)

    ' NOTE: decl.function.nested (nested NAMED function) is DEVICE-REJECTED
    ' (compile error &h02). Moved to corpus/negative/. See grammar/DEVICE_FACTS.md.

    ' --- sub declarations --------------------------------------------------
    t.spec("decl.sub.noargs", "SubDeclaration", "sub with no params")
    declh_sub_noargs()
    t.assertTrue("decl.sub.noargs: runs", true)

    t.spec("decl.sub.endsub_fused", "EndSub", "fused endsub terminator")
    declh_sub_endsub_fused()
    t.assertTrue("decl.sub.endsub_fused: runs", true)

    t.spec("decl.sub.returntype_void", "ReturnType", "sub with explicit as void")
    declh_sub_returntype_void()
    t.assertTrue("decl.sub.returntype_void: runs", true)

    ' --- parameters --------------------------------------------------------
    t.spec("decl.param.single", "Parameter", "one parameter, no type/default")
    t.assertTrue("decl.param.single: runs", true)
    t.assertEqual("decl.param.single value", declh_param_single(9), 9)

    t.spec("decl.param.multiple", "ParameterList", "comma-separated params")
    t.assertTrue("decl.param.multiple: runs", true)
    t.assertEqual("decl.param.multiple value", declh_param_multiple(3, 4), 7)

    t.spec("decl.param.typed", "Parameter", "param with as Type")
    t.assertTrue("decl.param.typed: runs", true)
    t.assertEqual("decl.param.typed value", declh_param_typed(11), 11)

    t.spec("decl.param.default", "Parameter", "param with default value")
    t.assertTrue("decl.param.default: runs", true)
    t.assertEqual("decl.param.default uses default", declh_param_default(), 7)
    t.assertEqual("decl.param.default override", declh_param_default(2), 2)

    t.spec("decl.param.default_and_type", "Parameter", "default then as Type (order: name = default as Type)")
    t.assertTrue("decl.param.default_and_type: runs", true)
    t.assertEqual("decl.param.default_and_type uses default", declh_param_default_and_type(), 7)
    t.assertEqual("decl.param.default_and_type override", declh_param_default_and_type(5), 5)

    ' --- declared types ----------------------------------------------------
    t.spec("decl.type.integer", "Type", "as integer")
    t.assertEqual("decl.type.integer", declh_type_integer(), 1)

    t.spec("decl.type.longinteger", "Type", "as longinteger (OS 7.0+)")
    t.assertTrue("decl.type.longinteger: runs", true)
    t.assertEqual("decl.type.longinteger value", declh_type_longinteger(), 1)

    t.spec("decl.type.float", "Type", "as float")
    t.assertTrue("decl.type.float: runs", true)
    t.assertEqual("decl.type.float value", declh_type_float(), 1.0)

    t.spec("decl.type.double", "Type", "as double")
    t.assertTrue("decl.type.double: runs", true)
    t.assertEqual("decl.type.double value", declh_type_double(), 1.0)

    t.spec("decl.type.string", "Type", "as string")
    t.assertTrue("decl.type.string: runs", true)
    t.assertEqual("decl.type.string value", declh_type_string(), "a")

    t.spec("decl.type.boolean", "Type", "as boolean")
    t.assertTrue("decl.type.boolean: runs", true)
    t.assertTrue("decl.type.boolean value", declh_type_boolean())

    t.spec("decl.type.object", "Type", "as object")
    t.assertTrue("decl.type.object: runs", true)
    t.assertEqual("decl.type.object value count", declh_type_object().count(), 0)

    t.spec("decl.type.function", "Type", "as function")
    t.assertTrue("decl.type.function: runs", true)
    fnVal = declh_type_function()
    t.assertTrue("decl.type.function returns a function", Type(fnVal) = "Function" or Type(fnVal) = "roFunction")

    ' NOTE: decl.type.interface (`as interface`) is DEVICE-REJECTED (compile error
    ' &ha7 - not an intrinsic type). Moved to corpus/negative/. See DEVICE_FACTS.md.

    t.spec("decl.type.dynamic", "Type", "as dynamic (the unconstrained default)")
    t.assertTrue("decl.type.dynamic: runs", true)
    t.assertEqual("decl.type.dynamic value", declh_type_dynamic(), 1)

    t.spec("decl.type.void", "Type", "as void")
    declh_type_void()
    t.assertTrue("decl.type.void: runs", true)

    ' NOTE: decl.type.custom (`as roSGNode`, a component/class type name) is
    ' DEVICE-REJECTED (compile error &ha7 - only intrinsic types allowed in `as`).
    ' Moved to corpus/negative/. See grammar/DEVICE_FACTS.md.
end sub

' ----- function declarations -----
function declh_noargs()
    return 1
end function

function declh_endfunction_fused()
    return 1
endfunction

function declh_returntype() as integer
    return 1
end function

' ----- sub declarations -----
sub declh_sub_noargs()
end sub

sub declh_sub_endsub_fused()
endsub

sub declh_sub_returntype_void() as void
end sub

' ----- parameters -----
function declh_param_single(a)
    return a
end function

function declh_param_multiple(a, b)
    return a + b
end function

function declh_param_typed(a as integer)
    return a
end function

function declh_param_default(a = 7)
    return a
end function

function declh_param_default_and_type(a = 7 as integer)
    return a
end function

' ----- declared types -----
function declh_type_integer() as integer
    return 1
end function

function declh_type_longinteger() as longinteger
    return 1
end function

function declh_type_float() as float
    return 1.0
end function

function declh_type_double() as double
    return 1.0
end function

function declh_type_string() as string
    return "a"
end function

function declh_type_boolean() as boolean
    return true
end function

function declh_type_object() as object
    return []
end function

function declh_type_function() as function
    return sub()
    end sub
end function

function declh_type_dynamic() as dynamic
    return 1
end function

sub declh_type_void() as void
end sub
