' Parse-only corpus: networking standard-library APIs (roUrlTransfer / roUrlEvent).
' These need a live network and an event loop to exercise, so they cannot be
' runtime-asserted by the on-device harness. They are VALID BrightScript syntax;
' the future tree-sitter grammar must parse each cleanly (no ERROR nodes).
' Each API gets a coverage-id / expect:parse tag and one representative call.

' coverage-id: lib.net.createobject
' expect: parse
xfer = CreateObject("roUrlTransfer")

' coverage-id: lib.net.seturl
' expect: parse
xfer.SetUrl("https://example.com/api/data.json")

' coverage-id: lib.net.gettostring
' expect: parse
body = xfer.GetToString()

' coverage-id: lib.net.asyncgettostring
' expect: parse
ok = xfer.AsyncGetToString()

' coverage-id: lib.net.postfromstring
' expect: parse
ok = xfer.PostFromString("{""key"":""value""}")

' coverage-id: lib.net.setrequest
' expect: parse
xfer.SetRequest("POST")

' coverage-id: lib.net.addheader
' expect: parse
xfer.AddHeader("Content-Type", "application/json")

' coverage-id: lib.net.setcertificatesfile
' expect: parse
xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")

' coverage-id: lib.net.getresponseheaders
' expect: parse
headers = xfer.GetResponseHeaders()

' coverage-id: lib.net.setmessageport
' expect: parse
xfer.SetMessagePort(port)

' coverage-id: lib.net.urlevent_getresponsecode
' expect: parse
code = msg.GetResponseCode()

' coverage-id: lib.net.urlevent_getstring
' expect: parse
str = msg.GetString()

' coverage-id: lib.net.urlevent_getint
' expect: parse
kind = msg.GetInt()
