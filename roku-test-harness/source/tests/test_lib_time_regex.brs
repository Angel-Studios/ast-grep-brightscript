' test_lib_time_regex.brs - STANDARD-LIBRARY coverage of the date/time and
' regular-expression component objects: roDateTime, roTimespan, roRegex.
'
' These are the stdlib LEAVES (layer:"stdlib") of the future tree-sitter grammar
' corpus: each is exercised as a CallExpression (a method call on a CreateObject
' instance) and asserted against its device-observed result. The leaves live in
' grammar/coverage_frags/time_regex.json (a fragment the orchestrator merges into
' coverage.json after device validation).
'
' Each t.spec id/kind matches time_regex.json VERBATIM. Every spec's exercise is
' wrapped in try/catch: the harness runs the whole suite in one pass, so an
' uncaught runtime error (a wrong API name/signature) would abort EVERYTHING.
' Wrapping turns a bad call into a single FAIL, not a crash, and lets the
' orchestrator see exactly which leaf diverged.
'
' Determinism:
'   - roDateTime / roTimespan read the device wall clock / monotonic timer, so
'     their results are NONDETERMINISTIC: assert only NotInvalid / numeric type /
'     a valid calendar range (e.g. month in 1..12). These carry expect:"parse".
'   - roRegex is DETERMINISTIC for a fixed pattern + input, so its specs assert
'     exact values (expect:"value:X").

