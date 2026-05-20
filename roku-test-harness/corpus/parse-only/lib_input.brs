' Parse-only corpus: input / channel-store APIs (roInput, roChannelStore).
' These need external input events or a billing/store backend and an event loop, so
' they cannot be runtime-asserted in the harness. Valid BrightScript syntax; parse-only.

' coverage-id: lib.input.createobject
' expect: parse
input = CreateObject("roInput")

' coverage-id: lib.input.setmessageport
' expect: parse
input.SetMessagePort(port)

' coverage-id: lib.input.eventinfo
' expect: parse
info = msg.GetInfo()

' coverage-id: lib.input.channelstore_createobject
' expect: parse
store = CreateObject("roChannelStore")

' coverage-id: lib.input.channelstore_getcatalog
' expect: parse
store.GetCatalog()

' coverage-id: lib.input.channelstore_getpurchases
' expect: parse
store.GetPurchases()

' coverage-id: lib.input.channelstore_doorder
' expect: parse
ok = store.DoOrder()
