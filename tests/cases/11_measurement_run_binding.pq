// Measurement rows must be bound to the run they were requested for, not to whatever testRunId the payload carries.
// A payload that omits or contradicts testRunId would otherwise detach rows from Filtered Test Runs in the model.
let
    T = LoginEnterprise_PBI.TestExports,
    L1 = T[Run_]("L1", "LoadTest", "2026-10-20T10:00:00Z", "2026-10-20T10:30:00Z"),
    good = T[Measurement]("L1", 1, "2026-10-20T10:00:10Z"),
    wrong = T[Measurement]("L1", 2, "2026-10-20T10:00:20Z") & [testRunId = "SOME-OTHER-RUN"],
    missing = Record.RemoveFields(T[Measurement]("L1", 3, "2026-10-20T10:00:30Z"), {"testRunId"}),
    router = (route, q, a) =>
        if route = "test-runs/L1/measurements" then T[Ok](T[Page]({good, wrong, missing}, q))
        else T[Raw](404, "not found: " & route),
    window = T[Window](null, true, #date(2026, 10, 20), #date(2026, 10, 20), #datetimezone(2026, 10, 22, 12, 0, 0, 0, 0)),
    meas = T[GetMeasurements](T[FakeCtx](router, null), {L1}, window)
in
    T[Run]({
        T[Check]("all three measurement rows are returned", () => Table.RowCount(meas) = 3),
        T[Check]("every row carries the requested run id (payload omitted or contradicting testRunId is overridden)", () => List.Distinct(Table.Column(meas, "testRunId")) = {"L1"})
    })
