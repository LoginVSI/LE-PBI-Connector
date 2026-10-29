# Template changes (candidate 1.1.0.2)

`template/Login Enterprise.pbit` (353 337 bytes, 9 pages, 34 tables, 70 measures, 33 relationships) is **unchanged**.
`template/candidate/Login Enterprise 1.1.0.2-candidate.pbit` now builds from the privacy-checked native Desktop export in `template/base/`, pinned by `source/desktop-base.json`. The builder applies editable measures, M partitions and date help, synchronizes persisted query metadata and preserves PBIR/resources. The original PBIT remains a compatibility reference.

The native export has 35 tables, 326 columns and 34 relationships. Its added automatic calendar serves Tests.created. Nine Tests fields use native date/integer/Boolean types matching the connector output instead of the old placeholder string types. All original 319 column identifiers, 70 measure identifiers and relationship semantics are retained and checked. No reviewed measure or visual query uses the nine refined fields. All 83 DAX expressions and 12 M partitions survived Desktop export unchanged.

Actual final legacy and Key Load/Refresh, model/source comparisons, Key persistence and rollback are in DESKTOP-ACCEPTANCE.md. Static checks remain separate from those runtime results. Parameter values are null in the native base and rebuilt candidate; privacy scans and native-export provenance are recorded in evidence/desktop-roundtrip.json.

Template 1.2.0.0-candidate (additive): see [NATIVE-EUX.md](NATIVE-EUX.md). New table `Load Test Overview` from `source/new-tables.json` and `partitions/Load Test Overview.m`; measures under `source/measures/Load Test Overview/`; exact-string visual edits in `source/pbir-edits.json`. Built by `template/Build-Template.ps1` into `template/candidate/Login Enterprise 1.2.0.0-candidate.pbit`. The 1.1.0.2 candidate file is kept as the Desktop-accepted artifact and is no longer rebuilt from source. Not yet opened in Power BI Desktop.

Editable sources: `template/source/measures/<Table>/<Measure>.dax`, `template/source/partitions/<Table>.m`, `template/source/layout-renames.json`, and `template/source/parameter-descriptions.json`.
Round trip: `Export-TemplateSource.ps1` (baseline from a .pbit) → edit → `Build-Template.ps1` → `Test-Template.ps1`.

## Rules the template now follows
- **Eligible runs** (counts/donut/Summary "Total Test Runs"): Application and Load runs in `Filtered Test Runs` (the loaded window, including failed runs with no data) plus Continuous runs that have retained evidence. Selection/filter context is preserved (`KEEPFILTERS` on `type`).
- **Success rate denominator:** finished Application/Load runs (`finished` not blank) in the current selection; in-progress runs are excluded from numerator and denominator; failed/aborted/abandoned runs with no measurements are included. Success = `successful` or `completed` (unchanged vocabulary). 0% is shown as `0.0`; "No Data" only when no finished eligible run exists.
- **Zero vs missing:** valid zeros stay numeric/visible (`Failed User Sessions…`, session metrics); gauges return BLANK when no single run is selected.
- **Numeric first:** new numeric measures (`…Value`, `Eligible …`, `Successful …`) with display measures on top; legacy display measures keep their names.
- **Weighting deferred:** the three additive weighted value measures return BLANK. The API defines `count` only as "Count"; its population has not been established. Legacy averages remain unweighted bucket means. Do not bind cards to the weighted placeholders as accepted statistics.

## Change list
| Measure (table) | Change |
|---|---|
| Overall Success Rate (% & Filtered Test Runs), Overall Success Rate (%) | New denominator, valid 0% |
| Total Tests Run by Type (Filtered Test Runs), Total Tests Run by Type, Total Test Runs, Distinct Test Run ID | Eligible-run rule; Total Test Runs no longer hard-codes 30 days or drops today |
| Show Hybrid Slicer Item (Run Evidence) *(new; replaces the Measurements-only rule on 8 slicers)* | Failed/no-measurement runs stay selectable |
| Show No Data Message (Session Metrics) | Numeric `COUNT(measurement)`, preserving zero and excluding blanks |
| Min/Max/Avg Measurement Gauge Values, Min/Max/Avg EUX Gauge Values | BLANK instead of 0 |
| Failed User Sessions (Matching Test Runs) Display | Valid 0 |
| Distinct Accounts (Measurements) *(new)*; Active Sessions Count *(deprecated, kept)* | Honest label; two cards rebound/relabelled |
| Run Evidence Rows, Eligible Test Runs, Eligible Success Denominator, Successful Test Runs, Overall Success Rate Value *(new)* | Numeric building blocks; success eligibility requires a finish timestamp |
| Average EUX Score Weighted Value / (Weighted); Avg CPU Weighted Value / Display; Avg Memory Weighted Value / Display *(new)* | Deferred placeholders returning BLANK |
| `Filtered Test Runs` M partition | Also keeps runs listed by the connector's `Test Runs In Window` (falls back to data-presence filtering on older connectors) |

## Audit notes (no change made)
- Resource measures filter on `displayName` = `CPU`/`Memory`; renamed/custom session metrics will not match and show "No Data". Weighted measures are disabled pending count semantics; `(MB)` in legacy labels is a label, not a conversion.
- Measurement cards filter on literal `measurementId` values (`total_login_time`, `connection`, `group_policies`, `user_profile`, `latency`, `latency_max`). Customer-renamed or custom measurements are excluded by design; per-run A/B slicers on Apps/Logon/EUX/Session pages keep their per-slicer run selection.
- `duration_seconds = duration / 1000` assumes the API reports milliseconds (field name/model only; no unit in the contract reviewed).
- Application/action timing: `Measurements` rows are per action timer; averages across applications mix action types unless a measurement/app slicer is applied.
- `Test Name` slicer behaviour ("All" shows nothing) is unchanged and documented in the README.
- The independent review also repaired name-slicer helpers to use the active Tests-to-Filtered-Test-Runs relationship, gated the disconnected legacy success measure by loaded-window IDs, excluded historical Continuous runs without in-window evidence, counted nonblank account IDs and distinguished null-only metrics from valid zero. These DAX changes have not been executed.
- Relationships are single-direction from `Filtered Test Runs`; slicers on fact tables (e.g. `measurementId`) do not filter runs, so they cannot hide failed runs.
