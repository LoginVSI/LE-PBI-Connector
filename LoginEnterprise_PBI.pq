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

// Main function to retrieve data from Login Enterprise API
[DataSource.Kind = "LoginEnterprise_PBI", Publish = "LoginEnterprise_PBI.Publish"]
shared LoginEnterprise_PBI.Contents = Value.ReplaceType(LoginEnterpriseImpl, LoginEnterpriseType);

LoginEnterpriseImpl = (
    FQDN as text,
    ApiToken as text,
    optional DaysBack as number,
    optional UseDateRange as any,
    optional StartDateParam as nullable date,
    optional EndDateParam as nullable date
) as table =>

    let
        // Want date range?
        UseDateRangeValid = UseDateRange <> null and UseDateRange = true,

        // Both dates provided?
        HasValidDates = UseDateRangeValid and StartDateParam <> null and EndDateParam <> null,

        // Fallback for DaysBack
        EffectiveDaysBack = if DaysBack <> null then DaysBack else 30,

        Today = DateTime.Date(DateTime.LocalNow()),

        // If dates provided -> use them
        // Else if UseDateRange was chosen but dates missing -> force last 30 days
        // Else use DaysBack (or 30 if blank)
        StartDate =
            if HasValidDates then
                StartDateParam
            else if UseDateRangeValid then
                Date.AddDays(Today, -30)
            else
                Date.AddDays(Today, -EffectiveDaysBack),

        EndDate =
            if HasValidDates then
                EndDateParam
            else
                Today,

        // Table functions that receive the date range
        testsTable = GetTests(FQDN, ApiToken),
        testRunsTable = GetTestRuns(FQDN, ApiToken),
        workloadStepsTable = GetWorkloadSteps(testRunsTable),
        applicationsTable = GetApplications(FQDN, ApiToken),
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
                Name = "Applications",
                Data = applicationsTable,
                ItemKind = "Table",
                ItemName = "Applications",
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
    ),
    optional DaysBack as (
        type number meta [
            Documentation.FieldCaption = "Days Back",
            Documentation.FieldDescription = "Select how many days of data to retrieve",
            Documentation.AllowedValues = {1, 7, 30, 60, 90},
            Documentation.SampleValues = {30}
        ]
    ),
    optional UseDateRange as (
        type logical meta [
            Documentation.FieldCaption = "Use Date Range",
            Documentation.FieldDescription = "Enable this to use the Start/End Date inputs instead of Days Back.",
            Documentation.SampleValues = {false}
        ]
    ),
    optional StartDateParam as (
        type nullable date meta [
            Documentation.FieldCaption = "Start Date",
            Documentation.FieldDescription = "Used if 'Use Date Range' is enabled. Defaults to 30 days ago if blank.",
            Documentation.SampleValues = { Date.AddDays(DateTime.Date(DateTime.LocalNow()), -30) }
        ]
    ),
    optional EndDateParam as (
        type nullable date meta [
            Documentation.FieldCaption = "End Date",
            Documentation.FieldDescription = "Used if 'Use Date Range' is enabled. Defaults to today if blank.",
            Documentation.SampleValues = { DateTime.Date(DateTime.LocalNow()) }
        ]
    )
) as table;

// Function to handle paginated API requests
PagedApiRequest = (baseEndpoint as text, FQDN as text, ApiToken as text, optional pageSize as number) as list =>
    let
        pageSizeVal = if (pageSize <> null) then pageSize else 5000,
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
                        RelativePath = "publicApi/v7-preview/" & endpoint,
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
        TableRaw  = Table.FromList(TestsList, Splitter.SplitByNothing(), {"Test"}),

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
                    exp1Raw = ExpandRecordSafe(
                        expanded,
                        "loginCounts",
                        {"successCount", "totalCount"}
                    ),
                    exp1 = Table.RenameColumns(
                        exp1Raw,
                        {
                            {"successCount", "login_successCount"},
                            {"totalCount",   "login_totalCount"}
                        }
                    ),
                    exp2Raw = ExpandRecordSafe(
                        exp1,
                        "engineCounts",
                        {"successCount", "totalCount"}
                    ),
                    exp2 = Table.RenameColumns(
                        exp2Raw,
                        {
                            {"successCount", "engine_successCount"},
                            {"totalCount",   "engine_totalCount"}
                        }
                    ),
                    exp3Raw = ExpandRecordSafe(
                        exp2,
                        "appExecutionCounts",
                        {"successCount", "totalCount"}
                    ),
                    exp3 = Table.RenameColumns(
                        exp3Raw,
                        {
                            {"successCount", "app_successCount"},
                            {"totalCount",   "app_totalCount"}
                        }
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
                    )
                in
                    expConfigSnapshot
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

