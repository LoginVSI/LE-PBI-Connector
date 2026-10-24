# First Desktop Load failure and shared-run repair

**Failed, not loaded or accepted.** The owner reported thirteen blocked queries, including Aggregated EUX Results, Measurements, User Session Metrics, Workload Steps and Filtered Test Runs. Each displayed HTTP 500 for `/publicApi/v7-preview/tests/test-runs` after three attempts. This failed acceptance attempt is retained separately from the original synthetic test passes.

## Sanitized reproduction and isolation

The installed 6393ce2 package constructed this first-page query for each test type:

```
GET /publicApi/v7-preview/tests/test-runs?testType=applicationTest&orderBy=created&direction=asc&count=1000&offset=0&includeTotalCount=true&include=testRunConfigurationSnapshot
```

This is reconstructed from the verified shipped code, not a captured Desktop trace. Native-vault read-only requests independently reproduced HTTP 500. No dates or free-text filter are sent on this route: the run catalog is global, and date selection is applied client-side. Thus ISO date serialization cannot explain this particular failure. `created`, `asc`, test types and `testRunConfigurationSnapshot` are valid matching Swagger enum values; `include` is a comma-separated form array. Count 1000 is accepted when expansion is omitted.

Minimal contract-correct reproduction:

```
GET /publicApi/v7-preview/tests/test-runs?testType=applicationTest&orderBy=created&direction=asc&count=1&offset=0&includeTotalCount=true&include=testRunConfigurationSnapshot
```

The oldest Application and Load results return HTTP 500 with snapshot expansion. Omitting `include` returns HTTP 200 with null snapshot fields. Varying count to 100/1000, ordering to testName, direction, offset or totals individually does not repair the full failing page. With count 1, selecting the newest record instead succeeds. The oldest records also fail through the independently tested v7-preview `/test-runs/{id}` route when snapshot expansion is requested; the newer records succeed. This establishes a record-dependent appliance snapshot-expansion failure, not a page-size, date or cache defect. The appliance's internal cause has not been established, and no appliance configuration or stored results were changed.

Evidence: [isolation matrix](evidence/desktop-test-runs-isolation.json), [snapshot contents](evidence/desktop-test-runs-snapshots.json), [single-run probe](evidence/desktop-test-runs-resource-probe.json). Origin, token, names, raw records and real IDs are excluded from public evidence.

## Verified workaround and compatibility

Simply omitting expansion would silently remove workload data, so it was rejected. The repair enumerates all run metadata without expansion and hydrates snapshots **only for overlapping Application/Load runs** through the verified v7-preview single-run endpoint. All 20 such runs in the unchanged acceptance window (18 through 24 September 2026) returned HTTP 200, nonnull snapshots and two workload steps each. [Selected-window verification](evidence/desktop-test-runs-workaround.json).

All run IDs, metadata, navigation names, columns, parameter identifiers and entry-point signatures are retained. Snapshot/name/workload columns are now populated for overlapping Application/Load runs only; older catalog rows outside the selected window retain metadata with null snapshots. This is an intentional acquisition-scope change, not a claim that unavailable history is empty. Continuous runs have no snapshot field in the matching contract and are not queried for it. No current test configuration is substituted for a historical snapshot.

If a selected snapshot itself fails, refresh still fails with its HTTP context. Narrowing to a healthy retained window can avoid broken history outside that window; a window containing a broken selected snapshot remains blocked on an appliance-side repair. There is no catch-to-empty fallback and retries were not increased. Existing request timeout, page limits and elapsed budget still apply; detail hydration adds requests proportional to overlapping Application/Load runs.

## Retry cache verification

Production requests retain `IsRetry = attempt > 0`. A real PQTest/M test used production cache options and retry orchestration against a bounded loopback server. A repeated ordinary 200 used one HTTP request, forcing IsRetry made two requests, and a transient 500 was followed by a successful second HTTP request. [Passing evidence](evidence/http-retry-cache.json).

The standalone query had to omit the extension-only ManualCredentials option, while retaining production cache flags and retry orchestration. The initial context-mismatch failure is preserved in [initial evidence](evidence/http-retry-cache-initial.json). This test establishes actual Web.Contents cache bypass in the SDK runtime, not packet-level Desktop tracing. Independent direct requests reproduce the server failure without a Power Query cache. The loopback test uses only synthetic credentials and does not change trust or contact the appliance.

## Acceptance disposition

The new candidate must be rebuilt and installed after the owner saves the current report and closes Desktop. The in-progress working PBIT/report and parameters have not been overwritten or edited by the repair. Retry on that same saved copy; do not create a fresh report or change its dates/token to conceal the failure. Actual Desktop refresh, DAX, visuals, Key migration and save/reopen acceptance remain pending. The separate date-tooltip finding is still waiting for explicit Desktop ISO-field validation; M culture tests alone are not that validation.
