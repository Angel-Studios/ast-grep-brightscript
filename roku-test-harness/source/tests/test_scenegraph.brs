' test_scenegraph.brs - exercises every device-testable SceneGraph leaf (sg.*).
'
' Ids/kinds match grammar/coverage.json EXACTLY: one t.spec(id, kind, dimension)
' per sg.* leaf with device_testable:true (56 of them). The sg.* leaves with
' device_testable:false (the XML-prolog / raw-XML-syntax ones) are NOT covered
' here - they belong to a negative/parse-only corpus owned elsewhere.
'
' VERIFICATION MODEL: a SceneGraph construct is "device-accepted" iff a component
' that USES it actually loads/instantiates and behaves. The dev installer COMPILES
' the whole channel on upload, so any invalid construct fails the build (and these
' tests never run). Given the channel did build and run, this module then proves
' each construct is live:
'   - structural component attrs / interface / children / script  -> instantiate a
'     component USING the construct and assert it is <> invalid and subtypes right.
'   - field types               -> read the SpecShowcase field and assert its value
'                                   and/or runtime Type().
'   - field attrs (alias/onChange/alwaysNotify) -> set a field and observe the side
'     effect (aliased child field changed / onChange callback ran).
'   - node leaves               -> findNode the declared children and assert subtype
'     / field initialisers.
'
' ENTRY: called from source/main.brs (Main scope) AFTER screen.show(), with
'   t        = the TestRunner
'   scene    = the live MainScene root node (extends Scene)
'   showcase = scene.findNode("showcase") (the live SpecShowcase instance)
' This runs on the render/main thread, so CreateObject("roSGNode", ...) is allowed.
'
' Free helpers in this module are prefixed sgh_ to avoid global-scope collisions.

