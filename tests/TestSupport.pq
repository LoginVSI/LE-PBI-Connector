// ===========================================================================
// TEST-ONLY support. Appended to the connector section by build/Build-Mez.ps1 -Test.
// Never part of the shipped package. Provides check helpers, fake API servers and exports.
// ===========================================================================

Test.Check = (name as text, f as function) as record =>
    let
        r = try f()
    in
        [
            Name = name,
            Pass = (not r[HasError]) and r[Value] = true,
            Detail = if r[HasError] then "raised: " & Text.From(r[Error][Message]) else "returned " & Text.From(r[Value])
        ];

// Passes only if f raises an error whose message contains `fragment`.
Test.CheckError = (name as text, f as function, fragment as text) as record =>
    let
        r = try f()
    in
        [
            Name = name,
            Pass = r[HasError] and Text.Contains(Text.From(r[Error][Message]), fragment),
            Detail = if r[HasError] then "message: " & Text.From(r[Error][Message]) else "expected an error containing '" & fragment & "' but it succeeded"
        ];

Test.Run = (checks as list) as text =>
    let
        failed = List.Select(checks, each not [Pass])
    in
        if List.Count(failed) = 0 then
            "PASS " & Text.From(List.Count(checks)) & " checks"
        else
            error Error.Record(
                "Test.Failed",
                Text.From(List.Count(failed)) & " of " & Text.From(List.Count(checks)) & " failed: "
                    & Text.Combine(List.Transform(failed, each [Name] & " => " & [Detail]), " || ")
            );

// ---------------------------- fake appliance --------------------------------
Fake.Token = "tok-SECRET-123";

Fake.Ok = (v as any) as record => [Status = 200, Body = Text.FromBinary(Json.FromValue(v))];
Fake.Raw = (status as number, body as text) as record => [Status = status, Body = body];

// Server-side slice honouring count/offset; totalCount only when requested.
Fake.Page = (items as list, q as record) as record =>
    let
        n = List.Count(items),
        off = List.Min({Number.FromText(Record.FieldOrDefault(q, "offset", "0"), "en-US"), n}),
        cnt = Number.FromText(q[count], "en-US"),
        take = List.Min({cnt, n - off}),
        slice = List.Range(items, off, take)
    in
        [items = slice]
            & (if Record.FieldOrDefault(q, "includeTotalCount", "false") = "true" then [totalCount = n] else []);

Fake.Ctx = (handler as function, optional overrides as nullable record) as record =>
    Ctx.Create(
        "test.example.com",
        Fake.Token,
        (route as text, q as record, attempt as number) => handler(route, q, attempt),
        [PageSize = 1000, MaxPages = 50, RetryDelays = {}] & (if overrides = null then [] else overrides)
    );

// Emulates an API whose `to` is INCLUSIVE (worst case for double counting) and applies from/to to `timestamp`.
Fake.Between = (items as list, q as record) as list =>
    List.Select(
        items,
        (i) =>
            Time.TextToUtc19(i[timestamp]) >= Time.TextToUtc19(q[from])
            and Time.TextToUtc19(i[timestamp]) <= Time.TextToUtc19(q[to])
    );

Fake.RunIdOf = (route as text) as text => Text.Split(route, "/"){1};

