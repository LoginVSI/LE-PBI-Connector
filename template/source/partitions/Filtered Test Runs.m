let
    // Referenced from Test Runs (keeps same columns/schema)
    Source = #"Test Runs",

    // Normalize type for reliable filtering, but keep all original columns
    Normalized = Table.TransformColumns(
        Source,
        {{"type", each if _ is null then null else Text.Lower(Text.From(_)), type text}}
    ),

    // Current connector: keep only Continuous runs in the loaded window; older connector fallback uses evidence.
    ContinuousCandidates = Table.SelectRows(Normalized, each [type] = "continuoustest"),

    // Filter only Application + Load runs by in-range fact data
    NonContinuousRuns = Table.SelectRows(
        Normalized,
        each [type] = "applicationtest" or [type] = "loadtest"
    ),

    // Pull distinct in-range run IDs from already-filtered fact tables
    MeasurementRuns =
        if Table.HasColumns(Measurements, {"testRunId"})
        then Table.SelectColumns(Measurements, {"testRunId"})
        else #table({"testRunId"}, {}),

    EventRuns =
        if Table.HasColumns(Events, {"testRunId"})
        then Table.SelectColumns(Events, {"testRunId"})
        else #table({"testRunId"}, {}),

    UserSessionRuns =
        if Table.HasColumns(#"User Sessions", {"testRunId"})
        then Table.SelectColumns(#"User Sessions", {"testRunId"})
        else #table({"testRunId"}, {}),

    UserSessionMetricRuns =
        if Table.HasColumns(#"User Session Metrics", {"testRunId"})
        then Table.SelectColumns(#"User Session Metrics", {"testRunId"})
        else #table({"testRunId"}, {}),

    EUXRuns =
        if Table.HasColumns(#"Aggregated EUX Results", {"testRunId"})
        then Table.SelectColumns(#"Aggregated EUX Results", {"testRunId"})
        else #table({"testRunId"}, {}),

    // 1.1.0.2: runs whose start/finish overlaps the loaded window, as reported by connector >= 1.1.0.2.
    // This keeps failed runs that produced no measurements/events/sessions in comparisons and denominators.
    // Older connectors do not expose this item; fall back to data-presence only (previous behaviour).
    ConnectorNav = LoginEnterprise_PBI.Contents(FQDN, APIToken, DaysBack, UseDateRange, StartDateParam, EndDateParam),
    InWindowRuns =
        if Table.Contains(ConnectorNav, [Name = "Test Runs In Window"])
        then Table.RenameColumns(
            Table.SelectColumns(ConnectorNav{[Name = "Test Runs In Window"]}[Data], {"id"}),
            {{"id", "testRunId"}}
        )
        else #table({"testRunId"}, {}),

    CombinedRunIds = Table.Combine({
        MeasurementRuns,
        EventRuns,
        UserSessionRuns,
        UserSessionMetricRuns,
        EUXRuns,
        InWindowRuns
    }),

    DistinctRunIds = Table.Distinct(CombinedRunIds),

    // Keep only non-continuous runs that have in-range data or overlap the loaded window
    FilteredNonContinuous = Table.NestedJoin(
        NonContinuousRuns,
        {"id"},
        DistinctRunIds,
        {"testRunId"},
        "MatchedRuns",
        JoinKind.Inner
    ),
    FilteredNonContinuousClean = Table.RemoveColumns(FilteredNonContinuous, {"MatchedRuns"}),

    ContinuousRuns = Table.RemoveColumns(
        Table.NestedJoin(ContinuousCandidates, {"id"}, DistinctRunIds, {"testRunId"}, "MatchedRuns", JoinKind.Inner),
        {"MatchedRuns"}
    ),
    Final = Table.Combine({ContinuousRuns, FilteredNonContinuousClean})
in
    Final