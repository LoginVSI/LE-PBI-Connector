# Focused audit handoff (for a separate Codex review)

The implementing session's self-review is **not** an independent audit and no nested Claude audit was run. Please review with public/synthetic inputs only; no appliance, token, Desktop or tenant is needed.

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
_(none recorded yet)_