// Function to retrieve aggregated EUX results for test runs
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

        // Convert into table with schema protection
        result = if List.Count(aggregatedEUXResults) > 0 then
                     let
                         tableRaw = Table.FromList(aggregatedEUXResults, Splitter.SplitByNothing(), {"EUX"}),
                         expanded = Table.ExpandRecordColumn(
                             tableRaw,
                             "EUX",
                             {"timestamp", "score", "count", "testRunId"}
                         ),
                         expandedFixed = Table.SelectColumns(expanded, {"timestamp","score","count","testRunId"}, MissingField.UseNull),
                         typed = Table.TransformColumnTypes(
                             expandedFixed,
                             {
                                 {"timestamp", type datetime},
                                 {"score", type number},
                                 {"count", Int64.Type},
                                 {"testRunId", type text}
                             }
                         )
                     in
                         typed
                 else
                     #table(
                         type table [timestamp = datetime, score = number, count = Int64.Type, testRunId = text],
                         {}
                     )
    in
        result;

// Function to retrieve applications from the Login Enterprise API
GetApplications = (FQDN as text, ApiToken as text) as table =>
    let
        endpoint = "applications?orderBy=name&direction=asc&count=1000&offset=0&includeTotalCount=false&include=none",
        rawList = PagedApiRequest(endpoint, FQDN, ApiToken),
        tableRaw = Table.FromList(rawList, Splitter.SplitByNothing(), {"Application"}),
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

// Function to retrieve measurements - OPTIMIZED (Metadata + Context Columns + Parallel)
GetMeasurements = (testRunsTable as table, FQDN as text, ApiToken as text, StartDate as date, EndDate as date) as table =>
    let
        // 1. Filter runs
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

        // 2. Prepare Date Ranges
        daysList = List.Generate(() => StartDate, each _ <= EndDate, each Date.AddDays(_, 1)),
        dateToIso = (d as date) => DateTime.ToText(DateTime.From(d), "yyyy-MM-ddTHH:mm:ssZ"),

        // 3. PARALLEL FETCHING SETUP
        RunIdList = Table.Column(runsBuffered, "id"),
        CrossJoin = List.TransformMany(
            RunIdList,
            each daysList, 
            (runId, day) => [RunId = runId, DayStart = day]
        ),
        ToDoTable = Table.FromRecords(CrossJoin),

        // B. Define the Fetch Function
        FetchDayData = (runId as text, dayStart as date) =>
            let
                dayEnd = Date.AddDays(dayStart, 1),
                fromParam = dateToIso(dayStart),
                toParam = dateToIso(dayEnd),
                endpoint = "test-runs/"
                    & runId
                    & "/measurements"
                    & "?from=" & fromParam
                    & "&to=" & toParam
                    & "&include=all"  // REQUIRED: Ensures AccountName/Protocol are included
                    & "&count=1000" 
                    & "&offset=0",
                
                rawResp = try GetLoginEnterpriseData(endpoint, FQDN, ApiToken) otherwise null
            in
                if rawResp <> null and Record.HasFields(rawResp, "items") then rawResp[items] else {},

        // C. Trigger Parallel Execution
        AddedData = Table.AddColumn(ToDoTable, "Data", each FetchDayData([RunId], [DayStart])),

        // D. Combine Results
        ExpandedList = Table.ExpandListColumn(AddedData, "Data"),
        allRawRecords = ExpandedList[Data],

        // 4. Process Results
        result = if List.Count(allRawRecords) > 0 then
             let
                 tableRaw = Table.FromList(allRawRecords, Splitter.SplitByNothing(), {"Measurement"}),
                 
                 // Step 4a: Expand Metadata AND Properties List
                 expandedMeas = Table.ExpandRecordColumn(
                     tableRaw,
                     "Measurement",
                     {
                         "measurementId", "appExecutionId", "applicationId", "launcherName",
                         "accountId", "testRunId", "userSessionId", "duration", "timestamp",
                         "properties" // We grab properties temporarily
                     }
                 ),

                 // Step 4b: Extract ONLY AccountName and RemotingProtocol
                 // We transform the properties list {[propertyId="AccountName", value="User1"], ...} 
                 // into a Record [AccountName="User1", ...] so we can expand it easily.
                 ExtractContext = Table.AddColumn(
                     expandedMeas, 
                     "ContextProps", 
                     each 
                        try 
                            Record.FromList(
                                List.Transform([properties], each [value]), 
                                List.Transform([properties], each [propertyId])
                            )
                        otherwise []
                 ),

                 // Step 4c: Expand the new custom record
                 // We use ExpandRecordSafe just in case some rows are missing these fields
                 ExpandedContext = ExpandRecordSafe(
                     ExtractContext, 
                     "ContextProps", 
                     {"AccountName", "RemotingProtocol"}, 
                     {type text, type text}
                 ),

                 // Step 4d: Select Final Columns (Dropping the heavy 'properties' list)
                 finalCols = Table.SelectColumns(
                     ExpandedContext, 
                     {
                        "measurementId", "appExecutionId", "applicationId", "launcherName", 
                        "accountId", "testRunId", "userSessionId", "duration", "timestamp",
                        "AccountName", "RemotingProtocol"
                     }, 
                     MissingField.UseNull
                 ),

                 typed = Table.TransformColumnTypes(
                     finalCols, 
                     {
                         {"timestamp", type datetime}, 
                         {"duration", type number},
                         {"AccountName", type text},
                         {"RemotingProtocol", type text}
                     }
                 )
             in
                 typed
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

