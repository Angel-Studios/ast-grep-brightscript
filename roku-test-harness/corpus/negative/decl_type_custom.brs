' coverage-id: decl.type.custom
' expect: error
' Device-confirmed REJECTED: a component/class type name (e.g. roSGNode) in an
' `as <Type>` annotation -> compile error &ha7 on Roku OS 15.1.4. Only the
' intrinsic type set is accepted in `as` clauses; custom/component type names are
' not (that is a BrighterScript transpile-time feature, not device BrightScript).
' See grammar/DEVICE_FACTS.md.
sub f(n as roSGNode)
end sub
