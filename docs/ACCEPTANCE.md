# Desktop acceptance checklist (run when the shared Power BI host is released)

**PARTIAL, 2026-10-22.** Repaired and subsequent refreshes succeeded. Actual populated-model DAX and bounded source reconciliation pass the recorded cases. All nine screenshots render without visual errors at All selection. ISO date fields accepted the specified strings; canonical tooltips/examples were rebuilt. Selected Logon successful/failed UI checks pass. Key migration, other page-specific interactions and remaining compatibility/export checks are still open. The Key import exposed persisted-query metadata defects; both failed copies are preserved and the rebuilt retry2 awaits Desktop validation. The initial failed Load and empty readback are retained. See [DESKTOP-ACCEPTANCE.md](DESKTOP-ACCEPTANCE.md) and [per-check results](evidence/desktop-acceptance-results.json). Keep PR #4 draft.

Preconditions (owner actions, in order):
1. Confirm the Results Toolkit session has released Power BI Desktop and the shared connector folder.
2. Print the effective folder (do not assume): `Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Power BI Desktop\Custom Connectors'`. On this workstation it resolved to `C:\Users\j.kennedy\Documents\Power BI Desktop\Custom Connectors` (no redirection) when inspected on 2026-10-20; it currently holds `LE-PBI-Connector.mez` (public 1.1.0, 30 158 bytes, SHA256 recorded below) and `ResultsToolkit.mez` (not ours – do not touch).
3. Back up the installed copy: copy `LE-PBI-Connector.mez` to a folder outside `Custom Connectors` (rollback). Record its SHA256.
4. Copy the candidate `bin/AnyCPU/Debug/LE-PBI-Connector.mez` (SHA256 in `docs/SHA256SUMS.txt`) over it (same file name, so there is exactly one copy). Fully restart Desktop. Do **not** change data-extension security or credentials settings beyond what is already enabled; ask before touching shared trust/credential settings.
5. Use a bounded scope: a lab appliance, a read-only token, Days Back 7 (then a fixed range), no tests/settings/workloads/results created or changed.

## A. Discovery and compatibility
- [ ] Get Data lists "Login Enterprise" (and "Login Enterprise (Key credential)"). No duplicate entries.
- [ ] An **existing** `.pbix` built on 1.1.0 opens, refreshes, and keeps its tables/relationships/measures (legacy entry point, unchanged signature).
- [ ] Wrong FQDN → new error text (transport message). Wrong token → "HTTP 401 … Authentication failed".

## B. Data correctness (reconcile with the appliance UI / API)
- [ ] Today: a run started today appears; End Date = today includes data after midnight UTC.
- [ ] A run with > 1000 measurements in one day: row count in `Measurements` equals the API rows satisfying the same half-open client filter (an inclusive API end can make its raw total one or more rows larger) (query `…/measurements?from=…&to=…&count=1&includeTotalCount=true`).
- [ ] > 1000 applications / environments (if available) all present; no duplicates by `id`.
- [ ] A Continuous run that started before the window and is still running: present for every in-window day.
- [ ] Boundary: an observation at exactly 00:00Z appears once.
- [ ] Reversed range, blank End Date with Use Date Range = true → explanatory error.
- [ ] Time zones: record the machine's UTC offset; confirm table timestamps are local time while the window is UTC (README "Date windows").

## C. Empty / error / zero / failure behaviour
- [ ] A window with no runs → empty typed tables, no error.
- [ ] Revoke/alter the token mid-way → refresh fails (no partial tables published).
- [ ] A run with zero-valued metrics is shown as 0, not "No Data". A finished failed run with no measurements counts in the success-rate denominator; a run with no finish timestamp does not, even if it has a result enum.