// Function to retrieve events for test runs - OPTIMIZED (Parallel + No Buffer)
GetEvents = (FQDN as text, ApiToken as text, StartDate as date, EndDate as date) as table =>
    let
        // 1. Prepare Date Ranges
        daysList = List.Generate(() => StartDate, each _ <= EndDate, each Date.AddDays(_, 1)),
        dateToIso = (d as date) => DateTime.ToText(DateTime.From(d), "yyyy-MM-ddTHH:mm:ssZ"),

        // 2. PARALLEL FETCHING SETUP
        // Events are global (not per test run), so we just iterate over Days
        ToDoTable = Table.FromList(daysList, Splitter.SplitByNothing(), {"DayStart"}),
        
        // Define the fetch function
        FetchEventData = (dayStart as date) =>
            let
                dayEnd = Date.AddDays(dayStart, 1),
                fromParam = dateToIso(dayStart),
                toParam = dateToIso(dayEnd),
                endpointDay =
                    "events"
                    & "?direction=asc"
                    & "&include=none"
                    & "&from=" & fromParam
                    & "&to=" & toParam,
                
                // Use PagedApiRequest here as events might exceed 1000 per day
                items = PagedApiRequest(endpointDay, FQDN, ApiToken)
            in
                items,

        // 3. Trigger Parallel Execution
        AddedData = Table.AddColumn(ToDoTable, "Data", each FetchEventData([DayStart])),

        // 4. Combine Results
        ExpandedList = Table.ExpandListColumn(AddedData, "Data"),
        sampledRowsPerDay = ExpandedList[Data],

        // 5. Process Results
        result = if List.Count(sampledRowsPerDay) > 0 then
             let
                 tableRaw = Table.FromList(sampledRowsPerDay, Splitter.SplitByNothing(), {"Event"}),
                 
                 // REMOVED: Table.Buffer(tableRaw) - Stream the data directly
                 
                 expanded = ExpandRecordSafe(
                     tableRaw,
                     "Event",
                     {"id","eventType","timestamp","title","testId","testRunId","userSessionId","applicationId"}
                 ),
                 fixed = Table.SelectColumns(
                     expanded,
                     {"id","eventType","timestamp","title","testId","testRunId","userSessionId","applicationId"},
                     MissingField.UseNull
                 ),
                 typed = Table.TransformColumnTypes(fixed, {{"timestamp", type datetime}})
             in
                 typed
         else
             #table(
                 type table [id = text, eventType = text, timestamp = datetime, title = text, 
                             testId = text, testRunId = text, userSessionId = text, applicationId = text],
                 {}
             )
    in
        result;