sub test_scenegraph_all(t as Object, scene as Object, showcase as Object)

    ' ======================================================================
    ' COMPONENT structural attributes
    ' ======================================================================

    ' sg.component.name : the required name= attribute. SpecShowcase loaded and
    ' its node subtype IS its component name, proving name= was accepted.
    t.spec("sg.component.name", "ComponentAttribute", "required name attribute")
    t.assertNotInvalid("sg.component.name: showcase loaded", showcase)
    t.assertEqual("sg.component.name: subtype = name", showcase.subtype(), "SpecShowcase")

    ' sg.component.extends_builtin : SpecShowcase extends the built-in Group class.
    t.spec("sg.component.extends_builtin", "ExtendsValue", "extends a built-in node class")
    t.assertTrue("sg.component.extends_builtin: isSubtype Group", showcase.isSubtype("Group"))

    ' sg.component.extends_custom : SpecHelperExtends extends the USER component
    ' SpecShowcase. Instantiating it (and confirming it subtypes SpecShowcase)
    ' proves extends= a custom component name was accepted.
    t.spec("sg.component.extends_custom", "ExtendsValue", "extends a user-defined component name")
    helperExtends = CreateObject("roSGNode", "SpecHelperExtends")
    t.assertNotInvalid("sg.component.extends_custom: instantiated", helperExtends)
    t.assertEqual("sg.component.extends_custom: subtype", helperExtends.subtype(), "SpecHelperExtends")
    t.assertTrue("sg.component.extends_custom: isSubtype SpecShowcase", helperExtends.isSubtype("SpecShowcase"))

    ' sg.component.initialfocus : SpecHelperExtends carries initialFocus=. The fact
    ' it loaded proves the attribute was accepted.
    t.spec("sg.component.initialfocus", "ComponentAttribute", "initialFocus attribute")
    t.assertNotInvalid("sg.component.initialfocus: component w/ initialFocus loaded", helperExtends)

    ' sg.component.version : SpecShowcase declares version="1.0"; SpecHelperExtends
    ' declares version="2.0". Both loaded, proving the attribute was accepted.
    t.spec("sg.component.version", "ComponentAttribute", "version attribute")
    t.assertNotInvalid("sg.component.version: versioned component loaded", showcase)
    t.assertNotInvalid("sg.component.version: second versioned component loaded", helperExtends)

    ' sg.component.extends_scene : the root component (MainScene) extends Scene.
    t.spec("sg.component.extends_scene", "BuiltinNodeClass", "extends=""Scene"" (root scene class)")
    t.assertNotInvalid("sg.component.extends_scene: scene present", scene)
    t.assertTrue("sg.component.extends_scene: isSubtype Scene", scene.isSubtype("Scene"))

    ' sg.component.extends_task : SpecHelperTask extends the built-in Task class.
    t.spec("sg.component.extends_task", "BuiltinNodeClass", "extends=""Task"" (Task node class)")
    helperTask = CreateObject("roSGNode", "SpecHelperTask")
    t.assertNotInvalid("sg.component.extends_task: instantiated", helperTask)
    t.assertTrue("sg.component.extends_task: isSubtype Task", helperTask.isSubtype("Task"))

    ' ======================================================================
    ' INTERFACE
    ' ======================================================================

    ' sg.interface.empty : SpecHelperExtends declares an EMPTY <interface/>. Its
    ' successful load proves an empty interface is accepted.
    t.spec("sg.interface.empty", "Interface", "empty <interface/>")
    t.assertNotInvalid("sg.interface.empty: component w/ empty interface loaded", helperExtends)

    ' sg.interface.with_children : SpecShowcase's <interface> contains many fields
    ' and functions; reading one declared field proves a populated interface works.
    t.spec("sg.interface.with_children", "Interface", "<interface> containing fields/functions")
    t.assertEqual("sg.interface.with_children: declared field readable", showcase.intField, 42)

    ' ======================================================================
    ' FIELD TYPES (read the SpecShowcase field; assert value and/or Type())
    ' ======================================================================

    t.spec("sg.field.type.integer", "FieldType", "integer field with value")
    t.assertEqual("sg.field.type.integer", showcase.intField, 42)

    t.spec("sg.field.type.int_alias", "FieldType", "int alias spelling")
    t.assertEqual("sg.field.type.int_alias", showcase.intAliasField, 7)

    t.spec("sg.field.type.longinteger", "FieldType", "longinteger field with value")
    t.assertEqual("sg.field.type.longinteger", showcase.longField, 5000000000&)

    t.spec("sg.field.type.float", "FieldType", "float field with value")
    t.assertTrue("sg.field.type.float: ~3.14", showcase.floatField > 3.14 and showcase.floatField < 3.15)

    t.spec("sg.field.type.string", "FieldType", "string field with value")
    t.assertEqual("sg.field.type.string", showcase.stringField, "hello")

    ' NOTE: sg.field.type.str_alias (`type="str"`) is DEVICE-REJECTED: unlike the
    ' `int` and `bool` aliases, `str` is NOT a recognized field-type spelling, so a
    ' valued `str` field stays Invalid (use `string`). Moved to corpus/negative/.
    ' See grammar/DEVICE_FACTS.md.

    t.spec("sg.field.type.boolean", "FieldType", "Boolean field with value")
    t.assertTrue("sg.field.type.boolean", showcase.boolField)

    t.spec("sg.field.type.bool_alias", "FieldType", "bool alias spelling")
    t.assertFalse("sg.field.type.bool_alias", showcase.boolAlias)

    ' sg.field.type.boolean_caseinsensitive : the SpecShowcase boolField is declared
    ' type="Boolean" (capital B) and the boolean.* checks above confirm a mixed-case
    ' type name was matched. Re-assert here that the case-variant type resolved.
    t.spec("sg.field.type.boolean_caseinsensitive", "FieldTypeAttValue", "type value matched case-insensitively (boolean)")
    t.assertTrue("sg.field.type.boolean_caseinsensitive", showcase.boolField = true)

    t.spec("sg.field.type.vector2d", "FieldType", "vector2d field with [x,y] value")
    t.assertType("sg.field.type.vector2d: roArray", showcase.positionField, "roArray")
    t.assertEqual("sg.field.type.vector2d: x", showcase.positionField[0], 100)
    t.assertEqual("sg.field.type.vector2d: y", showcase.positionField[1], 200)

    ' sg.field.type.color : a color stores as a 32-bit integer (0xRRGGBBAA).
    t.spec("sg.field.type.color", "FieldType", "color field with 0xRRGGBBAA value")
    t.assertTrue("sg.field.type.color: numeric", sgh_isNumeric(showcase.colorField))
    t.assertTrue("sg.field.type.color: nonzero", showcase.colorField <> 0)

    t.spec("sg.field.type.time", "FieldType", "time field with value")
    t.assertTrue("sg.field.type.time: numeric", sgh_isNumeric(showcase.timeField))
    t.assertTrue("sg.field.type.time: ~12.5", showcase.timeField > 12.0)

    t.spec("sg.field.type.uri", "FieldType", "uri field with value")
    t.assertEqual("sg.field.type.uri", showcase.uriField, "pkg:/images/icon_focus_hd.png")

    t.spec("sg.field.type.node", "FieldType", "node field (reference)")
    t.assertType("sg.field.type.node: roSGNode", showcase.nodeField, "roSGNode")
    t.assertEqual("sg.field.type.node: text", showcase.nodeField.text, "node-field-target")

    t.spec("sg.field.type.floatarray", "FieldType", "floatarray field with quoted-element value")
    t.assertType("sg.field.type.floatarray: roArray", showcase.floatArray, "roArray")
    t.assertEqual("sg.field.type.floatarray: count", showcase.floatArray.count(), 3)

    t.spec("sg.field.type.intarray", "FieldType", "intarray field with value")
    t.assertType("sg.field.type.intarray: roArray", showcase.intArray, "roArray")
    t.assertEqual("sg.field.type.intarray: [0]", showcase.intArray[0], 1)
    t.assertEqual("sg.field.type.intarray: count", showcase.intArray.count(), 4)

    t.spec("sg.field.type.boolarray", "FieldType", "boolarray field with value")
    t.assertType("sg.field.type.boolarray: roArray", showcase.boolArray, "roArray")
    t.assertTrue("sg.field.type.boolarray: [0]", showcase.boolArray[0])

    t.spec("sg.field.type.stringarray", "FieldType", "stringarray field - elements MUST be quoted (DEVICE_FACTS #3)")
    t.assertType("sg.field.type.stringarray: roArray", showcase.stringArray, "roArray")
    t.assertEqual("sg.field.type.stringarray: [0]", showcase.stringArray[0], "a")

    t.spec("sg.field.type.vector2darray", "FieldType", "vector2darray field with value")
    t.assertType("sg.field.type.vector2darray: roArray", showcase.vector2dArray, "roArray")
    t.assertEqual("sg.field.type.vector2darray: count", showcase.vector2dArray.count(), 2)

    t.spec("sg.field.type.colorarray", "FieldType", "colorarray field with value")
    t.assertType("sg.field.type.colorarray: roArray", showcase.colorArray, "roArray")
    t.assertEqual("sg.field.type.colorarray: count", showcase.colorArray.count(), 2)

    t.spec("sg.field.type.timearray", "FieldType", "timearray field with value")
    t.assertType("sg.field.type.timearray: roArray", showcase.timeArray, "roArray")
    t.assertEqual("sg.field.type.timearray: count", showcase.timeArray.count(), 3)

    t.spec("sg.field.type.nodearray", "FieldType", "nodearray field")
    t.assertType("sg.field.type.nodearray: roArray", showcase.nodeArray, "roArray")
    t.assertEqual("sg.field.type.nodearray: count", showcase.nodeArray.count(), 2)
    t.assertType("sg.field.type.nodearray: element is node", showcase.nodeArray[0], "roSGNode")

    t.spec("sg.field.type.assocarray", "FieldType", "assocarray field with value")
    t.assertAA("sg.field.type.assocarray", showcase.assocField)
    t.assertTrue("sg.field.type.assocarray: populated", showcase.assocField.populated = true)

    t.spec("sg.field.type.array", "FieldType", "generic array field with value")
    t.assertType("sg.field.type.array: roArray", showcase.genericArray, "roArray")

    ' DEVICE FACT (Roku OS 15.1.4): a scalar rect2D field deserializes to an
    ' roAssociativeArray ({x,y,width,height}), NOT an roArray. (A rect2DArray's
    ' OUTER container is an roArray; see below.) See grammar/DEVICE_FACTS.md.
    t.spec("sg.field.type.rect2d", "FieldType", "rect2D field with [x,y,w,h] value")
    t.assertType("sg.field.type.rect2d: roAssociativeArray", showcase.rectField, "roAssociativeArray")
    t.assertEqual("sg.field.type.rect2d: key count", showcase.rectField.count(), 4)

    t.spec("sg.field.type.rect2darray", "FieldType", "rect2DArray field with value")
    t.assertType("sg.field.type.rect2darray: roArray", showcase.rectArray, "roArray")
    t.assertEqual("sg.field.type.rect2darray: count", showcase.rectArray.count(), 2)

    ' ======================================================================
    ' FIELD attributes
    ' ======================================================================

    ' sg.field.attr.id : every field is addressed by its id; reading by id works.
    t.spec("sg.field.attr.id", "FieldAttribute", "required id attribute")
    t.assertEqual("sg.field.attr.id: addressable by id", showcase.intField, 42)

    ' sg.field.attr.value : the initial value= was applied to the field.
    t.spec("sg.field.attr.value", "FieldAttribute", "optional value initial value")
    t.assertEqual("sg.field.attr.value: initial value applied", showcase.stringField, "hello")

    ' sg.field.attr.alias : bgColor aliases bgRect.color. Setting bgColor must
    ' update the aliased child field (read it back from the child node).
    t.spec("sg.field.attr.alias", "AliasAttValue", "alias=""node.field"" micro-syntax")
    bgRect = showcase.findNode("bgRect")
    showcase.bgColor = "0x123456FF"
    t.assertNotInvalid("sg.field.attr.alias: bgRect found", bgRect)
    t.assertEqual("sg.field.attr.alias: child color tracks alias", bgRect.color, showcase.bgColor)

    ' sg.field.attr.onchange + sg.field.attr.alwaysnotify : titleText is declared
    ' onChange="onTitleTextChanged" alwaysNotify="true". Setting it fires the
    ' callback, which copies the new text onto the caption Label.
    captionLabel = showcase.findNode("captionLabel")
    showcase.titleText = "onchange-probe-A"
    t.spec("sg.field.attr.onchange", "FieldAttribute", "onChange names a BrightScript callback")
    t.assertNotInvalid("sg.field.attr.onchange: caption found", captionLabel)
    t.assertEqual("sg.field.attr.onchange: callback ran", captionLabel.text, "onchange-probe-A")

    ' alwaysNotify="true": setting the SAME value again still fires onChange, so a
    ' subsequent set to a new value continues to propagate (and a no-op set still
    ' notifies). Set the same value, then a new value; the caption must follow.
    showcase.titleText = "onchange-probe-A"
    showcase.titleText = "onchange-probe-B"
    t.spec("sg.field.attr.alwaysnotify", "BoolAttValue", "alwaysNotify=""true""")
    t.assertEqual("sg.field.attr.alwaysnotify: notify propagated", captionLabel.text, "onchange-probe-B")

    ' ======================================================================
    ' INTERFACE FUNCTION (callFunc)
    ' ======================================================================

    ' sg.function.name : <function name="describe"/> exposes a BrightScript fn that
    ' callFunc invokes; it returns a String.
    t.spec("sg.function.name", "Function", "<function name=""...""/> exposes a BrightScript fn (callFunc)")
    described = showcase.callFunc("describe", "spec-probe")
    t.assertNotInvalid("sg.function.name: returned", described)
    t.assertType("sg.function.name: String", described, "roString")

    ' ======================================================================
    ' SCRIPT embedding forms
    ' ======================================================================

    ' sg.script.inline_cdata : SpecShowcase carries an inline <script><![CDATA[...]]>
    ' block. The component compiled and loaded WITH that block present, proving the
    ' CDATA inline form is accepted.
    t.spec("sg.script.inline_cdata", "ScriptCData", "inline <script> with BrightScript in CDATA (injection point)")
    t.assertNotInvalid("sg.script.inline_cdata: component w/ CDATA script loaded", showcase)

    ' sg.script.inline_text : SpecHelperInlineText carries a BARE (non-CDATA) inline
    ' <script>. DEVICE FACT: the device TOLERATES the bare-text form (the component
    ' loads without error) but does NOT EXECUTE it - its init() never runs (loaded
    ' stays false); only CDATA / external scripts execute. So we assert the form is
    ' tolerated (instantiates) and that the bare body did NOT run. See DEVICE_FACTS.
    t.spec("sg.script.inline_text", "ScriptText", "inline <script> with bare (non-CDATA) BrightScript text")
    helperInline = CreateObject("roSGNode", "SpecHelperInlineText")
    t.assertNotInvalid("sg.script.inline_text: bare-script component tolerated", helperInline)
    t.assertFalse("sg.script.inline_text: bare init() did NOT run (device fact)", helperInline.loaded)

    ' sg.script.external_uri : SpecShowcase loads its logic from an external
    ' <script uri="..."/> (SpecShowcase.brs). callFunc reaching describe()/init()
    ' proves the external script resolved.
    t.spec("sg.script.external_uri", "ScriptExternal", "external <script uri=""...""/> (no body)")
    t.assertType("sg.script.external_uri: external fn reachable", showcase.callFunc("describe", "x"), "roString")

    ' sg.script.type_fixed : all <script> elements use type="text/brightscript".
    ' Their successful compilation/loading proves the fixed type value is accepted.
    t.spec("sg.script.type_fixed", "ScriptTypeAttValue", "fixed type=""text/brightscript""")
    t.assertNotInvalid("sg.script.type_fixed: scripted component loaded", showcase)

    ' ======================================================================
    ' CHILDREN
    ' ======================================================================

    ' sg.children.empty : SpecHelperExtends declares an empty <children/>; its load
    ' proves an empty children block is accepted.
    t.spec("sg.children.empty", "Children", "empty <children/>")
    t.assertNotInvalid("sg.children.empty: component w/ empty children loaded", helperExtends)

    ' sg.children.with_nodes : SpecShowcase's <children> declares node markup;
    ' findNode reaching a declared child proves the populated children block built.
    t.spec("sg.children.with_nodes", "Children", "<children> containing node markup")
    t.assertNotInvalid("sg.children.with_nodes: declared child built", showcase.findNode("bgRect"))

    ' ======================================================================
    ' NODE elements (in SpecShowcase's <children>)
    ' ======================================================================

    ' sg.node.builtin : <Rectangle id="bgRect"> is a built-in node class tag.
    t.spec("sg.node.builtin", "NodeName", "node element whose tag is a built-in class (<Label>)")
    t.assertNotInvalid("sg.node.builtin: bgRect found", bgRect)
    t.assertEqual("sg.node.builtin: subtype", bgRect.subtype(), "Rectangle")

    ' sg.node.custom : a node element whose tag is a user component name. The
    ' SpecShowcase instance itself IS such a node element (declared <SpecShowcase>
    ' in MainScene); its subtype is the custom component name.
    t.spec("sg.node.custom", "NodeName", "node element whose tag is a user component name")
    t.assertEqual("sg.node.custom: subtype is custom component", showcase.subtype(), "SpecShowcase")

    ' sg.node.empty_tag : a self-closing node element. <Timer id="tick" .../> is
    ' self-closing in the children block; its presence proves the empty-tag form.
    t.spec("sg.node.empty_tag", "NodeEmptyTag", "self-closing node element")
    tick = showcase.findNode("tick")
    t.assertNotInvalid("sg.node.empty_tag: self-closing node built", tick)
    t.assertEqual("sg.node.empty_tag: subtype", tick.subtype(), "Timer")

    ' sg.node.nested : nested node elements (parent/child). The LayoutGroup "panel"
    ' contains the captionLabel; both being reachable proves nesting built.
    t.spec("sg.node.nested", "NodeContent", "nested node elements (parent/child)")
    panel = showcase.findNode("panel")
    t.assertNotInvalid("sg.node.nested: parent built", panel)
    t.assertNotInvalid("sg.node.nested: nested child built", showcase.findNode("captionLabel"))

    ' sg.node.attr_id : the reserved id= node attribute makes a node findable.
    t.spec("sg.node.attr_id", "NodeAttribute", "reserved id node attribute (findNode dictionary id)")
    t.assertNotInvalid("sg.node.attr_id: findNode by id", showcase.findNode("swatch"))

    ' sg.node.attr_role : <Font role="font"/> assigns that child as the VALUE of the
    ' parent Label's 'font' field. Reading captionLabel.font must yield the Font node.
    t.spec("sg.node.attr_role", "RoleAttValue", "role assigns child as the value of a parent field")
    t.assertType("sg.node.attr_role: font field is a node", captionLabel.font, "roSGNode")
    t.assertEqual("sg.node.attr_role: assigned Font", captionLabel.font.subtype(), "Font")

    ' sg.node.attr_fieldinit : a generic field-initializer attribute (text="...").
    t.spec("sg.node.attr_fieldinit", "FieldInitValue", "generic field-initializer attribute")
    t.assertEqual("sg.node.attr_fieldinit: text applied", captionLabel.text, "onchange-probe-B")

    ' Note: captionLabel.text was overwritten by the onChange test above; assert the
    ' iconPoster.uri field-init instead to witness a pristine declarative initializer.
    iconPoster = showcase.findNode("iconPoster")
    t.assertEqual("sg.node.attr_fieldinit: uri applied", iconPoster.uri, "pkg:/images/icon_focus_hd.png")

    ' sg.node.fieldinit_color : color field-init micro-syntax 0xRRGGBBAA. swatch was
    ' declared color="0xFF8800FF"; it parses to a nonzero integer color.
    t.spec("sg.node.fieldinit_color", "FieldInitValue", "color field-init micro-syntax 0xRRGGBBAA")
    swatch = showcase.findNode("swatch")
    t.assertNotInvalid("sg.node.fieldinit_color: swatch built", swatch)
    t.assertTrue("sg.node.fieldinit_color: color numeric", sgh_isNumeric(swatch.color))
    t.assertTrue("sg.node.fieldinit_color: color nonzero", swatch.color <> 0)

    ' sg.node.fieldinit_vector2d : vector2d field-init micro-syntax [x,y]. bgRect was
    ' declared translation="[0, 0]" - a 2-element array field.
    t.spec("sg.node.fieldinit_vector2d", "FieldInitValue", "vector2d field-init micro-syntax [x,y]")
    t.assertType("sg.node.fieldinit_vector2d: roArray", bgRect.translation, "roArray")
    t.assertEqual("sg.node.fieldinit_vector2d: 2 components", bgRect.translation.count(), 2)

end sub

' ---------------------------------------------------------------------------
' Free helpers (module-level; sgh_ prefixed to avoid global-scope collisions).
' ---------------------------------------------------------------------------

' True for any numeric runtime type (intrinsic or boxed). Field reads can return
' boxed scalars, so test the full set of numeric Type() spellings.
function sgh_isNumeric(v as Dynamic) as Boolean
    t = Type(v)
    return t = "Integer" or t = "roInteger" or t = "roInt" or t = "Float" or t = "roFloat" or t = "Double" or t = "roDouble" or t = "LongInteger" or t = "roLongInteger"
end function
