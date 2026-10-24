# Repair candidate handoff

## Recommendation

Qualified acceptance for the exercised Desktop scope. The material acquisition, source/package, date, DAX and template defects are repaired. Recommend merge after owner review of the recorded limits below and final-head CI. PR #4 stays draft for that review; no merge, release or publication was performed.

## Verified

- Legacy and additive Key Load/Refresh work against the existing v7-preview appliance. Key uses native Feed Key credentials; no token parameter or inline token is in the migrated queries. All 12 loaded partition definitions match canonical M after the call migration.
- Fixed-window Key and legacy results match exactly across all recorded model result sets and 11,549 observation rows. Denominator=20, successful=19, rate=95%; failed/no-fact, single/two/empty, name relationships, zero/missing and distinct-account cases are reconciled. All 83 measures execute. Weighted alternatives stay BLANK.
- Nine pages render in individually inspected screenshots. Selected Logon success/failure views show Distinct Accounts=1 and valid failed-session zero, while the failed run remains selectable with No Data/blank gauges.
- Moved Key visual persists through save/close/reopen; refresh needs no new credential entry. The preserved legacy report still refreshes after migration.
- Final legacy candidate Load/Refresh and native PBIT export completed. All 83 DAX expressions and 12 M partitions survive unchanged. Known connection/result-value privacy scans pass; all six exported parameter values are null.
- Pinned Desktop PBIR base and editable M/DAX/help reproduce the candidate byte-for-byte. Original template, reports, failed evidence and connector backups remain preserved; ResultsToolkit.mez and its project were not modified.

The native export adds an automatic date table/relationship for Tests.created and refines nine Tests fields to connector-defined native types. All original column/measure identifiers and relationship semantics remain checked. No shipped measure or visual query uses the refined fields. See template/source/desktop-base.json.

## Limits to retain

- Direct Desktop credential-path observation is unavailable: the custom label hides it and PBIDS export is unsupported. FQDN-only scope has separate required-parameter/SDK-runtime evidence; it is not claimed observed in the Desktop path display.
- Not every cross-page interaction permutation or isolated wrong-credential Desktop dialog was exercised. DAX/context and selected UI evidence are separate. No older 1.1.0 PBIX was available.
- Exact-midnight/DST, null-only metrics, large application/environment populations and populated Load/Platform cases were unavailable in the selected retained data. Real M fixtures cover relevant boundary/error cases; unavailable Desktop cases are not marked passed.
- Aggregate count populations remain unproven, so weighted alternatives stay disabled. Paging is not a server snapshot; tied/mutable ordering can still shift data. Request timeout/retry/page limits and the cooperative budget are not a hard overall refresh deadline.
- A selected window containing a broken historical snapshot can still fail; the verified workaround avoids unrelated broken history and never substitutes empty results for errors.
- Historical credential revocation remains an owner action. Licence notices are preserved; ownership discussion did not stall technical acceptance.

Gateway, Service scheduling and incremental ingestion remain deferred.

## Artifacts

Connector version 1.1.0.2; template version 1.1.0.2-candidate, based on the native Desktop PBIR export.

- `bin/AnyCPU/Debug/LE-PBI-Connector.mez`: `8B7EAC70A460A0EF03DEAAE650AF9DCF747849538B70EAA1CEA22E5F5F43D768`
- `template/candidate/Login Enterprise 1.1.0.2-candidate.pbit`: `0E22BF675BE20D7084B34908B12C0C2CF966FEA68C20DE549402B4D394B74ADD`
- `template/Login Enterprise.pbit`: `4529178FFBE8AB5021FE4188F1683945012C362C82E4658CD8F1B554FD5B0D12`
- `template/base/Login Enterprise Desktop 2026-10.pbit`: `E0E4FEA065DD32E66B0355F35838D40E2B8D41FEFB428B6C0B9A86639A0FB1B4`

## Evidence and review

See DESKTOP-ACCEPTANCE.md, ACCEPTANCE.md, evidence/desktop-roundtrip.json, evidence/desktop-key-acceptance.json and the independent audit. Raw rows, credentials, private appliance details and working reports remain outside Git. Current Desktop report remains open for Josh; the connector retains the slot until he releases it.

Final commit/CI links are kept in draft PR #4's description so the record does not create a self-referential commit loop.
