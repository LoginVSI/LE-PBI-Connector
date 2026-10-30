# Desktop acceptance record and checklist

**QUALIFIED ACCEPTANCE, 2026-10-23 (Pacific).** Legacy and Key reports load and refresh. Actual fixed-window Key results exactly match the source-reconciled legacy results, including all 11,549 measurements, all 83 measures and recorded filter/zero/failure contexts. Key credentials are native Feed Key and absent from M parameters. Nine legacy page screenshots and selected Logon interactions pass. Key moved-visual save/close/reopen and refresh without another credential entry pass. Final legacy Load/Refresh, native PBIT export and reproducible rebaseline pass. Not every interaction/negative UI case is observed; unavailable cases are recorded separately. Desktop hides the source path and does not support PBIDS export for this connector; direct path observation is unavailable, with SDK scope evidence kept separate. See [DESKTOP-ACCEPTANCE.md](DESKTOP-ACCEPTANCE.md) and [per-check results](evidence/desktop-acceptance-results.json). Core exercised checks pass; unobserved cases below are not claimed passed. The owner accepted these coverage limits. PR #4 merged as `9eb1ab28097403b478d88d6da88730bb01b69f89` after final repair-head CI passed; see [the final merge record](MERGE-HANDOFF.md#merge-record). No release was published.

Preparation history (completed for this host; do not reinstall into an open session):
1. Confirm the Results Toolkit session has released Power BI Desktop and the shared connector folder.
2. Print the effective folder (do not assume): `Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Power BI Desktop\Custom Connectors'`. On this workstation it resolved to `C:\Users\<user>\Documents\Power BI Desktop\Custom Connectors` (no redirection) when inspected on 2026-10-20; it currently holds `LE-PBI-Connector.mez` (public 1.1.0, 30 158 bytes, SHA256 recorded below) and `ResultsToolkit.mez` (not ours – do not touch).
3. Back up the installed copy: copy `LE-PBI-Connector.mez` to a folder outside `Custom Connectors` (rollback). Record its SHA256.
4. Copy the candidate `bin/AnyCPU/Debug/LE-PBI-Connector.mez` (SHA256 in `docs/SHA256SUMS.txt`) over it (same file name, so there is exactly one copy). Fully restart Desktop. Do **not** change data-extension security or credentials settings beyond what is already enabled; ask before touching shared trust/credential settings.
5. Use a bounded scope: a lab appliance, a read-only token, Days Back 7 (then a fixed range), no tests/settings/workloads/results created or changed.

## A. Discovery and compatibility
- [x] Get Data lists "Login Enterprise" (and "Login Enterprise (Key credential)"). No duplicate entries.
- [ ] An **existing** `.pbix` built on 1.1.0 opens, refreshes, and keeps its tables/relationships/measures (legacy entry point, unchanged signature).
- [ ] Wrong FQDN → new error text (transport message). Wrong token → "HTTP 401 … Authentication failed".

## B. Data correctness (reconcile with the appliance UI / API)
- [ ] Today: a run started today appears; End Date = today includes data after midnight UTC.
- [ ] A run with > 1000 measurements in one day: row count in `Measurements` equals the API rows satisfying the same half-open client filter (an inclusive API end can make its raw total one or more rows larger) (query `…/measurements?from=…&to=…&count=1&includeTotalCount=true`).
- [ ] > 1000 applications / environments (if available) all present; no duplicates by `id`.
- [ ] A Continuous run that started before the window and is still running: present for every in-window day.
- [ ] Boundary: an observation at exactly 00:00Z appears once.
- [ ] Reversed range, blank End Date with Use Date Range = true → explanatory error.
- [x] Time zones: record the machine's UTC offset; confirm table timestamps are local time while the window is UTC (README "Date windows").

## C. Empty / error / zero / failure behaviour
- [ ] A window with no runs → empty typed tables, no error.
- [ ] Revoke/alter the token mid-way → refresh fails (no partial tables published).
- [ ] A run with zero-valued metrics is shown as 0, not "No Data". A finished failed run with no measurements counts in the success-rate denominator; a run with no finish timestamp does not, even if it has a result enum.

