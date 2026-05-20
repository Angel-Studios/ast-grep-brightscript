' coverage-id: decl.type.interface
' expect: error
' Device-confirmed REJECTED: `as interface` type annotation -> compile error
' &ha7 on Roku OS 15.1.4. The device validates `as <Type>` against the intrinsic
' type set (Boolean/Integer/LongInteger/Float/Double/String/Object/Dynamic/Void/
' Function); "interface" is not a valid declared type. See grammar/DEVICE_FACTS.md.
sub f(x as interface)
end sub
