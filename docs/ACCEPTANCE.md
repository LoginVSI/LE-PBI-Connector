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

## F. Gateway/Service
- [x] Local evaluation run 2026-11-02 to 2026-11-04: see section H and [GATEWAY.md](GATEWAY.md). Executed: install, connector folder, Key connection, publish to a private workspace, two on-demand refreshes, one scheduled refresh that completed, Service-side source check (7 of 7 after the on-demand runs). Failed: the first scheduled run (host shut down mid-run). Not established: why the early scheduled attempts stalled; always-on server hosting; multi-day schedules; token-revocation recovery.
## G. 1.2.0.0 additions (native overview)

### Executed (2026-10-30, no Desktop UI)
- Installed MEZ full SHA256 equals the built artifact (`fff51b3e...68a9`); the 1.1.0.2 backup (`8b7eac70...d768`) and `ResultsToolkit.mez` (`91dc405a...93e7`) are intact. Desktop was not running.
- Fixed window 2026-09-18..24 has no Load runs, so it cannot test native EUX. Windows used instead: A = 2025-06-30 (7 Load runs, large native/aggregate gaps) and B = 2025-05-28..29 (8 runs: two `disabled`, one `unavailable`, one null baseline).
- **Real Power Query engine against the live appliance (read-only, bounded):** the packaged 1.2.0.0 MEZ, `ContentsKey`, both windows. Navigator contains `Load Test Overview`; 7 of 7 and 8 of 8 rows reconcile with separate direct GETs (native values, states, bucket counts and means); no duplicate rows; nulls stay null, no 0 invented. [Evidence](evidence/native-eux-engine-reconciliation.json).
- Copies prepared in the private acceptance folder: existing-report copy and window-A Key `.pbit` (13 Key calls, static Key-copy check passes).

### Executed in Desktop (2026-11-02, owner-operated; Claude queried the open models and reconciled)
- **Existing-report copy:** opened, refreshed and saved with the 1.2.0.0 connector; model checks identical to the accepted legacy baseline in all four result sets ([evidence](evidence/desktop-existing-copy-120.json)).
- **First open of the Key candidate failed** (Desktop: file corrupted or unrecognized). Cause found by bisecting in Desktop: the stale `SecurityBindings` part; fixed in `Build-Template.ps1`; candidate rebuilt (v4).
- **Key candidate v4, window A (2025-06-30):** loaded with the saved Key credential; `NativeOverviewChecks.dax` reconciled 7 of 7 runs with direct API reads; counter 77 reads 3.3 (owner-observed card); no run selected shows the `Select one run` guard (run list is single-select by design; the multi-run DAX check also passes); gauges titled "Aggregate EUX Buckets (Avg, Min/Max)" (owner-observed); VSImax `aboveThreshold` display text contains "(bound, aboveThreshold)" (DAX result); no duplicate overview rows ([evidence](evidence/desktop-native-window-a.json)).
- **Persistence:** Save As new PBIX, close, reopen: card still 3.3 and 7 of 7 reconcile again.
- **Window B (2025-05-28..29):** 8 of 8 reconcile; disabled runs blank and `No Data`, unavailable run keeps 8.0, null baseline/steady stay blank ([evidence](evidence/desktop-native-window-b.json)).
- **Legacy-credential variant (public candidate file, owner-reported 2026-11-02):** the owner opened `template/candidate/Login Enterprise 1.2.0.0-candidate.pbit` itself in Desktop, refreshed, saved a new PBIX, closed and reopened it with no issues. No model query or reconciliation was run on that file by Claude, and the window and parameter values used were not recorded.
- **Rollback:** 1.1.0.2 installed (full hash verified), the existing-report copy refreshed without errors (owner-reported), 1.2.0.0 restored and its full SHA256 verified equal to the build (`FFF51B3E…68A9`); `ResultsToolkit.mez` unchanged (`91DC405A…`).

