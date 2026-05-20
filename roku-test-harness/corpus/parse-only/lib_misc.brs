' Parse-only corpus: assorted system components that need device facilities the
' harness can't assert (system log sink, AV metadata files, CEC/HDMI bus state,
' the app/theme manager). roRegistry is already runnable and is intentionally
' excluded. Valid BrightScript syntax; parse-only.

' coverage-id: lib.misc.systemlog_createobject
' expect: parse
syslog = CreateObject("roSystemLog")

' coverage-id: lib.misc.systemlog_enabletype
' expect: parse
syslog.EnableType("http.error")

' coverage-id: lib.misc.audiometadata_createobject
' expect: parse
audioMeta = CreateObject("roAudioMetadata")

' coverage-id: lib.misc.audiometadata_gettags
' expect: parse
tags = audioMeta.GetTags()

' coverage-id: lib.misc.imagemetadata_createobject
' expect: parse
imgMeta = CreateObject("roImageMetadata")

' coverage-id: lib.misc.imagemetadata_getmetadata
' expect: parse
meta = imgMeta.GetMetadata()

' coverage-id: lib.misc.cecstatus_createobject
' expect: parse
cec = CreateObject("roCECStatus")

' coverage-id: lib.misc.cecstatus_isactivesource
' expect: parse
active = cec.IsActiveSource()

' coverage-id: lib.misc.hdmistatus_createobject
' expect: parse
hdmi = CreateObject("roHdmiStatus")

' coverage-id: lib.misc.hdmistatus_isconnected
' expect: parse
connected = hdmi.IsConnected()

' coverage-id: lib.misc.appmanager_createobject
' expect: parse
appMgr = CreateObject("roAppManager")

' coverage-id: lib.misc.appmanager_getuptime
' expect: parse
uptime = appMgr.GetUpTime()

' coverage-id: lib.misc.appmanager_settheme
' expect: parse
appMgr.SetTheme(theme)
