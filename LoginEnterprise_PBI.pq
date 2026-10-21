[Version = "1.1.0.2"]
section LoginEnterprise_PBI;

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
// Login Enterprise public API route (v7-preview; unchanged from earlier releases).
ApiRoot = "publicApi/v7-preview/";
DefaultPageSize = 1000;
DefaultMaxPages = 5000;
MaxWindowDays = 366;
// HTTP statuses retried (bounded) before failing.
RetryStatuses = {408, 429, 500, 502, 503, 504};
// Statuses handed back to our code instead of raising a raw Web.Contents exception.
HandledStatuses = {400, 401, 403, 404, 405, 408, 409, 422, 429, 500, 502, 503, 504};

// ---------------------------------------------------------------------------
// Generic table helpers
// ---------------------------------------------------------------------------
// Converts a table to a navigation table with specified key columns and metadata
Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta [
            NavigationTable.NameColumn = nameColumn,
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn,
            Preview.DelayColumn = itemNameColumn,
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;

// Ensure a set of columns exists; add as null if missing, and optionally set types
EnsureColumns = (tbl as table, cols as list, optional types as nullable list) as table =>
    let
        added =
            List.Accumulate(
                cols,
                tbl,
                (state, c) => if Table.HasColumns(state, {c}) then state else Table.AddColumn(state, c, each null)
            ),
        typed =
            if types <> null and List.Count(types) = List.Count(cols)
            then Table.TransformColumnTypes(added, List.Zip({cols, types}))
            else added
    in  typed;

// Safely expand a record column (treats null as empty record, then guarantees all requested fields exist)
ExpandRecordSafe = (tbl as table, col as text, fields as list, optional types as nullable list) as table =>
    let
        normalized = Table.TransformColumns(tbl, {{col, each if _ is null then [] else _}}),
        expanded   = try Table.ExpandRecordColumn(normalized, col, fields, fields) otherwise normalized,
        ensured    = EnsureColumns(expanded, fields, types)
    in
        ensured;

// Convert a record to JSON text, handling nulls gracefully
RecordToJsonText = (value as any) as nullable text =>
    if value = null then
        null
    else
        try Text.FromBinary(Json.FromValue(value), TextEncoding.Utf8) otherwise null;

// Keep the first record per key value; rows without a key are kept (they cannot be de-duplicated).
Records.DistinctBy = (records as list, field as text) as list =>
    let
        t = Table.FromList(records, Splitter.SplitByNothing(), {"r"}),
        keyed = Table.AddColumn(t, "k", each Record.FieldOrDefault([r], field, null)),
        withKey = Table.Distinct(Table.SelectRows(keyed, each [k] <> null), {"k"}),
        noKey = Table.SelectRows(keyed, each [k] = null)
    in
        Table.Column(Table.Combine({withKey, noKey}), "r");

// ---------------------------------------------------------------------------
// Request context (host, credential, fetch function, limits)
// ---------------------------------------------------------------------------
// Fails fast with an actionable message instead of building a bad URL.
Ctx.NormalizeFqdn = (fqdn as nullable text) as text =>
    let
        t = if fqdn = null then "" else Text.Trim(fqdn),
        noScheme = if Text.StartsWith(t, "https://", Comparer.OrdinalIgnoreCase) then Text.Range(t, 8) else t,
        host = if Text.EndsWith(noScheme, "/") then Text.Start(noScheme, Text.Length(noScheme) - 1) else noScheme,
        bad = host = "" or Text.Contains(host, "/") or Text.Contains(host, " ") or Text.Contains(host, "?")
            or Text.StartsWith(host, "http:", Comparer.OrdinalIgnoreCase)
    in
        if bad then
            error Error.Record(
                "DataSource.Error",
                "FQDN must be a host name such as demo.loginvsi.com (HTTPS only, no path or query). Received: " & (if fqdn = null then "(blank)" else fqdn)
            )
        else
            host;

// fetch: optional (route, query, attempt) => [Status = number, Body = binary|text]; defaults to Web.Contents.
// overrides: optional record of PageSize / MaxPages / RetryDelays (seconds) used by tests.
Ctx.Create = (fqdn as nullable text, token as nullable text, optional fetch as nullable function, optional overrides as nullable record) as record =>
    let
        host = Ctx.NormalizeFqdn(fqdn),
        tok =
            if token = null or Text.Trim(token) = "" then
                error Error.Record("DataSource.Error", "The Login Enterprise API token is blank. Provide a token generated in the appliance (Settings > Public API).")
            else
                Text.Trim(token),
        defaults = [PageSize = DefaultPageSize, MaxPages = DefaultMaxPages, RetryDelays = {1, 2, 4}],
        merged = defaults & (if overrides = null then [] else overrides)
    in
        merged & [
            Fqdn = host,
            Token = tok,
            Fetch = if fetch <> null then fetch else Api.DefaultFetch(host, tok)
        ];

// ---------------------------------------------------------------------------
// Date policy
//   * A "day" is a UTC calendar day. The query window is [StartDate 00:00Z, EndDate+1 00:00Z) (half-open),
//     so the selected end day is fully included and a midnight observation belongs to exactly one day.
//   * Rolling mode (UseDateRange not true): EndDate = today (UTC), StartDate = today - DaysBack.
//     DaysBack = N therefore covers today plus the N previous UTC days.
//   * Fixed mode (UseDateRange = true): StartDate and EndDate are both required, start <= end.
//   * Nothing is silently widened, defaulted or swapped; invalid input raises an error.
//   * Power Query converts the API's UTC timestamps to the refreshing machine's local time when typing
//     datetime columns (verified); the windows themselves do not depend on the local time zone or DST.
// ---------------------------------------------------------------------------
Time.Iso = (dt as datetime) as text =>
    DateTime.ToText(dt, [Format = "yyyy-MM-ddTHH:mm:ss", Culture = "en-US"]);

// Normalises an API timestamp to a "yyyy-MM-ddTHH:mm:ss" UTC string for ordinal comparison. null when blank/unparseable.
Time.TextToUtc19 = (t as nullable text) as nullable text =>
    if t = null or Text.Length(t) < 19 then
        null
    else if Text.EndsWith(t, "Z") then
        Text.Start(t, 19)
    else if Text.PositionOfAny(Text.Range(t, 10), {"+", "-"}) = -1 then
        // no zone designator: the API contract is UTC
        Text.Start(t, 19)
    else
        let
            parsed = try DateTimeZone.FromText(t) otherwise null
        in
            if parsed = null then null else Time.Iso(DateTimeZone.RemoveZone(DateTimeZone.SwitchZone(parsed, 0)));

Window.Create = (
    daysBack as nullable number,
    useDateRange as nullable logical,
    startDate as nullable date,
    endDate as nullable date,
    optional nowUtc as nullable datetimezone
) as record =>
    let
        now = if nowUtc <> null then DateTimeZone.SwitchZone(nowUtc, 0) else DateTimeZone.UtcNow(),
        today = DateTime.Date(DateTimeZone.RemoveZone(now)),
        fixedMode = useDateRange = true,
        days = if daysBack = null then 30 else daysBack,
        daysValid = days >= 1 and days <= MaxWindowDays and days = Number.RoundDown(days),
        s = if fixedMode then startDate else Date.AddDays(today, -days),
        e = if fixedMode then endDate else today,
        spanDays = if s = null or e = null then null else Duration.Days(e - s) + 1,
        problem =
            if fixedMode and (startDate = null or endDate = null) then
                "Use Date Range is enabled but Start Date and End Date are not both set. Provide both dates, or turn Use Date Range off to use Days Back."
            else if not fixedMode and not daysValid then
                "Days Back must be a whole number between 1 and " & Text.From(MaxWindowDays, "en-US") & ". Received: " & Text.From(days, "en-US")
            else if spanDays < 1 then
                "Start Date (" & Date.ToText(s, [Format = "yyyy-MM-dd", Culture = "en-US"]) & ") is after End Date (" & Date.ToText(e, [Format = "yyyy-MM-dd", Culture = "en-US"]) & ")."
            else if spanDays > MaxWindowDays then
                "The selected range spans " & Text.From(spanDays, "en-US") & " days; the maximum is " & Text.From(MaxWindowDays, "en-US") & "."
            else
                null,
        fromDt = DateTime.From(s),
        toDt = DateTime.From(Date.AddDays(e, 1))
    in
        if problem <> null then
            error Error.Record("Expression.Error", problem)
        else
            [
                Mode = if fixedMode then "FixedRange" else "Rolling",
                StartDate = s,
                EndDate = e,
                DayCount = spanDays,
                Days = List.Transform({0 .. spanDays - 1}, each Date.AddDays(s, _)),
                From19 = Time.Iso(fromDt),
                To19 = Time.Iso(toDt),
                FromText = Time.Iso(fromDt) & "Z",
                ToText = Time.Iso(toDt) & "Z"
            ];

// Window of a single UTC day inside the overall window.
Window.Day = (day as date) as record =>
    [
        From19 = Time.Iso(DateTime.From(day)),
        To19 = Time.Iso(DateTime.From(Date.AddDays(day, 1))),
        FromText = Time.Iso(DateTime.From(day)) & "Z",
        ToText = Time.Iso(DateTime.From(Date.AddDays(day, 1))) & "Z"
    ];

// True when the API timestamp lies in [From19, To19) in UTC. Blank/unparseable timestamps are excluded.
Time.InRange = (timestamp as nullable text, from19 as text, to19 as text) as logical =>
    let
        t = Time.TextToUtc19(timestamp)
    in
        t <> null and t >= from19 and t < to19;

// ---------------------------------------------------------------------------
// Test-run selection (works on raw API run records)
// ---------------------------------------------------------------------------
Run.TypeOf = (run as record) as text =>
    Text.Lower(Text.From(Record.FieldOrDefault(run, "type", "")));

// A run overlaps [from19, to19) if it started before the end and has not finished before the start (finished = null: still running).
// A run that never started has no data and is excluded.
Run.Overlaps = (run as record, from19 as text, to19 as text) as logical =>
    let
        s = Time.TextToUtc19(Record.FieldOrDefault(run, "started", null)),
        f = Time.TextToUtc19(Record.FieldOrDefault(run, "finished", null))
    in
        s <> null and s < to19 and (f = null or f >= from19);

Runs.InWindow = (runs as list, window as record, types as nullable list) as list =>
    List.Select(
        runs,
        (r) =>
            (types = null or List.Contains(types, Run.TypeOf(r)))
            and Run.Overlaps(r, window[From19], window[To19])
    );

// ---------------------------------------------------------------------------
// HTTP / API layer
// ---------------------------------------------------------------------------
Api.Fail = (message as text, optional detail as nullable record) as any =>
    error Error.Record("DataSource.Error", message, detail);

Api.Scrub = (ctx as record, text as nullable text) as nullable text =>
    if text = null then null
    else Text.Replace(text, ctx[Token], "***");

Api.BodySnippet = (ctx as record, body as any) as text =>
    let
        raw = try (if body is binary then Text.FromBinary(body) else Text.From(body)) otherwise "",
        scrubbed = Api.Scrub(ctx, raw)
    in
        if scrubbed = null or scrubbed = "" then "(empty body)"
        else if Text.Length(scrubbed) > 300 then Text.Start(scrubbed, 300) & "..."
        else scrubbed;

Api.DefaultFetch = (fqdn as text, token as text) =>
    (route as text, query as record, attempt as number) as record =>
        let
            response = Web.Contents(
                "https://" & fqdn,
                [
                    RelativePath = ApiRoot & route,
                    Query = query,
                    Headers = [#"Accept" = "application/json", #"Authorization" = "Bearer " & token],
                    ManualStatusHandling = HandledStatuses,
                    IsRetry = attempt > 0,
                    Timeout = #duration(0, 0, 2, 0)
                ]
            ),
            status = Value.Metadata(response)[Response.Status],
            body = Binary.Buffer(response)
        in
            [Status = status, Body = body];

Api.TransportError = (ctx as record, route as text, err as record) as any =>
    Api.Fail(
        "Could not complete the request to https://" & ctx[Fqdn] & "/" & ApiRoot & route
            & ". " & Api.Scrub(ctx, Text.From(Record.FieldOrDefault(err, "Message", "Unknown error")))
            & " -- Check the FQDN, network reachability, and that the appliance TLS certificate is trusted by this machine "
            & "(this connector never disables certificate validation). See README > Troubleshooting.",
        [Route = route, Reason = Record.FieldOrDefault(err, "Reason", null)]
    );

Api.StatusError = (ctx as record, route as text, status as number, body as any, attempts as number) as any =>
    let
        where = "https://" & ctx[Fqdn] & "/" & ApiRoot & route,
        snippet = Api.BodySnippet(ctx, body),
        hint =
            if status = 401 then "Authentication failed: the API token is missing, expired or revoked. Generate a new token and update the connector credential/parameter."
            else if status = 403 then "Access denied: the token's user lacks permission for this resource."
            else if status = 404 then "Not found: check the FQDN and that this appliance version exposes API v7-preview."
            else if status = 400 or status = 422 then "The appliance rejected the request parameters; this appliance's API contract may differ from the one this connector targets."
            else if List.Contains(RetryStatuses, status) then "The appliance returned a transient error after " & Text.From(attempts, "en-US") & " attempt(s)."
            else "Unexpected response."
    in
        Api.Fail(
            "HTTP " & Text.From(status, "en-US") & " from " & where & ". " & hint & " Response: " & snippet,
            [Route = route, Status = status]
        );

// Returns [Found = logical, Json = any]. 404 is returned as Found = false only when allowNotFound is true.
Api.Request = (ctx as record, route as text, query as record, allowNotFound as logical) as record =>
    let
        delays = ctx[RetryDelays],
        Attempt = (n as number) as record =>
            let
                // Record/list fields are lazy: touch Status and Body inside the try so transport/TLS errors are caught here.
                r = try (let x = ctx[Fetch](route, query, n), s = x[Status], b = x[Body] in if s = s and b = b then {s, b} else {s, b}),
                resp = if r[HasError] then Api.TransportError(ctx, route, r[Error]) else [Status = r[Value]{0}, Body = r[Value]{1}],
                status = resp[Status],
                retry = List.Contains(RetryStatuses, status) and n < List.Count(delays)
            in
                if retry then
                    Function.InvokeAfter(() => @Attempt(n + 1), #duration(0, 0, 0, delays{n}))
                else
                    Api.Interpret(ctx, route, resp, allowNotFound, n + 1),
        result = Attempt(0)
    in
        result;

Api.Interpret = (ctx as record, route as text, resp as record, allowNotFound as logical, attempts as number) as record =>
    let
        status = resp[Status]
    in
        if status = 204 then
            [Found = true, Json = null]
        else if status >= 200 and status < 300 then
            let
                parsed = try Json.Document(resp[Body])
            in
                if parsed[HasError] then
                    Api.Fail(
                        "The response from " & ctx[Fqdn] & "/" & ApiRoot & route & " was not valid JSON ("
                            & Api.Scrub(ctx, Text.From(parsed[Error][Message])) & "). First characters: " & Api.BodySnippet(ctx, resp[Body]),
                        [Route = route, Status = status]
                    )
                else
                    [Found = true, Json = parsed[Value]]
        else if status = 404 and allowNotFound then
            [Found = false, Json = null]
        else
            Api.StatusError(ctx, route, status, resp[Body], attempts);

// Parses a paged result set: { items: [...], totalCount?: n }.
Api.ReadItems = (route as text, json as any) as record =>
    if json = null then
        [items = {}, total = null]
    else if json is record and Record.HasFields(json, "items") and Record.Field(json, "items") is list then
        [
            items = Record.Field(json, "items"),
            total = let t = Record.FieldOrDefault(json, "totalCount", null) in if t is number then t else null
        ]
    else
        Api.Fail("Unexpected response shape from " & route & ": expected an object with an 'items' array.", [Route = route]);

// Parses a non-paged list response (bare array, or an object with items).
Api.ReadList = (route as text, json as any) as list =>
    if json = null then {}
    else if json is list then json
    else if json is record and Record.HasFields(json, "items") and Record.Field(json, "items") is list then Record.Field(json, "items")
    else Api.Fail("Unexpected response shape from " & route & ": expected an array.", [Route = route]);

Api.PageFingerprint = (items as list) as text =>
    if List.Count(items) = 0 then
        ""
    else
        Text.From(List.Count(items), "en-US")
            & "|" & Text.FromBinary(Json.FromValue(List.First(items)))
            & "|" & Text.FromBinary(Json.FromValue(List.Last(items)));

// Fetches every page with count/offset appended exactly once (any count/offset/includeTotalCount in `query` is replaced).
// Stops on a short/empty page or when totalCount is reached; fails on non-progress, page-limit overrun, or fewer items than totalCount.
Api.GetAllItems = (ctx as record, route as text, query as record, optional allowNotFound as nullable logical) as list =>
    let
        allow = allowNotFound = true,
        pageSize = ctx[PageSize],
        maxPages = ctx[MaxPages],
        baseQuery = Record.RemoveFields(query, {"count", "offset", "includeTotalCount"}, MissingField.Ignore),
        LoadPage = (offset as number, prevFp as nullable text, index as number, knownTotal as nullable number) as record =>
            let
                q = baseQuery
                    & [count = Text.From(pageSize, "en-US"), offset = Text.From(offset, "en-US")]
                    & (if offset = 0 then [includeTotalCount = "true"] else []),
                resp = Api.Request(ctx, route, q, allow),
                shaped = if resp[Found] then Api.ReadItems(route, resp[Json]) else [items = {}, total = null],
                items = shaped[items],
                count = List.Count(items),
                fp = Api.PageFingerprint(items),
                total = if knownTotal <> null then knownTotal else shaped[total],
                nextOffset = offset + count
            in
                if index >= maxPages then
                    Api.Fail("Stopped after " & Text.From(maxPages, "en-US") & " pages from " & route & "; the result is larger than this connector's safety limit. Narrow the date window.", [Route = route])
                else if prevFp <> null and count > 0 and fp = prevFp then
                    Api.Fail("Pagination made no progress for " & route & " at offset " & Text.From(offset, "en-US") & ": the appliance returned the same page again.", [Route = route, Offset = offset])
                else
                    [
                        Items = items,
                        NextOffset = nextOffset,
                        Fingerprint = fp,
                        Index = index,
                        Total = total,
                        More = count > 0 and (if total <> null then nextOffset < total else count >= pageSize)
                    ],
        states = List.Generate(
            () => LoadPage(0, null, 0, null),
            each _ <> null,
            (s) => if s[More] then LoadPage(s[NextOffset], s[Fingerprint], s[Index] + 1, s[Total]) else null
        ),
        items = List.Combine(List.Transform(states, each [Items])),
        finalTotal = List.Last(states)[Total]
    in
        if finalTotal <> null and List.Count(items) < finalTotal then
            Api.Fail(
                "Incomplete result from " & route & ": received " & Text.From(List.Count(items), "en-US") & " of " & Text.From(finalTotal, "en-US") & " items.",
                [Route = route]
            )
        else
            items;

// Single non-paged list request (aggregated endpoints, platform metrics).
Api.GetList = (ctx as record, route as text, query as record, optional allowNotFound as nullable logical) as list =>
    let
        resp = Api.Request(ctx, route, query, allowNotFound = true)
    in
        if resp[Found] then Api.ReadList(route, resp[Json]) else {};

// Cheap eager request used so that setup, authentication and TLS problems surface immediately
// (this is also what makes a gateway/Desktop TestConnection perform a real request).
Api.Probe = (ctx as record) as logical =>
    let
        resp = Api.Request(ctx, "tests", [orderBy = "name", direction = "asc", count = "1", offset = "0", includeTotalCount = "false"], false),
        shaped = Api.ReadItems("tests", resp[Json])
    in
        ctx[Fqdn] <> null and ctx[Token] <> null and List.Count(shaped[items]) >= 0;

// ---------------------------------------------------------------------------
// Data retrieval
// ---------------------------------------------------------------------------

// Tests
GetTests = (ctx as record) as table =>
    let
        TestsList = Api.GetAllItems(ctx, "tests", [orderBy = "name", direction = "asc"]),
        TableRaw  = Table.FromList(Records.DistinctBy(TestsList, "id"), Splitter.SplitByNothing(), {"Test"}),

        // Safely expand the main Test record
        Expanded  = ExpandRecordSafe(
            TableRaw, "Test",
            {"id","name","description","type","created","state","numberOfSessions",
            "rampUpDurationInMinutes","testDurationInMinutes","rampDownDurationInMinutes",
            "euxEnabled","euxWorkFolders","sessionMetricsEnabled","sessionMetricScheduleRate",
            "sessionMetricGroupKey","environmentKey","connectionResources","workload",
            "logonTimeTrackingProcess","engineStartTimeout","applicationDebugModeEnabled"},
            {type text,type text,type text,type text,type datetime,type text,Int64.Type,
            Int64.Type,Int64.Type,Int64.Type,type logical,type any,type logical,Int64.Type,
            type text,type any,type any,type text,Int64.Type,type logical}
        ),

        // Be lenient if these optional columns don't exist
        Removed   = try Table.RemoveColumns(Expanded, {"euxWorkFolders","applicationDebugModeEnabled"}) otherwise Expanded,

        // Get the connector record
        ExpandedConnRes = ExpandRecordSafe(Removed, "connectionResources", {"connector"}),

        // Explicitly expand connector into connector_* columns (no name collision with Tests[type])
        ExpandedConnector =
            try
                Table.ExpandRecordColumn(
                    ExpandedConnRes,
                    "connector",
                    {"type","serverUrl","resource","commandLine"},
                    {"connector_type","connector_serverUrl","connector_resource","connector_commandLine"}
                )
            otherwise
                // If connector is missing, still guarantee the columns exist
                EnsureColumns(
                    ExpandedConnRes,
                    {"connector_type","connector_serverUrl","connector_resource","connector_commandLine"},
                    {type text,type text,type text,type text}
                )
    in
        ExpandedConnector;

// Raw test-run records (all three test types, de-duplicated by run id).
GetTestRunsRaw = (ctx as record) as list =>
    let
        testTypes = {"applicationTest", "loadTest", "continuousTest"},
        perType = List.Transform(
            testTypes,
            (tt) => Api.GetAllItems(
                ctx,
                "tests/test-runs",
                [testType = tt, orderBy = "testName", direction = "asc", include = "testRunConfigurationSnapshot"]
            )
        )
    in
        Records.DistinctBy(List.Combine(perType), "id");

TestRunsToTable = (rawRuns as list) as table =>
    let
        base = Table.FromList(rawRuns, Splitter.SplitByNothing(), {"TestRun"}),
        expanded = ExpandRecordSafe(
            base, "TestRun",
            {
                "id","testId","type","state","result","rampUpCompleted",
                "activeSessionCount","statisticsReady","productVersion",
                "created","started","finished","counter","numberOfEvents",
                "comment","loginCounts","engineCounts","appExecutionCounts",
                "vsiMax","testRunConfigurationSnapshot"
            }
        ),
        exp1 = Table.RenameColumns(
            ExpandRecordSafe(expanded, "loginCounts", {"successCount", "totalCount"}),
            {{"successCount", "login_successCount"}, {"totalCount", "login_totalCount"}}
        ),
        exp2 = Table.RenameColumns(
            ExpandRecordSafe(exp1, "engineCounts", {"successCount", "totalCount"}),
            {{"successCount", "engine_successCount"}, {"totalCount", "engine_totalCount"}}
        ),
        exp3 = Table.RenameColumns(
            ExpandRecordSafe(exp2, "appExecutionCounts", {"successCount", "totalCount"}),
            {{"successCount", "app_successCount"}, {"totalCount", "app_totalCount"}}
        ),
        addVSIMax = Table.AddColumn(
            exp3,
            "vsiMax_maxSessions",
            each try Record.Field([vsiMax], "maxSessions") otherwise null
        ),
        removedRawFields = Table.RemoveColumns(addVSIMax, {"vsiMax"}),
        expConfigSnapshot = Table.AddColumn(
            removedRawFields,
            "testRunConfigurationSnapshot_name",
            each try Record.Field([testRunConfigurationSnapshot], "name") otherwise null
        ),
        typed = Table.TransformColumnTypes(
            expConfigSnapshot,
            {
                {"created", type datetime},
                {"started", type datetime},
                {"finished", type datetime},
                {"rampUpCompleted", type datetime}
            }
        )
    in
        typed;

GetTestRuns = (ctx as record) as table =>
    TestRunsToTable(GetTestRunsRaw(ctx));

// Workload steps are derived from the already-retrieved run configuration snapshots.
// Function to retrieve all measurements for test runs
GetWorkloadSteps = (testRunsTable as table) as table =>
    let
        testRunsWithWorkload = Table.SelectColumns(testRunsTable, {"id", "testRunConfigurationSnapshot"}),
        workloadRecords = List.Transform(
            Table.ToRecords(testRunsWithWorkload),
            each
                let
                    testRunId = _[id],
                    snapshot = try _[testRunConfigurationSnapshot] otherwise null,
                    workload =
                        if snapshot <> null and Record.HasFields(snapshot, "workload") then
                            snapshot[workload]
                        else
                            null,
                    steps = if workload <> null and Record.HasFields(workload, "steps") then workload[steps] else {},
                    flattened = List.Combine(
                        List.Transform(
                            steps,
                            (step) =>
                                if
                                    step is record
                                    and Record.FieldOrDefault(step, "type", null) <> "AppGroupReference"
                                then
                                    {
                                        [
                                            testRunId = testRunId,
                                            isGroupStep = false,
                                            stepType = Record.FieldOrDefault(step, "type", null),
                                            appId = Record.FieldOrDefault(step, "appId", null),
                                            applicationName = Record.FieldOrDefault(step, "applicationName", null),
                                            runOnce = Record.FieldOrDefault(step, "runOnce", null),
                                            leaveRunning = Record.FieldOrDefault(step, "leaveRunning", null),
                                            delayInSeconds = Record.FieldOrDefault(step, "delayInSeconds", null),
                                            groupName = null
                                        ]
                                    }
                                else if Record.FieldOrDefault(step, "type", null) = "AppGroupReference" and Record.HasFields(step, "groupSteps") then
                                    List.Transform(
                                        step[groupSteps],
                                        (gs) =>
                                            if gs is record then
                                                [
                                                    testRunId = testRunId,
                                                    isGroupStep = true,
                                                    stepType = Record.FieldOrDefault(gs, "type", null),
                                                    appId = Record.FieldOrDefault(gs, "appId", null),
                                                    applicationName = Record.FieldOrDefault(
                                                        gs, "applicationName", null
                                                    ),
                                                    runOnce = Record.FieldOrDefault(gs, "runOnce", null),
                                                    leaveRunning = Record.FieldOrDefault(gs, "leaveRunning", null),
                                                    delayInSeconds = Record.FieldOrDefault(
                                                        gs, "delayInSeconds", null
                                                    ),
                                                    groupName = Record.FieldOrDefault(step, "name", null)
                                                ]
                                            else
                                                null
                                    )
                                else
                                    {}
                        )
                    )
                in
                    flattened
        ),
        cleanedRecords = List.Transform(workloadRecords, each List.RemoveNulls(_)),
        allRecords = List.Combine(cleanedRecords),
        
        // Handle empty result
        table = if List.Count(allRecords) > 0 then
                    Table.FromRecords(allRecords)
                else
                    #table(
                        {"testRunId", "isGroupStep", "stepType", "appId", "applicationName", 
                         "runOnce", "leaveRunning", "delayInSeconds", "groupName"},
                        {}
                    )
    in
        table;

// Aggregated EUX scores. Applies to Load and Continuous runs only (Application tests have no aggregated EUX endpoint).
GetAggregatedEUXResults = (ctx as record, runsRaw as list, window as record) as table =>
    let
        runs = Runs.InWindow(runsRaw, window, {"loadtest", "continuoustest"}),
        rows = List.Combine(
            List.Transform(
                runs,
                (r) =>
                    let
                        runId = r[id],
                        items = Api.GetList(
                            ctx,
                            "test-runs/" & runId & "/aggregated-eux-results",
                            [from = window[FromText], to = window[ToText]],
                            true
                        )
                    in
                        List.Transform(
                            List.Select(items, (i) => i is record and Time.InRange(Record.FieldOrDefault(i, "timestamp", null), window[From19], window[To19])),
                            (i) => i & [testRunId = runId]
                        )
            )
        ),
        result =
            if List.Count(rows) > 0 then
                let
                    tableRaw = Table.FromList(rows, Splitter.SplitByNothing(), {"EUX"}),
                    expanded = ExpandRecordSafe(tableRaw, "EUX", {"timestamp", "score", "count", "testRunId"}),
                    expandedFixed = Table.SelectColumns(expanded, {"timestamp","score","count","testRunId"}, MissingField.UseNull)
                in
                    Table.TransformColumnTypes(
                        expandedFixed,
                        {{"timestamp", type datetime}, {"score", type number}, {"count", Int64.Type}, {"testRunId", type text}}
                    )
            else
                #table(type table [timestamp = datetime, score = number, count = Int64.Type, testRunId = text], {})
    in
        result;

// Applications
GetApplications = (ctx as record) as table =>
    let
        rawList = Api.GetAllItems(ctx, "applications", [orderBy = "name", direction = "asc", include = "none"]),
        tableRaw = Table.FromList(Records.DistinctBy(rawList, "id"), Splitter.SplitByNothing(), {"Application"}),
        expanded = ExpandRecordSafe(
            tableRaw, "Application",
            {"id","name","description","type","username","commandLine","workingDirectory",
            "mainWindowTitle","mainProcessName","created","lastModified","takeScreenshots","hasPassword"},
            {type text,type text,type text,type text,type text,type text,type text,
            type text,type text,type datetime,type datetime,type logical,type logical}
        ),
        typed = Table.TransformColumnTypes(
            expanded,
            {
                {"created", type datetime},
                {"lastModified", type datetime},
                {"takeScreenshots", type logical},
                {"hasPassword", type logical}
            }
        )
    in
        typed;

// Reads one named property value from a measurement's properties list ([propertyId, value] items).
Measurement.Prop = (props as any, id as text) as any =>
    if not (props is list) then
        null
    else
        let
            hit = List.First(List.Select(props, (p) => p is record and Record.FieldOrDefault(p, "propertyId", null) = id), null)
        in
            if hit = null then null else Record.FieldOrDefault(hit, "value", null);

// Measurements: per run, per UTC day the run overlaps. Each day is fully paged, then filtered to [day start, day end)
// so an observation exactly on a midnight boundary is counted once regardless of the API's `to` inclusivity.
GetMeasurements = (ctx as record, runsRaw as list, window as record) as table =>
    let
        runs = Runs.InWindow(runsRaw, window, null),
        FetchDay = (runId as text, day as date) as list =>
            let
                dw = Window.Day(day),
                items = Api.GetAllItems(
                    ctx,
                    "test-runs/" & runId & "/measurements",
                    [from = dw[FromText], to = dw[ToText], include = "all", direction = "asc"],
                    true
                )
            in
                List.Select(items, (i) => i is record and Time.InRange(Record.FieldOrDefault(i, "timestamp", null), dw[From19], dw[To19])),
        perRun = List.Transform(
            runs,
            (r) =>
                List.Combine(
                    List.Transform(
                        List.Select(window[Days], (d) => Run.Overlaps(r, Window.Day(d)[From19], Window.Day(d)[To19])),
                        (d) => FetchDay(r[id], d)
                    )
                )
        ),
        allRawRecords = List.Combine(perRun),
        result =
            if List.Count(allRawRecords) > 0 then
                let
                    withContext = List.Transform(
                        allRawRecords,
                        (m) =>
                            Record.SelectFields(
                                m,
                                {"measurementId", "appExecutionId", "applicationId", "launcherName", "accountId", "testRunId", "userSessionId", "duration", "timestamp"},
                                MissingField.UseNull
                            )
                            & [
                                AccountName = Measurement.Prop(Record.FieldOrDefault(m, "properties", null), "AccountName"),
                                RemotingProtocol = Measurement.Prop(Record.FieldOrDefault(m, "properties", null), "RemotingProtocol")
                            ]
                    ),
                    tableRaw = Table.FromRecords(withContext, null, MissingField.UseNull),
                    finalCols = Table.SelectColumns(
                        tableRaw,
                        {
                            "measurementId", "appExecutionId", "applicationId", "launcherName",
                            "accountId", "testRunId", "userSessionId", "duration", "timestamp",
                            "AccountName", "RemotingProtocol"
                        },
                        MissingField.UseNull
                    )
                in
                    Table.TransformColumnTypes(
                        finalCols,
                        {
                            {"measurementId", type text}, {"appExecutionId", type text}, {"applicationId", type text},
                            {"launcherName", type text}, {"accountId", type text}, {"testRunId", type text},
                            {"userSessionId", type text},
                            {"timestamp", type datetime},
                            {"duration", type number},
                            {"AccountName", type text},
                            {"RemotingProtocol", type text}
                        }
                    )
            else
                #table(
                    type table [
                        measurementId = text, appExecutionId = text, applicationId = text, launcherName = text,
                        accountId = text, testRunId = text, userSessionId = text, duration = number,
                        timestamp = datetime, AccountName = text, RemotingProtocol = text
                    ],
                    {}
                )
    in
        result;

// Events: global endpoint, whole window in one fully paged request, filtered to [From, To).
GetEvents = (ctx as record, window as record) as table =>
    let
        items = Api.GetAllItems(
            ctx,
            "events",
            [direction = "asc", include = "none", from = window[FromText], to = window[ToText]]
        ),
        inWindow = List.Select(items, (i) => i is record and Time.InRange(Record.FieldOrDefault(i, "timestamp", null), window[From19], window[To19])),
        result =
            if List.Count(inWindow) > 0 then
                let
                    tableRaw = Table.FromList(inWindow, Splitter.SplitByNothing(), {"Event"}),
                    expanded = ExpandRecordSafe(
                        tableRaw,
                        "Event",
                        {"id","eventType","timestamp","title","testId","testRunId","userSessionId","applicationId"}
                    ),
                    fixed = Table.SelectColumns(
                        expanded,
                        {"id","eventType","timestamp","title","testId","testRunId","userSessionId","applicationId"},
                        MissingField.UseNull
                    )
                in
                    Table.TransformColumnTypes(fixed, {{"timestamp", type datetime}})
            else
                #table(
                    type table [id = text, eventType = text, timestamp = datetime, title = text,
                                testId = text, testRunId = text, userSessionId = text, applicationId = text],
                    {}
                )
    in
        result;