### Not executed (not claimed)
The Get Data one-legacy-one-Key entry check was not performed. No screenshots were captured. VSImax bound text was verified from the DAX result, not by eye. No retained native value of 0 exists (valid zero is covered by engine fixtures). The rollback refresh was not followed by a model query. Gateway/Service runtime remains environment-blocked. Static checks and the offline model-schema reader remain separate from Desktop validation.
### Owner checklist (completed 2026-11-02; retained for repeating on another report)

Helpers (read-only against the open model; they change no file): `tools/Start-AcceptanceFile.ps1` opens one copy, waits for a queryable model and reconciles `NativeOverviewChecks.dax` against the private source expectations with `tools/Reconcile-NativeChecks.ps1` (PASS/FAIL per run, duplicate-row and multi-run guard). Windows: A = `A_2025-06-30`, B = `B_2025-05-28_to_29`. Private copies are in `.cache/desktop-acceptance-20261028/` (not in Git). Use `LE-acceptance-120-key-A-v4.pbit`; v1 to v3 are superseded (v1 to v3 do not open in Desktop; see TEMPLATE-CHANGES.md). The installed connector is already 1.2.0.0 (hash in SHA256SUMS.txt).

1. **Existing report copy.** Open the file (double-click) and click Refresh. Expect the same visuals and counts as the accepted 1.1.0.2 baseline in [DESKTOP-ACCEPTANCE.md](DESKTOP-ACCEPTANCE.md); no `Load Test Overview` exists in this old report, so the reconcile script is not used here. Save.
2. **Key candidate, window A.** Open `LE-acceptance-120-key-A-v4.pbit` (window A is pre-set), supply the Key credential in the Desktop dialog (the token is never given to Claude), Load. In Get Data confirm one legacy and one Key entry and `Load Test Overview` in the navigator. Run `pwsh tools/Start-AcceptanceFile.ps1 -File .cache/desktop-acceptance-20261028/LE-acceptance-120-key-A-v4.pbit -Window A_2025-06-30 -NoLaunch` while the model is open: expect `RESULT: all reconciled`. Then look at the page: Load Testing > tick the run that started 14:40 (the 6th entry, counter 77; the list shows test name and start time, not counter) > EUX Score card reads 3.3; the Run list is single-select by design, so clear the selection (all runs in scope) and the card reads `Select one run` (the multi-run DAX check covers the same guard); EUX Overview gauges are titled "Aggregate EUX Buckets (Avg, Min/Max)"; a run with VSImax `aboveThreshold` shows a "(bound, aboveThreshold)" display. Save As a new PBIX (`LE-acceptance-120-key-A-A.pbix`), close, reopen, confirm values persist.
3. **Window B.** In the same model change the window parameters to 2025-05-28 .. 2025-05-29, refresh, run the script with `-Window B_2025-05-28_to_29 -NoLaunch`: expect all reconciled; the two `disabled` runs show `No Data` (never 0), the `unavailable`/null-baseline run shows BLANK for the missing values and keeps its present score, and the counter-1 abandoned run keeps 8.0. Capture the two screenshots (redact names and FQDN).
4. **Rollback.** Close Desktop and tell Claude. Claude (or you: `pwsh tools/Swap-Connector.ps1 -To 1.1.0.2`) swaps in the 1.1.0.2 MEZ, you open the existing-report copy and refresh once, close Desktop, tell Claude; restore with `pwsh tools/Swap-Connector.ps1 -To 1.2.0.0`, which verifies the full installed hash (the script refuses to run while Desktop is open, and never touches ResultsToolkit.mez).

## H. Gateway / Service local evaluation (2026-11-02 to 2026-11-04)

Evidence: [gateway-service-acceptance.json](evidence/gateway-service-acceptance.json). Owner-operated where a UAC prompt, sign-in or credential was needed; Claude read refresh history and ran the read-only checks in the owner's signed-in browser pane.

