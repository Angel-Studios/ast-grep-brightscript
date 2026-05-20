' SpecShowcase.brs - implements the SpecShowcase component.
'
' Provides init(), the two interface functions declared in the XML
' (describe / resetState, callable via callFunc), and the onChange observer
' onTitleTextChanged for the titleText field.

sub init()
    ' Cache references to the declared child nodes.
    m.bgRect = m.top.findNode("bgRect")
    m.caption = m.top.findNode("captionLabel")

    ' Initialize a few of the non-value-defaulted fields with real objects so
    ' their declared types are exercised at runtime.
    m.top.assocField = { populated: true, label: "spec" }
    m.top.genericArray = ["x", 1, true]
    m.top.roArrayField = CreateObject("roArray", 2, true)
    m.top.roArrayField.push("a")

    ' nodeField holds a node reference.
    childNode = CreateObject("roSGNode", "Label")
    childNode.text = "node-field-target"
    m.top.nodeField = childNode

    ' Keep the caption in sync with the (aliased / observed) title text.
    m.top.titleText = "SpecShowcase " + showcaseVersionTag()
end sub

' Interface <function name="describe"/>: returns a description string. Exercises
' a typed parameter and an 'as String' return type; callable via callFunc().
function describe(note as String) as String
    summary = showcaseVersionTag() + " [" + note + "]"
    summary = summary + " intField=" + StrI(m.top.intField).Trim()
    summary = summary + " bool=" + boolToStr(m.top.boolField)
    return summary
end function

' Interface <function name="resetState"/>: resets a couple of fields. Returns the
' new title for convenience.
function resetState() as String
    m.top.intField = 0
    m.top.titleText = "reset"
    return m.top.titleText
end function

' onChange observer for titleText (declared with onChange + alwaysNotify in XML).
sub onTitleTextChanged()
    if m.caption <> invalid then
        m.caption.text = m.top.titleText
    end if
    print "SpecShowcase.titleText -> "; m.top.titleText
end sub

' Version tag helper. Defined in this component script (not the inline <script>)
' so describe()/init() resolve it under BrighterScript.
function showcaseVersionTag() as String
    return "SpecShowcase/1.0"
end function

function boolToStr(b as Boolean) as String
    if b then return "true" else return "false"
end function
