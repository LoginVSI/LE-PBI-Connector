# Changelog

## 1.1.0.2 (community preview, qualified Desktop acceptance)
Connector (`LE-PBI-Connector.mez`)
- Fixed: measurements were truncated at 1000 rows per run per day; applications received duplicate paging parameters; environments read one page. All lists are now fully paged with `count`/`offset` added once, completeness checked against `totalCount`, non-progress and page-limit protected.
- Fixed: failed requests no longer become empty/partial tables. Errors carry route/status/hint, never the token. Bounded retry for 408/429/5xx.
- Fixed: one date policy (UTC calendar days, half-open window, end day and today fully included). `GetUserSessions` no longer stops at End Date midnight; platform metrics use the same policy. Reversed/partial/invalid inputs raise explanatory errors (previously silently defaulted to 30 days).
- Fixed: test-run type matching is case-insensitive; long-running (unfinished) Continuous runs are fetched for every in-window day; runs outside the window are no longer queried per-run.
- Added: `LoginEnterprise_PBI.ContentsKey` (Key credential, token not stored in the query). Legacy `LoginEnterprise_PBI.Contents` unchanged.
- Added: `Test Runs In Window` navigation item (additive).
- Fixed: `TestConnection` uses the documented `dataSourcePath` callback and the call performs a real small request.
- Fixed: example query uses placeholders and the current signature. Packaging: single canonical `LE-PBI-Connector.mez`, byte-reproducible build, `.proj` corrected.
- Behaviour changes to be aware of: Use Date Range with a missing date is now an error; windows are UTC days (platform metrics previously used a local-to-UTC conversion); Application test runs are not queried for aggregated endpoints (they were previously requested and swallowed).

Template (candidate, see TEMPLATE-CHANGES.md)
- Success rate/Total Test Runs/donut count failed and no-measurement runs; slicers no longer hide them; valid zeros preserved; gauges blank when no run selected; weighted EUX/CPU/Memory alternatives; Active Sessions relabelled Distinct Accounts.

## 1.1.0.1 (shipped binary, previously undocumented)
- EndDate+1 day for Aggregated EUX and User Session Metrics only (preserved and generalised in 1.1.0.2).

## 1.1.0 (public source)

## Independent audit corrections to 1.1.0.2 candidate

Correct capped/no-total paging, totals/offset validation, late-page and production subresource 404 handling, strict lower timestamp boundaries, session interval filtering and terminal startup failures. Add manual credential handling for the bearer header, stricter malformed-data errors, a cooperative elapsed budget and tighter request/retry/page limits.

Repair loaded-window success and name-slicer context, require terminal timestamps, count account IDs and preserve zero versus missing values. Weighted statistics remain disabled until API count meaning is established. CI now checks the deliberate M failure probe and staged PBIT source parity. Independent evidence and all acceptance limits are in INDEPENDENT-AUDIT.md.

## First Desktop Load repair (acceptance pending)

Reproduced the run-catalog 500 caused by expansion of some older stored snapshots. Enumerate metadata without expansion and hydrate overlapping Application/Load snapshots through the independently verified v7-preview single-run route. Keep metadata and schemas; document that snapshot/workload values are now window-scoped. Preserve errors for selected-run failures. Add a real HTTP cache/retry probe and selected-window snapshot regression. The failed Desktop attempt remains failed until an actual retry succeeds.

## Desktop retry, 22 October 2026

Owner reports a successful repaired refresh with visible data and a saved edit that survived closing and reopening. Retain the first failed Load and installation history. Execute ModelChecks and all 83 measures read-only on the prepared saved copy; that copy is empty, so these results establish only empty-context execution. Record all nine pages separately as awaiting visual checks. Populated reconciliation, compatibility, Key migration and date-control validation remain open. Package versions and hashes are unchanged.

## Populated Desktop reconciliation and date help

Actual-model checks now reconcile the retained run list, 95% Application success rate, failed/no-measurement denominator, account count and representative durations. A 5,601-row run matches six source pages, and a real zero session metric remains data. All nine supplied screenshots render without visual errors at All selection. Selected-run interactions and Key acceptance remain open. After the owner verified ISO Date-field entry in en-US, replace both unexplained US date examples with YYYY-MM-DD examples and explicit whole-UTC-end-day guidance. Parameter identifiers and parsing remain unchanged; rebuild the canonical candidate without overwriting the working report.

## Persisted-query metadata repair during Key acceptance

Initial Key import failed because APIToken was removed from DataModelSchema but retained in UnappliedChanges. That inspection also found stale canonical Filtered Test Runs M and date help. The first metadata repair incorrectly wrote raw M into lastLoadedAsTableFormulaText; Desktop expects nested JSON. Both failed files and sanitized errors are preserved. The builder now synchronizes text, nested RootFormulaText, descriptions and lineage owners; Key preparation explicitly removes the token query and query-order entry. Seven static metadata regressions pass, and the installed Desktop JSON parser rejects all 12 broken fields but parses all 12 corrected fields. Source/template parity passes; final Desktop retry2 is pending. Actual populated DAX/source and selected Logon passes remain evidence for the earlier legacy copy, not acceptance of the new metadata repair. See evidence/template-persisted-metadata.json and evidence/desktop-key-preparation.json.

## Key retry2 actual acceptance, 23 October 2026

Key import, Load and Refresh succeeded. Actual model: no token parameter, 12 Key calls, zero legacy calls, and all 12 partition definitions match canonical M after migration. The first read used rolling 30 days because the preparation tool had contradictory DefaultValue metadata. Preserve that report, fix the preparer to synchronize DaysBack/UseDateRange values and defaults, and add a static Key-copy check that rejects both old defaults and accepts the corrected copy. The separate fixed-window report matches every legacy result multiset, including all 11,549 observations, all 83 measures and context/relationship/zero checks. Feed Key authentication is visible with a masked token. Direct Desktop path is hidden by the label and PBIDS export is unsupported; retain SDK scope evidence separately. Persistence and legacy rollback remain pending owner UI actions. See evidence/desktop-key-acceptance.json. No source MEZ, report parameters, Toolkit project, installed connector, trust or credential was changed by the agent.

## Final native Desktop round trip

Final legacy Load/Refresh and ModelChecks match baseline; 12 loaded M partitions and both date descriptions match canonical sources. A genuine Desktop PBIT export resets all six parameter values to null and passes known connection/result-value privacy scans. Re-exported editable sources retain all 83 DAX expressions and 12 M partitions; empty header whitespace is normalized. Pin the native PBIR base and deterministically rebuild the candidate, preserving nine pages/220 visuals and all original identifiers/relationships. Desktop adds one automatic date table/relationship and refines nine Tests field types to the connector's types; no shipped measure or visual query uses those fields. See evidence/desktop-roundtrip.json and template/source/desktop-base.json. Original reports, failed evidence, original template and installed connectors remain preserved.
