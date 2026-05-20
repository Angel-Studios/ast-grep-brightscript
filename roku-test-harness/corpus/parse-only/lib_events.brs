' Parse-only corpus: event/message-port APIs (roMessagePort, wait(), event types).
' These require a running event loop and asynchronous device events, so they cannot
' be runtime-asserted in the harness. Valid BrightScript syntax; parse-only.

' coverage-id: lib.events.port_createobject
' expect: parse
port = CreateObject("roMessagePort")

' coverage-id: lib.events.port_waitmessage
' expect: parse
msg = port.WaitMessage(0)

' coverage-id: lib.events.port_getmessage
' expect: parse
msg = port.GetMessage()

' coverage-id: lib.events.port_peekmessage
' expect: parse
msg = port.PeekMessage()

' coverage-id: lib.events.wait
' expect: parse
msg = wait(500, port)

' coverage-id: lib.events.deviceinfoevent
' expect: parse
info = msg.GetInfo()
