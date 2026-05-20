' test_lib_device_storage.brs - STANDARD-LIBRARY coverage of the DEVICE / APP
' INFO + PERSISTENT-STORAGE component families:
'   - roDeviceInfo  (model / OS / locale / display getters)
'   - roAppInfo     (channel id / version / title / manifest values)
'   - roRegistry / roRegistrySection (persistent key/value store)
'   - File I/O      (ReadAsciiFile / WriteAsciiFile, roFileSystem, roPath)
'
' These are stdlib LEAVES (layer:"stdlib") of the future tree-sitter grammar
' corpus: each is exercised as a CallExpression and asserted against its
' device-observed result. Each t.spec id/kind matches
' grammar/coverage_frags/device_storage.json VERBATIM (the fragment the
' orchestrator merges into coverage.json after device validation).
'
' Every spec's exercise is wrapped in try/catch: the harness runs the whole
' suite in one pass, so an uncaught runtime error (a wrong API name/signature)
' would abort EVERYTHING. Wrapping turns a bad call into a single FAIL, not a
' crash, and lets the orchestrator see exactly which leaf diverged.
'
' Determinism:
'   - roDeviceInfo / roAppInfo getters are DEVICE-SPECIFIC, so they assert only
'     NotInvalid / type / shape (expect:"parse").
'   - roAppInfo.GetValue of a known manifest key, the registry WRITE->READ-BACK
'     round-trip, and the WriteAsciiFile->ReadAsciiFile round-trip ARE
'     deterministic and assert exact values (expect:"value:X").
'
' Side-effect safety: registry work uses a DEDICATED section ("specHarness") and
' is cleaned up at the end; file I/O uses the writable, device-safe tmp:/ volume
' and deletes its scratch file. No getter that prompts the user or changes
' device state is exercised.

