# Backlog reconciliation (2026-10-28, after PR #4)

Historical unchecked boxes in older handoffs are not automatically open work; this matrix is the current view, built from the code, [ACCEPTANCE.md](ACCEPTANCE.md), [DESKTOP-ACCEPTANCE.md](DESKTOP-ACCEPTANCE.md), [MERGE-HANDOFF.md](MERGE-HANDOFF.md), [INDEPENDENT-AUDIT.md](INDEPENDENT-AUDIT.md) and the evidence folder. Everything here is an unsupported community preview. "Owner" is this repository unless stated.

Dispositions: **complete**, **implement now** (done in this phase), **assess feasibility**, **documented limitation**, **blocked** (owner or environment), **deferred** (deliberate).

| # | Item | Customer outcome | Evidence / state | Remaining gap | Disposition | Next acceptance step |
|---|---|---|---|---|---|---|
| 1 | Native vs aggregate EUX (engine-verified; Desktop pending) | Report the score Login Enterprise shows | Live read-only check: native 8.2/8.4/8.3 vs bucket mean 8.15; 3.3 vs 4.2 ([evidence](evidence/native-eux-overview-live.json)). `Load Test Overview` table, 11 measures, tests 10 (19 checks) | Desktop has not opened or refreshed the 1.2.0.0 template; measures not executed; UI/PDF comparison limited to the lab run | **Implement now** (code and tests complete; Desktop pending) | Section G of ACCEPTANCE.md, then `NativeOverviewChecks.dax` |
| 2 | Aggregate mean semantics | Honest trend and period statistics | Unweighted mean retained and relabelled; gauges retitled; new `Aggregate EUX Mean (Window Observations)` | Bucket `count` semantics unproven | **Documented limitation**; weighted measures stay BLANK | Vendor definition of `count` or raw-to-bucket reconciliation |
| 3 | Retrieval, windows, state, template correctness | Complete, correctly windowed data | Complete for the exercised scope: paging, UTC half-open windows, snapshot repair, 83 measures reconcile ([acceptance](DESKTOP-ACCEPTANCE.md)) | Tied or mutable ordering; no server snapshot; Swagger gives no `count` maximum | **Complete** (limits documented) | None |
| 4 | Compatibility, install, packages | Safe upgrade and rollback | Additive navigation item; old 1.1.0.2 template runs against 1.2.0.0 by design (Filtered Test Runs probes for optional items); 1.1.0.2 MEZ preserved in `bin/archive/1.1.0.2/` | No older saved PBIX was available; 1.2.0.0 MEZ not yet loaded by Desktop | **Documented limitation** for older PBIX; **blocked on owner** for Desktop load | Install 1.2.0.0 (backed up), open a copy of an existing report, refresh |
| 5 | Credential migration and recovery | No token in reports | Key entry: Desktop Load/Refresh/persistence and legacy rollback passed (1.1.0.2); Key copy preparer updated to 13 calls and checked statically | Legacy token-in-report risk remains for existing reports; historical credential in public history unconfirmed rotated | **Complete** (Key); credential rotation **blocked on owner** | Owner confirms rotation |
| 6 | Stale documentation and article references | Consistent instructions | README, ACCEPTANCE (section G), OPEN-ITEMS, TEMPLATE-CHANGES reconciled in this phase; chronological history preserved | Published article URLs not recorded in this repository and not invented | **Implement now** | Owner supplies final article URLs if wanted |
| 7 | Gateway and Service scheduled refresh | Scheduled Import refresh in the Service | `TestConnection` for both kinds (tested), Key scope, [GATEWAY.md](GATEWAY.md), read-only preflight `tools/Test-GatewayReadiness.ps1` | No gateway, tenant or workspace authorised; no publication, on-demand or scheduled refresh run | Code and setup **complete**; runtime **blocked on owner/environment** | Administrator follows GATEWAY.md; record attempt, last success, newest observation |
| 8 | Refresh freshness and failure visibility | Know whether data is current | Distinction documented; `Newest Source Observation` measure | Last-refresh time lives in Service history, not in the model | **Implement now** (measure, docs); no refresh-time table added | Observe in a real Service refresh |
| 9 | Incremental refresh / ingestion | Faster refresh on large history | Assessed below | See below | **Deferred** | Revisit if refresh duration becomes a customer problem |
| 10 | Remaining Desktop M/DAX negative cases | Confidence at the edges | Real-engine M fixtures cover boundaries and HTTP failures; Desktop DAX covers success, failure, zero, multi-run and empty contexts | Exact-midnight/DST, null-only metrics, large populations, Platform/Load populated cases not in retained data | **Documented limitation** (no new LE data requested) | Run when such data exists |
| 11 | Older-PBIX compatibility | Existing reports keep working | Legacy rollback passed on the acceptance report | No pre-1.1.0.2 PBIX available | **Documented limitation** | Test with a real older customer-style PBIX on a copy |
| 12 | Requirements, manual examples, onboarding | Usable without AI | README steps, direct examples, migration notes in NATIVE-EUX.md | Screenshots of the new cards not yet captured | **Implement now** (text); screenshots owner action | Capture after Desktop acceptance |
| 13 | Independent review | Acceptance beyond self-review | Prior independent audit covers 1.1.0.2. [REVIEW-HANDOFF.md](REVIEW-HANDOFF.md) scopes the 1.2.0.0 delta | Self-review is not independent acceptance | **Blocked on owner** | Reviewer runs the handoff |
| 14 | Blog 4 evidence, customer/partner handoff | Accurate public claims | Private claim notes and customer wording prepared outside Git | Nothing published or sent | **Blocked on owner** | Owner decides |
| 15 | Licensing | Reuse terms | No LICENSE file | Not a technical blocker | **Deferred** (owner decision) | Owner |
| 16 | Application-test aggregated session metrics | Per-app CPU/memory | No matching endpoint in the reviewed contract | n/a | **Documented limitation** | New contract |
| 17 | Grafana / InfluxDB and custom PDF/report generation | Other reporting surfaces | Owned by Results Toolkit | Cross-reference only | **Not here** | Track in LoginEnterprise-ResultsToolkit |

