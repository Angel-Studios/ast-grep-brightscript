' Parse-only corpus: XML parsing API (roXMLElement).
' roXMLElement does parse + run on-device, but it is held parse-only here to round
' out the standard-library surface alongside the other non-runnable component groups.
' Valid BrightScript syntax; the grammar must parse each cleanly.

' coverage-id: lib.xml.createobject
' expect: parse
xml = CreateObject("roXMLElement")

' coverage-id: lib.xml.parse
' expect: parse
ok = xml.Parse("<root><item id=""1"">a</item></root>")

' coverage-id: lib.xml.getname
' expect: parse
name = xml.GetName()

' coverage-id: lib.xml.getattributes
' expect: parse
attrs = xml.GetAttributes()

' coverage-id: lib.xml.getchildelements
' expect: parse
children = xml.GetChildElements()

' coverage-id: lib.xml.getnamedelements
' expect: parse
items = xml.GetNamedElements("item")

' coverage-id: lib.xml.gettext
' expect: parse
text = xml.GetText()
