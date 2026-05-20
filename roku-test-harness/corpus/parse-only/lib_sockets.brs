' Parse-only corpus: TCP socket APIs (roStreamSocket, roSocketAddress).
' These need a real network peer and an event loop, so they cannot be
' runtime-asserted in the harness. Valid BrightScript syntax; parse-only.

' coverage-id: lib.sockets.stream_createobject
' expect: parse
sock = CreateObject("roStreamSocket")

' coverage-id: lib.sockets.addr_createobject
' expect: parse
addr = CreateObject("roSocketAddress")

' coverage-id: lib.sockets.setmessageport
' expect: parse
sock.SetMessagePort(port)

' coverage-id: lib.sockets.send
' expect: parse
sent = sock.Send(ba, 0, ba.Count())

' coverage-id: lib.sockets.receive
' expect: parse
got = sock.Receive(ba, 0, 1024)

' coverage-id: lib.sockets.connect
' expect: parse
ok = sock.Connect()

' coverage-id: lib.sockets.listen
' expect: parse
ok = sock.Listen(5)

' coverage-id: lib.sockets.bindtolocaladdress
' expect: parse
ok = sock.BindToLocalAddress(addr)
