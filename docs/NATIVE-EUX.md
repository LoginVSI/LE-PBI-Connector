# Native EUX scores versus aggregate EUX means

Unsupported community preview. Added in connector 1.2.0.0 and template 1.2.0.0-candidate.

## Two different things

| | Aggregate EUX (`Aggregated EUX Results`) | Native overview (`Load Test Overview`) |
|---|---|---|
| Source | `GET test-runs/{id}/aggregated-eux-results` | `GET load-test-run-overview/{id}` |
| Grain | Hourly buckets (`timestamp`, `score`, `count`) | One row per Load run |
| Window | Only buckets inside the loaded date window | The whole run, whatever the window |
| Use for | Trends and period statistics | The score Login Enterprise shows for a run |
| Aggregation | Unweighted mean of buckets (`AVERAGE(score)`) | Never summed or averaged by the template |

The unweighted bucket mean is **not** the native overall score. On the lab appliance (read-only check, 2026-10-28, [evidence](evidence/native-eux-overview-live.json)) one run had native overall 8.2 (baseline 8.4, steady state 8.3) while its two aggregate buckets averaged 8.15; another had native 3.3 against a bucket mean of 4.2. A count-weighted mean differed again (7.98 and 4.23). The scoring formula is not documented and the connector does not try to reproduce it. Bucket `count` semantics remain unproven, so weighted statistics stay disabled. This shows a distinction on retained data. It is not a customer diagnosis.

## What was verified

- Both `GET /publicApi/v7/load-test-run-overview/{baseTestRunId}` and `GET /publicApi/v7-preview/load-test-run-overview/{baseTestRunId}` returned 200 with identical bodies on the lab appliance. The appliance's retrieved Swagger lists only the `/v7/` operation (`Data_GetLoadTestResultOverview`, with an optional `testRunIds` comparison list); the connector calls the route under its existing `v7-preview` root, which the appliance accepted. The connector is **not** migrated to v8 and calls no undocumented route.
- Shape: `results[]` entries with `testRunId`, `testName`, `counter`, `isBase`, `state`, `testResult`, and `results.performance` with `euxState`, `vsiMaxState` and `results[]` of `{resultId, value, differenceFromBase}`. Observed ids: `eux_score`, `eux_baseline`, `eux_steady_state`, `vsi_max`.
- A Load run with EUX disabled returns `euxState: "disabled"` and `null` for every result. The connector keeps those as null; the template shows `No Data`, never 0.
- Only Load runs have this endpoint. Application and Continuous runs get no row. A 404 for a Load run gives no row; any other failure fails the refresh.

## Connector table

`Load Test Overview` is appended as the last navigation item; existing items, keys, tables and columns are unchanged. Columns: `testRunId, testName, counter, isBase, state, testResult, euxState, vsiMaxState, euxScore, euxBaseline, euxSteadyState, vsiMax`. One request per Load run that overlaps the loaded window, base run only.

## Template measures (1.2.0.0)

Numeric: `Native EUX Score (Selected Run)`, `Native EUX Baseline (Selected Run)`, `Native EUX Steady State (Selected Run)`, `Native Overview Runs`. Text: `Native EUX State (Selected Run)`, `Native VSImax State (Selected Run)`. Display: `Native EUX Score/Baseline/Steady State (Display)`. Also `Aggregate EUX Mean (Window Observations)` and `Newest Source Observation`.

Rules: a native value appears only when exactly one run is selected and it has exactly one overview row. Zero or several runs, a missing row or an unavailable result give BLANK (display: `Select one run` or `No Data`). A genuine 0 is kept. The model relationship is `Load Test Overview[testRunId]` to `Filtered Test Runs[id]` (many to one, single direction), so it filters exactly like the other fact tables and cannot duplicate runs. VSImax value semantics are not interpreted; the template exposes the appliance's state text only.

Visual changes in the template (nothing added or removed; 9 pages, 220 visuals): the Load Testing page "EUX Score" card now shows the native value; the two EUX Overview gauges are retitled "Aggregate EUX Buckets (Avg, Min/Max)". The Summary page's average card and the line charts remain aggregate.

## Which filters affect what

- Report date window (`DaysBack` / Start / End): decides which hourly aggregate buckets are loaded and which runs are fetched. A run that overlaps the window is included **with its whole-run native score**, even if few or none of its buckets are in the window.
- Run, test and type slicers (`Filtered Test Runs`): filter both aggregate buckets and the native row.
- Native values are not affected by the date window beyond run inclusion.

## Optional migration of an existing customer report (copy first)

Installing the 1.2.0.0 connector changes no existing report and no existing DAX. To adopt native scores:

1. Close Desktop; back up your `.mez` and your `.pbix`. Work on a **copy** of the report.
2. Install the 1.2.0.0 connector. Open the copy and refresh once; confirm existing visuals are unchanged.
3. Either start from the 1.2.0.0 template and copy your visuals across, or in the copy add the table: Get Data, Login Enterprise, same parameters, select `Load Test Overview`; relate `Load Test Overview[testRunId]` to `Filtered Test Runs[id]` (many to one, single); set numeric columns to "Don't summarize"; add the measures from `template/source/measures/Load Test Overview/*.dax`.
4. Bind single-run cards to the native display measures. Keep the aggregate measures for trends.
5. Check with `template/acceptance/NativeOverviewChecks.dax` against the appliance values.

Rollback: delete the added table, relationship and measures (or discard the copy), and reinstall the 1.1.0.2 connector from `bin/archive/1.1.0.2/`. The original report is never modified.

## Status

Connector table and edge cases: tested on the real Power Query engine with synthetic fixtures (`tests/cases/10_native_overview.pq`). Live appliance: bounded read-only GETs only. Template: built reproducibly, statically checked, and accepted by Power BI Desktop's own TMSL deserializer offline. **Not yet opened or refreshed in Power BI Desktop; the new measures have not been executed.** See [ACCEPTANCE.md](ACCEPTANCE.md) section G.
