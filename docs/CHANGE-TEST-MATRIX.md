# Change / test matrix (connector 1.1.0.2, template candidate)

**Evidence levels.** *M-engine* = executed on the real Power Query mashup engine (PQTest from `Microsoft.PowerQuery.SdkTools` 2.155.2) against synthetic fixtures through an injected fetch function. *SDK-runtime* = executed through PQTest with the real `Web.Contents` path and its credential store (no live appliance). *Static* = file/JSON parsing and name resolution only. *Not run* = not executed anywhere. **No live Login Enterprise appliance, Power BI Desktop, Power BI Service or gateway was used.**

## Connector

| # | Confirmed problem | Change | Tests (file) | Evidence |
|---|---|---|---|---|
| 1 | `GetMeasurements` truncated at `count=1000&offset=0` per run/day | Every day fully paged with stable `direction=asc` (documented required param) | 03 (2500 rows/day in one run); 02 (3-page, exact-multiple, capped-page, no-total) | M-engine |
| 2 | `GetApplications` sent paging params and `PagedApiRequest` appended them again | Query is a record; helper strips caller `count/offset/includeTotalCount` and adds them once | 02 "caller-supplied count/offset…" | M-engine |
| 3 | `GetEnvironments` read one page | Uses the shared pager | 03 (schema/empty), 02 | M-engine |
| 4 | Failed requests hidden as empty/partial success (`try … otherwise null/{}`) everywhere | `Api.Request` classifies: success-empty (200/204), *unavailable* (404 on per-run sub-resources), *not applicable* (not queried: Application runs for aggregated endpoints; environments with collection disabled), failure (everything else raises with route/status/hint, token scrubbed) | 02 (401/403/404/400/malformed/shape/later page), 03 (per-run failure fails refresh, guard routes) | M-engine |
| 5 | Lazy `Web.Contents` errors escaped `try` (found by running the real engine) | Status/Body touched inside the `try` | 02 "lazy failure…"; PQTest `run-test` against `invalid.invalid` shows the wrapped message | M-engine + SDK-runtime |
| 6 | `GetUserSessions` used End Date midnight | Shared window helper; `to` = day after selected end | 03 guard route (`to=2026-10-22T00:00:00Z`) | M-engine |
| 7 | `LocalNow`/literal-`Z` vs local→UTC conversion | UTC-day policy; "today" = `DateTimeZone.UtcNow()`; platform metrics now same policy | 01 (rolling, single day, DST fall/spring, UTC-7/UTC+12 same instant) | M-engine |
| 8 | Reversed/partial/invalid dates; empty-run cross joins | Explicit errors; list-based fetch (no cross-join) | 01 (6 error cases), 03 empty tenant | M-engine |
| 9 | Type casing (`continuousTest` vs `ContinuousTest`) and long-running Continuous overlap | Case-insensitive type; overlap = `started < end && (finished null or ≥ start)` | 01 run-selection tests, 03 | M-engine |
| 10 | Boundary double counting | Client-side `[from,to)` filter on the day chunk (fake server treats `to` as inclusive) | 03 midnight cases | M-engine |
| 11 | Non-progress / unbounded paging | Page-limit, same-page detection, `totalCount` completeness check. **Wall-clock deadline not implemented**: `DateTime.LocalNow` is fixed per evaluation (verified) | 02 | M-engine |
| 12 | Credential-like literal + stale args in `query.pq` | Placeholders, current signature (literal never printed/tested) | `tools/Test-NoSecrets.ps1` | Static |
| 13 | `TestConnection` wrong shape; lazy nav passes trivially | `(dataSourcePath) => {fn, args…}`; function probes `tests?count=1` eagerly | 03 (shape); PQTest `test-connection` returns *Failure* for an unresolvable host (a real request is made) | M-engine + SDK-runtime |
| 14 | Token as clear-text argument | Additive Key entry point `ContentsKey`; legacy untouched | 04 (interfaces); PQTest set-credential Key + run + test-connection | SDK-runtime only; **Desktop/Service not run** |
| 15 | Package name/`.proj` mismatch, non-reproducible zip | `LE-PBI-Connector.mez`, `build/Build-Mez.ps1` (stored zip, fixed timestamps, LF via `.gitattributes`), CI `-Check` | CI | Executed locally |
| 16 | 1.1.0.1 hotfix (EndDate+1 for EUX/session metrics) | Generalised: every table uses `[start, end+1)` | 03 | M-engine |

## Template candidate (DAX not executed – no engine available)

| # | Confirmed problem | Change (identifier kept unless noted) | Check | Evidence |
|---|---|---|---|---|
| T1 | Success rate required Measurements | `Overall Success Rate (% & Filtered Test Runs)` and `Overall Success Rate (%)`: denominator = finished Application/Load runs; numeric `…Value` measure; valid 0% stays 0 | Static reference check; **DAX not executed** | Static |
| T2 | Session Metrics "No Data" = `SUM=0` | `COUNTROWS = 0` | Static | Static |
| T3 | Active Sessions Count was distinct accounts | New `Distinct Accounts (Measurements)`; two Logon-page cards rebound + relabelled; old measure kept (deprecated description) | Static; layout binding check | Static |
| T4 | Total Test Runs hard-coded 30d / `<= TODAY()` | Follows loaded window via Filtered Test Runs | Static | Static |
| T5 | Gauges show 0 with no selected run | `BLANK()` | Static | Static |
| T6 | Aggregate averages ignore `count`; min/max are bucket extrema | New weighted EUX/CPU/Memory (numeric + display), unit guard; legacy kept; labels documented | Static | Static |
| T7 | Measurement-only slicers hide failed runs | New `Show Hybrid Slicer Item (Run Evidence)` (16 filter bindings renamed); `Filtered Test Runs` M also includes connector `Test Runs In Window` ids | Partition M evaluated on engine (05); DAX static | M-engine (M) / Static (DAX) |
| T8 | Failed-sessions card showed "No Data" for a valid 0 | Shows 0 when sessions exist | Static | Static |

## Unverified / to confirm against the appliance's own Swagger (`/publicApi/swagger`, v7-preview)
- Maximum `count` per endpoint and the effective ordering for each route (only `direction`/`orderBy` documented as required on some routes). Page size 1000 is used everywhere (value already accepted for measurements by 1.1.0.1).
- `totalCount` semantics when `includeTotalCount=true` (field name taken from the generated v7-preview models; only requested on page 1).
- Whether `from/to` are inclusive/exclusive on each route (handled defensively by client-side filtering).
- Whether aggregated EUX / session-metric endpoints are paged (treated as non-paged arrays, as 1.1.0.1 did).
- Platform-metrics response for environments without collection (404 handled as empty; disabled environments are not queried).
- Application session-metric branch: **not implemented**; no aggregated Application-test session-metric endpoint is documented in the public models reviewed, so Application runs contribute measurements/events/sessions only.
- Test-run `result` vocabulary: load-test models list `completed|aborted|abandoned`; Application runs may use other words. Success set kept as `successful|completed`.
