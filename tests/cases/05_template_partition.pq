// Evaluates the template's shipped 'Filtered Test Runs' partition M (template/source/partitions) on the real engine
// with synthetic upstream tables, with and without a 1.1.0.2 connector navigation item.
let
    partitionText = {{FILE:template/source/partitions/Filtered Test Runs.m}},
    run = (id, ty) => [id = id, type = ty],
    testRuns = Table.FromRecords({run("L1", "LoadTest"), run("F1", "LoadTest"), run("O1", "LoadTest"), run("C1", "ContinuousTest"), run("A1", "ApplicationTest")}),
    fact = (ids) => Table.FromRecords(List.Transform(ids, each [testRunId = _])),
    navWith = Table.FromRecords({[Name = "Test Runs In Window", Data = Table.FromRecords({[id = "L1"], [id = "F1"], [id = "C1"], [id = "A1"]})]}),
    navWithout = Table.FromRecords({[Name = "Tests", Data = #table({"id"}, {})]}),
    envFor = (nav) => #shared & [
        #"Test Runs" = testRuns,
        Measurements = fact({"L1"}),
        Events = fact({}),
        #"User Sessions" = fact({}),
        #"User Session Metrics" = fact({}),
        #"Aggregated EUX Results" = fact({}),
        FQDN = "x", APIToken = "y", DaysBack = null, UseDateRange = null, StartDateParam = null, EndDateParam = null,
        LoginEnterprise_PBI.Contents = (a, b, c, d, e, f) => nav
    ],
    ids = (nav) => List.Sort(Table.Column(Expression.Evaluate(partitionText, envFor(nav)), "id")),
    T = LoginEnterprise_PBI.TestExports
in
    T[Run]({
        T[Check]("1.1.0.2 connector: failed run with no data (F1) and no-measurement app run (A1) stay; run outside window (O1) dropped; all Continuous kept",
            () => ids(navWith) = {"A1", "C1", "F1", "L1"}),
        T[Check]("older connector (no nav item): previous behaviour, data-presence only", () => ids(navWithout) = {"C1", "L1"}),
        T[Check]("type is still normalised to lowercase for measures", () => List.Contains(Table.Column(Expression.Evaluate(partitionText, envFor(navWith)), "type"), "loadtest"))
    })
