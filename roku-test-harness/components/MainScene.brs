' MainScene.brs - root Scene logic (RENDER ONLY).
'
' IMPORTANT (scope): SceneGraph component scripts do NOT see pkg:/source/**
' functions ("&h91 Function is not defined in component's namespace"; see
' grammar/DEVICE_FACTS.md). So this scene does NOT run the test suite -
' source/main.brs runs it in the Main scope, emits the ##SPEC## protocol, and
' hands the per-spec results here via the 'specResults' field. We render them as
' a terse, server-boot-log style list: one "<spec.id>" line per spec, GREEN for
' pass and RED for fail (color is the only status indicator), in columns.

sub init()
    m.title = m.top.findNode("title")
    m.summary = m.top.findNode("summary")
    m.colsGroup = m.top.findNode("cols")

    ' Small monospace font (bundled Ubuntu Mono TTF) for the terse boot-log -
    ' ~half the default size to leave room for many more specs.
    m.bodyFont = MakeFont(14)
    m.title.font = MakeFont(24)
    m.summary.font = m.bodyFont

    ' Prove the SpecShowcase loaded and its interface is reachable (component-scope
    ' callFunc, which is allowed across components).
    showcase = m.top.findNode("showcase")
    if showcase <> invalid then
        echoed = showcase.callFunc("describe", "from MainScene")
        showcase.titleText = "Spec Showcase Loaded"
        print "SpecShowcase.describe -> "; echoed
    end if
end sub

' onChange observer for 'specResults': Main sets this after running the suite.
sub onResultsChanged()
    render()
end sub

' Render the per-spec results into the three columns + the summary line.
sub render()
    specs = m.top.specResults
    if specs = invalid then return

    ' Clear any previous render (OK re-render / repeated sets).
    while m.colsGroup.getChildCount() > 0
        m.colsGroup.removeChildIndex(0)
    end while

    total = specs.count()
    if total = 0 then return

    ' Fill each column down to the bottom of the screen (~55 rows at 14px on a
    ' 1080 canvas), then start a new column to the right.
    rowsPerCol = 55
    passed = 0
    i = 0
    col = invalid
    for each sp in specs
        if i mod rowsPerCol = 0 then
            col = m.colsGroup.createChild("LayoutGroup")
            col.layoutDirection = "vert"
            col.itemSpacings = [1]
        end if

        ok = sp.passed
        if ok then passed = passed + 1

        ' Color IS the pass/fail indicator (green/red) - no "[ ok ]/[FAIL]"
        ' prefix needed. Failing rows still append the failure detail.
        rowColor = "0x6FCF6FFF"       ' green = pass
        if not ok then rowColor = "0xE05555FF"   ' red = fail

        line = sp.id
        if not ok and sp.detail <> "" then line = line + "  " + sp.detail

        row = col.createChild("Label")
        row.font = m.bodyFont
        row.width = 290
        row.wrap = false
        row.text = line
        row.color = rowColor
        i = i + 1
    end for

    failed = total - passed
    m.summary.text = passed.ToStr() + " ok   " + failed.ToStr() + " fail   (" + total.ToStr() + " specs)"
    if failed = 0 then
        m.summary.color = "0x6FCF6FFF"
    else
        m.summary.color = "0xE05555FF"
    end if
end sub

' Interface <function name="rerunTests"/>: re-render the last results (the suite
' itself cannot be re-run from component scope).
function rerunTests() as Boolean
    render()
    return true
end function

' OK re-renders; everything else propagates.
function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "OK" then
        render()
        return true
    end if
    return false
end function

' Build a Font node from the bundled Ubuntu Mono TTF at the given pixel size.
function MakeFont(sz as Integer) as Object
    f = CreateObject("roSGNode", "Font")
    f.uri = "pkg:/fonts/UbuntuMono-Regular.ttf"
    f.size = sz
    return f
end function
