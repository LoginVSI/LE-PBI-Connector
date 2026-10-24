// Date policy: UTC calendar days, half-open [start 00:00Z, end+1 00:00Z); rolling vs fixed; validation; run selection.
let
    T = LoginEnterprise_PBI.TestExports,
    now = #datetimezone(2026, 10, 20, 17, 0, 0, 0, 0),
    W = (d, u, s, e, n) => T[Window](d, u, s, e, n),
    r30 = W(30, false, null, null, now),
    single = W(null, true, #date(2026, 10, 20), #date(2026, 10, 20), now),
    dstFall = W(null, true, #date(2026, 10, 31), #date(2026, 11, 2), now),
    dstSpring = W(null, true, #date(2026, 3, 7), #date(2026, 3, 9), now),
    // 2026-10-20 20:00 at UTC-7 is already 2026-10-21 03:00 UTC: UTC policy => today is the 21st.
    westLate = W(1, false, null, null, #datetimezone(2026, 10, 20, 20, 0, 0, -7, 0)),
    // same instant expressed in UTC+12
    eastEarly = W(1, false, null, null, #datetimezone(2026, 10, 21, 15, 0, 0, 12, 0)),
    run = (id, ty, s, f) => T[Run_](id, ty, s, f),
    runs = {
        run("ongoingCont", "ContinuousTest", "2026-09-01T00:00:00Z", null),
        run("finishedBefore", "LoadTest", "2026-08-01T00:00:00Z", "2026-08-01T01:00:00Z"),
        run("startsAfter", "LoadTest", "2026-10-22T00:00:00Z", "2026-10-22T01:00:00Z"),
        run("neverStarted", "LoadTest", null, null),
        run("inside", "ApplicationTest", "2026-10-20T10:00:00Z", "2026-10-20T10:05:00Z"),
        run("endsExactlyAtStart", "LoadTest", "2026-10-19T00:00:00Z", "2026-10-20T00:00:00Z"),
        run("startsExactlyAtEnd", "LoadTest", "2026-10-21T00:00:00Z", "2026-10-21T00:10:00Z")
    },
    ids = (rs) => List.Transform(rs, each _[id]),
    sel = ids(T[RunsInWindow](runs, single, null)),
    selLoadCont = ids(T[RunsInWindow](runs, single, {"loadtest", "continuoustest"}))
in
    T[Run]({
        T[Check]("rolling 30 => 31 UTC days incl. today", () => r30[DayCount] = 31 and r30[StartDate] = #date(2026, 9, 20) and r30[EndDate] = #date(2026, 10, 20)),
        T[Check]("rolling end day is fully included (To = next midnight)", () => r30[FromText] = "2026-09-20T00:00:00Z" and r30[ToText] = "2026-10-21T00:00:00Z"),
        T[Check]("today's data included: To is after 'now'", () => r30[To19] > "2026-10-20T17:00:00"),
        T[Check]("mode flags", () => r30[Mode] = "Rolling" and single[Mode] = "FixedRange"),
        T[Check]("single selected end day = exactly 24h half-open", () => single[DayCount] = 1 and single[FromText] = "2026-10-20T00:00:00Z" and single[ToText] = "2026-10-21T00:00:00Z"),
        T[Check]("DST fall-back range is 3 contiguous UTC days", () => dstFall[DayCount] = 3 and dstFall[FromText] = "2026-10-31T00:00:00Z" and dstFall[ToText] = "2026-11-03T00:00:00Z"),
        T[Check]("DST spring-forward range is 3 contiguous UTC days", () => dstSpring[DayCount] = 3 and dstSpring[FromText] = "2026-03-07T00:00:00Z" and dstSpring[ToText] = "2026-03-10T00:00:00Z"),
        T[Check]("per-day windows tile with no gap/overlap across DST", () =>
            List.Transform(dstFall[Days], each T[WindowDay](_)[ToText]) = {"2026-11-01T00:00:00Z", "2026-11-02T00:00:00Z", "2026-11-03T00:00:00Z"}
            and List.Transform(dstFall[Days], each T[WindowDay](_)[FromText]) = {"2026-10-31T00:00:00Z", "2026-11-01T00:00:00Z", "2026-11-02T00:00:00Z"}),
        T[Check]("local offset does not change 'today' (same instant, UTC-7 vs UTC+12)", () => westLate[EndDate] = #date(2026, 10, 21) and eastEarly[EndDate] = #date(2026, 10, 21)),
        T[Check]("DaysBack ignored when fixed range is used", () => single[StartDate] = #date(2026, 10, 20)),
        T[Check]("dates ignored in rolling mode", () => W(7, false, #date(2000, 1, 1), #date(2000, 1, 2), now)[StartDate] = #date(2026, 10, 13)),
        T[Check]("DaysBack null defaults to 30", () => W(null, false, null, null, now)[DayCount] = 31),
        T[CheckError]("reversed range is rejected", () => W(null, true, #date(2026, 10, 21), #date(2026, 10, 20), now), "after End Date"),
        T[CheckError]("partial range (no end) is rejected, not widened", () => W(null, true, #date(2026, 10, 1), null, now), "not both set"),
        T[CheckError]("partial range (no start) is rejected, not widened", () => W(null, true, null, #date(2026, 10, 1), now), "not both set"),
        T[CheckError]("DaysBack 0 rejected", () => W(0, false, null, null, now), "Days Back"),
        T[CheckError]("DaysBack fractional rejected", () => W(1.5, false, null, null, now), "Days Back"),
        T[Check]("rolling 365 is the maximum 366-day window", () => W(365,false,null,null,now)[DayCount]=366),
        T[CheckError]("rolling 366 is rejected consistently", () => W(366,false,null,null,now), "1 and 365"),
        T[CheckError]("DaysBack too large rejected", () => W(400, false, null, null, now), "Days Back"),
        T[CheckError]("range longer than 366 days rejected", () => W(null, true, #date(2024, 1, 1), #date(2026, 1, 1), now), "maximum"),
        T[Check]("typed timestamps preserve refreshing-machine local conversion", () => Table.TransformColumnTypes(#table({"t"},{{"2026-10-20T00:00:00Z"}}),{{"t",type datetime}}){0}[t] = DateTimeZone.RemoveZone(DateTimeZone.ToLocal(DateTimeZone.FromText("2026-10-20T00:00:00Z")))),
        T[Check]("TextToUtc19 Z", () => T[TimeTextToUtc19]("2026-10-20T10:00:00Z") = "2026-10-20T10:00:00"),
        T[Check]("TextToUtc19 fractional Z", () => T[TimeTextToUtc19]("2026-10-20T10:00:00.1234567Z") = "2026-10-20T10:00:00"),
        T[Check]("TextToUtc19 offset", () => T[TimeTextToUtc19]("2026-10-20T03:00:00-07:00") = "2026-10-20T10:00:00"),
        T[Check]("TextToUtc19 no zone treated as UTC", () => T[TimeTextToUtc19]("2026-10-20T10:00:00") = "2026-10-20T10:00:00"),
        T[Check]("TextToUtc19 null/blank", () => T[TimeTextToUtc19](null) = null and T[TimeTextToUtc19]("") = null),
        T[Check]("run selection: ongoing continuous, inside, boundary-touching start; excludes finished-before/after/never-started",
            () => sel = {"ongoingCont", "inside", "endsExactlyAtStart"}),
        T[Check]("terminal startup failure uses created when started is missing", () => List.Count(T[RunsInWindow]({T[Run_]("failed", "ApplicationTest", null, "2026-10-20T10:01:00Z") & [created="2026-10-20T10:00:00Z"]},single,null))=1),
        T[Check]("run selection by type is case-insensitive", () => selLoadCont = {"ongoingCont", "endsExactlyAtStart"})
    })
