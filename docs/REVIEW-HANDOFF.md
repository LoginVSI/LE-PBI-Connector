# Independent review handoff: 1.2.0.0 delta

Scope: the change from `main` at `06854de` to this branch. The prior 1.1.0.2 work already has an [independent audit](INDEPENDENT-AUDIT.md); this asks for a fresh, independent read of the delta only. The author's own review is not independent acceptance.

## What changed

1. `LoginEnterprise_PBI.pq`: `GetLoadTestOverview`, `Overview.Row`, `Overview.Metric`; one new navigation item appended last; version 1.2.0.0; stale comment fixed.
2. `tests/cases/10_native_overview.pq`, `tests/TestSupport.pq` (fake route and exports), `03_measurements_core.pq` (navigation list).
3. Template: `template/source/new-tables.json`, `partitions/Load Test Overview.m`, `measures/Load Test Overview/*.dax`, two measures elsewhere, `pbir-edits.json`; `Build-Template.ps1`, `Test-Template.ps1`, KeyCopy scripts (13 calls).
4. `tools/Test-GatewayReadiness.ps1` (read-only).
5. Docs: NATIVE-EUX, GATEWAY, BACKLOG, README, ACCEPTANCE section G.

## Questions worth an independent answer

- Does `Overview.Row` ever turn a missing value into 0, or hide a failed request? (Only 404 on this route yields no row.)
- Is calling `load-test-run-overview` under the `v7-preview` root acceptable when the retrieved Swagger lists only `/v7/`? Live bodies were identical.
- Can `Load Test Overview` duplicate or contaminate runs through the relationship? Do the measures return BLANK for multi-run selections?
- Are the visual edits limited to the stated card binding and two titles, and is everything else byte-identical (see Test-Template)?
- Is the readiness script truly read-only, and are its claims limited to what it checks?
- Do README/ACCEPTANCE/GATEWAY claim anything Desktop or the Service has not exercised?

## How to reproduce

```
pwsh tools/Test-NoSecrets.ps1
pwsh build/Build-Mez.ps1 -Check
pwsh tests/Run-Tests.ps1
pwsh template/Build-Template.ps1 -Check
pwsh template/Test-Template.ps1
pwsh template/Test-PersistedQueries.ps1
```

Not covered: any Power BI Desktop load of the new template, DAX execution of the new measures, any Service or gateway behaviour. Those are ACCEPTANCE.md sections G and F.
