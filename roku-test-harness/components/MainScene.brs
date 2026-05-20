' MainScene.brs - root Scene logic (RENDER ONLY).
'
' IMPORTANT (scope): SceneGraph component scripts do NOT see pkg:/source/**
' functions ("&h91 Function is not defined in component's namespace"; see
' grammar/DEVICE_FACTS.md). So this scene does NOT run the test suite -
' source/main.brs runs it in the Main scope, emits the ##SPEC## protocol, and
' hands the per-spec results here via the 'specResults' field. We render them as
' a terse, server-boot-log style list: one "[ ok ]/[FAIL] <spec.id>" line per
' spec, GREEN for pass and RED for fail, in three columns.

sub init()
    m.title = m.top.findNode("title")
    m.summary = m.top.findNode("summary")
    m.cols = [m.top.findNode("col0"), m.top.findNode("col1"), m.top.findNode("col2")]

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
    for each c in m.cols
        while c.getChildCount() > 0
            c.removeChildIndex(0)
        end while
    end for

    total = specs.count()
    if total = 0 then return
    perCol = (total + 2) \ 3          ' integer divide, rounded up: 3 balanced columns

    passed = 0
    i = 0
    for each sp in specs
        ok = sp.passed
        if ok then passed = passed + 1

        mark = "[ ok ]"
        rowColor = "0x6FCF6FFF"       ' green
        if not ok then
            mark = "[FAIL]"
            rowColor = "0xE05555FF"   ' red
        end if

        line = mark + " " + sp.id
        if not ok and sp.detail <> "" then line = line + "  " + sp.detail

        idx = i \ perCol
        if idx > 2 then idx = 2
        row = m.cols[idx].createChild("Label")
        row.width = 600
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
