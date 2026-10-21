# Changelog

## 1.1.0.2 (candidate – not yet accepted in Power BI Desktop)
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
