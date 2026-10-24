# Focused audit handoff (for a separate Codex review)

The implementing session's self-review is **not** an independent audit and no nested Claude audit was run. The original brief used synthetic inputs. The owner subsequently authorized bounded read-only reuse of the existing approved appliance profile for this independent audit; see the findings below.

Scope (branch `fix/connector-repair-1.1.0.2` vs `origin/main` `089200f`):
1. `LoginEnterprise_PBI.pq` – full rewrite of acquisition: `Api.*` (request, retry, interpretation, `GetAllItems`), `Window.Create`, `Runs.InWindow`, per-table `Get*` functions, entry points, `TestConnection`.
2. `build/Build-Mez.ps1`, `LoginEnterprise_PBI.proj`, `.gitattributes` – reproducibility claim (stored zip, fixed timestamps, LF).
3. `template/Build-Template.ps1`, `template/source/**`, `template/Test-Template.ps1` – DAX semantics and the claim that only measures/one partition/layout names changed.
4. `tests/**` – do the tests really assert what the matrix claims (docs/CHANGE-TEST-MATRIX.md)? Mutation-test a few.

Questions that deserve a second pair of eyes
- Date policy: is "UTC calendar day, half-open" the right default for customers who reconcile in local time? Any place a local-time comparison remains (`Test Runs` datetime columns are local after typing)?
- `Api.GetAllItems`: any input where it terminates early or loops (page size capped below request without `totalCount`; `totalCount` present but wrong; first page empty but total > 0).
- Treating 404 on per-run sub-resources as "unavailable (empty)" – is silent emptiness acceptable there, or should it be surfaced?
- Disabled-environment skip (`enableEnvironmentDataCollection = false`) for platform metrics.
- `Run.Overlaps` for runs with `finished = null` that are dead (aborted without a finish time): extra requests only, or a correctness issue?
- DAX: `KEEPFILTERS` usage in `Eligible Test Runs`, `Eligible Success Denominator`, `Successful Test Runs`; BLANK vs 0 handling; `Show Hybrid Slicer Item (Run Evidence)` when a slicer item maps to several runs (Continuous labels); weighted measures when `count` is blank. **None of the DAX has been executed.**
- Layout string renames: any place a renamed string could appear in an unintended context (counts are asserted: 16/4/10).
- Key credential: `Extension.CurrentCredential()[Key]` usage, `TestConnection` for a single-parameter path (the SDK passes the path as JSON `{"FQDN":…}`; the Key `TestConnection` accepts both), legacy `TestConnection` JSON keys.

How to run: `pwsh tests/Run-Tests.ps1` (Windows; downloads hash-pinned PQTest from NuGet), `pwsh build/Build-Mez.ps1 -Check`, `pwsh template/Build-Template.ps1 -Output <tmp>` then `pwsh template/Test-Template.ps1 -Candidate <tmp>`, `pwsh tools/Test-NoSecrets.ps1`.

Dispositions of findings should be recorded in this file under a "Findings" heading.

## Findings
Independent Codex review completed. Material defects were reproduced against `f503293` and repaired on the same branch. See [INDEPENDENT-AUDIT.md](INDEPENDENT-AUDIT.md) for severity, evidence, live-contract coverage and remaining acceptance limits. No Desktop, DAX, gateway or Service acceptance is claimed.

## Desktop finding after the independent audit

The first real Load failed. See [DESKTOP-LOAD-FAILURE.md](DESKTOP-LOAD-FAILURE.md) for the independently reproduced old-snapshot expansion failure and verified window-scoped workaround. Earlier synthetic passes did not establish this acquisition behavior against old stored snapshots. Current report/parameters and failed evidence are preserved; acceptance is pending a real retry.

## Successful retry reported, 22 October 2026

The owner reports that the repaired report refreshed and displayed data, and that a saved edit survived closing and reopening. The locally reopened prepared PBIX still has an empty model and its pre-refresh timestamp. The owner confirmed that file path; a refresh/save/leave-open handoff is pending. ModelChecks and all 83 measures execute on that empty model, with seven empty-context assertions passing. This does not establish populated DAX, page rendering or compatibility. See [the per-check acceptance record](evidence/desktop-acceptance-results.json). Keep PR #4 draft until the remaining acceptance checks pass.

## Populated readback established

The owner completed Refresh and Save with Desktop left open, resolving the empty saved-copy dependency. Actual populated DAX and bounded source reconciliation now pass the cases in DESKTOP-ACCEPTANCE.md. All nine screenshots were inspected separately without visual errors at All selection. ISO Date-field entry is owner-verified under en-US, descriptions/examples updated, and candidate rebuilt. Key and remaining selected-run/compatibility/export checks are still open; keep the PR draft. Initial failures remain preserved.

## Persisted-query metadata repair during Key acceptance

Initial Key import failed because APIToken was removed from DataModelSchema but retained in UnappliedChanges. That inspection also found stale canonical Filtered Test Runs M and date help. The first metadata repair incorrectly wrote raw M into lastLoadedAsTableFormulaText; Desktop expects nested JSON. Both failed files and sanitized errors are preserved. The builder now synchronizes text, nested RootFormulaText, descriptions and lineage owners; Key preparation explicitly removes the token query and query-order entry. Seven static metadata regressions pass, and the installed Desktop JSON parser rejects all 12 broken fields but parses all 12 corrected fields. Source/template parity passes; final Desktop retry2 is pending. Actual populated DAX/source and selected Logon passes remain evidence for the earlier legacy copy, not acceptance of the new metadata repair. See evidence/template-persisted-metadata.json and evidence/desktop-key-preparation.json.

## Key retry2 actual acceptance, 23 October 2026

Key import, Load and Refresh succeeded. Actual model: no token parameter, 12 Key calls, zero legacy calls, and all 12 partition definitions match canonical M after migration. The first read used rolling 30 days because the preparation tool had contradictory DefaultValue metadata. Preserve that report, fix the preparer to synchronize DaysBack/UseDateRange values and defaults, and add a static Key-copy check that rejects both old defaults and accepts the corrected copy. The separate fixed-window report matches every legacy result multiset, including all 11,549 observations, all 83 measures and context/relationship/zero checks. Feed Key authentication is visible with a masked token. Direct Desktop path is hidden by the label and PBIDS export is unsupported; retain SDK scope evidence separately. Persistence and legacy rollback remain pending owner UI actions. See evidence/desktop-key-acceptance.json. No source MEZ, report parameters, Toolkit project, installed connector, trust or credential was changed by the agent.

## Final native Desktop round trip

Final legacy Load/Refresh and ModelChecks match baseline; 12 loaded M partitions and both date descriptions match canonical sources. A genuine Desktop PBIT export resets all six parameter values to null and passes known connection/result-value privacy scans. Re-exported editable sources retain all 83 DAX expressions and 12 M partitions; empty header whitespace is normalized. Pin the native PBIR base and deterministically rebuild the candidate, preserving nine pages/220 visuals and all original identifiers/relationships. Desktop adds one automatic date table/relationship and refines nine Tests field types to the connector's types; no shipped measure or visual query uses those fields. See evidence/desktop-roundtrip.json and template/source/desktop-base.json. Original reports, failed evidence, original template and installed connectors remain preserved.