## D. Template candidate (`template/candidate/…candidate.pbit`)
- [x] Opens without repair prompts; prompts for FQDN/token/Days Back; first refresh completes; second refresh completes (owner confirmed; durations not recorded).
- [x] All 9 pages render; no "Fix this" visuals (nine screenshots inspected individually; both Distinct Accounts cards render; selected-run interactions still pending).
- [ ] Slicer selection and cross-filtering (Run labels, name slicers) behave; failed/no-measurement runs are selectable on Session/Apps/EUX/Logon pages.
- [x] Summary: Total Test Runs, Success Rate, donut by type vs a hand count from the API.
- [x] Gauges are empty (not 0) with no run selected; `Show No Data (Session Metrics)` is blank for an all-zero metric.
- [x] Run these DAX queries in DAX query view and compare with hand counts: `EVALUATE ROW("eligible",[Eligible Test Runs (Filtered Test Runs)],"den",[Eligible Success Denominator (Filtered Test Runs)],"succ",[Successful Test Runs (Filtered Test Runs)],"rate",[Overall Success Rate Value (Filtered Test Runs)])` and the same wrapped in `CALCULATETABLE(…, 'Filtered Test Runs'[type] = "loadtest")`.
- [x] Edit (move a visual), **Save As .pbix**, close, reopen, refresh. If everything is fine: Save as template (`.pbit`) from Desktop, then run `template/Export-TemplateSource.ps1 -Pbit <saved>` to re-baseline the text source, and replace the structurally derived candidate with the Desktop-saved file.
- [ ] Note any metadata/security-binding prompts caused by the patched file.

## E. Key credential (only if kept in scope)
- [x] Migrate a copy of a report per README ("Choosing how the token is supplied"); credential dialog offers **Key**; token is not in the query or a parameter; refresh twice; rollback to the original works.
- [ ] Data source settings shows the data source as `LoginEnterprise_PBI_Key` with only the FQDN in its path.

## F. Gateway/Service (separate, admin-level, out of this patch)
- [ ] Runtime pending (no authorised gateway/tenant). Code, TestConnection, Key scope, setup and preflight are prepared: [GATEWAY.md](GATEWAY.md). Requires gateway admin, custom-connector enablement on the gateway, `.mez` in the gateway's folder, a data source with the same kind, TestConnection and a scheduled refresh. Record version, build, outcome.

## G. 1.2.0.0 additions (native overview)

### Executed (2026-10-30, no Desktop UI)
- Installed MEZ full SHA256 equals the built artifact (`fff51b3e...68a9`); the 1.1.0.2 backup (`8b7eac70...d768`) and `ResultsToolkit.mez` (`91dc405a...93e7`) are intact. Desktop was not running.
- Fixed window 2026-09-18..24 has no Load runs, so it cannot test native EUX. Windows used instead: A = 2025-06-30 (7 Load runs, large native/aggregate gaps) and B = 2025-05-28..29 (8 runs: two `disabled`, one `unavailable`, one null baseline).
- **Real Power Query engine against the live appliance (read-only, bounded):** the packaged 1.2.0.0 MEZ, `ContentsKey`, both windows. Navigator contains `Load Test Overview`; 7 of 7 and 8 of 8 rows reconcile with separate direct GETs (native values, states, bucket counts and means); no duplicate rows; nulls stay null, no 0 invented. [Evidence](evidence/native-eux-engine-reconciliation.json).
- Copies prepared in the private acceptance folder: existing-report copy and window-A Key `.pbit` (13 Key calls, static Key-copy check passes).

### NOT executed: Power BI Desktop
No Desktop controller is available to this session and Desktop was not started. These remain unexecuted and are not claimed: refresh of the existing-report copy with the new connector; opening and refreshing the 1.2.0.0 template and Key copy; one-legacy-and-one-Key navigator check in the Get Data UI; execution of any new DAX measure (`NativeOverviewChecks.dax`); the native card for run counter 77 and the multi-run message; aggregate-gauge titles on screen; window B disabled-run card; save/reopen persistence; rollback with 1.1.0.2. Static template checks and Desktop's offline model-schema reader are not DAX or Desktop validation.

### Finite checklist for the Desktop owner (copies only; one grouped pass)

Helpers (read-only against the open model; they change no file): `tools/Start-AcceptanceFile.ps1` opens one copy, waits for a queryable model and reconciles `NativeOverviewChecks.dax` against the private source expectations with `tools/Reconcile-NativeChecks.ps1` (PASS/FAIL per run, duplicate-row and multi-run guard). Windows: A = `A_2025-06-30`, B = `B_2025-05-28_to_29`. Private copies are in `.cache/desktop-acceptance-20261028/` (not in Git). Use `LE-acceptance-120-key-A-v3.pbit`; earlier versions are superseded. The installed connector is already 1.2.0.0 (hash in SHA256SUMS.txt).

