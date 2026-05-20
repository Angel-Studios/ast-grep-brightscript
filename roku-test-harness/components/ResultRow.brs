' ResultRow.brs - logic for one MarkupList row.
'
' The MarkupList sets width/height (from itemSize), itemContent (this row's
' ContentNode), and itemHasFocus on each visible instance. We size the children
' to the cell, fill in the text, and - the whole point - color the label GREEN
' for a passing assertion and RED for a failing one.

sub init()
    m.focusBg = m.top.findNode("focusBg")
    m.rowLabel = m.top.findNode("rowLabel")
end sub

' Resize the children to fill whatever cell size the list assigned.
sub onLayoutChanged()
    w = m.top.width
    h = m.top.height
    m.focusBg.width = w
    m.focusBg.height = h
    ' Label is inset 12px on the left (see its translation in the XML).
    m.rowLabel.width = w - 24
    m.rowLabel.height = h
end sub

' Populate AND color this row from its content node. content.passed drives the
' GREEN (0x00FF00FF) / RED (0xFF0000FF) color - the core harness behavior.
sub onItemContentChanged()
    content = m.top.itemContent
    if content = invalid then return

    m.rowLabel.text = content.text
    if content.passed then
        m.rowLabel.color = "0x00FF00FF"   ' GREEN = pass
    else
        m.rowLabel.color = "0xFF0000FF"   ' RED   = fail
    end if
end sub

' Show the focus highlight only on the currently focused row.
sub onFocusChanged()
    m.focusBg.visible = m.top.itemHasFocus
end sub
