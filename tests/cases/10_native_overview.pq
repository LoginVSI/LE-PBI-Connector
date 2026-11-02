// Native whole-run overview (GET load-test-run-overview/{id}) versus aggregate EUX buckets.
// Fixtures mirror observed shapes (8.2/8.4/8.3, a disabled-EUX run with null results) but contain no appliance data.
let
    T = LoginEnterprise_PBI.TestExports,
    run = (id, ty, s, f) => T[Run_](id, ty, s, f),
    L1 = run("L1", "LoadTest", "2026-10-20T10:00:00Z", "2026-10-20T10:30:00Z"),
    L2 = run("L2", "LoadTest", "2026-10-20T11:00:00Z", "2026-10-20T11:30:00Z"),
    L3 = run("L3", "LoadTest", "2026-10-20T12:00:00Z", "2026-10-20T12:30:00Z"),
    L4 = run("L4", "LoadTest", "2026-10-20T13:00:00Z", "2026-10-20T13:30:00Z"),
    LO = run("LO", "LoadTest", "2026-08-01T10:00:00Z", "2026-08-01T10:30:00Z"),
    A1 = run("A1", "ApplicationTest", "2026-10-20T14:00:00Z", "2026-10-20T14:01:00Z"),
    C1 = run("C1", "ContinuousTest", "2026-10-01T00:00:00Z", null),
    window = T[Window](null, true, #date(2026, 10, 20), #date(2026, 10, 20), #datetimezone(2026, 10, 22, 12, 0, 0, 0, 0)),
    O = T[Overview],
    data = T[EmptyData] & [
        runs = {L1, L2, L3, L4, LO, A1, C1},
        eux = [L1 = {[timestamp = "2026-10-20T10:05:00Z", score = 7.9, count = 10], [timestamp = "2026-10-20T11:00:00Z", score = 8.4, count = 23]}],
        overview = [
            L1 = O("L1", "completed", "aboveThreshold", {{"eux_steady_state", 8.3}, {"eux_baseline", 8.4}, {"eux_score", 8.2}, {"vsi_max", 6.0}}),
            L2 = O("L2", "disabled", "disabled", {{"eux_steady_state", null}, {"eux_baseline", null}, {"eux_score", null}, {"vsi_max", null}}),
            L3 = O("L3", "completed", "belowThreshold", {{"eux_score", 0}, {"vsi_max", 0}})
        ]
    ],
    guarded = (route, q, a) =>
        if Text.StartsWith(route, "load-test-run-overview/") and not List.Contains({"L1", "L2", "L3", "L4"}, Text.AfterDelimiter(route, "/"))
            then T[Raw](500, "overview must only be requested for Load runs overlapping the window: " & route)
        else T[Router](data)(route, q, a),
    ctx = T[FakeCtx](guarded, null),
    runsRaw = T[GetTestRunsRaw](ctx),
    ov = T[GetLoadTestOverview](ctx, runsRaw, window),
    rowOf = (id) => Table.SelectRows(ov, each [testRunId] = id){0},
    aggregate = T[GetAggregatedEUXResults](ctx, runsRaw, window),
    aggMean = List.Average(Table.Column(Table.SelectRows(aggregate, each [testRunId] = "L1"), "score")),
    nav = T[Core](ctx, window),
    single = (body) => T[GetLoadTestOverview](T[FakeCtx]((r, q, a) => if Text.StartsWith(r, "load-test-run-overview/") then T[Ok](body) else T[Router](data)(r, q, a), null), {L1}, window)
in
    T[Run]({
        T[Check]("columns and order are the documented set", () => Table.ColumnNames(ov) = {"testRunId", "testName", "counter", "isBase", "state", "testResult", "euxState", "vsiMaxState", "euxScore", "euxBaseline", "euxSteadyState", "vsiMax"}),
        T[Check]("only Load runs overlapping the window with an overview produce rows (L1, L2, L3; L4 is 404, LO/A1/C1 never requested)", () => List.Sort(Table.Column(ov, "testRunId")) = {"L1", "L2", "L3"}),
        T[Check]("native values are taken verbatim: score 8.2, baseline 8.4, steady 8.3, vsiMax 6", () => let r = rowOf("L1") in r[euxScore] = 8.2 and r[euxBaseline] = 8.4 and r[euxSteadyState] = 8.3 and r[vsiMax] = 6),
        T[Check]("states are carried", () => let r = rowOf("L1") in r[euxState] = "completed" and r[vsiMaxState] = "aboveThreshold" and r[state] = "completed" and r[testResult] = "completed" and r[isBase] = true),
        T[Check]("native overall differs from the unweighted aggregate mean (distinction is real, not recomputed)", () => aggMean = 8.15 and rowOf("L1")[euxScore] <> aggMean),
        T[Check]("disabled EUX run: every metric stays null (not 0) and states are preserved", () => let r = rowOf("L2") in r[euxScore] = null and r[euxBaseline] = null and r[euxSteadyState] = null and r[vsiMax] = null and r[euxState] = "disabled"),
        T[Check]("valid zero is kept as 0, absent metric stays null", () => let r = rowOf("L3") in r[euxScore] = 0 and r[vsiMax] = 0 and r[euxBaseline] = null),
        T[Check]("native rows do not depend on aggregate rows being in the window (L2 has none)", () => Table.RowCount(Table.SelectRows(aggregate, each [testRunId] = "L2")) = 0 and Table.RowCount(Table.SelectRows(ov, each [testRunId] = "L2")) = 1),
        T[Check]("one row per run (no duplication)", () => Table.RowCount(ov) = 3 and List.Count(List.Distinct(Table.Column(ov, "testRunId"))) = 3),
        T[Check]("navigation: new item is last and existing eleven keys are untouched", () => List.Last(Table.Column(nav, "Name")) = "Load Test Overview" and List.FirstN(Table.Column(nav, "Name"), 12) = {"Environments", "Platform Metrics", "Tests", "Test Runs", "Workload Steps", "Aggregated EUX Results", "Applications", "Measurements", "Events", "User Sessions", "User Session Metrics", "Test Runs In Window"}),
        T[Check]("empty tenant yields a typed empty overview", () => Table.RowCount(T[Core](T[FakeCtx](T[Router](T[EmptyData]), null), window){[Name = "Load Test Overview"]}[Data]) = 0),
        T[CheckError]("HTTP 500 fails the refresh (no partial overview)", () => Table.RowCount(T[GetLoadTestOverview](T[FakeCtx]((r, q, a) => T[Raw](500, "boom"), null), {L1}, window)), "HTTP 500"),
        T[CheckError]("authentication failure is reported", () => Table.RowCount(T[GetLoadTestOverview](T[FakeCtx]((r, q, a) => T[Raw](401, "no"), null), {L1}, window)), "Authentication failed"),
        T[CheckError]("non-numeric metric value is an error, not a silent zero/null", () => Table.ToRows(single(O("L1", "completed", "x", {{"eux_score", "high"}}))){0}{8}, "Non-numeric"),
        T[CheckError]("duplicate result id is an error", () => Table.ToRows(single(O("L1", "completed", "x", {{"eux_score", 1}, {"eux_score", 2}}))){0}{8}, "Duplicate result"),
        T[CheckError]("response for a different run is an error", () => Table.RowCount(single(O("OTHER", "completed", "x", {{"eux_score", 1}}))), "did not contain the requested run"),
        T[CheckError]("unexpected response shape is an error", () => Table.RowCount(single([unexpected = true])), "Unexpected response shape"),
        T[Check]("missing performance block yields null scores without failing", () => Table.RowCount(single([results = {[testRunId = "L1", testName = "n", counter = 1, isBase = true, state = "completed", testResult = "aborted"]}])) = 1 and single([results = {[testRunId = "L1", state = "completed", testResult = "aborted"]}]){0}[euxScore] = null),
        T[Check]("run id match is case-insensitive", () => Table.RowCount(T[GetLoadTestOverview](T[FakeCtx]((r, q, a) => T[Ok](O("l1", "completed", "x", {{"eux_score", 5}})), null), {run("L1", "LoadTest", "2026-10-20T10:00:00Z", "2026-10-20T10:30:00Z")}, window)) = 1)
    })
