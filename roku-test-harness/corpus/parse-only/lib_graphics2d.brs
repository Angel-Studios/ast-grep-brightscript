' Parse-only corpus: legacy Roku 2D graphics API (roScreen, roBitmap, roRegion,
' roCompositor, roSprite, roFontRegistry, roTextureManager / roTextureRequest).
' These need the legacy 2D draw surface (a full-screen roScreen and its render loop),
' which a SceneGraph harness does not own, so they cannot be runtime-asserted here.
' Valid BrightScript syntax; parse-only.

' coverage-id: lib.graphics2d.screen_createobject
' expect: parse
screen = CreateObject("roScreen", true, 1280, 720)

' coverage-id: lib.graphics2d.screen_drawrect
' expect: parse
screen.DrawRect(0, 0, 100, 50, &hFF0000FF)

' coverage-id: lib.graphics2d.screen_swapbuffers
' expect: parse
screen.SwapBuffers()

' coverage-id: lib.graphics2d.bitmap_createobject
' expect: parse
bmp = CreateObject("roBitmap", "pkg:/images/logo.png")

' coverage-id: lib.graphics2d.bitmap_drawobject
' expect: parse
screen.DrawObject(0, 0, bmp)

' coverage-id: lib.graphics2d.region_createobject
' expect: parse
region = CreateObject("roRegion", bmp, 0, 0, 64, 64)

' coverage-id: lib.graphics2d.region_offset
' expect: parse
region.Offset(8, 0, 0, 0)

' coverage-id: lib.graphics2d.compositor_createobject
' expect: parse
compositor = CreateObject("roCompositor")

' coverage-id: lib.graphics2d.compositor_setdrawto
' expect: parse
compositor.SetDrawTo(screen, &h000000FF)

' coverage-id: lib.graphics2d.compositor_newsprite
' expect: parse
sprite = compositor.NewSprite(0, 0, region)

' coverage-id: lib.graphics2d.sprite_moveto
' expect: parse
sprite.MoveTo(100, 100)

' coverage-id: lib.graphics2d.compositor_draw
' expect: parse
compositor.Draw()

' coverage-id: lib.graphics2d.fontregistry_createobject
' expect: parse
fonts = CreateObject("roFontRegistry")

' coverage-id: lib.graphics2d.fontregistry_getdefaultfont
' expect: parse
font = fonts.GetDefaultFont(28, false, false)

' coverage-id: lib.graphics2d.texturemanager_createobject
' expect: parse
tm = CreateObject("roTextureManager")

' coverage-id: lib.graphics2d.texturerequest_createobject
' expect: parse
req = CreateObject("roTextureRequest", "pkg:/images/poster.jpg")

' coverage-id: lib.graphics2d.texturemanager_requesttexture
' expect: parse
tm.RequestTexture(req)
