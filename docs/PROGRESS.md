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
- Verified on the real engine: Power Query converts `…Z` timestamps to the *refreshing machine's local time* when typing `datetime`; `DateTime.LocalNow()` is fixed during an evaluation (a wall-clock paging deadline is therefore not implementable in M; page-count limit is used instead).
- Legacy `LoginEnterprise_PBI.Contents(FQDN, ApiToken, …)` interface unchanged. New additive `LoginEnterprise_PBI.ContentsKey(FQDN, …)` (Key credential). Template stays on legacy function until Desktop acceptance.

## Credential hygiene
The old `LoginEnterprise_PBI.query.pq` in public history contained a credential-like literal. It was **not** printed, copied or tested. Replaced with placeholders. **Owner action: the credential's owner must revoke/rotate it; removing it from the current tree does not invalidate it, and history was not rewritten.**