// Function to retrieve user sessions for test runs
GetUserSessions = (testRunsTable as table, FQDN as text, ApiToken as text, StartDate as date, EndDate as date) as table =>
    let
        // Buffer testRunsTable so the .Column("id") call is cheap
        testRunsBuffered = Table.Buffer(testRunsTable),

        // Build from/to strings
        fromParam = DateTime.ToText(DateTime.From(StartDate), "yyyy-MM-ddTHH:mm:ssZ"),
        toParam = DateTime.ToText(DateTime.From(EndDate), "yyyy-MM-ddTHH:mm:ssZ"),

        // Fetch and expand each run/day into a little sub-table
        rawList = List.Transform(
            Table.Column(testRunsBuffered, "id"),
            each
                try
                    let
                        endpoint = "test-runs/" & _
                            & "/user-sessions?direction=asc"
                            & "&includeTotalCount=false"
                            & "&from=" & fromParam
                            & "&to=" & toParam,

                        response = PagedApiRequest(endpoint, FQDN, ApiToken),
                        base = Table.FromList(response, Splitter.SplitByNothing(), {"UserSession"}),

                        // Expand with error handling for missing fields
                        expanded = try Table.ExpandRecordColumn(
                            base,
                            "UserSession",
                            {
                                "id", "testId", "testRunId", "created", "loginState", "sessionState",
                                "stateLastModified", "testType", "accountId", "launcherName",
                                "loginStartTime", "loginEndTime", "sessionEndTime",
                                "sessionMetricEnabled", "properties"
                            }
                        ) otherwise #table(
                            {"id", "testId", "testRunId", "created", "loginState", "sessionState",
                             "stateLastModified", "testType", "accountId", "launcherName",
                             "loginStartTime", "loginEndTime", "sessionEndTime",
                             "sessionMetricEnabled", "properties"},
                            {}
                        )
                    in
                        expanded
                    otherwise #table(
                        {"id", "testId", "testRunId", "created", "loginState", "sessionState",
                         "stateLastModified", "testType", "accountId", "launcherName",
                         "loginStartTime", "loginEndTime", "sessionEndTime",
                         "sessionMetricEnabled", "properties"},
                        {}
                    )
        ),

        // Combine with empty data protection
        cleanedList = List.RemoveNulls(rawList),
        combined = if List.Count(cleanedList) > 0 then 
                       Table.Combine(cleanedList)
                   else
                       #table(
                           {"id", "testId", "testRunId", "created", "loginState", "sessionState",
                            "stateLastModified", "testType", "accountId", "launcherName",
                            "loginStartTime", "loginEndTime", "sessionEndTime",
                            "sessionMetricEnabled", "properties"},
                           {}
                       ),

        // Guarantee schema even if some fields are missing this refresh
        expectedCols = {
            "id","testId","testRunId","created","loginState","sessionState",
            "stateLastModified","testType","accountId","launcherName",
            "loginStartTime","loginEndTime","sessionEndTime",
            "sessionMetricEnabled","properties"
        },
        // Guarantee schema even if some fields are missing this refresh
        fixed =
            EnsureColumns(
                Table.SelectColumns(combined, expectedCols, MissingField.UseNull),
                expectedCols,
                {
                    type text,          // id
                    type text,          // testId
                    type text,          // testRunId
                    type datetime,      // created
                    type text,          // loginState
                    type text,          // sessionState
                    type datetime,      // stateLastModified
                    type text,          // testType
                    type text,          // accountId
                    type text,          // launcherName
                    type datetime,      // loginStartTime
                    type datetime,      // loginEndTime
                    type datetime,      // sessionEndTime
                    type logical,       // sessionMetricEnabled
                    type any            // properties
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

// Function to retrieve user session metrics for test runs
GetUserSessionMetrics = (
    testRunsTable as table,
    FQDN as text,
    ApiToken as text,
    StartDate as date,
    EndDate as date
) as table =>
    let
        // Convert StartDate/EndDate
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

        // Handle empty result with proper schema
        result = if List.Count(allAggregatedRows) > 0 then
                     let
                         tableRaw  = Table.FromList(allAggregatedRows, Splitter.SplitByNothing(), {"Metric"}),
                         expanded   = ExpandRecordSafe(
                                        tableRaw,
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
                         expandedFixed = Table.SelectColumns(
                             expanded,
                             {"timestamp","metricId","measurement","count","displayName","unit","testRunId"},
                             MissingField.UseNull
                         ),
                         typed = Table.TransformColumnTypes(
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
                     in
                         typed
                 else
                     #table(
                         type table [timestamp = datetime, metricId = Int64.Type, measurement = number, 
                                     count = Int64.Type, displayName = text, unit = text, testRunId = text],
                         {}
                     )
    in
        result;

// Test connection function for the Login Enterprise data source
LoginEnterprise_PBI.TestConnection = (FQDN as text, ApiToken as text) =>
    { "LoginEnterprise_PBI.Contents", { FQDN, ApiToken } };

// Metadata for the Login Enterprise data source
LoginEnterprise_PBI = [
    Authentication = [ Anonymous = [] ],
    TestConnection = LoginEnterprise_PBI.TestConnection
];

// Publish metadata for the Login Enterprise data source
LoginEnterprise_PBI.Publish = [
    Beta = true,
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
