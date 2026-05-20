' Parse-only corpus: the ifSGNode* method surface on roSGNode.
' These run only on the SceneGraph render thread (node tree mutation, field
' observation, callFunc dispatch), so they cannot be runtime-asserted from the
' harness scope. Valid BrightScript syntax; parse-only.

' coverage-id: lib.sgnode.createchild
' expect: parse
child = node.createChild("Label")

' coverage-id: lib.sgnode.getchild
' expect: parse
first = node.getChild(0)

' coverage-id: lib.sgnode.getchildcount
' expect: parse
n = node.getChildCount()

' coverage-id: lib.sgnode.appendchild
' expect: parse
ok = node.appendChild(child)

' coverage-id: lib.sgnode.removechild
' expect: parse
ok = node.removeChild(child)

' coverage-id: lib.sgnode.getparent
' expect: parse
parent = node.getParent()

' coverage-id: lib.sgnode.findnode
' expect: parse
target = node.findNode("myButton")

' coverage-id: lib.sgnode.observefield
' expect: parse
ok = node.observeField("text", "onTextChanged")

' coverage-id: lib.sgnode.observefieldscoped
' expect: parse
ok = node.observeFieldScoped("focus", "onFocus")

' coverage-id: lib.sgnode.unobservefield
' expect: parse
ok = node.unobserveField("text")

' coverage-id: lib.sgnode.setfields
' expect: parse
node.setFields({ text: "hi", visible: true })

' coverage-id: lib.sgnode.getfields
' expect: parse
all = node.getFields()

' coverage-id: lib.sgnode.addfield
' expect: parse
ok = node.addField("count", "integer", false)

' coverage-id: lib.sgnode.addreplace
' expect: parse
node.addReplace("text", "updated")

' coverage-id: lib.sgnode.removefield
' expect: parse
ok = node.removeField("count")

' coverage-id: lib.sgnode.callfunc
' expect: parse
result = node.callFunc("doThing", arg1, arg2)

' coverage-id: lib.sgnode.issubtype
' expect: parse
yes = node.isSubtype("Group")

' coverage-id: lib.sgnode.subtype
' expect: parse
kind = node.subtype()

' coverage-id: lib.sgnode.getfieldtypes
' expect: parse
types = node.getFieldTypes()

' coverage-id: lib.sgnode.threadinfo
' expect: parse
info = node.threadinfo()

' coverage-id: lib.sgnode.clone
' expect: parse
copy = node.clone(true)

' coverage-id: lib.sgnode.update
' expect: parse
node.update({ text: "v2" }, true)