UserSessionColumns = {
    "id","testId","testRunId","created","loginState","sessionState",
    "stateLastModified","testType","accountId","launcherName",
    "loginStartTime","loginEndTime","sessionEndTime",
    "sessionMetricEnabled","properties"
};

// User sessions per run overlapping the window (all run types), fully paged.
GetUserSessions = (ctx as record, runsRaw as list, window as record) as table =>
    let
        runs = Runs.InWindow(runsRaw, window, null),
        rows = List.Combine(
            List.Transform(
                runs,
                (r) => Api.GetAllItems(
                    ctx,
                    "test-runs/" & r[id] & "/user-sessions",
                    [direction = "asc", from = window[FromText], to = window[ToText]],
                    true
                )
            )
        ),
        base = Table.FromList(Records.DistinctBy(rows, "id"), Splitter.SplitByNothing(), {"UserSession"}),
        expanded = ExpandRecordSafe(base, "UserSession", UserSessionColumns),
        fixed = EnsureColumns(
            Table.SelectColumns(expanded, UserSessionColumns, MissingField.UseNull),
            UserSessionColumns,
            {
                type text, type text, type text, type datetime, type text, type text,
                type datetime, type text, type text, type text,
                type datetime, type datetime, type datetime,
                type logical, type any
            }
        ),
        typed = Table.TransformColumnTypes(
            fixed,
            {
                {"created", type datetime},
                {"stateLastModified", type datetime},
                {"loginStartTime", type datetime},
                {"loginEndTime", type datetime},
                {"sessionEndTime", type datetime}
            }
        )
    in
        typed;