1. **Existing report copy.** Open the file (double-click) and click Refresh. Expect the same visuals and counts as the accepted 1.1.0.2 baseline in [DESKTOP-ACCEPTANCE.md](DESKTOP-ACCEPTANCE.md); no `Load Test Overview` exists in this old report, so the reconcile script is not used here. Save.
2. **Key candidate, window A.** Open `LE-acceptance-120-key-A-v3.pbit` (window A is pre-set), supply the Key credential in the Desktop dialog (the token is never given to Claude), Load. In Get Data confirm one legacy and one Key entry and `Load Test Overview` in the navigator. Run `pwsh tools/Start-AcceptanceFile.ps1 -File .cache/desktop-acceptance-20261028/LE-acceptance-120-key-A-v3.pbit -Window A_2025-06-30 -NoLaunch` while the model is open: expect `RESULT: all reconciled`. Then look at the page: Load Testing > select counter 77 > EUX Score card reads 3.3; select several runs > the card reads `Select one run`; EUX Overview gauges are titled "Aggregate EUX Buckets (Avg, Min/Max)"; a run with VSImax `aboveThreshold` shows a "(bound, aboveThreshold)" display. Save As a new PBIX (`LE-acceptance-120-key-A-A.pbix`), close, reopen, confirm values persist.
3. **Window B.** In the same model change the window parameters to 2025-05-28 .. 2025-05-29, refresh, run the script with `-Window B_2025-05-28_to_29 -NoLaunch`: expect all reconciled; the two `disabled` runs show `No Data` (never 0), the `unavailable`/null-baseline run shows BLANK for the missing values and keeps its present score, and the counter-1 abandoned run keeps 8.0. Capture the two screenshots (redact names and FQDN).
4. **Rollback.** Close Desktop and tell Claude. Claude swaps in the 1.1.0.2 MEZ (from `.cache/desktop-install-20261028`), you open the existing-report copy and refresh once, close Desktop, tell Claude; Claude restores 1.2.0.0 and verifies the full installed hash.

## Rollback
Close Desktop → delete the candidate `.mez` → copy the backed-up copy back (same name) → restart Desktop → refresh an old `.pbix`.

## Recorded hashes (pre-acceptance)
Installed public 1.1.0 copy (read-only inspection): see `docs/SHA256SUMS.txt`.

## Acceptance procedure retained for reference

This historical procedure is not a request for further Desktop work. Completed checks and accepted coverage limits are recorded above and in DESKTOP-ACCEPTANCE.md.

1. Confirm the Toolkit owner has released Desktop. Record and back up the installed connector outside Custom Connectors. Verify candidate SHA256 against SHA256SUMS.txt; replace only LE-PBI-Connector.mez and restart Desktop. Leave ResultsToolkit.mez, trust and shared credentials alone.
2. Open a copy of an existing legacy PBIX and refresh a small existing-result window twice. Reconcile run IDs and half-open measurement/event timestamps, inclusive API end rows, ongoing Continuous runs, session interval IDs and local display times. Do not sum session counts across adjacent windows. Check an empty window and explanatory invalid-range errors. Do not revoke a shared token to simulate a failure; use an intentionally invalid value in an isolated copy.
3. Open the candidate PBIT, enter the existing authorized scope, refresh twice, and inspect every one of its 9 pages. Check failed/no-measurement run selection via both test-name and hybrid slicers, type filters and cross-highlighting.
4. In DAX query view run `template/acceptance/ModelChecks.dax`. Compare eligible/finished/successful counts with a hand list of loaded IDs. Exercise no selection, one run, multiple runs, a failed finished run without facts, an unfinished run with a default result, a true zero metric, null-only metrics and duplicate/blank account names with distinct IDs where existing results permit. Record unavailable cases rather than creating tests. Weighted values must be BLANK.
5. On a separate report copy, migrate only that copy to ContentsKey. Verify Key credential UI, FQDN-only data-source scope, two refreshes and rollback to the legacy copy. No token should appear in query text or parameters on that copy.
6. Move one visual, Save As PBIX, close, reopen and refresh. Record Desktop version, durations, prompts and DAX results. Re-save the PBIT from Desktop and re-export its editable source only after all checks pass; do not publish to Service. Restore the backed-up connector if acceptance fails.