## D. Template candidate (`template/candidate/…candidate.pbit`)
- [ ] Opens without repair prompts; prompts for FQDN/token/Days Back; first refresh completes; second refresh completes (note durations).
- [x] All 9 pages render; no "Fix this" visuals (nine screenshots inspected individually; both Distinct Accounts cards render; selected-run interactions still pending).
- [ ] Slicer selection and cross-filtering (Run labels, name slicers) behave; failed/no-measurement runs are selectable on Session/Apps/EUX/Logon pages.
- [ ] Summary: Total Test Runs, Success Rate, donut by type vs a hand count from the API.
- [ ] Gauges are empty (not 0) with no run selected; `Show No Data (Session Metrics)` is blank for an all-zero metric.
- [ ] Run these DAX queries in DAX query view and compare with hand counts: `EVALUATE ROW("eligible",[Eligible Test Runs (Filtered Test Runs)],"den",[Eligible Success Denominator (Filtered Test Runs)],"succ",[Successful Test Runs (Filtered Test Runs)],"rate",[Overall Success Rate Value (Filtered Test Runs)])` and the same wrapped in `CALCULATETABLE(…, 'Filtered Test Runs'[type] = "loadtest")`.
- [ ] Edit (move a visual), **Save As .pbix**, close, reopen, refresh. If everything is fine: Save as template (`.pbit`) from Desktop, then run `template/Export-TemplateSource.ps1 -Pbit <saved>` to re-baseline the text source, and replace the structurally derived candidate with the Desktop-saved file.
- [ ] Note any metadata/security-binding prompts caused by the patched file.

## E. Key credential (only if kept in scope)
- [ ] Migrate a copy of a report per README ("Choosing how the token is supplied"); credential dialog offers **Key**; token is not in the query or a parameter; refresh twice; rollback to the original works.
- [ ] Data source settings shows the data source as `LoginEnterprise_PBI_Key` with only the FQDN in its path.

## F. Gateway/Service (separate, admin-level, out of this patch)
- [ ] Not started. Requires gateway admin, custom-connector enablement on the gateway, `.mez` in the gateway's folder, a data source with the same kind, TestConnection and a scheduled refresh. Record version, build, outcome.

## Rollback
Close Desktop → delete the candidate `.mez` → copy the backed-up copy back (same name) → restart Desktop → refresh an old `.pbix`.

## Recorded hashes (pre-acceptance)
Installed public 1.1.0 copy (read-only inspection): see `docs/SHA256SUMS.txt`.

## Exact sequence after the host is available

1. Confirm the Toolkit owner has released Desktop. Record and back up the installed connector outside Custom Connectors. Verify candidate SHA256 against SHA256SUMS.txt; replace only LE-PBI-Connector.mez and restart Desktop. Leave ResultsToolkit.mez, trust and shared credentials alone.
2. Open a copy of an existing legacy PBIX and refresh a small existing-result window twice. Reconcile run IDs and half-open measurement/event timestamps, inclusive API end rows, ongoing Continuous runs, session interval IDs and local display times. Do not sum session counts across adjacent windows. Check an empty window and explanatory invalid-range errors. Do not revoke a shared token to simulate a failure; use an intentionally invalid value in an isolated copy.
3. Open the candidate PBIT, enter the existing authorized scope, refresh twice, and inspect every one of its 9 pages. Check failed/no-measurement run selection via both test-name and hybrid slicers, type filters and cross-highlighting.
4. In DAX query view run `template/acceptance/ModelChecks.dax`. Compare eligible/finished/successful counts with a hand list of loaded IDs. Exercise no selection, one run, multiple runs, a failed finished run without facts, an unfinished run with a default result, a true zero metric, null-only metrics and duplicate/blank account names with distinct IDs where existing results permit. Record unavailable cases rather than creating tests. Weighted values must be BLANK.
5. On a separate report copy, migrate only that copy to ContentsKey. Verify Key credential UI, FQDN-only data-source scope, two refreshes and rollback to the legacy copy. No token should appear in query text or parameters on that copy.
6. Move one visual, Save As PBIX, close, reopen and refresh. Record Desktop version, durations, prompts and DAX results. Re-save the PBIT from Desktop and re-export its editable source only after all checks pass; do not publish to Service. Restore the backed-up connector if acceptance fails.