// Aggregated user-session metrics. Load runs use the load-test endpoint, Continuous runs the continuous endpoint
// (avgHour). Application runs have no such endpoint and are not queried.
GetUserSessionMetrics = (ctx as record, runsRaw as list, window as record) as table =>
    let
        loadRuns       = Runs.InWindow(runsRaw, window, {"loadtest"}),
        continuousRuns = Runs.InWindow(runsRaw, window, {"continuoustest"}),
        Fetch = (r as record, routeSuffix as text, extra as record) as list =>
            let
                route = "test-runs/" & r[id] & "/" & routeSuffix,
                items = Api.GetList(ctx, route, extra & [from = window[FromText], to = window[ToText]], true)
            in
                List.Transform(
                    List.Select(items, (i) => i is record and Time.InRange(Record.FieldOrDefault(i, "timestamp", null), window[From19], window[To19])),
                    (i) => i & [testRunId = r[id]]
                ),
        loadAggregated = List.Combine(List.Transform(loadRuns, (r) => Fetch(r, "aggregated-load-test-user-session-metrics", []))),
        continuousAggregated = List.Combine(List.Transform(continuousRuns, (r) => Fetch(r, "aggregated-continuous-test-user-session-metrics", [aggregationMode = "avgHour"]))),
        allAggregatedRows = List.Combine({loadAggregated, continuousAggregated}),
        result =
            if List.Count(allAggregatedRows) > 0 then
                let
                    tableRaw = Table.FromList(allAggregatedRows, Splitter.SplitByNothing(), {"Metric"}),
                    expanded = ExpandRecordSafe(tableRaw, "Metric", {"timestamp","metricId","measurement","count","displayName","unit","testRunId"}),
                    expandedFixed = Table.SelectColumns(expanded, {"timestamp","metricId","measurement","count","displayName","unit","testRunId"}, MissingField.UseNull)
                in
                    Table.TransformColumnTypes(
                        expandedFixed,
                        {
                            {"timestamp", type datetime},
                            {"metricId", Int64.Type},
                            {"measurement", type number},
                            {"count", Int64.Type},
                            {"displayName", type text},
                            {"unit", type text},
                            {"testRunId", type text}
                        }
                    )
            else
                #table(
                    type table [timestamp = datetime, metricId = Int64.Type, measurement = number,
                                count = Int64.Type, displayName = text, unit = text, testRunId = text],
                    {}
                )
    in
        result;

