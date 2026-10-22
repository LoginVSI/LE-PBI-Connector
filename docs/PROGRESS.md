# Repair progress / handoff (branch `fix/connector-repair-1.1.0.2`)

Resume point for an interrupted session. Updated as phases complete. Owner: Josh. Status values: DONE / PARTIAL / DEFERRED / TODO.

## Baseline evidence (inspected 2026-10-20)
- `origin/main` = `089200f0eb2a3a21de872beba4c4c76a3d68b1dc` (unchanged since review; no newer remote fixes). `origin/dev` exists (not used).
- Public `LoginEnterprise_PBI.pq` = 1.1.0; shipped MEZ `bin/AnyCPU/Debug/LE-PBI-Connector.mez` = 1.1.0.1. Diff of the unpacked MEZ vs source: version banner + two `Date.AddDays(EndDate, 1)` lines (Aggregated EUX, User Session Metrics). All icons/resx identical. Hotfix preserved (generalised, see below).
- Installed copy in the user connector folder (read-only look) is the public 1.1.0 build; it was not touched.
- No local 1.1.0.2 candidate archive was found (searched Downloads/Desktop/Documents/C:\Repos). Nothing reused.
- Template `template/Login Enterprise.pbit`: 353 337 bytes, 34 tables, 70 measures, 33 relationships, compat level 1567, no `DataMashup` part (queries live in model partitions), 6 parameters (FQDN, APIToken, DaysBack, UseDateRange, StartDateParam, EndDateParam).
- Tooling here: no Python, no Power Query SDK installed; **PQTest.exe obtained from NuGet `Microsoft.PowerQuery.SdkTools` 2.155.2 into a scratch/cache folder (not installed globally)**. Power BI Desktop is installed but NOT touched (async boundary).

## Phase status
| Phase | State | Evidence |
|---|---|---|
| 1 Evidence/compat | DONE | baseline above; `docs/CHANGE-TEST-MATRIX.md` |
| 2 Acquisition + time windows | DONE on fixtures (real M engine); **live API not exercised** | tests 01-03; API limits unverified (matrix "Unverified") |
| 3 Template semantics | DONE as *candidate*; **DAX not executed, Desktop not opened** | `docs/TEMPLATE-CHANGES.md`, `template/Test-Template.ps1` |
| 4 Credentials/TestConnection/setup | PARTIAL | Key entry point + TestConnection done and run in PQTest; Desktop/Service/gateway **not run**; README rewritten |
| 5 Build/tests/CI/review | DONE except independent review | reproducible MEZ, 6 test files (89 checks), CI workflow; **independent review deferred to a separate Codex session** (`docs/AUDIT-HANDOFF.md`) per session instructions |
| 6 Acceptance/upgrade/blog prep | DONE (prep only) | `docs/ACCEPTANCE.md`, `docs/CHANGELOG.md`, `docs/blog/OUTLINE.md`, `docs/SHA256SUMS.txt` |

READY-FOR-DESKTOP: staged MEZ `bin/AnyCPU/Debug/LE-PBI-Connector.mez` + candidate PBIT `template/candidate/…`. Nothing was installed in shared Power BI folders, no Desktop process was started/controlled, no shared settings/credentials changed, Toolkit checkout untouched. (A separate Analysis Services instance was considered for DAX execution and **not** started: the harness denied launching the Desktop-bundled engine as interfering with the shared host, which was respected.)
## Key decisions
- Canonical package: `bin/AnyCPU/Debug/LE-PBI-Connector.mez`, version **1.1.0.2**, built by `build/Build-Mez.ps1` (byte-reproducible; stored ZIP, fixed timestamps, LF sources via `.gitattributes`). CI checks source == package.
- Date policy: UTC calendar days, half-open `[start 00:00Z, end+1 00:00Z)`. Rolling `DaysBack=N` = today(UTC) + N previous days. Fixed range needs both dates. Invalid input errors; nothing silently widened.
- Verified on the real engine: Power Query converts `…Z` timestamps to the *refreshing machine's local time* when typing `datetime`; the original fixed-clock conclusion was disproved by the independent forced-clock probe. The current implementation has a cooperative elapsed request budget and separate timeout/retry/page limits, not a hard overall refresh deadline.
- Legacy `LoginEnterprise_PBI.Contents(FQDN, ApiToken, …)` interface unchanged. New additive `LoginEnterprise_PBI.ContentsKey(FQDN, …)` (Key credential). Template stays on legacy function until Desktop acceptance.

## Credential hygiene
The old `LoginEnterprise_PBI.query.pq` in public history contained a credential-like literal. It was **not** printed, copied or tested. Replaced with placeholders. **Owner action: the credential's owner must revoke/rotate it; removing it from the current tree does not invalidate it, and history was not rewritten.**

## Delivery state
- Branch `fix/connector-repair-1.1.0.2`, draft PR #4 (not merged, nothing released/published). CI (`ci` workflow, windows-latest): green on commit `72ccf1b` (secret scan, MEZ source parity, 89 M test checks on PQTest, template static checks). First CI run failed on parity because a CRLF `resources.resx` had been packaged locally; fixed by LF-normalising and rebuilding.
- Remaining owner actions: revoke/rotate the old credential-like literal; run `docs/ACCEPTANCE.md` when Power BI Desktop is released; separate Codex audit (`docs/AUDIT-HANDOFF.md`); licence/ownership decision; confirm API limits on a lab appliance.

