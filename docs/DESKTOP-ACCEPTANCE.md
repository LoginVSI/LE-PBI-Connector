# Desktop acceptance: first Load failed, 21 October 2026

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