// Environments (fully paged)
GetEnvironments = (ctx as record, testsTable as table) as table =>
    let
        rawList = Api.GetAllItems(ctx, "environments", [orderBy = "name", include = "none"]),

        tableRaw =
            Table.FromList(Records.DistinctBy(rawList, "id"), Splitter.SplitByNothing(), {"Environment"}),

        expanded =
            ExpandRecordSafe(
                tableRaw,
                "Environment",
                {
                    "id",
                    "name",
                    "description",
                    "enableEnvironmentDataCollection",
                    "enableCostCalculation",
                    "environmentCost",
                    "environmentAttributes",
                    "provider"
                },
                {type text, type text, type text, type logical, type logical, type any, type any, type any}
            ),

        expandedAttrs =
            ExpandRecordSafe(expanded, "environmentAttributes", {"resourceGroup", "hostPool"}, {type text, type text}),

        expandedCost =
            ExpandRecordSafe(
                expandedAttrs,
                "environmentCost",
                {"currency", "expectedUserAmount", "actualUserAmount", "capitalExpenditures", "operationalExpenditures"},
                {type text, type number, type number, type number, type number}
            ),

        providerField = (name as text) => (r as record) =>
            try Record.FieldOrDefault(r[provider], name, null) otherwise null,

        withProvider =
            List.Accumulate(
                {
                    {"providerType", "type"},
                    {"providerId", "id"},
                    {"providerName", "name"},
                    {"providerDescription", "description"},
                    {"providerTenantId", "tenantId"},
                    {"providerApplicationId", "applicationId"}
                },
                expandedCost,
                (state, pair) => Table.AddColumn(state, pair{0}, providerField(pair{1}), type text)
            ),

        providerRemoved =
            try Table.RemoveColumns(withProvider, {"provider"}) otherwise withProvider,

        testCountTable =
            Table.Group(
                Table.SelectRows(
                    Table.SelectColumns(testsTable, {"environmentKey"}),
                    each [environmentKey] <> null
                ),
                {"environmentKey"},
                {{"mappedTestCount", each Table.RowCount(_), Int64.Type}}
            ),

        mergedTestCounts =
            Table.NestedJoin(providerRemoved, {"id"}, testCountTable, {"environmentKey"}, "TestCounts", JoinKind.LeftOuter),

        expandedTestCounts =
            Table.ExpandTableColumn(mergedTestCounts, "TestCounts", {"mappedTestCount"}, {"mappedTestCount"}),

        finalTyped =
            Table.TransformColumnTypes(
                EnsureColumns(expandedTestCounts, {"mappedTestCount"}, {Int64.Type}),
                {
                    {"enableEnvironmentDataCollection", type logical},
                    {"enableCostCalculation", type logical},
                    {"expectedUserAmount", type number},
                    {"actualUserAmount", type number},
                    {"capitalExpenditures", type number},
                    {"operationalExpenditures", type number},
                    {"mappedTestCount", Int64.Type}
                }
            )
    in
        finalTyped;