## Independent audit completion

The separate Codex audit reproduced material defects against f503293 and continued the existing repair branch. See [INDEPENDENT-AUDIT.md](INDEPENDENT-AUDIT.md), [evidence](evidence/) and SHA256SUMS.txt for the current evidence, rather than the historical phase claims above. Bounded live GET checks reused the approved native vault/profile without modifying Toolkit or shared Desktop state. Weighted measures are deferred until count populations are established. Desktop/DAX/Service/gateway acceptance remains outstanding. Final delivery and CI are recorded in the draft PR description and the audit session response.

## Desktop acceptance started, 2026-10-21

The owner released the shared slot. Candidate hashes were verified, installed 1.1.0 was backed up and candidate 1.1.0.2 installed; Toolkit connector is unchanged. Working candidate and legacy templates are staged. Native computer-use pipe remains unavailable after recovery, and no model catalog existed before first Load. No Desktop/DAX acceptance is claimed. Read-only source expectations and the exact next dependency are in [DESKTOP-ACCEPTANCE.md](DESKTOP-ACCEPTANCE.md).

## First Desktop Load failed; shared acquisition repaired

Owner reports thirteen queries blocked by HTTP 500 on tests/test-runs after three attempts. No successful load or acceptance. The trigger was reproduced and isolated to snapshot expansion of older records; all 20 selected-window snapshots succeeded on the independently tested single-run route. Real Web.Contents cache bypass and production retry orchestration passed a loopback test. See [DESKTOP-LOAD-FAILURE.md](DESKTOP-LOAD-FAILURE.md). Current report/parameters remain untouched; save and close is required before installing the rebuilt candidate.

## Repaired connector installed for retry (2026-10-21)
Owner saved and closed the failed report. Installed the verified 8B7EAC70A460 candidate, preserved both prior connector revisions and the saved PBIX, and verified ResultsToolkit.mez unchanged. Reopened LE-acceptance-in-progress. Read-only ModelChecks executed before retry with result-set row counts 0, 0, 0, 1; this is an empty pre-retry model, not retrieval acceptance. Desktop native UI control remains unavailable. Refresh retry awaits the owner action. Evidence: evidence/desktop-retry-preparation.json and evidence/desktop-installation-8B7EAC70A460.json.

## Successful retry reported; model readback pending (2026-10-22)

Owner reports successful refresh with visible data and saved-edit persistence after close/reopen. Preserve those observations separately from the failed first Load. The prepared PBIX still has its pre-refresh timestamp and reopens with zero rows in all five checked tables; the owner confirms this same path. ModelChecks and all 83 measures execute read-only on this empty model, with seven blank/no-data assertions passing. No populated source reconciliation is claimed. Refresh/save/leave-open is the next essential owner action because native UI control remains unavailable after recovery. Each of nine pages, Key migration, legacy-report compatibility, relevant filters and ISO date-control validation remain open. MEZ/source parity, template/source parity, static template checks and secret scan passed. See evidence/desktop-acceptance-results.json. No report, parameter, Toolkit project, trust or credential was changed by the agent.

## Populated acceptance and date help (2026-10-22)

After the owner refreshed, saved and left Desktop open, ModelChecks returned 50/3/71/1 rows on the populated model. Physical window IDs match all 49 source IDs; Application denominator 20, successful 19, rate 95%. Total eligible 24 includes four Continuous runs with retained evidence. Successful/failed/two-run/empty contexts, actual Tests relationship and legacy selection behave as recorded. Real zero session metric is retained; empty subset shows No Data. Seven read-only appliance GETs reconcile 5,601 measurement rows across six pages and the zero aggregate. All 83 measures evaluate. Nine owner screenshots were inspected individually without visual errors; detail pages were at All selection. Owner confirmed ISO Date-field entry in en-US; canonical help and setup examples updated and candidate rebuilt, preserving working files. Separate credential-free Key PBIT is prepared; Key UI and selected-run screenshots remain pending. See DESKTOP-ACCEPTANCE.md and evidence/desktop-acceptance-results.json.

## Selected Logon UI passed

Inspected both owner screenshots. Successful Test (A) displays Distinct Accounts 1 and Failed User Sessions 0 with populated logon values. Failed/no-measurement run remains selectable and displays No Data/blank gauges. Test (B) remains All/No Data. Neither screenshot has visual errors. This is a specific Logon A interaction pass, not every page's A/B interaction. Owner handoff now requests save/close legacy copy, open prepared Key template, enter existing credentials locally, refresh twice and save a separate Key PBIX.

## Persisted-query metadata repair during Key acceptance

Initial Key import failed because APIToken was removed from DataModelSchema but retained in UnappliedChanges. That inspection also found stale canonical Filtered Test Runs M and date help. The first metadata repair incorrectly wrote raw M into lastLoadedAsTableFormulaText; Desktop expects nested JSON. Both failed files and sanitized errors are preserved. The builder now synchronizes text, nested RootFormulaText, descriptions and lineage owners; Key preparation explicitly removes the token query and query-order entry. Seven static metadata regressions pass, and the installed Desktop JSON parser rejects all 12 broken fields but parses all 12 corrected fields. Source/template parity passes; final Desktop retry2 is pending. Actual populated DAX/source and selected Logon passes remain evidence for the earlier legacy copy, not acceptance of the new metadata repair. See evidence/template-persisted-metadata.json and evidence/desktop-key-preparation.json.
