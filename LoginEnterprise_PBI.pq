[Version = "1.0.0"]
section LoginEnterprise_PBI;

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

// Main function to retrieve data from Login Enterprise API
[DataSource.Kind = "LoginEnterprise_PBI", Publish = "LoginEnterprise_PBI.Publish"]
shared LoginEnterprise_PBI.Contents = Value.ReplaceType(LoginEnterpriseImpl, LoginEnterpriseType);

LoginEnterpriseImpl = (
    FQDN as text, ApiToken as text
) as table =>
    let
        // Default StartDate and EndDate if not provided
        StartDate = Date.AddDays(DateTime.Date(DateTime.LocalNow()), -30),
        EndDate   = DateTime.Date(DateTime.LocalNow()),

        // Table functions that receive the date range
        testsTable = GetTests(FQDN, ApiToken),
        testRunsTable = GetTestRuns(FQDN, ApiToken),
        workloadStepsTable = GetWorkloadSteps(testRunsTable),
        allMeasurements = GetMeasurements(testRunsTable, FQDN, ApiToken, StartDate, EndDate),
        aggregatedEUXResultsTable = GetAggregatedEUXResults(testRunsTable, FQDN, ApiToken, StartDate, EndDate),
        allEvents = GetEvents(FQDN, ApiToken, StartDate, EndDate),
        userSessionsTable = GetUserSessions(testRunsTable, FQDN, ApiToken, StartDate, EndDate),
        userSessionMetricsTable = GetUserSessionMetrics(testRunsTable, FQDN, ApiToken, StartDate, EndDate),
        entities = {
            [
                Name = "Tests",
                Data = testsTable,
                ItemKind = "Table",
                ItemName = "Tests",
                IsLeaf = true
            ],
            [
                Name = "Test Runs",
                Data = testRunsTable,
                ItemKind = "Table",
                ItemName = "TestRuns",
                IsLeaf = true
            ],
            [
                Name = "Workload Steps",
                Data = workloadStepsTable,
                ItemKind = "Table",
                ItemName = "WorkloadSteps",
                IsLeaf = true
            ],
            [
                Name = "Aggregated EUX Results",
                Data = aggregatedEUXResultsTable,
                ItemKind = "Table",
                ItemName = "AggregatedEUXResults",
                IsLeaf = true
            ],
            [
                Name = "Measurements",
                Data = allMeasurements,
                ItemKind = "Table",
                ItemName = "Measurements",
                IsLeaf = true
            ],
            [
                Name = "Events",
                Data = allEvents,
                ItemKind = "Table",
                ItemName = "Events",
                IsLeaf = true
            ],
            [
                Name = "User Sessions",
                Data = userSessionsTable,
                ItemKind = "Table",
                ItemName = "UserSessions",
                IsLeaf = true
            ],
            [
                Name = "User Session Metrics",
                Data = userSessionMetricsTable,
                ItemKind = "Table",
                ItemName = "UserSessionMetrics",
                IsLeaf = true
            ]
        },
        navTable = Table.FromRecords(entities),
        finalNav = Table.ToNavigationTable(navTable, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        finalNav;

// Define the type for the Login Enterprise function
LoginEnterpriseType = type function (
    FQDN as (
        type text meta [
            Documentation.FieldCaption = "FQDN",
            Documentation.FieldDescription = "Fully qualified domain name (e.g., demo.loginvsi.com)",
            Documentation.SampleValues = {"demo.loginvsi.com"}
        ]
    ),
    ApiToken as (
        type text meta [
            Documentation.FieldCaption = "API Token",
            Documentation.FieldDescription = "Your Login Enterprise API token",
            Documentation.SampleValues = {"eyJhbGciOi..."}
        ]
    )
    // optional StartDate as (
    //     type nullable date meta [
    //         Documentation.FieldCaption = "Start Date",
    //         Documentation.FieldDescription = "Pick a start date (optional). Defaults to 30 days ago if blank.",
    //         Documentation.SampleValues = {#date(2025, 6, 1)}
    //     ]
    // ),
    // optional EndDate as (
    //     type nullable date meta [
    //         Documentation.FieldCaption = "End Date",
    //         Documentation.FieldDescription = "Pick an end date (optional). Defaults to today if blank.",
    //         Documentation.SampleValues = {#date(2025, 6, 4)}
    //     ]
    // )
) as table;

// Function to handle paginated API requests
PagedApiRequest = (baseEndpoint as text, FQDN as text, ApiToken as text, optional pageSize as number) as list =>
    let
        pageSizeVal = if (pageSize <> null) then pageSize else 1000,
        // Increased default page size
        PageFn = (offset as number) as list =>
            let
                // Check if baseEndpoint already has query parameters
                delimiter = if Text.Contains(baseEndpoint, "?") then "&" else "?",
                // Construct endpoint with pagination parameters
                endpoint = baseEndpoint & delimiter & "count=" & Text.From(pageSizeVal) & "&offset=" & Text.From(
                    offset
                ),
                // Get response and handle nulls
                response = try GetLoginEnterpriseData(endpoint, FQDN, ApiToken) otherwise null,
                items = if response <> null and Record.HasFields(response, "items") then response[items] else {},
                // Check if we need to get more pages
                count = List.Count(items),
                next = if count = pageSizeVal then @PageFn(offset + pageSizeVal) else {}
            in
                List.Combine({items, next})
    in
        PageFn(0);

// Function to retrieve data from the Login Enterprise API
GetLoginEnterpriseData = (endpoint as text, FQDN as text, ApiToken as text) as any =>
    let
        Response = 
            try Json.Document(
                Web.Contents(
                    "https://" & FQDN, [
                        RelativePath = "publicApi/v7/" & endpoint,
                        Headers = [
                            #"accept" = "application/json",
                            #"Authorization" = "Bearer " & ApiToken
                        ]
                    ]
                )
            ) otherwise error "Failed to retrieve data from: " & endpoint
    in
        Response;

// Function to retrieve tests from the Login Enterprise API
GetTests = (FQDN as text, ApiToken as text) as table =>
    let
        TestsList = PagedApiRequest("tests?orderBy=name&direction=asc&includeTotalCount=false", FQDN, ApiToken),
        TableRaw = Table.FromList(TestsList, Splitter.SplitByNothing(), {"Test"}),
        Expanded = Table.ExpandRecordColumn(
            TableRaw,
            "Test",
            {
                "id",
                "name",
                "description",
                "type",
                "created",
                "state",
                "numberOfSessions",
                "rampUpDurationInMinutes",
                "testDurationInMinutes",
                "rampDownDurationInMinutes",
                "euxEnabled",
                "euxWorkFolders",
                "sessionMetricsEnabled",
                "sessionMetricScheduleRate",
                "sessionMetricGroupKey",
                "environmentKey",
                "connectionResources",
                "workload",
                "logonTimeTrackingProcess",
                "engineStartTimeout",
                "applicationDebugModeEnabled"
            }
        ),
        // Remove unwanted columns
        Removed = Table.RemoveColumns(Expanded, {"euxWorkFolders", "applicationDebugModeEnabled"}),
        ExpandedConnRes = Table.ExpandRecordColumn(Removed, "connectionResources", {"connector"}),
        ExpandedConnector = Table.ExpandRecordColumn(
            ExpandedConnRes,
            "connector",
            {"type", "serverUrl", "resource", "commandLine"},
            {"connector_type", "connector_serverUrl", "connector_resource", "connector_commandLine"}
        )
    in
        ExpandedConnector;

// Function to retrieve test runs from the Login Enterprise API
GetTestRuns = (FQDN as text, ApiToken as text) as table =>
    let
        testTypes = {"applicationTest", "loadTest", "continuousTest"},
        allTestRunsRaw = List.Transform(
            testTypes,
            each
                let
                    baseEndpoint = "tests/test-runs?testType=" & _ & "&orderBy=testName&direction=asc&include=testRunConfigurationSnapshot",
                    rows = PagedApiRequest(baseEndpoint, FQDN, ApiToken),
                    base = Table.FromList(rows, Splitter.SplitByNothing(), {"TestRun"}),
                    expanded = Table.ExpandRecordColumn(
                        base,
                        "TestRun",
                        {
                            "id",
                            "testId",
                            "type",
                            "state",
                            "result",
                            "rampUpCompleted",
                            "activeSessionCount",
                            "statisticsReady",
                            "productVersion",
                            "created",
                            "started",
                            "finished",
                            "counter",
                            "numberOfEvents",
                            "comment",
                            "loginCounts",
                            "engineCounts",
                            "appExecutionCounts",
                            "vsiMax",
                            "testRunConfigurationSnapshot"
                        }
                    ),
                    exp1 = Table.ExpandRecordColumn(
                        expanded,
                        "loginCounts",
                        {"successCount", "totalCount"},
                        {"login_successCount", "login_totalCount"}
                    ),
                    exp2 = Table.ExpandRecordColumn(
                        exp1,
                        "engineCounts",
                        {"successCount", "totalCount"},
                        {"engine_successCount", "engine_totalCount"}
                    ),
                    exp3 = Table.ExpandRecordColumn(
                        exp2,
                        "appExecutionCounts",
                        {"successCount", "totalCount"},
                        {"app_successCount", "app_totalCount"}
                    ),
                    addVSIMax = Table.AddColumn(
                        exp3,
                        "vsiMax_maxSessions",
                        each try Record.Field([vsiMax], "maxSessions") otherwise null
                    ),
                    removedRawFields = Table.RemoveColumns(addVSIMax, {"vsiMax"})
                in
                    removedRawFields
        ),
        combined = Table.Combine(allTestRunsRaw),
        typed = Table.TransformColumnTypes(
            combined,
            {
                {"created", type datetime},
                {"started", type datetime},
                {"finished", type datetime},
                {"rampUpCompleted", type datetime}
            }
        )
    in
        typed;

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
        table = Table.Combine(List.Transform(workloadRecords, each Table.FromRecords(List.RemoveNulls(_))))
    in
        table;

GetAggregatedEUXResults = (
    testRunsTable as table,
    FQDN as text,
    ApiToken as text,
    StartDate as date,
    EndDate as date
) as table =>
    let
        // Format datetime range
        dateToIso = (d as date) => DateTime.ToText(DateTime.From(d), "yyyy-MM-ddTHH:mm:ssZ"),
        fromParam = dateToIso(StartDate),
        toParam   = dateToIso(EndDate),

        // Filter to only continuous and load test runs
        runsFiltered = Table.SelectRows(
            Table.Buffer(testRunsTable),
            each [type] = "LoadTest" or [type] = "ContinuousTest"
        ),

        // Retrieve and append testRunId to each response item
        aggregatedEUXResults = List.Combine(
            List.Transform(
                Table.Column(runsFiltered, "id"),
                (runId) =>
                    let
                        endpoint = 
                            "test-runs/" & runId
                            & "/aggregated-eux-results"
                            & "?from=" & fromParam
                            & "&to=" & toParam,

                        rawResp = try GetLoginEnterpriseData(endpoint, FQDN, ApiToken) otherwise null,
                        baseList =
                            if rawResp <> null and Value.Is(rawResp, type list) then rawResp else {},
                        itemsList = List.Transform(baseList, each Record.AddField(_, "testRunId", runId))
                    in
                        itemsList
            )
        ),

        // Convert into table
        tableRaw = Table.FromList(aggregatedEUXResults, Splitter.SplitByNothing(), {"EUX"}),

        // Expand fields
        expanded = Table.ExpandRecordColumn(
            tableRaw,
            "EUX",
            {"timestamp", "score", "count", "testRunId"}
        ),

        // Cast types
        typed = Table.TransformColumnTypes(
            expanded,
            {
                {"timestamp", type datetime},
                {"score", type number},
                {"count", Int64.Type},
                {"testRunId", type text}
            }
        )
    in
        typed;

// Function to retrieve measurements for test runs
GetMeasurements = (testRunsTable as table, FQDN as text, ApiToken as text, StartDate as date, EndDate as date) as table =>
    let
        // Filter runs exactly like GetUserSessionMetrics
        continuousRuns = Table.SelectRows(testRunsTable, each [type] = "continuousTest"),
        otherRuns = Table.SelectRows(testRunsTable, each [type] <> "continuousTest"),
        otherFiltered = Table.SelectRows(
            otherRuns,
            each
                (Record.Field(_, "started") <= DateTime.From(EndDate) + #duration(1, 0, 0, 0))
                and (
                    (
                        Record.Field(_, "finished") <> null
                        and Record.Field(_, "finished") >= DateTime.From(StartDate)
                    )
                    or (Record.Field(_, "finished") = null)
                )
        ),
        runsToFetch = Table.Combine({continuousRuns, otherFiltered}),
        runsBuffered = Table.Buffer(runsToFetch),
        // Prepare the one-day boundaries
        daysList = List.Generate(() => StartDate, each _ <= EndDate, each Date.AddDays(_, 1)),
        dateToIso = (d as date) => DateTime.ToText(DateTime.From(d), "yyyy-MM-ddTHH:mm:ssZ"),
        // Fetch all measurement JSON objects into one big list
        allRawRecords = List.Combine(
            List.Transform(
                Table.Column(runsBuffered, "id"),
                (runId) =>
                    List.Combine(
                        List.Transform(
                            daysList,
                            (dayStart) =>
                                let
                                    dayEnd = Date.AddDays(dayStart, 1),
                                    fromParam = dateToIso(dayStart),
                                    toParam = dateToIso(dayEnd),
                                    endpoint = "test-runs/"
                                        & runId
                                        & "/measurements"
                                        & "?from="
                                        & fromParam
                                        & "&to="
                                        & toParam
                                        & "&count=1000"
                                        & "&offset=0",
                                    rawResp = try GetLoginEnterpriseData(endpoint, FQDN, ApiToken) otherwise null,
                                    itemsList =
                                        if rawResp <> null and Record.HasFields(rawResp, "items") then
                                            rawResp[items]
                                        else
                                            {}
                                in
                                    itemsList
                        )
                    )
            )
        ),
        // Build a single table from that combined list
        tableRaw = Table.FromList(allRawRecords, Splitter.SplitByNothing(), {"Measurement"}),
        // Buffer once before expanding/pivoting
        bufferedTable = Table.Buffer(tableRaw),
        // Expand record & pivot properties in one shot
        expandedMeas = Table.ExpandRecordColumn(
            bufferedTable,
            "Measurement",
            {
                "measurementId",
                "appExecutionId",
                "applicationId",
                "launcherName",
                "accountId",
                "testRunId",
                "userSessionId",
                "duration",
                "timestamp",
                "properties"
            }
        ),
        propertiesExp = Table.ExpandListColumn(expandedMeas, "properties"),
        propertyFields = Table.ExpandRecordColumn(propertiesExp, "properties", {"propertyId", "value"}),
        pivoted = Table.Pivot(propertyFields, List.Distinct(propertyFields[propertyId]), "propertyId", "value"),
        allCols = List.Distinct(
            {
                "measurementId",
                "appExecutionId",
                "applicationId",
                "launcherName",
                "accountId",
                "testRunId",
                "userSessionId",
                "duration",
                "timestamp"
            }
                & List.Distinct(propertyFields[propertyId])
        ),
        finalCols = Table.SelectColumns(pivoted, allCols),
        // Cast to correct types
        typed = Table.TransformColumnTypes(finalCols, {{"timestamp", type datetime}, {"duration", type number}})
    in
        typed;

// Function to retrieve events for test runs
GetEvents = (FQDN as text, ApiToken as text, StartDate as date, EndDate as date) as table =>
    let
        // Build a list of 1-day boundaries from StartDate to EndDate
        daysList = List.Generate(() => StartDate, each _ <= EndDate, each Date.AddDays(_, 1)),
        // Helper functions to convert a date to ISO-8601 strings
        dateToIso = (d as date) => DateTime.ToText(DateTime.From(d), "yyyy-MM-ddTHH:mm:ssZ"),
        // For each day, pull only the first 1000 events (count=1000, offset=0)
        sampledRowsPerDay = List.Combine(
            List.Transform(
                daysList,
                (dayStart) =>
                    let
                        dayEnd = Date.AddDays(dayStart, 1),
                        fromParam = dateToIso(dayStart),
                        toParam = dateToIso(dayEnd),
                        // Construct endpoint: fetch only the first page (count=1000, offset=0)
                        endpointDay = "events"
                            & "?direction=asc"
                            & "&include=none"
                            & "&from="
                            & fromParam
                            & "&to="
                            & toParam
                            & "&count=1000"
                            & "&offset=0",
                        // Call the API directly (returns a record with [items])
                        response = try GetLoginEnterpriseData(endpointDay, FQDN, ApiToken) otherwise null,
                        items = if response <> null and Record.HasFields(response, "items") then response[items] else {}
                    in
                        items
            )
        ),
        // Convert the combined list into a table
        tableRaw = Table.FromList(sampledRowsPerDay, Splitter.SplitByNothing(), {"Event"}),
        // Buffer once (so further steps aren’t re-querying)
        bufferedTable = Table.Buffer(tableRaw),
        // Expand only the core fields (skip the full 'properties' for perf)
        expanded = Table.ExpandRecordColumn(
            bufferedTable,
            "Event",
            {"id", "eventType", "timestamp", "title", "testId", "testRunId", "userSessionId", "applicationId"}
        ),
        // Cast types
        typed = Table.TransformColumnTypes(expanded, {{"timestamp", type datetime}})
    in
        typed;

// Function to retrieve user session metrics for test runs
GetUserSessions = (testRunsTable as table, FQDN as text, ApiToken as text, StartDate as date, EndDate as date) as table =>
    let
        // Buffer testRunsTable so the .Column("id") call is cheap
        testRunsBuffered = Table.Buffer(testRunsTable),
        // Build from/to strings
        fromParam = DateTime.ToText(DateTime.From(StartDate), "yyyy-MM-ddTHH:mm:ssZ"),
        toParam = DateTime.ToText(DateTime.From(EndDate), "yyyy-MM-ddTHH:mm:ssZ"),
        // Fetch-and-expand each run/day into a little sub-table
        rawList = List.Transform(
            Table.Column(testRunsBuffered, "id"),
            each
                try
                    let
                        endpoint = "test-runs/"
                            & _
                            & "/user-sessions?direction=asc"
                            & "&includeTotalCount=false"
                            & "&from="
                            & fromParam
                            & "&to="
                            & toParam,
                        response = PagedApiRequest(endpoint, FQDN, ApiToken),
                        base = Table.FromList(response, Splitter.SplitByNothing(), {"UserSession"}),
                        expanded = Table.ExpandRecordColumn(
                            base,
                            "UserSession",
                            {
                                "id",
                                "testId",
                                "testRunId",
                                "created",
                                "loginState",
                                "sessionState",
                                "stateLastModified",
                                "testType",
                                "accountId",
                                "launcherName",
                                "loginStartTime",
                                "loginEndTime",
                                "sessionEndTime",
                                "sessionMetricEnabled",
                                "properties"
                            }
                        )
                    in
                        expanded
                    otherwise null
        ),
        // Combine all those small tables into one big table
        combined = Table.Combine(List.RemoveNulls(rawList)),
        // BUFFER here so Power BI “knows” the full row count before proceeding
        bufferedTable = Table.Buffer(combined),
        // Now do your final type‐casts (or any additional transforms)
        typed = Table.TransformColumnTypes(
            bufferedTable,
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

// Function to retrieve user session metrics for test runs
GetUserSessionMetrics = (
    testRunsTable as table,
    FQDN as text,
    ApiToken as text,
    StartDate as date,
    EndDate as date
) as table =>
    let
        // Convert StartDate/EndDate to ISO‐8601 strings
        dateToIso = (d as date) => DateTime.ToText(DateTime.From(d), "yyyy-MM-ddTHH:mm:ssZ"),
        fromParam = dateToIso(StartDate),
        toParam   = dateToIso(EndDate),

        // Buffer and split runs into loadTest vs continuousTest
        runsBuffered   = Table.Buffer(testRunsTable),
        loadRuns       = Table.SelectRows(runsBuffered, each [type] = "LoadTest"),
        continuousRuns = Table.SelectRows(runsBuffered, each [type] = "ContinuousTest"),

        // For each loadTest runId, call the aggregated‐load endpoint and append testRunId
        loadAggregated =
          List.Combine(
            List.Transform(
              Table.Column(loadRuns, "id"),
              (runId) =>
                let
                  endpoint = 
                    "test-runs/" & runId
                    & "/aggregated-load-test-user-session-metrics"
                    & "?from=" & fromParam
                    & "&to="   & toParam,

                  rawResp  = try GetLoginEnterpriseData(endpoint, FQDN, ApiToken) otherwise null,
                  baseList =
                    if rawResp = null then
                      {}
                    else if Value.Is(rawResp, type list) then
                      rawResp
                    else if Value.Is(rawResp, type record) and Record.HasFields(rawResp, "items") then
                      rawResp[items]
                    else
                      {},
                  // inject testRunId into every record
                  itemsList = List.Transform(baseList, each Record.AddField(_, "testRunId", runId))
                in
                  itemsList
            )
          ),

        // For each continuousTest runId, call the aggregated‐continuous endpoint and append testRunId
        continuousAggregated =
          List.Combine(
            List.Transform(
              Table.Column(continuousRuns, "id"),
              (runId) =>
                let
                  endpoint = 
                    "test-runs/" & runId
                    & "/aggregated-continuous-test-user-session-metrics"
                    & "?aggregationMode=avgHour"
                    & "&from=" & fromParam
                    & "&to="   & toParam,

                  rawResp  = try GetLoginEnterpriseData(endpoint, FQDN, ApiToken) otherwise null,
                  baseList =
                    if rawResp = null then
                      {}
                    else if Value.Is(rawResp, type list) then
                      rawResp
                    else if Value.Is(rawResp, type record) and Record.HasFields(rawResp, "items") then
                      rawResp[items]
                    else
                      {},
                  // inject testRunId into every record
                  itemsList = List.Transform(baseList, each Record.AddField(_, "testRunId", runId))
                in
                  itemsList
            )
          ),

        // Combine both lists into a single flat list of records
        allAggregatedRows = List.Combine({ loadAggregated, continuousAggregated }),

        // Convert that flat list into a one‐column table of JSON records
        tableRaw  = Table.FromList(allAggregatedRows, Splitter.SplitByNothing(), {"Metric"}),

        // Buffer that table to materialize all rows at once
        buffered   = Table.Buffer(tableRaw),

        // Expand the six fields plus testRunId
        expanded   = Table.ExpandRecordColumn(
                       buffered,
                       "Metric",
                       {
                         "timestamp",
                         "metricId",
                         "measurement",
                         "count",
                         "displayName",
                         "unit",
                         "testRunId"
                       }
                     ),

        // Cast types: timestamp→datetime, metricId & count → Int64, measurement → number, testRunId → text
        typed = Table.TransformColumnTypes(
                  expanded,
                  {
                    {"timestamp",   type datetime},
                    {"metricId",    Int64.Type},
                    {"measurement", type number},
                    {"count",       Int64.Type},
                    {"displayName", type text},
                    {"unit",        type text},
                    {"testRunId",   type text}
                  }
               )
    in
        typed;

// Metadata for the Login Enterprise data source
LoginEnterprise_PBI = [
    Authentication = [
        Anonymous = []
    ]
];

// Publish metadata for the Login Enterprise data source
LoginEnterprise_PBI.Publish = [
    Beta = false,
    Category = "Other",
    ButtonText = {Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp")},
    LearnMoreUrl = "https://www.loginvsi.com/",
    SourceImage = LoginEnterprise_PBI.Icons,
    SourceTypeImage = LoginEnterprise_PBI.Icons
];

// Icons for the Login Enterprise data source
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