sub test_lib_time_regex_all(t as Object)
    ' =====================================================================
    ' roDateTime  (CreateObject("roDateTime") -> ifDateTime)
    ' Time values come from the device clock => nondeterministic => "parse".
    ' Mark() snapshots "now" into the object; the getters then read that
    ' snapshot. We re-Mark before each getter so every spec is self-contained.
    ' =====================================================================

    t.spec("lib.datetime.mark", "CallExpression", "roDateTime Mark() snapshot current time")
    try
        dt = CreateObject("roDateTime")
        dt.Mark()
        t.assertNotInvalid("lib.datetime.mark", dt)
    catch e
        t.assertTrue("lib.datetime.mark: runtime error", false)
    end try

    t.spec("lib.datetime.asseconds", "CallExpression", "roDateTime AsSeconds() epoch seconds (int)")
    try
        dt = CreateObject("roDateTime")
        dt.Mark()
        r = dt.AsSeconds()
        t.assertTrue("lib.datetime.asseconds: numeric", ltr_is_numeric(r))
        t.assertTrue("lib.datetime.asseconds: positive", r > 0)
    catch e
        t.assertTrue("lib.datetime.asseconds: runtime error", false)
    end try

    t.spec("lib.datetime.assecondslong", "CallExpression", "roDateTime AsSecondsLong() epoch seconds (longinteger)")
    try
        dt = CreateObject("roDateTime")
        dt.Mark()
        r = dt.AsSecondsLong()
        t.assertTrue("lib.datetime.assecondslong: numeric", ltr_is_numeric(r))
        t.assertTrue("lib.datetime.assecondslong: positive", r > 0)
    catch e
        t.assertTrue("lib.datetime.assecondslong: runtime error", false)
    end try

    t.spec("lib.datetime.gethours", "CallExpression", "roDateTime GetHours() 0..23")
    try
        dt = CreateObject("roDateTime")
        dt.Mark()
        r = dt.GetHours()
        t.assertTrue("lib.datetime.gethours: range", r >= 0 and r <= 23)
    catch e
        t.assertTrue("lib.datetime.gethours: runtime error", false)
    end try

    t.spec("lib.datetime.getminutes", "CallExpression", "roDateTime GetMinutes() 0..59")
    try
        dt = CreateObject("roDateTime")
        dt.Mark()
        r = dt.GetMinutes()
        t.assertTrue("lib.datetime.getminutes: range", r >= 0 and r <= 59)
    catch e
        t.assertTrue("lib.datetime.getminutes: runtime error", false)
    end try

    t.spec("lib.datetime.getseconds", "CallExpression", "roDateTime GetSeconds() 0..60 (leap)")
    try
        dt = CreateObject("roDateTime")
        dt.Mark()
        r = dt.GetSeconds()
        t.assertTrue("lib.datetime.getseconds: range", r >= 0 and r <= 60)
    catch e
        t.assertTrue("lib.datetime.getseconds: runtime error", false)
    end try

    t.spec("lib.datetime.getmilliseconds", "CallExpression", "roDateTime GetMilliseconds() 0..999")
    try
        dt = CreateObject("roDateTime")
        dt.Mark()
        r = dt.GetMilliseconds()
        t.assertTrue("lib.datetime.getmilliseconds: range", r >= 0 and r <= 999)
    catch e
        t.assertTrue("lib.datetime.getmilliseconds: runtime error", false)
    end try

    t.spec("lib.datetime.getdayofweek", "CallExpression", "roDateTime GetDayOfWeek() 0..6 (0=Sun)")
    try
        dt = CreateObject("roDateTime")
        dt.Mark()
        r = dt.GetDayOfWeek()
        t.assertTrue("lib.datetime.getdayofweek: range", r >= 0 and r <= 6)
    catch e
        t.assertTrue("lib.datetime.getdayofweek: runtime error", false)
    end try

    t.spec("lib.datetime.getdayofmonth", "CallExpression", "roDateTime GetDayOfMonth() 1..31")
    try
        dt = CreateObject("roDateTime")
        dt.Mark()
        r = dt.GetDayOfMonth()
        t.assertTrue("lib.datetime.getdayofmonth: range", r >= 1 and r <= 31)
    catch e
        t.assertTrue("lib.datetime.getdayofmonth: runtime error", false)
    end try

    t.spec("lib.datetime.getmonth", "CallExpression", "roDateTime GetMonth() 1..12")
    try
        dt = CreateObject("roDateTime")
        dt.Mark()
        r = dt.GetMonth()
        t.assertTrue("lib.datetime.getmonth: range", r >= 1 and r <= 12)
    catch e
        t.assertTrue("lib.datetime.getmonth: runtime error", false)
    end try

    t.spec("lib.datetime.getyear", "CallExpression", "roDateTime GetYear() full year >= 1970")
    try
        dt = CreateObject("roDateTime")
        dt.Mark()
        r = dt.GetYear()
        t.assertTrue("lib.datetime.getyear: range", r >= 1970)
    catch e
        t.assertTrue("lib.datetime.getyear: runtime error", false)
    end try

    t.spec("lib.datetime.getweekday", "CallExpression", "roDateTime GetWeekday() day name string")
    try
        dt = CreateObject("roDateTime")
        dt.Mark()
        r = dt.GetWeekday()
        t.assertTrue("lib.datetime.getweekday: string", ltr_is_string(r))
        t.assertTrue("lib.datetime.getweekday: nonempty", Len(r) > 0)
    catch e
        t.assertTrue("lib.datetime.getweekday: runtime error", false)
    end try

    t.spec("lib.datetime.toisostring", "CallExpression", "roDateTime ToISOString() ISO-8601 string")
    try
        dt = CreateObject("roDateTime")
        dt.Mark()
        r = dt.ToISOString()
        t.assertTrue("lib.datetime.toisostring: string", ltr_is_string(r))
        t.assertTrue("lib.datetime.toisostring: nonempty", Len(r) > 0)
    catch e
        t.assertTrue("lib.datetime.toisostring: runtime error", false)
    end try

    t.spec("lib.datetime.gettimezoneoffset", "CallExpression", "roDateTime GetTimeZoneOffset() minutes offset")
    try
        dt = CreateObject("roDateTime")
        dt.Mark()
        r = dt.GetTimeZoneOffset()
        t.assertTrue("lib.datetime.gettimezoneoffset: numeric", ltr_is_numeric(r))
    catch e
        t.assertTrue("lib.datetime.gettimezoneoffset: runtime error", false)
    end try

    ' ToLocalTime() mutates the object in place (UTC -> local); after it, the
    ' getters still return valid calendar values. We assert it does not blow up
    ' and the hour stays in range.
    t.spec("lib.datetime.tolocaltime", "CallExpression", "roDateTime ToLocalTime() shift to local zone")
    try
        dt = CreateObject("roDateTime")
        dt.Mark()
        dt.ToLocalTime()
        r = dt.GetHours()
        t.assertTrue("lib.datetime.tolocaltime: hours range", r >= 0 and r <= 23)
    catch e
        t.assertTrue("lib.datetime.tolocaltime: runtime error", false)
    end try

    ' FromISO8601String(s) parses an ISO-8601 string into the object. We round
    ' trip a known-good Mark()ed value back through it and assert it stays valid.
    t.spec("lib.datetime.fromiso8601string", "CallExpression", "roDateTime FromISO8601String(s) parse ISO-8601")
    try
        dt = CreateObject("roDateTime")
        dt.Mark()
        iso = dt.ToISOString()
        dt2 = CreateObject("roDateTime")
        dt2.FromISO8601String(iso)
        r = dt2.GetYear()
        t.assertTrue("lib.datetime.fromiso8601string: year", r >= 1970)
    catch e
        t.assertTrue("lib.datetime.fromiso8601string: runtime error", false)
    end try

    ' =====================================================================
    ' roTimespan  (CreateObject("roTimespan") -> ifTimespan)
    ' A monotonic stopwatch; Mark() resets the start point and returns the ms
    ' since the previous Mark. All readings are device-timer dependent =>
    ' nondeterministic => "parse" (assert numeric / NotInvalid / non-negative).
    ' =====================================================================

    ' DEVICE FACT: roTimespan.Mark() RESETS the start point and returns void (NOT
    ' the elapsed ms); TotalMilliseconds() reads the elapsed time since the mark.
    t.spec("lib.timespan.mark", "CallExpression", "roTimespan Mark() resets the start point")
    try
        ts = CreateObject("roTimespan")
        ts.Mark()
        ms = ts.TotalMilliseconds()
        t.assertTrue("lib.timespan.mark: TotalMilliseconds numeric", ltr_is_numeric(ms))
        t.assertTrue("lib.timespan.mark: nonneg", ms >= 0)
    catch e
        t.assertTrue("lib.timespan.mark: runtime error", false)
    end try

    t.spec("lib.timespan.totalmilliseconds", "CallExpression", "roTimespan TotalMilliseconds() ms since last mark")
    try
        ts = CreateObject("roTimespan")
        ts.Mark()
        r = ts.TotalMilliseconds()
        t.assertTrue("lib.timespan.totalmilliseconds: numeric", ltr_is_numeric(r))
        t.assertTrue("lib.timespan.totalmilliseconds: nonneg", r >= 0)
    catch e
        t.assertTrue("lib.timespan.totalmilliseconds: runtime error", false)
    end try

    t.spec("lib.timespan.totalseconds", "CallExpression", "roTimespan TotalSeconds() seconds since last mark")
    try
        ts = CreateObject("roTimespan")
        ts.Mark()
        r = ts.TotalSeconds()
        t.assertTrue("lib.timespan.totalseconds: numeric", ltr_is_numeric(r))
        t.assertTrue("lib.timespan.totalseconds: nonneg", r >= 0)
    catch e
        t.assertTrue("lib.timespan.totalseconds: runtime error", false)
    end try

    ' =====================================================================
    ' roRegex  (CreateObject("roRegex", pattern, flags) -> ifRegex)
    ' Deterministic for a fixed pattern + input => exact-value assertions.
    ' Patterns use BrightScript string literals: a backslash is LITERAL (no
    ' escape sequences in BrightScript strings), so "\d+" is the 3-char source
    ' the regex engine compiles to "one-or-more digits".
    ' =====================================================================

    t.spec("lib.regex.ismatch", "CallExpression", "roRegex IsMatch(s) -> Boolean")
    try
        rx = CreateObject("roRegex", "\d+", "")
        t.assertTrue("lib.regex.ismatch: hit", rx.IsMatch("abc123"))
        t.assertFalse("lib.regex.ismatch: miss", rx.IsMatch("abcdef"))
    catch e
        t.assertTrue("lib.regex.ismatch: runtime error", false)
    end try

    ' Flags string "i" => case-insensitive matching.
    t.spec("lib.regex.flags_ignorecase", "CallExpression", "roRegex case-insensitive flag ""i""")
    try
        rx = CreateObject("roRegex", "hello", "i")
        t.assertTrue("lib.regex.flags_ignorecase", rx.IsMatch("HELLO"))
    catch e
        t.assertTrue("lib.regex.flags_ignorecase: runtime error", false)
    end try

    ' Match(s) returns an roArray: [whole match, group1, group2, ...]. With one
    ' capture group, element 0 is the full match and element 1 is the group.
    t.spec("lib.regex.match", "CallExpression", "roRegex Match(s) -> roArray of groups")
    try
        rx = CreateObject("roRegex", "(\d+)-(\d+)", "")
        m = rx.Match("on 12-34 end")
        t.assertTrue("lib.regex.match: is array", Type(m) = "roArray")
        t.assertEqual("lib.regex.match: whole", m[0], "12-34")
        t.assertEqual("lib.regex.match: group1", m[1], "12")
        t.assertEqual("lib.regex.match: group2", m[2], "34")
    catch e
        t.assertTrue("lib.regex.match: runtime error", false)
    end try

    ' Match on no hit returns an empty roArray (count 0).
    t.spec("lib.regex.match_nohit", "CallExpression", "roRegex Match(s) no match -> empty roArray")
    try
        rx = CreateObject("roRegex", "\d+", "")
        m = rx.Match("none here")
        t.assertTrue("lib.regex.match_nohit: is array", Type(m) = "roArray")
        t.assertEqual("lib.regex.match_nohit: empty", m.Count(), 0)
    catch e
        t.assertTrue("lib.regex.match_nohit: runtime error", false)
    end try

    ' MatchAll(s) returns an roArray of matches, each itself an roArray of groups.
    t.spec("lib.regex.matchall", "CallExpression", "roRegex MatchAll(s) -> roArray of match-arrays")
    try
        rx = CreateObject("roRegex", "\d+", "")
        all = rx.MatchAll("a1 b22 c333")
        t.assertTrue("lib.regex.matchall: is array", Type(all) = "roArray")
        t.assertEqual("lib.regex.matchall: count", all.Count(), 3)
        t.assertEqual("lib.regex.matchall: first", all[0][0], "1")
        t.assertEqual("lib.regex.matchall: third", all[2][0], "333")
    catch e
        t.assertTrue("lib.regex.matchall: runtime error", false)
    end try

    ' Replace(s, repl) replaces the FIRST match only.
    t.spec("lib.regex.replace", "CallExpression", "roRegex Replace(s,repl) first match")
    try
        rx = CreateObject("roRegex", "\d+", "")
        r = rx.Replace("a1b2c3", "#")
        t.assertEqual("lib.regex.replace", r, "a#b2c3")
    catch e
        t.assertTrue("lib.regex.replace: runtime error", false)
    end try

    ' ReplaceAll(s, repl) replaces EVERY match.
    t.spec("lib.regex.replaceall", "CallExpression", "roRegex ReplaceAll(s,repl) every match")
    try
        rx = CreateObject("roRegex", "\d+", "")
        r = rx.ReplaceAll("a1b2c3", "#")
        t.assertEqual("lib.regex.replaceall", r, "a#b#c#")
    catch e
        t.assertTrue("lib.regex.replaceall: runtime error", false)
    end try

    ' Split(s) splits the string on the pattern, returning an roArray of pieces.
    ' Split(s) splits on the pattern. Assert type-agnostically (Count + for-each)
    ' so it passes whether the device returns an roArray or an roList.
    t.spec("lib.regex.split", "CallExpression", "roRegex Split(s) -> list of pieces")
    try
        rx = CreateObject("roRegex", ",", "")
        parts = rx.Split("a,b,c")
        t.assertNotInvalid("lib.regex.split: not invalid", parts)
        t.assertEqual("lib.regex.split: count", parts.Count(), 3)
        first = invalid
        for each p in parts
            first = p
            exit for
        end for
        t.assertEqual("lib.regex.split: first", first, "a")
    catch e
        t.assertTrue("lib.regex.split: runtime error", false)
    end try
end sub

' ---------------------------------------------------------------------------
' Module-level helpers (uniquely named, ltr_ prefix) for the nondeterministic
' time leaves: kind checks across the boxed/intrinsic boundary (component method
' results are BOXED scalars - see grammar/DEVICE_FACTS.md runtime observations).
' ---------------------------------------------------------------------------

' True if v is any numeric kind (intrinsic or boxed integer/long/float/double).
function ltr_is_numeric(v as Dynamic) as Boolean
    t = Type(v)
    return t = "Integer" or t = "roInteger" or t = "roInt" or t = "Float" or t = "roFloat" or t = "Double" or t = "roDouble" or t = "LongInteger" or t = "roLongInteger"
end function

' True if v is a string kind (intrinsic String or boxed roString).
function ltr_is_string(v as Dynamic) as Boolean
    t = Type(v)
    return t = "String" or t = "roString"
end function
