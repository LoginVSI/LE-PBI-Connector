// Measurement acquisition (>1000/day, midnight boundaries, ongoing Continuous, zero values, empty runs)
// and full navigation-table assembly with schema/compatibility checks.
let
    T = LoginEnterprise_PBI.TestExports,
    run = (id, ty, s, f) => T[Run_](id, ty, s, f),
    L1 = run("L1", "LoadTest", "2026-10-20T10:00:00Z", "2026-10-20T10:30:00Z"),
    C1 = run("C1", "ContinuousTest", "2026-10-01T00:00:00Z", null),
    A1 = run("A1", "ApplicationTest", "2026-10-20T11:00:00Z", "2026-10-20T11:01:00Z"),
    F1 = run("F1", "LoadTest", "2026-10-20T12:00:00Z", "2026-10-20T12:05:00Z"),
    O1 = run("O1", "LoadTest", "2026-08-01T00:00:00Z", "2026-08-01T01:00:00Z"),
    secondsAfter = (n) => DateTime.ToText(#datetime(2026, 10, 20, 10, 0, 0) + #duration(0, 0, 0, n), [Format = "yyyy-MM-ddTHH:mm:ss", Culture = "en-US"]) & "Z",
    l1m = List.Transform({0 .. 2499}, each T[Measurement]("L1", _, secondsAfter(_))),
    c1m = {
        T[Measurement]("C1", 9001, "2026-10-19T23:59:59Z"),
        T[Measurement]("C1", 9002, "2026-10-20T00:00:00Z"),
        T[Measurement]("C1", 9003, "2026-10-20T12:00:00Z"),
        T[Measurement]("C1", 9004, "2026-10-21T00:00:00Z"),
        T[Measurement]("C1", 9005, "2026-10-21T23:59:59Z"),
        T[Measurement]("C1", 9006, "2026-10-22T00:00:00Z")
    },
    a1m = {T[Measurement]("A1", 8001, "2026-10-20T11:00:10Z") & [duration = 0], T[Measurement]("A1", 8002, "2026-10-20T11:00:20Z")},
    data = T[EmptyData] & [
        tests = {[id = "t-LoadTest", name = "Load", type = "LoadTest", environmentKey = "env1"], [id = "t-ContinuousTest", name = "Cont", type = "ContinuousTest", environmentKey = null]},
        runs = {L1, C1, A1, F1, O1},
        applications = {[id = "app1", name = "Notepad"]},
        environments = {[id = "env1", name = "E1", enableEnvironmentDataCollection = true], [id = "env2", name = "E2", enableEnvironmentDataCollection = false]},
        measurements = [L1 = l1m, C1 = c1m, A1 = a1m, O1 = {T[Measurement]("O1", 1, "2026-10-20T10:00:00Z")}],
        events = {
            [id = "e1", eventType = "applicationFailure", timestamp = "2026-10-20T10:00:00Z", testRunId = "L1"],
            [id = "e2", eventType = "x", timestamp = "2026-10-22T00:00:00Z", testRunId = "L1"],
            [id = "e3", eventType = "x", timestamp = "2026-10-21T23:59:59Z", testRunId = "C1"]
        },
        sessions = [L1 = {[created = "2026-10-20T10:00:00Z", id = "s1", testRunId = "L1", loginState = "failed"], [created = "2026-10-20T10:00:00Z", id = "s2", testRunId = "L1", loginState = "success"]}, C1 = {[created = "2026-10-20T10:00:00Z", id = "s3", testRunId = "C1"]}],
        eux = [L1 = {[timestamp = "2026-10-20T10:01:00Z", score = 7.5, count = 10]}, C1 = {[timestamp = "2026-10-20T10:01:00Z", score = 8, count = 3], [timestamp = "2026-10-22T00:00:00Z", score = 1, count = 1]}],
        metricsLoad = [L1 = {[timestamp = "2026-10-20T10:01:00Z", metricId = 1, measurement = 0, count = 5, displayName = "CPU", unit = "%"]}],
        metricsCont = [C1 = {[timestamp = "2026-10-20T10:00:00Z", metricId = 2, measurement = 2048, count = 4, displayName = "Memory", unit = "MB"]}],
        platform = {[metricId = "m1", environmentKey = "env1", displayName = "CPU", unit = "%", instance = "i1", group = "g", componentType = "host",
                     customTags = [cluster_name = "c1"], dataPoints = {[timestamp = "2026-10-20T10:00:00Z", value = 1.5], [timestamp = "2026-10-23T00:00:00Z", value = 9]}]}
    ],
    window = T[Window](null, true, #date(2026, 10, 20), #date(2026, 10, 21), #datetimezone(2026, 10, 22, 12, 0, 0, 0, 0)),
    // guard rails: fail loudly if the connector calls something it must not
    guarded = (route, q, a) =>
        if route = "test-runs/A1/aggregated-eux-results" or route = "test-runs/A1/aggregated-load-test-user-session-metrics" or route = "test-runs/A1/aggregated-continuous-test-user-session-metrics"
            then T[Raw](500, "Application test must not be queried for aggregated endpoints: " & route)
        else if (route = "test-runs/O1/measurements" or route = "test-runs/O1/user-sessions")
            then T[Raw](500, "run that finished before the window must not be queried: " & route)
        else if route = "platform-metrics" and q[environmentIds] <> "env1"
            then T[Raw](500, "environment with collection disabled must not be queried: " & q[environmentIds])
        else if Text.EndsWith(route, "/user-sessions") and q[to] <> "2026-10-22T00:00:00Z"
            then T[Raw](500, "user-sessions to= must be the day AFTER the selected end day, got " & q[to])
        else if route = "tests/test-runs" and q[testType] = "loadTest"
            then T[Ok](T[Page]({L1, L1, F1, O1}, q))
        else T[Router](data)(route, q, a),
    ctx = T[FakeCtx](guarded, null),
    runsRaw = T[GetTestRunsRaw](ctx),
    meas = T[GetMeasurements](ctx, runsRaw, window),
    zeroRow = Table.SelectRows(meas, each [userSessionId] = "us8001"){0},
    nav = T[Core](ctx, window),
    navNames = Table.Column(nav, "Name"),
    cols = (name) => Table.ColumnNames(nav{[Name = name]}[Data]),
    expected = [
        #"Applications" = {"id","name","description","type","username","commandLine","workingDirectory","mainWindowTitle","mainProcessName","created","lastModified","takeScreenshots","hasPassword"},
        #"Aggregated EUX Results" = {"timestamp","score","count","testRunId"},
        #"Events" = {"id","eventType","timestamp","title","testId","testRunId","userSessionId","applicationId"},
        #"Measurements" = {"measurementId","appExecutionId","applicationId","launcherName","accountId","testRunId","userSessionId","duration","timestamp","AccountName","RemotingProtocol"},
        #"Test Runs" = {"id","testId","type","state","result","rampUpCompleted","activeSessionCount","statisticsReady","productVersion","created","started","finished","counter","numberOfEvents","comment","login_successCount","login_totalCount","engine_successCount","engine_totalCount","app_successCount","app_totalCount","testRunConfigurationSnapshot","vsiMax_maxSessions","testRunConfigurationSnapshot_name"},
        #"Tests" = {"id","name","description","type","created","state","numberOfSessions","rampUpDurationInMinutes","testDurationInMinutes","rampDownDurationInMinutes","euxEnabled","sessionMetricsEnabled","sessionMetricScheduleRate","sessionMetricGroupKey","environmentKey","connector_type","connector_serverUrl","connector_resource","connector_commandLine","workload","logonTimeTrackingProcess","engineStartTimeout"},
        #"User Session Metrics" = {"timestamp","metricId","measurement","count","displayName","unit","testRunId"},
        #"User Sessions" = {"id","testId","testRunId","created","loginState","sessionState","stateLastModified","testType","accountId","launcherName","loginStartTime","loginEndTime","sessionEndTime","sessionMetricEnabled","properties"},
        #"Workload Steps" = {"testRunId","isGroupStep","stepType","appId","applicationName","runOnce","leaveRunning","delayInSeconds","groupName"},
        #"Environments" = {"id","name","description","enableEnvironmentDataCollection","enableCostCalculation","currency","expectedUserAmount","actualUserAmount","capitalExpenditures","operationalExpenditures","resourceGroup","hostPool","providerType","providerId","providerName","providerDescription","providerTenantId","providerApplicationId","mappedTestCount"},
        #"Platform Metrics" = {"metricId","environmentKey","displayName","unit","instance","group","componentType","customTagsJson","customTag_cluster_name","customTag_cluster_uuid","timestamp","value"}
    ],
    schemaMismatches = List.Select(Record.FieldNames(expected), (n) => cols(n) <> Record.Field(expected, n)),
    rows = (name) => Table.RowCount(nav{[Name = name]}[Data]),
    emptyNav = T[Core](T[FakeCtx](T[Router](T[EmptyData]), null), window),
    allNames = {"Test Runs", "Tests", "Measurements", "Events", "User Sessions", "Aggregated EUX Results", "User Session Metrics", "Platform Metrics", "Applications", "Environments", "Workload Steps"}
in
    T[Run]({
        T[Check]("navigation keys/names unchanged and ordered", () => navNames = {"Environments", "Platform Metrics", "Tests", "Test Runs", "Workload Steps", "Aggregated EUX Results", "Applications", "Measurements", "Events", "User Sessions", "User Session Metrics", "Test Runs In Window", "Load Test Overview"}),
        T[Check]("Test Runs In Window lists overlapping runs incl. failed run with no data (F1) but not O1", () => List.Sort(Table.Column(nav{[Name = "Test Runs In Window"]}[Data], "id")) = {"A1", "C1", "F1", "L1"}),
        T[Check]("every table keeps its exact column set/order (customer PBIX compatibility): mismatches=" & Text.Combine(schemaMismatches, ","), () => List.Count(schemaMismatches) = 0),
        T[Check]("runs de-duplicated by id across duplicate pages", () => List.Count(runsRaw) = 5 and List.Count(List.Distinct(List.Transform(runsRaw, each _[id]))) = 5),
        T[Check]("Test Runs table keeps ALL runs (incl. outside window and failed)", () => rows("Test Runs") = 5),
        T[Check](">1000 measurements/day: all 2500 L1 rows present", () => Table.RowCount(Table.SelectRows(meas, each [testRunId] = "L1")) = 2500),
        T[Check]("midnight boundaries: each Continuous observation counted exactly once, outside-window excluded",
            () => List.Sort(Table.Column(Table.SelectRows(meas, each [testRunId] = "C1"), "userSessionId")) = List.Sort({"us9002", "us9003", "us9004", "us9005"})),
        T[Check]("run finished before window not fetched; total rows 2500+4+2", () => Table.RowCount(meas) = 2506),
        T[Check]("valid zero duration kept as 0 (not null)", () => zeroRow[duration] = 0),
        T[Check]("AccountName/RemotingProtocol extracted from properties", () => Table.SelectRows(meas, each [userSessionId] = "us9003"){0}[AccountName] <> null and Table.SelectRows(meas, each [userSessionId] = "us9003"){0}[RemotingProtocol] = "RDP"),
        T[Check]("events filtered to window", () => rows("Events") = 2),
        T[Check]("user sessions queried with to = day AFTER selected end (guard would 500)", () => rows("User Sessions") = 3),
        T[Check]("aggregated EUX: Load+Continuous only, out-of-window dropped", () => rows("Aggregated EUX Results") = 2),
        T[Check]("session metrics: load + continuous endpoints, zero measurement preserved", () => rows("User Session Metrics") = 2 and Table.SelectRows(nav{[Name = "User Session Metrics"]}[Data], each [displayName] = "CPU"){0}[measurement] = 0),
        T[Check]("platform metrics: disabled env skipped (not applicable), out-of-window point dropped", () => rows("Platform Metrics") = 1),
        T[Check]("empty tenant produces typed empty tables, no cross-join error", () => List.Sum(List.Transform(allNames, (n) => Table.RowCount(emptyNav{[Name = n]}[Data]))) = 0),
        T[Check]("empty tenant keeps measurement schema", () => Table.ColumnNames(emptyNav{[Name = "Measurements"]}[Data]) = Record.Field(expected, "Measurements")),
        T[CheckError]("auth failure surfaces at once with context (probe)", () => T[Core](T[FakeCtx]((r, q, a) => T[Raw](401, "no"), null), window), "Authentication failed"),
        T[CheckError]("a failing per-run call fails the refresh rather than publishing partial data", () => Table.RowCount(T[GetMeasurements](T[FakeCtx]((r, q, a) => if Text.EndsWith(r, "/measurements") then T[Raw](500, "x") else T[Router](data)(r, q, a), null), runsRaw, window)), "HTTP 500"),
        T[Check]("TestConnection (legacy) returns flat positional args from the data source path JSON", () => T[TestConnection]("{""FQDN"":""demo.loginvsi.com"",""ApiToken"":""abc""}") = {"LoginEnterprise_PBI.Contents", "demo.loginvsi.com", "abc"}),
        T[Check]("TestConnection (key) accepts plain and JSON paths", () => T[KeyTestConnection]("demo.loginvsi.com") = {"LoginEnterprise_PBI.ContentsKey", "demo.loginvsi.com"} and T[KeyTestConnection]("{""FQDN"":""demo.loginvsi.com""}") = {"LoginEnterprise_PBI.ContentsKey", "demo.loginvsi.com"}),
        T[Check]("Probe performs a real request (fails when the service is down)", () => (try T[Probe](T[FakeCtx]((r, q, a) => T[Raw](500, "down"), null)))[HasError])
    })
