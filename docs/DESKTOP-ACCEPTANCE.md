# Desktop acceptance: populated model reconciled, final UI gates open

Updated 22 October 2026. Draft PR #4 remains draft. The connector retains the Desktop slot; no Toolkit project was opened or changed.

## Completed checks

| Check | Result and evidence |
|---|---|
| Repaired refresh | Owner observed successful refresh and visible data, then completed a further Refresh and Save with Desktop left open. Durations were not recorded. |
| Edit/save/reopen | Owner observed a saved edit persisting without errors. The edit type was not specified, so an explicit moved-visual check is not inferred. |
| Actual model | ModelChecks executed on the populated local Desktop model: 50, 3, 71 and 1 result rows. The 49 physical window IDs exactly match the independent source list; DAX also exposes a synthetic BLANK member with eligible count zero. |
| Counts and denominators | 20 Application and 29 overlapping Continuous metadata runs. Eligible total is 24: 20 Application plus 4 Continuous runs with evidence. Finished success denominator 20, successful 19, rate 95%. The other 25 Continuous metadata rows do not add to the evidence-based eligible count. |
| Failed run without measurements | Eligible=1, denominator=1, successful=0, rate=0%; no measurements, blank gauge. Actual Tests relationship retains this run and its name; hybrid visibility=1. |
| One/multiple/no-run contexts | Successful representative: 8 measurements, mean 0.80775 seconds, 1 distinct account. Success plus failure: denominator 2, success 1, rate 50%, blank gauge. Empty selection: denominator 0 and blank rate/gauges. Unselected and multiple-run gauges are blank. |
| Real zero versus missing | Existing session-metric row has numeric count 1, sum 0 and an empty No Data message. Source confirms the zero and its count. Empty numeric subset shows No Data. No actual null-only metric rows exist in this scope. |
| Account and duration reconciliation | Representative measurement durations and account-ID sets match the source. The successful run's Distinct Accounts measure is 1. Missing facts return No Data. |
| Large-run paging | Seven bounded read-only appliance requests: six measurement pages return 5,601 rows, stable totalCount, exact match of observation-key/duration/account multisets; one aggregate-array request confirms the real zero. |
| UTC end day and local display | All 11,549 loaded measurement timestamps are inside the selected UTC window; 2,331 are on the final UTC day. Local display uses -07:00. No exact-midnight observation or DST transition exists in this scope. Timestamp storage differs from the source by up to 1.195 ms on the eight-row sample; exact timestamp equality is not claimed. |
| DAX execution | All 83 measures evaluated without errors on the populated model. Weighted alternatives stay BLANK in all exercised contexts because count populations remain unverified. |
| Nine pages | Agent inspected nine owner-provided screenshots individually. No visual errors or Fix this. Summary matches DAX: 24 eligible, 223 sessions, 95.0% success. Other detail pages were at All selection; selection gates explain their blank charts. Load has zero source runs and Platform has zero rows, so populated acceptance of those pages is unavailable. |
| Date fields and help | Owner re-entered exact ISO strings 2026-09-18 and 2026-09-24, confirmed acceptance and applied unchanged effective dates under en-US. Updated both canonical descriptions and README examples, preserving parameter identifiers and Date parsing. Rebuilt candidate; working PBIX and PBIT were not overwritten. Other cultures have M parsing coverage only. |
| Preservation | Original and prior repair connectors backed up; installed MEZ matches verified candidate. ResultsToolkit hash unchanged. No agent writes to the report/parameters, appliance mutation, trust or credential change. |

Public evidence: [per-check results](evidence/desktop-acceptance-results.json), [measurement comparison](evidence/desktop-measurement-reconciliation.json), [bounded live reconciliation](evidence/desktop-live-reconciliation.json), [date control](evidence/date-parameter-validation.json), [artifacts](evidence/artifacts.json). Raw source/model rows, identifiers, account names and screenshots stay outside Git. Initial empty-model readback is retained as history; after the owner refreshed and saved, populated checks succeeded.

## Remaining acceptance

- Selected successful and failed Logon screenshots now pass: successful Distinct Accounts=1, Failed User Sessions=0 and populated logon values; the failed run remains selectable, with No Data and blank gauges. Test (B) remains All/No Data. Remaining page-specific cross-filter and A/B combinations were not inferred from this check.
- The initial Key copy failed on an orphan APIToken lineage in UnappliedChanges. The first repair then failed because nested loaded-query JSON was written as raw M. Both failed files are preserved. The corrected `.cache/desktop-acceptance-20261021/LE-acceptance-key-retry2.pbit` has 17 consistent queries, 12 migrated calls, no token parameter and valid nested JSON. The installed Desktop parser rejects all 12 first-retry fields and accepts all 12 corrected fields. Seven metadata regressions pass. Actual retry, Key scope, two refreshes and legacy rollback are pending.
- No existing 1.1.0 PBIX was available. The original legacy PBIT is staged; legacy signature and the current legacy-function report refresh are verified, but compatibility with an older saved model is not established.
- Connector discovery entries, intentional wrong-credential UI, explicit visual move, Desktop export of the final PBIT and the revised tooltip display remain unobserved.
- Summary donut retains a zero-valued BLANK legend category from the model's unknown member. It does not change the reconciled counts.