// Platform metrics per environment. Environments that explicitly disable data collection are not applicable and are
// not queried; a 404 for an environment is treated as "unavailable" (empty); any other failure raises an error.
GetPlatformMetrics = (ctx as record, environmentsTable as table, window as record) as table =>
    let
        queryable =
            Table.SelectRows(
                Table.SelectColumns(environmentsTable, {"id", "enableEnvironmentDataCollection"}, MissingField.UseNull),
                each [id] <> null and [enableEnvironmentDataCollection] <> false
            ),
        envIds = List.Buffer(List.Distinct(Table.Column(queryable, "id"))),

        EmptyTable =
            #table(
                type table [
                    metricId = text, environmentKey = text, displayName = text, unit = text, instance = text,
                    group = text, componentType = text, customTagsJson = text, customTag_cluster_name = text,
                    customTag_cluster_uuid = text, timestamp = datetime, value = number
                ],
                {}
            ),

        allMetricSeries =
            List.Combine(
                List.Transform(
                    envIds,
                    (envId) =>
                        Api.GetList(
                            ctx,
                            "platform-metrics",
                            [from = window[FromText], to = window[ToText], environmentIds = Text.From(envId)],
                            true
                        )
                )
            ),

        // keep only in-window data points; series with none left carry no data
        inWindowSeries =
            List.Select(
                List.Transform(
                    List.Select(allMetricSeries, (s) => s is record),
                    (s) =>
                        Record.TransformFields(
                            s,
                            {{"dataPoints", (dp) =>
                                if dp is list then
                                    List.Select(dp, (p) => p is record and Time.InRange(Record.FieldOrDefault(p, "timestamp", null), window[From19], window[To19]))
                                else
                                    {}}},
                            MissingField.UseNull
                        )
                ),
                (s) => (Record.FieldOrDefault(s, "dataPoints", null) is list) and List.Count(Record.Field(s, "dataPoints")) > 0
            ),

        result =
            if List.Count(inWindowSeries) > 0 then
                let
                    tableRaw = Table.FromList(inWindowSeries, Splitter.SplitByNothing(), {"PlatformMetric"}),
                    expandedMetric =
                        Table.ExpandRecordColumn(
                            tableRaw,
                            "PlatformMetric",
                            {"metricId", "environmentKey", "displayName", "unit", "instance", "group", "componentType", "customTags", "dataPoints"},
                            {"metricId", "environmentKey", "displayName", "unit", "instance", "group", "componentType", "customTags", "dataPoints"}
                        ),
                    normalized =
                        Table.TransformColumns(
                            expandedMetric,
                            {
                                {"customTags", each if _ is null then [] else _, type record},
                                {"dataPoints", each if _ is null then {} else _, type list}
                            }
                        ),
                    withCustomTagsJson =
                        Table.AddColumn(normalized, "customTagsJson", each RecordToJsonText([customTags]), type text),
                    withClusterName =
                        Table.AddColumn(
                            withCustomTagsJson,
                            "customTag_cluster_name",
                            each try Text.From(Record.FieldOrDefault([customTags], "cluster_name", null)) otherwise null,
                            type text
                        ),
                    withClusterUuid =
                        Table.AddColumn(
                            withClusterName,
                            "customTag_cluster_uuid",
                            each try Text.From(Record.FieldOrDefault([customTags], "cluster_uuid", null)) otherwise null,
                            type text
                        ),
                    expandedDataPointsList = Table.ExpandListColumn(withClusterUuid, "dataPoints"),
                    expandedDataPoints =
                        Table.ExpandRecordColumn(expandedDataPointsList, "dataPoints", {"timestamp", "value"}, {"timestamp", "value"}),
                    selected =
                        Table.SelectColumns(
                            expandedDataPoints,
                            {
                                "metricId", "environmentKey", "displayName", "unit", "instance", "group",
                                "componentType", "customTagsJson", "customTag_cluster_name", "customTag_cluster_uuid",
                                "timestamp", "value"
                            },
                            MissingField.UseNull
                        ),
                    typed =
                        Table.TransformColumnTypes(
                            selected,
                            {
                                {"metricId", type text},
                                {"environmentKey", type text},
                                {"displayName", type text},
                                {"unit", type text},
                                {"instance", type text},
                                {"group", type text},
                                {"componentType", type text},
                                {"customTagsJson", type text},
                                {"customTag_cluster_name", type text},
                                {"customTag_cluster_uuid", type text},
                                {"timestamp", type datetime},
                                {"value", type number}
                            }
                        )
                in
                    typed
            else
                EmptyTable
    in
        result;