Executed
- Standard gateway installed from Microsoft's signed installer; test gateway registered; connector folder outside the profile with only the 1.2.0.0 MEZ and a hardened ACL; service account given Read and Execute; Key-kind connection Online.
- Private Key-based report (13 Key queries, no token parameter, window 2025-06-30) published to My workspace under a unique name and mapped to the gateway connection.
- On-demand refreshes 1 and 2: Completed in about 2 minutes each; the second showed six gateway-child containers connecting to the appliance.
- Service DAX check after the on-demand refreshes: 7 of 7 runs match the source, including native 3.3 against bucket mean 4.2 for one run.
- Scheduled refresh 2026-11-04 13:01: Completed at 13:18:32 after the first two attempts did not get through. The Service DAX check was repeated afterwards: 7 of 7 runs match the source again (connector 1.2.0.0).
- **Connector 1.2.1.0 on the gateway, one on-demand refresh (2026-11-04 15:29 to 15:31 Pacific):** the package was swapped while nothing was running, the service restarted, the key re-entered locally; Completed in 2 minutes; six gateway-child containers connected; 7 of 7 runs reconcile in the Service. This is the only 1.2.1.0 gateway evidence; the earlier on-demand and scheduled successes belong to 1.2.0.0.
- Host and network checks listed in the evidence file; temporary schedules disabled and verified.

Observed failure
- Scheduled refresh 2026-11-02 18:01 failed after 31 minutes with `DM_GWPipeline_Client_GatewayUnreachable`; the gateway host shut down at 18:18:45 mid-run. The refresh was in a retry rhythm of about 6.5 minutes between gateway attempts.

Not executed or not established
- Why the first scheduled attempts stalled while on-demand runs did not; gateway logs were not collected. A stale key in the connection is an unconfirmed hypothesis.
- A scheduled refresh with connector 1.2.1.0 (only one on-demand refresh was run with it); timings, resource or EUX data from a Continuous source (only failure records were produced; see the dummy lab scenario below).
- **Dummy Continuous lab scenario, 2026-11-04 (UTC 03:12 to 03:58), connector 1.2.1.0, on-demand refreshes only:** a temporary Continuous test with a custom connector and an unreachable target ran on one registered laptop launcher. It produced genuinely new source records: five user sessions (three failed, two aborted when the test was disabled) and three `connectionInitializationTimeout` events, with no measurements and no EUX results. A private Continuous Key copy (window 2026-11-04 to 2026-11-05) was loaded in Desktop, published to a private workspace, mapped to the gateway connection, and refreshed on demand twice through the gateway (both Completed, about 1.5 minutes each). After refresh 1 the Service model held the first sessions and two events; after refresh 2 it held all five sessions and all three events, matching the appliance API by ID and creation time, including a session that moved from in progress to failed and a later event that was not present at refresh 1. **This establishes** that new failure/session/event records flow from the appliance through the gateway into the Service model on demand. **It does not establish** timing, resource or EUX arrival, scheduled refresh, streaming, or any Toolkit result. The test launched seven sessions in total, not the three that were authorised (the two Service refreshes saw the first five): it was disabled after the third, found enabled again at 03:55 UTC and disabled again, then found enabled a second time at about 04:10 UTC (two more sessions and a fourth timeout event) and disabled again; each time it was read back as off. Who re-enabled it was not established from the API (the owner had the test open in the UI). The Service model was not refreshed after the first five sessions.
- **Closeout status, 2026-11-05 (read-only):** the appliance was still reachable and the temporary test was read back as **disabled** (restart-on-complete and repeat both off). Source count is **seven sessions** in total, with no session after 04:07 UTC on 2026-11-05, no measurements and no EUX results; the original test configuration is saved privately, and the test was enabled before the lab began, so "restored" means disabled. The launcher remains registered. **A scheduled refresh was started on 2026-11-04 at 21:03:07 Pacific** (a temporary one-time schedule set by the owner after the approval tool blocked the assistant from changing schedules). It was still "In progress" at the last observation (about 13 minutes in; two unrelated on-demand refreshes by the owner at 20:35 and 20:36 had Completed). Its **final status, end time and error were not read**: the Service could not be opened signed in from the assistant's session and gateway logs are not readable by it. The owner reports the schedule was turned off; the assistant did not verify that. Scheduled refresh on 1.2.1.0 is therefore **not established**, and it is consistent with, but does not explain, the earlier stalled scheduled attempts. Remaining step for the owner: open the model's Refresh history, note the 21:03:07 run's status, end time and message, and confirm the schedule toggle is Off.
- Always-on server hosting, schedules over several days, token-revocation recovery (no real token was revoked). Email subscription: blocked, the account has no paid Power BI licence ([DELIVERY.md](DELIVERY.md)).
## I. 1.2.1.0 template and connector in Desktop (2026-11-04)