The Key failure also exposed stale Filtered Test Runs M and old date help in the canonical UnappliedChanges entry. The builder now synchronizes it with DataModelSchema, including nested RootFormulaText. The rebuilt candidate needs a fresh Desktop retry; earlier populated DAX evidence describes the previously refreshed legacy copy. See [metadata diagnosis](evidence/template-persisted-metadata.json).

Disposition: **partial acceptance; not merge-ready**. Preserve the current report and leave Desktop in the connector slot until the UI handoff is complete. Gateway, Service scheduling and incremental ingestion remain deferred.

## Historical preparation and first failure

The records below preserve the earlier state; they are superseded by the current results above.

Candidate branch started clean at 6393ce2. Draft PR #4 remains open and draft. The owner released the Desktop slot for this connector. No prior audit was repeated.

## Preparation completed

- Verified all three artifact hashes against `docs/evidence/artifacts.json`.
- Confirmed no Desktop process before installation, so no open or unsaved report was closed.
- Recorded Desktop 2.159.883.0 and UTC offset -07:00.
- Actual connector folder: `C:\Users\j.kennedy\Documents\Power BI Desktop\Custom Connectors`.
- Backed up installed public connector 1.1.0, SHA256 `E5931450DDD625ED1BCEC37556B5BC372BC73BC499B52221752B6102105C2338`, to `.cache/desktop-acceptance-20261021/backup/LE-PBI-Connector.original.mez`. The backup was verified before installation.
- Installed only candidate LE-PBI-Connector.mez, version 1.1.0.2, SHA256 `2E40132F078EF8E7D1BD76175D380DEF3AFA0CD1869ACF632858162247F752D7`.
- ResultsToolkit.mez hash stayed `91DC405A3D94AA072A5BE1C24B81BFEEEC14012EB50FA4CD92D723CCA6AA93E7`. No trust or shared credential settings changed.
- No PBIX was found under Documents, Downloads or Desktop. A copy of the original legacy PBIT is staged for compatibility acceptance. Original template and candidate remain unchanged.
- Candidate working file: `.cache/desktop-acceptance-20261021/LE-acceptance-candidate.pbit`. It was launched in Desktop. Work is confined to copies.

Installation evidence: [desktop-installation.json](evidence/desktop-installation.json).

## Source expectations prepared, not yet reconciled in Desktop

A bounded native-vault read-only check selected existing retained results for fixed dates **2026-09-18 through 2026-09-24**, UTC. This gives 20 finished Application runs, 19 successful, so the Application/Load success denominator is 20 and success rate 0.95. The source includes a finished internal-error Application run with zero measurements. A successful representative has 8 measurements, mean duration 0.80775 seconds and 1 distinct nonblank account ID. Continuous eligibility requires fact evidence and has not yet been reconciled. No appliance test or configuration changed and no new results were requested.

The recent rolling seven-day window had no Application/Load runs, so it is retained as a separate empty-finite-run case rather than used as the main acceptance scope. All raw IDs and rows remain ignored local evidence. Public projections: [retained-window reference](evidence/desktop-source-reference.json), [recent-window reference](evidence/desktop-empty-window-source-reference.json).

## Current dependency and failed first Load

The Windows computer-use native pipe is unavailable after the prescribed recovery. Desktop started with the candidate but its model exposed no catalog before first load; **no DAX query was executed**. The staged read-only ADOMD helper refuses non-template models and preserves private query rows outside Git. See [runtime state](evidence/desktop-runtime-state.json).

The owner attempted the first Load. Thirteen queries were blocked by HTTP 500 on the shared test-run catalog after three attempts. **Not loaded or accepted.** The failed evidence, reproduced trigger, verified selected-window workaround and retry-cache experiment are in [DESKTOP-LOAD-FAILURE.md](DESKTOP-LOAD-FAILURE.md). First successful refresh, second refresh, nine pages, slicers, zero/missing cases, DAX, Key migration and save/reopen remain pending. The next step is to preserve the current report and parameters by saving a private PBIX copy and closing Desktop before installing the repaired connector.

## Rollback

Save working reports before closing Desktop. With Desktop closed, copy the verified original backup above over **only** `LE-PBI-Connector.mez` in the actual connector folder. Confirm the installed hash equals the original hash above, then restart Desktop. Leave ResultsToolkit.mez, trust, credentials and original report files unchanged. Do not remove the backup until acceptance and rollback checks are complete.
