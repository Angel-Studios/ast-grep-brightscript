' Parse-only corpus: legacy AV component APIs (roVideoPlayer / roAudioPlayer + events).
' In modern SceneGraph these are the Video/Audio NODES, but the legacy component
' APIs still parse. They need real AV content + an event loop + (for video) a screen,
' so they cannot be runtime-asserted here. Valid BrightScript syntax; parse-only.

' coverage-id: lib.av.video_createobject
' expect: parse
player = CreateObject("roVideoPlayer")

' coverage-id: lib.av.video_setcontentlist
' expect: parse
player.SetContentList(contentList)

' coverage-id: lib.av.video_play
' expect: parse
player.Play()

' coverage-id: lib.av.video_stop
' expect: parse
player.Stop()

' coverage-id: lib.av.video_pause
' expect: parse
player.Pause()

' coverage-id: lib.av.video_resume
' expect: parse
player.Resume()

' coverage-id: lib.av.video_seek
' expect: parse
player.Seek(30000)

' coverage-id: lib.av.video_setloop
' expect: parse
player.SetLoop(true)

' coverage-id: lib.av.audio_createobject
' expect: parse
audio = CreateObject("roAudioPlayer")

' coverage-id: lib.av.audio_play
' expect: parse
audio.Play()

' coverage-id: lib.av.event_gettype
' expect: parse
t = msg.GetType()

' coverage-id: lib.av.event_getindex
' expect: parse
idx = msg.GetIndex()

' coverage-id: lib.av.event_getmessage
' expect: parse
m = msg.GetMessage()
