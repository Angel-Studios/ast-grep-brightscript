' test_objects.brs - exercises CreateObject, m usage, component interfaces.
'
' CreateObject for roArray / roAssociativeArray / roDateTime / roDeviceInfo
' (read-only safe calls), the 'm' implicit instance AA, and function dispatch via
' m (a method stored on an AA and called as m.method()).

sub test_objects_all(t as Object)
    ' --- CreateObject roArray ----------------------------------------------
    t.spec("obj.createobject.roarray", "CreateObjectCall", "CreateObject(roArray, size, resize)")
    a = CreateObject("roArray", 4, true)
    a.push("first")
    t.assertType("obj: roArray type", a, "roArray")
    t.assertEqual("obj: roArray push", a[0], "first")

    ' --- CreateObject roAssociativeArray -----------------------------------
    t.spec("obj.createobject.roaa", "CreateObjectCall", "CreateObject(roAssociativeArray) + ifAssociativeArray methods")
    h = CreateObject("roAssociativeArray")
    h.addReplace("key", "value")
    t.assertType("obj: roAssociativeArray type", h, "roAssociativeArray")
    t.assertEqual("obj: roAA addReplace/lookup", h.lookup("key"), "value")
    t.assertTrue("obj: roAA doesExist", h.doesExist("key"))

    ' Case-insensitive vs case-sensitive AA mode.
    h.setModeCaseSensitive()
    h.addReplace("Mixed", 1)
    t.assertInvalid("obj: case-sensitive miss", h.lookup("mixed"))

    ' --- roDateTime (deterministic-enough read-only calls) -----------------
    t.spec("obj.createobject.rodatetime", "CreateObjectCall", "CreateObject(roDateTime) read-only calls")
    dt = CreateObject("roDateTime")
    t.assertType("obj: roDateTime type", dt, "roDateTime")
    ' Set a fixed epoch so the assertion is deterministic and device-safe.
    dt.fromSeconds(0)
    t.assertEqual("obj: roDateTime fromSeconds(0) year", dt.getYear(), 1970)
    t.assertTrue("obj: roDateTime getDayOfWeek in range", dt.getDayOfWeek() >= 0 and dt.getDayOfWeek() <= 6)

    ' --- roDeviceInfo (read-only, safe) ------------------------------------
    t.spec("obj.createobject.rodeviceinfo", "CreateObjectCall", "CreateObject(roDeviceInfo) read-only getters")
    di = CreateObject("roDeviceInfo")
    t.assertType("obj: roDeviceInfo type", di, "roDeviceInfo")
    ' These getters never mutate device state; just confirm non-invalid returns.
    t.assertNotInvalid("obj: roDeviceInfo getModel", di.getModel())
    t.assertNotInvalid("obj: roDeviceInfo getVersion", di.getVersion())
    t.assertNotInvalid("obj: roDeviceInfo uiResolution", di.getUIResolution())

    ' --- 'm' usage + function dispatch via m -------------------------------
    ' Build a tiny object whose methods reference m to read/modify its own state.
    t.spec("obj.m_dispatch", "MemberSuffix", "m-style method dispatch on an AA-backed object")
    obj = MakeCounter(10)
    obj.increment()
    obj.increment()
    t.assertEqual("obj: m-dispatch increment", obj.getValue(), 12)
    obj.add(5)
    t.assertEqual("obj: m-dispatch add", obj.getValue(), 17)

    ' --- roRegex (CreateObject with two args) ------------------------------
    t.spec("obj.createobject.roregex", "CreateObjectCall", "CreateObject(roRegex, pattern, flags)")
    re = CreateObject("roRegex", "[0-9]+", "")
    t.assertTrue("obj: roRegex isMatch", re.isMatch("abc123"))
    t.assertEqual("obj: roRegex replace", re.replaceAll("a1b2c3", "#"), "a#b#c#")
end sub

' Factory that returns an object whose methods use 'm' for instance state.
function MakeCounter(start as Integer) as Object
    self = {}
    self.value = start
    self.increment = sub()
        m.value = m.value + 1
    end sub
    self.add = sub(n as Integer)
        m.value = m.value + n
    end sub
    self.getValue = function() as Integer
        return m.value
    end function
    return self
end function
