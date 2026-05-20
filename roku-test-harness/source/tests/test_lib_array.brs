' test_lib_array.brs - STANDARD-LIBRARY coverage of the array-family BrightScript
' component objects: roArray (ifArray / ifArrayGet / ifArraySet / ifEnum),
' roList (ifList / ifListToArray / ifEnum), and roByteArray (ifByteArray).
'
' These are not language-grammar leaves; they are stdlib method CALLS exercised on
' real device objects, captured as device-confirmed ground truth so the future
' tree-sitter grammar / ast-grep corpus has a verified picture of how the method
' call sites behave. Every spec id/kind here matches a leaf in
' grammar/coverage_frags/array.json EXACTLY (id prefixes lib.array.* / lib.list.*
' / lib.bytearray.*, kind "CallExpression").
'
' DEFENSIVE PATTERN: an uncaught runtime error aborts the WHOLE suite, so each
' spec's exercise is wrapped in try/catch. A non-existent / mis-used API then FAILs
' its one spec (the catch records false) instead of crashing the run. Helpers are
' prefixed la_ (this module) per the harness naming convention.

sub test_lib_array_all(t as Object)
    ' =====================================================================
    ' roArray - ifArray / ifArrayGet / ifArraySet (mutators + accessors)
    ' =====================================================================

    ' Push appends to the tail (snippet: a=[] : a.Push(7) -> a[0] == 7)
    t.spec("lib.array.push", "CallExpression", "roArray Push appends to the tail")
    try
        a = []
        a.Push(7)
        t.assertEqual("lib.array.push", a[0], 7)
    catch e
        t.assertTrue("lib.array.push: runtime error", false)
    end try

    ' Pop removes and returns the last element (snippet: a=[1,2] : a.Pop() -> 2)
    t.spec("lib.array.pop", "CallExpression", "roArray Pop removes/returns the tail")
    try
        a = [1, 2]
        y = a.Pop()
        t.assertEqual("lib.array.pop", y, 2)
    catch e
        t.assertTrue("lib.array.pop: runtime error", false)
    end try

    ' Peek returns the last element without removing it (snippet: a=[1,2] : a.Peek() -> 2)
    t.spec("lib.array.peek", "CallExpression", "roArray Peek reads the tail (no remove)")
    try
        a = [1, 2]
        y = a.Peek()
        t.assertEqual("lib.array.peek", y, 2)
    catch e
        t.assertTrue("lib.array.peek: runtime error", false)
    end try

    ' Shift removes and returns the first element (snippet: a=[1,2] : a.Shift() -> 1)
    t.spec("lib.array.shift", "CallExpression", "roArray Shift removes/returns the head")
    try
        a = [1, 2]
        y = a.Shift()
        t.assertEqual("lib.array.shift", y, 1)
    catch e
        t.assertTrue("lib.array.shift: runtime error", false)
    end try

    ' Unshift prepends to the head (snippet: a=[2] : a.Unshift(1) -> a[0] == 1)
    t.spec("lib.array.unshift", "CallExpression", "roArray Unshift prepends to the head")
    try
        a = [2]
        a.Unshift(1)
        t.assertEqual("lib.array.unshift", a[0], 1)
    catch e
        t.assertTrue("lib.array.unshift: runtime error", false)
    end try

    ' Append concatenates another array (snippet: a=[1] : a.Append([2,3]) -> count 3)
    t.spec("lib.array.append", "CallExpression", "roArray Append concatenates another array")
    try
        a = [1]
        a.Append([2, 3])
        t.assertEqual("lib.array.append", a.Count(), 3)
    catch e
        t.assertTrue("lib.array.append: runtime error", false)
    end try

    ' Delete removes the element at an index (snippet: a=[1,2,3] : a.Delete(1) -> [1,3])
    t.spec("lib.array.delete", "CallExpression", "roArray Delete removes by index")
    try
        a = [1, 2, 3]
        a.Delete(1)
        t.assertEqual("lib.array.delete", a[1], 3)
    catch e
        t.assertTrue("lib.array.delete: runtime error", false)
    end try

    ' Count returns the element count (snippet: a=[1,2,3] : a.Count() -> 3)
    t.spec("lib.array.count", "CallExpression", "roArray Count returns the length")
    try
        a = [1, 2, 3]
        t.assertEqual("lib.array.count", a.Count(), 3)
    catch e
        t.assertTrue("lib.array.count: runtime error", false)
    end try

    ' Clear empties the array (snippet: a=[1,2] : a.Clear() -> count 0)
    t.spec("lib.array.clear", "CallExpression", "roArray Clear empties the array")
    try
        a = [1, 2]
        a.Clear()
        t.assertEqual("lib.array.clear", a.Count(), 0)
    catch e
        t.assertTrue("lib.array.clear: runtime error", false)
    end try

    ' Join concatenates string elements with a separator (snippet: ["a","b"].Join(",") -> "a,b")
    t.spec("lib.array.join", "CallExpression", "roArray Join builds a delimited string")
    try
        a = ["a", "b"]
        y = a.Join(",")
        t.assertEqual("lib.array.join", y, "a,b")
    catch e
        t.assertTrue("lib.array.join: runtime error", false)
    end try

    ' Sort orders in place ascending (snippet: a=[3,1,2] : a.Sort() -> [1,2,3])
    t.spec("lib.array.sort", "CallExpression", "roArray Sort orders in place")
    try
        a = [3, 1, 2]
        a.Sort()
        t.assertEqual("lib.array.sort", a[0], 1)
    catch e
        t.assertTrue("lib.array.sort: runtime error", false)
    end try

    ' SortBy orders AAs by a key (snippet: [{k:2},{k:1}].SortBy("k") -> first.k == 1)
    t.spec("lib.array.sortby", "CallExpression", "roArray SortBy orders AAs by a key")
    try
        a = [{ k: 2 }, { k: 1 }]
        a.SortBy("k")
        t.assertEqual("lib.array.sortby", a[0].k, 1)
    catch e
        t.assertTrue("lib.array.sortby: runtime error", false)
    end try

    ' Reverse reverses in place (snippet: a=[1,2,3] : a.Reverse() -> a[0] == 3)
    t.spec("lib.array.reverse", "CallExpression", "roArray Reverse reverses in place")
    try
        a = [1, 2, 3]
        a.Reverse()
        t.assertEqual("lib.array.reverse", a[0], 3)
    catch e
        t.assertTrue("lib.array.reverse: runtime error", false)
    end try

    ' GetEntry reads the element at an index (ifArrayGet) (snippet: [1,2].GetEntry(1) -> 2)
    t.spec("lib.array.getentry", "CallExpression", "roArray GetEntry reads by index (ifArrayGet)")
    try
        a = [1, 2]
        y = a.GetEntry(1)
        t.assertEqual("lib.array.getentry", y, 2)
    catch e
        t.assertTrue("lib.array.getentry: runtime error", false)
    end try

    ' SetEntry writes the element at an index (ifArraySet) (snippet: a=[1,2] : a.SetEntry(0,9) -> a[0]==9)
    t.spec("lib.array.setentry", "CallExpression", "roArray SetEntry writes by index (ifArraySet)")
    try
        a = [1, 2]
        a.SetEntry(0, 9)
        t.assertEqual("lib.array.setentry", a[0], 9)
    catch e
        t.assertTrue("lib.array.setentry: runtime error", false)
    end try

    ' IsEmpty reports emptiness (snippet: [].IsEmpty() -> true)
    t.spec("lib.array.isempty", "CallExpression", "roArray IsEmpty reports emptiness")
    try
        a = []
        y = a.IsEmpty()
        t.assertTrue("lib.array.isempty", y)
    catch e
        t.assertTrue("lib.array.isempty: runtime error", false)
    end try

    ' CreateObject("roArray", n, resizable) constructs the same component (snippet: count after push -> 1)
    t.spec("lib.array.createobject", "CallExpression", "roArray via CreateObject(n, resizable)")
    try
        a = CreateObject("roArray", 4, true)
        a.Push(1)
        t.assertEqual("lib.array.createobject", a.Count(), 1)
    catch e
        t.assertTrue("lib.array.createobject: runtime error", false)
    end try

    ' --- ifEnum on roArray --------------------------------------------------

    ' Reset rewinds the enumerator; Next yields the first element (snippet: a.Reset():a.Next() -> 1)
    t.spec("lib.array.enum_reset", "CallExpression", "roArray ifEnum Reset rewinds the cursor")
    try
        a = [1, 2]
        a.Reset()
        y = a.Next()
        t.assertEqual("lib.array.enum_reset", y, 1)
    catch e
        t.assertTrue("lib.array.enum_reset: runtime error", false)
    end try

    ' Next advances the enumerator (snippet: after Reset, two Next calls -> 2)
    t.spec("lib.array.enum_next", "CallExpression", "roArray ifEnum Next advances the cursor")
    try
        a = [1, 2]
        a.Reset()
        a.Next()
        y = a.Next()
        t.assertEqual("lib.array.enum_next", y, 2)
    catch e
        t.assertTrue("lib.array.enum_next: runtime error", false)
    end try

    ' IsNext reports whether another element remains (snippet: a.Reset():a.IsNext() -> true)
    t.spec("lib.array.enum_isnext", "CallExpression", "roArray ifEnum IsNext peeks for more")
    try
        a = [1, 2]
        a.Reset()
        y = a.IsNext()
        t.assertTrue("lib.array.enum_isnext", y)
    catch e
        t.assertTrue("lib.array.enum_isnext: runtime error", false)
    end try

    ' =====================================================================
    ' roList - ifList / ifListToArray / ifEnum (doubly-linked list)
    ' =====================================================================

    ' AddTail appends to the tail (snippet: l.AddTail(1) -> Count 1)
    t.spec("lib.list.addtail", "CallExpression", "roList AddTail appends to the tail")
    try
        l = CreateObject("roList")
        l.AddTail(1)
        t.assertEqual("lib.list.addtail", l.Count(), 1)
    catch e
        t.assertTrue("lib.list.addtail: runtime error", false)
    end try

    ' AddHead prepends to the head (snippet: AddTail(2):AddHead(1):GetHead -> 1)
    t.spec("lib.list.addhead", "CallExpression", "roList AddHead prepends to the head")
    try
        l = CreateObject("roList")
        l.AddTail(2)
        l.AddHead(1)
        y = l.GetHead()
        t.assertEqual("lib.list.addhead", y, 1)
    catch e
        t.assertTrue("lib.list.addhead: runtime error", false)
    end try

    ' RemoveTail removes and returns the tail element (snippet: 1,2 -> RemoveTail -> 2)
    t.spec("lib.list.removetail", "CallExpression", "roList RemoveTail removes/returns the tail")
    try
        l = CreateObject("roList")
        l.AddTail(1)
        l.AddTail(2)
        y = l.RemoveTail()
        t.assertEqual("lib.list.removetail", y, 2)
    catch e
        t.assertTrue("lib.list.removetail: runtime error", false)
    end try

    ' RemoveHead removes and returns the head element (snippet: 1,2 -> RemoveHead -> 1)
    t.spec("lib.list.removehead", "CallExpression", "roList RemoveHead removes/returns the head")
    try
        l = CreateObject("roList")
        l.AddTail(1)
        l.AddTail(2)
        y = l.RemoveHead()
        t.assertEqual("lib.list.removehead", y, 1)
    catch e
        t.assertTrue("lib.list.removehead: runtime error", false)
    end try

    ' GetHead reads the head element without removing it (snippet: 5,6 -> GetHead -> 5)
    t.spec("lib.list.gethead", "CallExpression", "roList GetHead reads the head (no remove)")
    try
        l = CreateObject("roList")
        l.AddTail(5)
        l.AddTail(6)
        y = l.GetHead()
        t.assertEqual("lib.list.gethead", y, 5)
    catch e
        t.assertTrue("lib.list.gethead: runtime error", false)
    end try

    ' GetTail reads the tail element without removing it (snippet: 5,6 -> GetTail -> 6)
    t.spec("lib.list.gettail", "CallExpression", "roList GetTail reads the tail (no remove)")
    try
        l = CreateObject("roList")
        l.AddTail(5)
        l.AddTail(6)
        y = l.GetTail()
        t.assertEqual("lib.list.gettail", y, 6)
    catch e
        t.assertTrue("lib.list.gettail: runtime error", false)
    end try

    ' Count returns the element count (snippet: 1,2,3 -> Count -> 3)
    t.spec("lib.list.count", "CallExpression", "roList Count returns the length")
    try
        l = CreateObject("roList")
        l.AddTail(1)
        l.AddTail(2)
        l.AddTail(3)
        t.assertEqual("lib.list.count", l.Count(), 3)
    catch e
        t.assertTrue("lib.list.count: runtime error", false)
    end try

    ' Clear empties the list (snippet: 1,2 -> Clear -> Count 0)
    t.spec("lib.list.clear", "CallExpression", "roList Clear empties the list")
    try
        l = CreateObject("roList")
        l.AddTail(1)
        l.AddTail(2)
        l.Clear()
        t.assertEqual("lib.list.clear", l.Count(), 0)
    catch e
        t.assertTrue("lib.list.clear: runtime error", false)
    end try

    ' ResetIndex rewinds the ifList cursor; GetIndex then yields the first (snippet: -> 1)
    t.spec("lib.list.resetindex", "CallExpression", "roList ResetIndex rewinds the ifList cursor")
    try
        l = CreateObject("roList")
        l.AddTail(1)
        l.AddTail(2)
        l.ResetIndex()
        y = l.GetIndex()
        t.assertEqual("lib.list.resetindex", y, 1)
    catch e
        t.assertTrue("lib.list.resetindex: runtime error", false)
    end try

    ' GetIndex advances the ifList cursor element by element (snippet: two GetIndex -> 2)
    t.spec("lib.list.getindex", "CallExpression", "roList GetIndex advances the ifList cursor")
    try
        l = CreateObject("roList")
        l.AddTail(1)
        l.AddTail(2)
        l.ResetIndex()
        l.GetIndex()
        y = l.GetIndex()
        t.assertEqual("lib.list.getindex", y, 2)
    catch e
        t.assertTrue("lib.list.getindex: runtime error", false)
    end try

    ' ifEnum Reset/Next yields the first element (snippet: Reset:Next -> 1)
    t.spec("lib.list.enum_next", "CallExpression", "roList ifEnum Reset/Next yields the head")
    try
        l = CreateObject("roList")
        l.AddTail(1)
        l.AddTail(2)
        l.Reset()
        y = l.Next()
        t.assertEqual("lib.list.enum_next", y, 1)
    catch e
        t.assertTrue("lib.list.enum_next: runtime error", false)
    end try

    ' ToArray converts the list to an roArray (ifListToArray) (snippet: ToArray()[0] -> 1)
    t.spec("lib.list.toarray", "CallExpression", "roList ToArray converts to roArray (ifListToArray)")
    try
        l = CreateObject("roList")
        l.AddTail(1)
        l.AddTail(2)
        arr = l.ToArray()
        t.assertEqual("lib.list.toarray", arr[0], 1)
    catch e
        t.assertTrue("lib.list.toarray: runtime error", false)
    end try

    ' =====================================================================
    ' roByteArray - ifByteArray (mutable byte buffer + (de)serialization)
    ' =====================================================================

    ' FromAsciiString fills the buffer from a string's bytes (snippet: "AB" -> Count 2)
    t.spec("lib.bytearray.fromasciistring", "CallExpression", "roByteArray FromAsciiString loads bytes")
    try
        ba = CreateObject("roByteArray")
        ba.FromAsciiString("AB")
        t.assertEqual("lib.bytearray.fromasciistring", ba.Count(), 2)
    catch e
        t.assertTrue("lib.bytearray.fromasciistring: runtime error", false)
    end try

    ' ToAsciiString round-trips the bytes back to a string (snippet: "AB" -> "AB")
    t.spec("lib.bytearray.toasciistring", "CallExpression", "roByteArray ToAsciiString reads bytes")
    try
        ba = CreateObject("roByteArray")
        ba.FromAsciiString("AB")
        y = ba.ToAsciiString()
        t.assertEqual("lib.bytearray.toasciistring", y, "AB")
    catch e
        t.assertTrue("lib.bytearray.toasciistring: runtime error", false)
    end try

    ' FromHexString parses hex pairs into bytes (snippet: "4142" -> Count 2)
    t.spec("lib.bytearray.fromhexstring", "CallExpression", "roByteArray FromHexString parses hex pairs")
    try
        ba = CreateObject("roByteArray")
        ba.FromHexString("4142")
        t.assertEqual("lib.bytearray.fromhexstring", ba.Count(), 2)
    catch e
        t.assertTrue("lib.bytearray.fromhexstring: runtime error", false)
    end try

    ' ToHexString serializes bytes to upper-case hex (snippet: "AB" -> "4142")
    t.spec("lib.bytearray.tohexstring", "CallExpression", "roByteArray ToHexString serializes to hex")
    try
        ba = CreateObject("roByteArray")
        ba.FromAsciiString("AB")
        y = ba.ToHexString()
        t.assertEqual("lib.bytearray.tohexstring", UCase(y), "4142")
    catch e
        t.assertTrue("lib.bytearray.tohexstring: runtime error", false)
    end try

    ' ToBase64String serializes bytes to Base64 (snippet: "AB" -> "QUI=")
    t.spec("lib.bytearray.tobase64string", "CallExpression", "roByteArray ToBase64String serializes to Base64")
    try
        ba = CreateObject("roByteArray")
        ba.FromAsciiString("AB")
        y = ba.ToBase64String()
        t.assertEqual("lib.bytearray.tobase64string", y, "QUI=")
    catch e
        t.assertTrue("lib.bytearray.tobase64string: runtime error", false)
    end try

    ' FromBase64String decodes Base64 back to bytes (snippet: "QUI=" -> "AB")
    t.spec("lib.bytearray.frombase64string", "CallExpression", "roByteArray FromBase64String decodes Base64")
    try
        ba = CreateObject("roByteArray")
        ba.FromBase64String("QUI=")
        y = ba.ToAsciiString()
        t.assertEqual("lib.bytearray.frombase64string", y, "AB")
    catch e
        t.assertTrue("lib.bytearray.frombase64string: runtime error", false)
    end try

    ' Append concatenates another roByteArray (snippet: "A" + "B" -> Count 2)
    t.spec("lib.bytearray.append", "CallExpression", "roByteArray Append concatenates another buffer")
    try
        ba = CreateObject("roByteArray")
        ba.FromAsciiString("A")
        bb = CreateObject("roByteArray")
        bb.FromAsciiString("B")
        ba.Append(bb)
        t.assertEqual("lib.bytearray.append", ba.Count(), 2)
    catch e
        t.assertTrue("lib.bytearray.append: runtime error", false)
    end try

    ' Count returns the byte count (snippet: "ABC" -> 3)
    t.spec("lib.bytearray.count", "CallExpression", "roByteArray Count returns the byte length")
    try
        ba = CreateObject("roByteArray")
        ba.FromAsciiString("ABC")
        t.assertEqual("lib.bytearray.count", ba.Count(), 3)
    catch e
        t.assertTrue("lib.bytearray.count: runtime error", false)
    end try

    ' Indexed write/read of a single byte (ifByteArray index suffix) (snippet: ba[0]=65 -> 65)
    t.spec("lib.bytearray.index", "CreateObjectCall", "roByteArray indexed byte read/write")
    try
        ba = CreateObject("roByteArray")
        ba[0] = 65
        t.assertEqual("lib.bytearray.index", ba[0], 65)
    catch e
        t.assertTrue("lib.bytearray.index: runtime error", false)
    end try
end sub