// ---------------------------------------------------------------------------
// Navigation table assembly
// ---------------------------------------------------------------------------
LoginEnterpriseCore = (ctx as record, window as record) as table =>
    let
        testsTable = GetTests(ctx),
        environmentsTable = GetEnvironments(ctx, testsTable),
        testRunsRaw = GetTestRunsRaw(ctx),
        testRunsTable = TestRunsToTable(testRunsRaw),
        workloadStepsTable = GetWorkloadSteps(testRunsTable),
        applicationsTable = GetApplications(ctx),
        allMeasurements = GetMeasurements(ctx, testRunsRaw, window),
        aggregatedEUXResultsTable = GetAggregatedEUXResults(ctx, testRunsRaw, window),
        allEvents = GetEvents(ctx, window),
        userSessionsTable = GetUserSessions(ctx, testRunsRaw, window),
        userSessionMetricsTable = GetUserSessionMetrics(ctx, testRunsRaw, window),
        platformMetricsTable = GetPlatformMetrics(ctx, environmentsTable, window),
        // Additive (1.1.0.2): ids of runs whose start/finish overlaps the window, even if they produced no fact rows
        // (e.g. failed runs with no measurements). Used by the template to keep such runs in comparisons.
        testRunsInWindowTable = Table.TransformColumnTypes(
            Table.FromList(List.Transform(Runs.InWindow(testRunsRaw, window, null), each _[id]), Splitter.SplitByNothing(), {"id"}),
            {{"id", type text}}
        ),

        entities = {
            [Name = "Environments", Data = environmentsTable, ItemKind = "Table", ItemName = "Environments", IsLeaf = true],
            [Name = "Platform Metrics", Data = platformMetricsTable, ItemKind = "Table", ItemName = "PlatformMetrics", IsLeaf = true],
            [Name = "Tests", Data = testsTable, ItemKind = "Table", ItemName = "Tests", IsLeaf = true],
            [Name = "Test Runs", Data = testRunsTable, ItemKind = "Table", ItemName = "TestRuns", IsLeaf = true],
            [Name = "Workload Steps", Data = workloadStepsTable, ItemKind = "Table", ItemName = "WorkloadSteps", IsLeaf = true],
            [Name = "Aggregated EUX Results", Data = aggregatedEUXResultsTable, ItemKind = "Table", ItemName = "AggregatedEUXResults", IsLeaf = true],
            [Name = "Applications", Data = applicationsTable, ItemKind = "Table", ItemName = "Applications", IsLeaf = true],
            [Name = "Measurements", Data = allMeasurements, ItemKind = "Table", ItemName = "Measurements", IsLeaf = true],
            [Name = "Events", Data = allEvents, ItemKind = "Table", ItemName = "Events", IsLeaf = true],
            [Name = "User Sessions", Data = userSessionsTable, ItemKind = "Table", ItemName = "UserSessions", IsLeaf = true],
            [Name = "User Session Metrics", Data = userSessionMetricsTable, ItemKind = "Table", ItemName = "UserSessionMetrics", IsLeaf = true],
            [Name = "Test Runs In Window", Data = testRunsInWindowTable, ItemKind = "Table", ItemName = "TestRunsInWindow", IsLeaf = true]
        },
        navTable = Table.FromRecords(entities),
        finalNav = Table.ToNavigationTable(navTable, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        // Probing first makes URL/auth/TLS problems (and gateway TestConnection) fail fast with a clear message.
        if window[DayCount] > 0 and Api.Probe(ctx) then finalNav else error "unreachable";

// Shared implementation behind both entry points.
LoginEnterpriseBuild = (
    FQDN as nullable text,
    token as nullable text,
    DaysBack as nullable number,
    UseDateRange as nullable logical,
    StartDateParam as nullable date,
    EndDateParam as nullable date
) as table =>
    LoginEnterpriseCore(
        Ctx.Create(FQDN, token),
        Window.Create(DaysBack, UseDateRange, StartDateParam, EndDateParam)
    );

// ---------------------------------------------------------------------------
// Entry point 1 (legacy, unchanged interface): API token passed as a function argument, Anonymous authentication.
// NOTE: the token is part of the data source path and is stored in the report/parameters in clear text.
// Prefer LoginEnterprise_PBI.ContentsKey for new reports (see README).
// ---------------------------------------------------------------------------
[DataSource.Kind = "LoginEnterprise_PBI", Publish = "LoginEnterprise_PBI.Publish"]
shared LoginEnterprise_PBI.Contents = Value.ReplaceType(LoginEnterpriseImpl, LoginEnterpriseType);

LoginEnterpriseImpl = (
    FQDN as text,
    ApiToken as text,
    optional DaysBack as nullable number,
    optional UseDateRange as nullable logical,
    optional StartDateParam as nullable date,
    optional EndDateParam as nullable date
) as table =>
    LoginEnterpriseBuild(FQDN, ApiToken, DaysBack, UseDateRange, StartDateParam, EndDateParam);

LoginEnterpriseType = type function (
    FQDN as (
        type text meta [
            Documentation.FieldCaption = "FQDN",
            Documentation.FieldDescription = "Fully qualified domain name of the Login Enterprise appliance (e.g., demo.loginvsi.com). HTTPS only; no path.",
            Documentation.SampleValues = {"demo.loginvsi.com"}
        ]
    ),
    ApiToken as (
        type text meta [
            Documentation.FieldCaption = "API Token",
            Documentation.FieldDescription = "Your Login Enterprise API token. Stored in clear text with this entry point; see README for the Key-credential alternative.",
            Documentation.SampleValues = {"<your-api-token>"}
        ]
    ),
    optional DaysBack as (
        type number meta [
            Documentation.FieldCaption = "Days Back",
            Documentation.FieldDescription = "Rolling window: today (UTC) plus this many previous UTC days (whole number 1-366). Ignored when Use Date Range is true.",
            Documentation.AllowedValues = {1, 7, 30, 60, 90},
            Documentation.SampleValues = {30}
        ]
    ),
    optional UseDateRange as (
        type logical meta [
            Documentation.FieldCaption = "Use Date Range",
            Documentation.FieldDescription = "Enable to use the fixed Start/End Date inputs (both required) instead of Days Back.",
            Documentation.SampleValues = {false}
        ]
    ),
    optional StartDateParam as (
        type nullable date meta [
            Documentation.FieldCaption = "Start Date",
            Documentation.FieldDescription = "First UTC day to include. Required when Use Date Range is true.",
            Documentation.SampleValues = {#date(2026, 1, 1)}
        ]
    ),
    optional EndDateParam as (
        type nullable date meta [
            Documentation.FieldCaption = "End Date",
            Documentation.FieldDescription = "Last UTC day to include (the whole day is included). Required when Use Date Range is true; must not be before Start Date.",
            Documentation.SampleValues = {#date(2026, 1, 31)}
        ]
    )
) as table;

// ---------------------------------------------------------------------------
// Entry point 2 (new, additive): Key credential. The token is entered once in the Power BI credential dialog
// (Extension.CurrentCredential) and is NOT part of the query or data source path.
// Not yet runtime-accepted in Power BI Desktop/Service; see ACCEPTANCE.md.
// ---------------------------------------------------------------------------
[DataSource.Kind = "LoginEnterprise_PBI_Key", Publish = "LoginEnterprise_PBI_Key.Publish"]
shared LoginEnterprise_PBI.ContentsKey = Value.ReplaceType(LoginEnterpriseKeyImpl, LoginEnterpriseKeyType);

LoginEnterpriseKeyImpl = (
    FQDN as text,
    optional DaysBack as nullable number,
    optional UseDateRange as nullable logical,
    optional StartDateParam as nullable date,
    optional EndDateParam as nullable date
) as table =>
    LoginEnterpriseBuild(FQDN, Extension.CurrentCredential()[Key], DaysBack, UseDateRange, StartDateParam, EndDateParam);

LoginEnterpriseKeyType = type function (
    FQDN as (
        type text meta [
            Documentation.FieldCaption = "FQDN",
            Documentation.FieldDescription = "Fully qualified domain name of the Login Enterprise appliance (e.g., demo.loginvsi.com). HTTPS only; no path.",
            Documentation.SampleValues = {"demo.loginvsi.com"}
        ]
    ),
    optional DaysBack as (
        type number meta [
            Documentation.FieldCaption = "Days Back",
            Documentation.FieldDescription = "Rolling window: today (UTC) plus this many previous UTC days (whole number 1-366). Ignored when Use Date Range is true.",
            Documentation.AllowedValues = {1, 7, 30, 60, 90},
            Documentation.SampleValues = {30}
        ]
    ),
    optional UseDateRange as (
        type logical meta [
            Documentation.FieldCaption = "Use Date Range",
            Documentation.FieldDescription = "Enable to use the fixed Start/End Date inputs (both required) instead of Days Back.",
            Documentation.SampleValues = {false}
        ]
    ),
    optional StartDateParam as (
        type nullable date meta [
            Documentation.FieldCaption = "Start Date",
            Documentation.FieldDescription = "First UTC day to include. Required when Use Date Range is true.",
            Documentation.SampleValues = {#date(2026, 1, 1)}
        ]
    ),
    optional EndDateParam as (
        type nullable date meta [
            Documentation.FieldCaption = "End Date",
            Documentation.FieldDescription = "Last UTC day to include (the whole day is included). Required when Use Date Range is true; must not be before Start Date.",
            Documentation.SampleValues = {#date(2026, 1, 31)}
        ]
    )
) as table;

// ---------------------------------------------------------------------------
// TestConnection (documented dataSourcePath callback; flat positional arguments).
// The invoked function probes the API eagerly, so a successful test performs a real small request.
// ---------------------------------------------------------------------------
LoginEnterprise_PBI.TestConnection = (dataSourcePath as text) as list =>
    let
        json = Json.Document(dataSourcePath)
    in
        {"LoginEnterprise_PBI.Contents", json[FQDN], json[ApiToken]};

LoginEnterprise_PBI_Key.TestConnection = (dataSourcePath as text) as list =>
    let
        trimmed = Text.Trim(dataSourcePath),
        fqdn = if Text.StartsWith(trimmed, "{") then Json.Document(trimmed)[FQDN] else trimmed
    in
        {"LoginEnterprise_PBI.ContentsKey", fqdn};

// Data source kinds
LoginEnterprise_PBI = [
    Authentication = [ Anonymous = [] ],
    TestConnection = LoginEnterprise_PBI.TestConnection,
    Label = "Login Enterprise (API token parameter)"
];

LoginEnterprise_PBI_Key = [
    Authentication = [ Key = [ KeyLabel = "API Token", Label = "Login Enterprise API token" ] ],
    TestConnection = LoginEnterprise_PBI_Key.TestConnection,
    Label = "Login Enterprise (Key credential)"
];

// Publish metadata
LoginEnterprise_PBI.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = {Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp")},
    LearnMoreUrl = "https://www.loginvsi.com/",
    SourceImage = LoginEnterprise_PBI.Icons,
    SourceTypeImage = LoginEnterprise_PBI.Icons
];

LoginEnterprise_PBI_Key.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = {"Login Enterprise (Key credential)", "Connect to Login Enterprise using a stored API token credential"},
    LearnMoreUrl = "https://www.loginvsi.com/",
    SourceImage = LoginEnterprise_PBI.Icons,
    SourceTypeImage = LoginEnterprise_PBI.Icons
];

// Icons
LoginEnterprise_PBI.Icons = [
    Icon16 = {
        Extension.Contents("LE_16.png"),
        Extension.Contents("LE_20.png"),
        Extension.Contents("LE_24.png"),
        Extension.Contents("LE_32.png")
    },
    Icon32 = {
        Extension.Contents("LE_32.png"),
        Extension.Contents("LE_40.png"),
        Extension.Contents("LE_64.png"),
        Extension.Contents("LE_80.png")
    }
];
