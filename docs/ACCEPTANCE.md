# Desktop acceptance checklist (run when the shared Power BI host is released)

**READY-FOR-DESKTOP.** Nothing here has been run. Do not call the candidate accepted from parsing or PQTest results.

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
- [ ] A run with > 1000 measurements in one day: row count in `Measurements` equals the API `totalCount` for the run/day (query `…/measurements?from=…&to=…&count=1&includeTotalCount=true`).
- [ ] > 1000 applications / environments (if available) all present; no duplicates by `id`.
- [ ] A Continuous run that started before the window and is still running: present for every in-window day.
- [ ] Boundary: an observation at exactly 00:00Z appears once.
- [ ] Reversed range, blank End Date with Use Date Range = true → explanatory error.
- [ ] Time zones: record the machine's UTC offset; confirm table timestamps are local time while the window is UTC (README "Date windows").

## C. Empty / error / zero / failure behaviour
- [ ] A window with no runs → empty typed tables, no error.
- [ ] Revoke/alter the token mid-way → refresh fails (no partial tables published).
- [ ] A run with zero-valued metrics is shown as 0, not "No Data". A failed run with no measurements counts in the success-rate denominator.

## D. Template candidate (`template/candidate/…candidate.pbit`)
- [ ] Opens without repair prompts; prompts for FQDN/token/Days Back; first refresh completes; second refresh completes (note durations).
- [ ] All 9 pages render; no "Fix this" visuals (check each page; the two Logon Metrics "Distinct Accounts" cards and the 8 hybrid slicers specifically).
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