Evidence: [desktop-1210-acceptance.json](evidence/desktop-1210-acceptance.json). Connector 1.2.1.0 (`05CAF70F…FD25`) was installed in the per-user folder and the template candidate `1.2.1.0-candidate` was opened as a Key copy for window A (2025-06-30). The owner entered the working Key credential locally, saved the file as a PBIX and reopened it; Claude drove the parameter dialog and a Refresh click through Windows UI Automation and queried the open model read-only. Real GUI evidence and engine-only queries are separated below.

Real Desktop GUI
- Parameter dialog filled (FQDN from a private file, dates already 2025-06-30, `UseDateRange` True) and Load clicked; a first load with the old saved credential failed with HTTP 401 (clear route and status in the error; no token shown), consistent with a rotated token; after the owner re-entered the key, all 15 data partitions loaded (refresh stamps 22:19 to 22:21 UTC).
- Save as PBIX, close, reopen by the owner: the saved package holds all 222 visuals including the two new ones, the card's run-label title and smaller font, and Desktop regenerated its own `SecurityBindings`.
- Second GUI refresh after reopening (UI Automation click, 14:53 Pacific): all 15 data partitions re-stamped between 22:54:40 and 22:56:24 UTC with no credential prompt and no error dialog.
- Rendered page, run 77 selected (Load Testing, window capture): EUX Score card shows 3.3 at the smaller font, `Select one run` fits without clipping when nothing is selected, the "How to read this page" box and "About these metrics" link render, Started 06/30/25 02:40 PM. After dismissing Desktop's "Auto recovery" bar (keeping the recovered files), a window-only capture shows the card title `Run #77 | started 2025-06-30 14:40` above the 3.3, the other cards, gauges and tables populated for the run, and the help box with its link.
- EUX Overview, no run selected: both gauges titled "Aggregate EUX Buckets (Avg, Min/Max)" and the aggregate caption with its link render; the gauges read `(Blank)`. With Test (A) set to the 14:40 run the left gauge shows avg 4.20, min 3.10, max 5.30 and the left line chart populates; the right side stays `(Blank)` because Test (B) is still All. The blanks were therefore a filter context (the page compares A with B and each side needs a selection), not a defect.

Engine queries against the open model (not GUI evidence)
- Parameters, window A: 7 of 7 runs reconcile with the source expectations, no duplicate overview rows, multi-run guard `Select one run`, before and after the save/reopen and after the second refresh.
- 1.2.1.0 measures: no selection gives `Select one run in the list` and `Select one run`; run 77 gives `Run #77 | started 2025-06-30 14:40`, score 3.3, baseline 7.6, steady 3.1, VSImax `6 (bound, aboveThreshold)`; a Continuous run gives `No overview`.
- Aggregate gauge measures: null with no run selected (by design), avg 4.2, min 3.1, max 5.3 for run 77, and the aggregate mean for run 77 is 4.2 against native 3.3.

Not yet shown
- The no-selection frame with the card title unobstructed (the guard text fit was seen earlier, partly under the recovery bar).
- The 1.2.1.0 connector on the gateway (see GATEWAY.md); evidence from 1.2.0.0 is not carried over.
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