sub test_lib_device_storage_all(t as Object)
    ' =====================================================================
    ' roDeviceInfo - model / OS / locale / display getters (device-specific)
    ' =====================================================================

    t.spec("lib.deviceinfo.getmodel", "CallExpression", "roDeviceInfo GetModel() device model code")
    try
        di = CreateObject("roDeviceInfo")
        t.assertNotInvalid("lib.deviceinfo.getmodel", di.GetModel())
    catch e
        t.assertTrue("lib.deviceinfo.getmodel: runtime error", false)
    end try

    t.spec("lib.deviceinfo.getmodeldisplayname", "CallExpression", "roDeviceInfo GetModelDisplayName() friendly name")
    try
        di = CreateObject("roDeviceInfo")
        t.assertNotInvalid("lib.deviceinfo.getmodeldisplayname", di.GetModelDisplayName())
    catch e
        t.assertTrue("lib.deviceinfo.getmodeldisplayname: runtime error", false)
    end try

    t.spec("lib.deviceinfo.getmodeltype", "CallExpression", "roDeviceInfo GetModelType() (STB/TV/...)")
    try
        di = CreateObject("roDeviceInfo")
        t.assertNotInvalid("lib.deviceinfo.getmodeltype", di.GetModelType())
    catch e
        t.assertTrue("lib.deviceinfo.getmodeltype: runtime error", false)
    end try

    t.spec("lib.deviceinfo.getmodeldetails", "CallExpression", "roDeviceInfo GetModelDetails() -> AA")
    try
        di = CreateObject("roDeviceInfo")
        r = di.GetModelDetails()
        t.assertTrue("lib.deviceinfo.getmodeldetails", Type(r) = "roAssociativeArray")
    catch e
        t.assertTrue("lib.deviceinfo.getmodeldetails: runtime error", false)
    end try

    t.spec("lib.deviceinfo.getosversion", "CallExpression", "roDeviceInfo GetOSVersion() -> AA")
    try
        di = CreateObject("roDeviceInfo")
        r = di.GetOSVersion()
        t.assertTrue("lib.deviceinfo.getosversion", Type(r) = "roAssociativeArray")
    catch e
        t.assertTrue("lib.deviceinfo.getosversion: runtime error", false)
    end try

    ' GetRandomUUID returns a fresh UUID string each call (nondeterministic value,
    ' deterministic shape: a non-empty string).
    t.spec("lib.deviceinfo.getrandomuuid", "CallExpression", "roDeviceInfo GetRandomUUID() -> string")
    try
        di = CreateObject("roDeviceInfo")
        r = di.GetRandomUUID()
        t.assertTrue("lib.deviceinfo.getrandomuuid", Type(r) = "String" or Type(r) = "roString")
        t.assertTrue("lib.deviceinfo.getrandomuuid: nonempty", Len(r) > 0)
    catch e
        t.assertTrue("lib.deviceinfo.getrandomuuid: runtime error", false)
    end try

    t.spec("lib.deviceinfo.gettimezone", "CallExpression", "roDeviceInfo GetTimeZone() configured tz")
    try
        di = CreateObject("roDeviceInfo")
        t.assertNotInvalid("lib.deviceinfo.gettimezone", di.GetTimeZone())
    catch e
        t.assertTrue("lib.deviceinfo.gettimezone: runtime error", false)
    end try

    t.spec("lib.deviceinfo.getcurrentlocale", "CallExpression", "roDeviceInfo GetCurrentLocale() (e.g. en_US)")
    try
        di = CreateObject("roDeviceInfo")
        t.assertNotInvalid("lib.deviceinfo.getcurrentlocale", di.GetCurrentLocale())
    catch e
        t.assertTrue("lib.deviceinfo.getcurrentlocale: runtime error", false)
    end try

    t.spec("lib.deviceinfo.getcountrycode", "CallExpression", "roDeviceInfo GetCountryCode()")
    try
        di = CreateObject("roDeviceInfo")
        t.assertNotInvalid("lib.deviceinfo.getcountrycode", di.GetCountryCode())
    catch e
        t.assertTrue("lib.deviceinfo.getcountrycode: runtime error", false)
    end try

    t.spec("lib.deviceinfo.getdisplaysize", "CallExpression", "roDeviceInfo GetDisplaySize() -> AA {w,h}")
    try
        di = CreateObject("roDeviceInfo")
        r = di.GetDisplaySize()
        t.assertTrue("lib.deviceinfo.getdisplaysize", Type(r) = "roAssociativeArray")
    catch e
        t.assertTrue("lib.deviceinfo.getdisplaysize: runtime error", false)
    end try

    t.spec("lib.deviceinfo.getdisplaytype", "CallExpression", "roDeviceInfo GetDisplayType() (HDTV/...)")
    try
        di = CreateObject("roDeviceInfo")
        t.assertNotInvalid("lib.deviceinfo.getdisplaytype", di.GetDisplayType())
    catch e
        t.assertTrue("lib.deviceinfo.getdisplaytype: runtime error", false)
    end try

    t.spec("lib.deviceinfo.getdisplaymode", "CallExpression", "roDeviceInfo GetDisplayMode() (e.g. 1080p)")
    try
        di = CreateObject("roDeviceInfo")
        t.assertNotInvalid("lib.deviceinfo.getdisplaymode", di.GetDisplayMode())
    catch e
        t.assertTrue("lib.deviceinfo.getdisplaymode: runtime error", false)
    end try

    t.spec("lib.deviceinfo.getvideomode", "CallExpression", "roDeviceInfo GetVideoMode() current video mode")
    try
        di = CreateObject("roDeviceInfo")
        t.assertNotInvalid("lib.deviceinfo.getvideomode", di.GetVideoMode())
    catch e
        t.assertTrue("lib.deviceinfo.getvideomode: runtime error", false)
    end try

    t.spec("lib.deviceinfo.getdisplayaspectratio", "CallExpression", "roDeviceInfo GetDisplayAspectRatio()")
    try
        di = CreateObject("roDeviceInfo")
        t.assertNotInvalid("lib.deviceinfo.getdisplayaspectratio", di.GetDisplayAspectRatio())
    catch e
        t.assertTrue("lib.deviceinfo.getdisplayaspectratio: runtime error", false)
    end try

    ' =====================================================================
    ' roAppInfo - channel identity + manifest values
    ' =====================================================================

    t.spec("lib.appinfo.getid", "CallExpression", "roAppInfo GetID() channel/dev id")
    try
        ai = CreateObject("roAppInfo")
        t.assertNotInvalid("lib.appinfo.getid", ai.GetID())
    catch e
        t.assertTrue("lib.appinfo.getid: runtime error", false)
    end try

    t.spec("lib.appinfo.getversion", "CallExpression", "roAppInfo GetVersion() manifest version")
    try
        ai = CreateObject("roAppInfo")
        t.assertNotInvalid("lib.appinfo.getversion", ai.GetVersion())
    catch e
        t.assertTrue("lib.appinfo.getversion: runtime error", false)
    end try

    ' GetTitle reads manifest title=; the harness manifest sets a known title, so
    ' assert the device returns the manifest's exact value.
    t.spec("lib.appinfo.gettitle", "CallExpression", "roAppInfo GetTitle() manifest title (exact)")
    try
        ai = CreateObject("roAppInfo")
        t.assertEqual("lib.appinfo.gettitle", ai.GetTitle(), "AST-Grep BrightScript Spec Harness")
    catch e
        t.assertTrue("lib.appinfo.gettitle: runtime error", false)
    end try

    ' GetValue("title") reads an arbitrary manifest key; title= is known, so this
    ' round-trips deterministically.
    t.spec("lib.appinfo.getvalue", "CallExpression", "roAppInfo GetValue(""title"") manifest key (exact)")
    try
        ai = CreateObject("roAppInfo")
        t.assertEqual("lib.appinfo.getvalue", ai.GetValue("title"), "AST-Grep BrightScript Spec Harness")
    catch e
        t.assertTrue("lib.appinfo.getvalue: runtime error", false)
    end try

    ' IsDev returns true for a sideloaded dev channel; the harness is always
    ' sideloaded during validation, so assert true.
    t.spec("lib.appinfo.isdev", "CallExpression", "roAppInfo IsDev() dev (sideloaded) channel")
    try
        ai = CreateObject("roAppInfo")
        t.assertTrue("lib.appinfo.isdev", ai.IsDev() = true)
    catch e
        t.assertTrue("lib.appinfo.isdev: runtime error", false)
    end try

    ' =====================================================================
    ' roRegistry / roRegistrySection - persistent key/value store
    ' (WRITE then READ-BACK is deterministic + device-safe; dedicated section)
    ' =====================================================================

    ' Write a value, flush, read it back: the canonical persistence round-trip.
    t.spec("lib.registry.write", "CallExpression", "roRegistrySection Write(k,v) then Read -> v")
    try
        sec = CreateObject("roRegistrySection", "specHarness")
        sec.Write("k", "v")
        sec.Flush()
        t.assertEqual("lib.registry.write", sec.Read("k"), "v")
    catch e
        t.assertTrue("lib.registry.write: runtime error", false)
    end try

    t.spec("lib.registry.read", "CallExpression", "roRegistrySection Read(k) reads the stored value")
    try
        sec = CreateObject("roRegistrySection", "specHarness")
        sec.Write("rk", "rv")
        sec.Flush()
        t.assertEqual("lib.registry.read", sec.Read("rk"), "rv")
    catch e
        t.assertTrue("lib.registry.read: runtime error", false)
    end try

    t.spec("lib.registry.flush", "CallExpression", "roRegistrySection Flush() persists pending writes")
    try
        sec = CreateObject("roRegistrySection", "specHarness")
        sec.Write("fk", "fv")
        t.assertTrue("lib.registry.flush", sec.Flush() = true)
    catch e
        t.assertTrue("lib.registry.flush: runtime error", false)
    end try

    t.spec("lib.registry.exists", "CallExpression", "roRegistrySection Exists(k) key membership")
    try
        sec = CreateObject("roRegistrySection", "specHarness")
        sec.Write("ek", "ev")
        sec.Flush()
        t.assertTrue("lib.registry.exists", sec.Exists("ek") = true)
    catch e
        t.assertTrue("lib.registry.exists: runtime error", false)
    end try

    t.spec("lib.registry.getkeylist", "CallExpression", "roRegistrySection GetKeyList() -> roArray of keys")
    try
        sec = CreateObject("roRegistrySection", "specHarness")
        sec.Write("lk", "lv")
        sec.Flush()
        r = sec.GetKeyList()
        t.assertTrue("lib.registry.getkeylist", Type(r) = "roArray" or Type(r) = "roList")
    catch e
        t.assertTrue("lib.registry.getkeylist: runtime error", false)
    end try

    ' Delete a key then confirm it no longer Exists (deterministic round-trip).
    t.spec("lib.registry.delete", "CallExpression", "roRegistrySection Delete(k) removes a key")
    try
        sec = CreateObject("roRegistrySection", "specHarness")
        sec.Write("dk", "dv")
        sec.Flush()
        sec.Delete("dk")
        sec.Flush()
        t.assertFalse("lib.registry.delete", sec.Exists("dk"))
    catch e
        t.assertTrue("lib.registry.delete: runtime error", false)
    end try

    t.spec("lib.registry.getsectionlist", "CallExpression", "roRegistry GetSectionList() -> roArray of sections")
    try
        sec = CreateObject("roRegistrySection", "specHarness")
        sec.Write("sk", "sv")
        sec.Flush()
        reg = CreateObject("roRegistry")
        r = reg.GetSectionList()
        t.assertTrue("lib.registry.getsectionlist", Type(r) = "roArray" or Type(r) = "roList")
    catch e
        t.assertTrue("lib.registry.getsectionlist: runtime error", false)
    end try

    t.spec("lib.registry.regflush", "CallExpression", "roRegistry Flush() persists registry")
    try
        reg = CreateObject("roRegistry")
        t.assertTrue("lib.registry.regflush", reg.Flush() = true)
    catch e
        t.assertTrue("lib.registry.regflush: runtime error", false)
    end try

    ' Cleanup: remove every key the registry specs wrote so the section is left
    ' empty (idempotent across runs). Best-effort; not itself a spec.
    lds_registry_cleanup()

    ' =====================================================================
    ' File I/O - ReadAsciiFile / WriteAsciiFile, roFileSystem, roPath
    ' (writable tmp:/ volume is device-safe; scratch file cleaned up)
    ' =====================================================================

    ' WriteAsciiFile then ReadAsciiFile is the canonical text round-trip and is
    ' fully deterministic.
    t.spec("lib.fs.writeasciifile", "CallExpression", "WriteAsciiFile(path,text) write text to tmp:/")
    try
        ok = WriteAsciiFile("tmp:/spec.txt", "hi")
        t.assertTrue("lib.fs.writeasciifile", ok = true)
    catch e
        t.assertTrue("lib.fs.writeasciifile: runtime error", false)
    end try

    t.spec("lib.fs.readasciifile", "CallExpression", "ReadAsciiFile(path) read back written text")
    try
        WriteAsciiFile("tmp:/spec.txt", "hi")
        t.assertEqual("lib.fs.readasciifile", ReadAsciiFile("tmp:/spec.txt"), "hi")
    catch e
        t.assertTrue("lib.fs.readasciifile: runtime error", false)
    end try

    t.spec("lib.fs.exists", "CallExpression", "roFileSystem Exists(path) on a written file")
    try
        WriteAsciiFile("tmp:/spec.txt", "hi")
        fs = CreateObject("roFileSystem")
        t.assertTrue("lib.fs.exists", fs.Exists("tmp:/spec.txt") = true)
    catch e
        t.assertTrue("lib.fs.exists: runtime error", false)
    end try

    t.spec("lib.fs.getvolumelist", "CallExpression", "roFileSystem GetVolumeList() -> roList/roArray")
    try
        fs = CreateObject("roFileSystem")
        r = fs.GetVolumeList()
        t.assertTrue("lib.fs.getvolumelist", Type(r) = "roList" or Type(r) = "roArray")
    catch e
        t.assertTrue("lib.fs.getvolumelist: runtime error", false)
    end try

    ' Delete the scratch file then confirm it no longer Exists (round-trip +
    ' cleanup in one).
    t.spec("lib.fs.delete", "CallExpression", "roFileSystem Delete(path) removes file")
    try
        WriteAsciiFile("tmp:/spec.txt", "hi")
        fs = CreateObject("roFileSystem")
        fs.Delete("tmp:/spec.txt")
        t.assertFalse("lib.fs.delete", fs.Exists("tmp:/spec.txt"))
    catch e
        t.assertTrue("lib.fs.delete: runtime error", false)
    end try

    ' roPath wraps a path string; IsValid validates the syntactic path.
    t.spec("lib.fs.path_isvalid", "CallExpression", "roPath IsValid() valid path string")
    try
        p = CreateObject("roPath", "pkg:/source/main.brs")
        t.assertTrue("lib.fs.path_isvalid", p.IsValid() = true)
    catch e
        t.assertTrue("lib.fs.path_isvalid: runtime error", false)
    end try

    ' roPath Split() decomposes a path into an AA (basename/parent/extension/...).
    t.spec("lib.fs.path_split", "CallExpression", "roPath Split() -> AA path components")
    try
        p = CreateObject("roPath", "pkg:/source/main.brs")
        r = p.Split()
        t.assertTrue("lib.fs.path_split", Type(r) = "roAssociativeArray")
    catch e
        t.assertTrue("lib.fs.path_split: runtime error", false)
    end try

    ' roPath Change() re-targets the wrapped path; IsValid stays true afterward.
    t.spec("lib.fs.path_change", "CallExpression", "roPath Change(newpath) re-target path")
    try
        p = CreateObject("roPath", "pkg:/source/main.brs")
        p.Change("pkg:/source/main.brs")
        t.assertTrue("lib.fs.path_change", p.IsValid() = true)
    catch e
        t.assertTrue("lib.fs.path_change: runtime error", false)
    end try
end sub

' ---------------------------------------------------------------------------
' Module-level helpers (lds_ prefix).
' ---------------------------------------------------------------------------

' Best-effort teardown of the dedicated "specHarness" registry section: delete
' every key the registry specs wrote and persist. Wrapped so a failure here can
' never abort the suite.
sub lds_registry_cleanup()
    try
        sec = CreateObject("roRegistrySection", "specHarness")
        sec.Delete("k")
        sec.Delete("rk")
        sec.Delete("fk")
        sec.Delete("ek")
        sec.Delete("lk")
        sec.Delete("dk")
        sec.Delete("sk")
        sec.Flush()
    catch e
        ' swallow: cleanup is non-fatal
    end try
end sub
