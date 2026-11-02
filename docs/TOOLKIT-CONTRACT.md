# Native EUX contract and evidence matrix (for the Results Toolkit session)

Unsupported community preview. This is a written contract between LE-PBI-Connector and LoginEnterprise-ResultsToolkit. It does not edit the Toolkit checkout, and the two connectors are not interchangeable: this one targets `v7-preview`, the Toolkit targets `v8-preview`. Grafana/InfluxDB and custom PDF/report generation stay in the Toolkit.

## Endpoint and fields

`GET /publicApi/{v7-preview|v8-preview}/load-test-run-overview/{baseTestRunId}` (Load runs only; one base run, no `testRunIds`). The retrieved Swagger lists the `/v7/` and `/v8-preview/` operations with identical request and response shapes for this route. Live bodies for `v7` and `v7-preview` were identical.

| Source field | Connector column | Type | Notes |
|---|---|---|---|
| `results[].testRunId` | `testRunId` | text | Must equal the requested run, else the refresh fails. Matched case-insensitively. |
| `results[].testName`, `counter` | `testName`, `counter` | text, int | `counter` repeats across tests; identify a run by `testRunId`. |
| `results[].isBase`, `state`, `testResult` | same | logical, text, text | |
| `results.performance.euxState` | `euxState` | text | Seen: `completed`, `disabled`, `unavailable`. |
| `results.performance.vsiMaxState` | `vsiMaxState` | text | Seen: `aboveThreshold`, `belowSessionCount`, `completed`, `disabled`, `unavailable`. |
| result `eux_score` | `euxScore` | number or null | Native overall. |
| result `eux_baseline` | `euxBaseline` | number or null | |
| result `eux_steady_state` | `euxSteadyState` | number or null | |
| result `vsi_max` | `vsiMax` | number or null | See VSImax below. |

## Rules both sides should share

- Null means unavailable. Never substitute 0. A genuine 0 stays 0.
- Whole-run native scores are not date-windowed and are never averaged or summed across runs. Several runs selected means no single native value.
- Aggregate EUX (`aggregated-eux-results`) is hourly buckets with an unweighted mean in reports; it differs from the native score (lab examples: 8.15 vs 8.2, 4.2 vs 3.3, 6.3 vs 3.7). The scoring formula and the meaning of bucket `count` are undocumented, so neither side should infer weights.
- VSImax: when `vsiMaxState` is `aboveThreshold` the value is a bound, not an exact capacity. The state is the appliance's decision.
- Application and Continuous runs have no load overview. A 404 for a Load run means no row; other failures are errors.

## Actual source reconciliation

Packaged 1.2.0.0 MEZ run on the real Power Query engine against the live appliance (read-only, bounded), compared with separate direct GETs: window 2025-06-30 gave 7 of 7 runs matching and 2025-05-28..29 gave 8 of 8 (including two `disabled` runs with all-null values, one `unavailable`, and one run with a null baseline). No duplicate overview rows. See [evidence](evidence/native-eux-engine-reconciliation.json). This is engine-level only: it is not a Power BI Desktop refresh and not DAX execution.

## v7-preview versus v8-preview (decision: no v8 adapter now)

Compared the appliance's retrieved contracts for every route the connector calls. Parameters and responses are identical for tests, test runs list, aggregated EUX, measurements, aggregated session metrics, applications and the overview. Differences that matter: the v8-preview test-run detail response no longer carries `counter` or `testRunConfigurationSnapshot` as this connector reads them, environments return `tests.testKey/testName` instead of `tests.testId`, and events and platform metrics gain optional filters. There is no native-EUX capability gap in v7-preview. An opt-in v8 adapter would change Test Runs, Workload Steps and Environments columns for no EUX benefit, so it is deliberately deferred; no toggle or silent fallback was added. Revisit if a v7 route is removed or a v8-only capability is needed.

## What the Toolkit can reuse

The same field table and rules for PDF/Grafana output so numbers match the Login Enterprise UI. The Toolkit's own v8-preview client and vault handling remain authoritative there.
