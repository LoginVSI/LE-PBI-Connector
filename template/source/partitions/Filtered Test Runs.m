let
    // Referenced from Test Runs (keeps same columns/schema)
    Source = #"Test Runs",

    // Normalize type for reliable filtering, but keep all original columns
    // (this overwrites the type values to lowercase; if you want to preserve original casing, I can give a helper-column version)
    Normalized = Table.TransformColumns(
        Source,
        {{"type", each if _ is null then null else Text.Lower(Text.From(_)), type text}}
    ),

    // Keep all Continuous test runs
    ContinuousRuns = Table.SelectRows(Normalized, each [type] = "continuoustest"),

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

    CombinedRunIds = Table.Combine({
        MeasurementRuns,
        EventRuns,
        UserSessionRuns,
        UserSessionMetricRuns,
        EUXRuns
    }),

    DistinctRunIds = Table.Distinct(CombinedRunIds),

    // Keep only non-continuous runs that have in-range data
    FilteredNonContinuous = Table.NestedJoin(
        NonContinuousRuns,
        {"id"},
        DistinctRunIds,
        {"testRunId"},
        "MatchedRuns",
        JoinKind.Inner
    ),
    FilteredNonContinuousClean = Table.RemoveColumns(FilteredNonContinuous, {"MatchedRuns"}),

    // Add all continuous runs back
    Final = Table.Combine({ContinuousRuns, FilteredNonContinuousClean})
in
    Final