## Update 2026-10-30

- Row 1: the connector now has **actual engine and live-source reconciliation** (15 of 15 runs, two windows, no duplicates, nulls preserved), see [evidence](evidence/native-eux-engine-reconciliation.json). Disposition: implemented, engine-verified, **Desktop-runtime pending** (no controller available; exact cases in ACCEPTANCE.md section G).
- Added `Native VSImax (Display)`: an `aboveThreshold` value is shown as a bound, never an exact capacity.
- API versions: compared the appliance's v7-preview and v8-preview contracts for every route used. No native-EUX gap; v8 renames `counter` and reshapes the snapshot. **No v8 adapter; deliberately deferred**, see [TOOLKIT-CONTRACT.md](TOOLKIT-CONTRACT.md) (also the Toolkit coordination contract).
- Freshness: refresh attempt, last success and newest source observation stay distinct (GATEWAY.md, `Newest Source Observation`). Error paths (401, 404, 500, late-page failure, budget) are covered by real-engine fixtures; stale/recovery behaviour in the Service is runtime-blocked.
- Gateway/Service: connector identity (`TestConnection`, Key scope), preflight and runbook complete; **environment-blocked**: no authorised gateway, tenant, workspace or cadence.
- Credential in history: still absent from the tree (secret scan passes); rotation is an owner security action and is **unconfirmed**.
- Merge: not performed. Material changed Desktop behaviour (new table, card, measures) has no Desktop acceptance yet.

## Relevance of Results Toolkit work

Grafana/InfluxDB export and custom PDF/report generation are owned by LoginEnterprise-ResultsToolkit. They matter here for two reasons: the native overview values are the natural source for a Toolkit PDF so it matches the Login Enterprise UI, and Toolkit's read-only, vault-credential approach is the pattern used for the live evidence in this phase. This repository does not duplicate that work.

## Incremental refresh feasibility

Power BI incremental refresh partitions an Import table by `RangeStart`/`RangeEnd` datetime parameters. This connector's window is date parameters, and every navigation table comes from one function call, so each partition refresh would re-run the whole connector (tests, environments, run catalog, snapshots) for its slice. That multiplies appliance load and requests, query folding is not available, the run-level tables (Test Runs, Tests, Sessions with interval semantics) do not partition cleanly by one timestamp, and a late-changing run (still running, or re-scored) would be missed in an archived partition. The native overview is whole-run, so it does not partition by date at all. Verdict: not justified now. If refresh time becomes a problem, narrow the window or move history to a store (the Toolkit direction) rather than adding partitioning logic to this connector.

## Journey from older handoffs

Historical boxes about "gateway not started", "Desktop pending", "Key not accepted" and "template not validated" are superseded by the records above: Key and legacy Desktop acceptance are complete for the exercised scope; the 1.2.0.0 additions and all gateway runtime steps are the open items.