// A realistic appliance. `data` fields: tests, runs, applications, environments, measurements (by run id record),
// events, sessions (by run id), eux (by run id), metricsLoad / metricsCont (by run id), platform.
Fake.Router = (data as record) =>
    (route as text, q as record, attempt as number) as record =>
        if route = "tests" then Fake.Ok(Fake.Page(data[tests], q))
        else if route = "tests/test-runs" then
            Fake.Ok(Fake.Page(List.Select(data[runs], (r) => Text.Lower(r[type]) = Text.Lower(q[testType])), q))
        else if route = "applications" then Fake.Ok(Fake.Page(data[applications], q))
        else if route = "environments" then Fake.Ok(Fake.Page(data[environments], q))
        else if route = "events" then Fake.Ok(Fake.Page(Fake.Between(data[events], q), q))
        else if route = "platform-metrics" then Fake.Ok(data[platform])
        else if Text.EndsWith(route, "/measurements") then
            Fake.Ok(Fake.Page(Fake.Between(Record.FieldOrDefault(data[measurements], Fake.RunIdOf(route), {}), q), q))
        else if Text.EndsWith(route, "/user-sessions") then
            Fake.Ok(Fake.Page(Record.FieldOrDefault(data[sessions], Fake.RunIdOf(route), {}), q))
        else if Text.EndsWith(route, "/aggregated-eux-results") then
            Fake.Ok(Fake.Between(Record.FieldOrDefault(data[eux], Fake.RunIdOf(route), {}), q))
        else if Text.EndsWith(route, "/aggregated-load-test-user-session-metrics") then
            Fake.Ok(Fake.Between(Record.FieldOrDefault(data[metricsLoad], Fake.RunIdOf(route), {}), q))
        else if Text.EndsWith(route, "/aggregated-continuous-test-user-session-metrics") then
            Fake.Ok(Fake.Between(Record.FieldOrDefault(data[metricsCont], Fake.RunIdOf(route), {}), q))
        else
            Fake.Raw(500, "unexpected route in fake: " & route);

Fake.Run = (id as text, ty as text, started as nullable text, finished as nullable text) as record =>
    [id = id, testId = "t-" & ty, #"type" = ty, state = "Finished", result = "Successful", started = started, finished = finished,
     created = started, loginCounts = [successCount = 1, totalCount = 1], testRunConfigurationSnapshot = [name = "Snap " & id]];

Fake.Measurement = (runId as text, n as number, timestamp as text) as record =>
    [measurementId = "total_login_time", appExecutionId = "ae" & Text.From(n), applicationId = "app1", launcherName = "L1",
     accountId = "acc" & Text.From(Number.Mod(n, 3)), testRunId = runId, userSessionId = "us" & Text.From(n), duration = 1000 + n,
     timestamp = timestamp, properties = {[propertyId = "AccountName", value = "user" & Text.From(Number.Mod(n, 3))], [propertyId = "RemotingProtocol", value = "RDP"]}];

Fake.EmptyData = [
    tests = {}, runs = {}, applications = {}, environments = {}, measurements = [], events = {}, sessions = [],
    eux = [], metricsLoad = [], metricsCont = [], platform = {}
];

// ------------------------------- exports ------------------------------------
shared LoginEnterprise_PBI.TestExports = [
    Check = Test.Check, CheckError = Test.CheckError, Run = Test.Run,
    Ctx = Ctx.Create, Window = Window.Create, WindowDay = Window.Day, Core = LoginEnterpriseCore,
    GetAllItems = Api.GetAllItems, GetList = Api.GetList, Request = Api.Request, Probe = Api.Probe,
    GetMeasurements = GetMeasurements, GetTests = GetTests, GetApplications = GetApplications, GetEnvironments = GetEnvironments,
    GetTestRunsRaw = GetTestRunsRaw, GetTestRuns = GetTestRuns, GetUserSessions = GetUserSessions, GetEvents = GetEvents,
    GetAggregatedEUXResults = GetAggregatedEUXResults, GetUserSessionMetrics = GetUserSessionMetrics,
    GetPlatformMetrics = GetPlatformMetrics, RunsInWindow = Runs.InWindow, TimeTextToUtc19 = Time.TextToUtc19,
    Token = Fake.Token, Ok = Fake.Ok, Raw = Fake.Raw, Page = Fake.Page, FakeCtx = Fake.Ctx, Router = Fake.Router,
    Run_ = Fake.Run, Measurement = Fake.Measurement, EmptyData = Fake.EmptyData,
    TestConnection = LoginEnterprise_PBI.TestConnection, KeyTestConnection = LoginEnterprise_PBI_Key.TestConnection,
    Impl = LoginEnterpriseImpl, Build = LoginEnterpriseBuild
];
