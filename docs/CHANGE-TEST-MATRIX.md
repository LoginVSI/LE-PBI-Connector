# Change / test matrix, candidate 1.1.0.2

**M-engine** means real PQTest/M execution with synthetic fetch fixtures. **SDK-runtime** means the staged production package through PQTest and an isolated synthetic credential cache. **Live** means bounded read-only v7-preview requests using the approved native vault/profile, outside M. **Static** means ZIP/JSON/source inspection only. DAX, Desktop, gateway and Service acceptance are **not run**.

| Area | Production behavior / checks | Evidence |
|---|---|---|
| UTC windows and selected end day | UTC acquisition, full selected end day, half-open point filters, offset normalization, UTC DST windows, rolling/fixed validation, local datetime typing, terminal startup failures | M-engine `01_window.pq`; selected inclusive measurement bounds confirmed live |
| Pagination | All paged endpoints use count/offset once, whole-result totals, nullable totals, echoed offsets, capped no-total pages, empty terminator, full-page non-progress comparison, pre-fetch cap, late-page errors | M-engine `02_paging_errors.pq`, `06_independent_regressions.pq`; live configuration/measurement/session shape and offset-total probes |
| Measurements | More than 1000/day; strict/inclusive bounds handled with superset fetch and point filters; no speculative observation-key deduplication | M-engine `03_measurements_core.pq`, `06`; bounded live existing results |
| Errors and malformed data | Auth, permission, transport, JSON/shape errors, invalid timestamps/nested values fail; no raw exception/body content; all queried production 404s fail; 204/empty success remain empty | M-engine `02`, `03`, `06` |
| Runs and sessions | Case-insensitive types; ongoing Continuous overlap; failed runs with no facts; session active-interval semantics and distinct IDs; disabled environments/inapplicable aggregated routes skipped | M-engine `01`, `03`, `06`; live Swagger confirms session filter modes |
| Limits | 300s shared cooperative request budget; 30s request timeout; 3 attempts with 1/2s delays; 1000 pages per read; no hard overall refresh deadline | M-engine real delayed clock/response/retry checks `07_elapsed_budget.pq`; source inspection |
| Credentials / TestConnection | Legacy signature unchanged, additive Key has FQDN-only scope; ManualCredentials with explicit bearer header; eager probe | M-engine `04`, `03`; isolated SDK-runtime discover/set/test-connection |
| Source/package | Canonical MEZ matches source; test exports excluded; original PBIT unchanged; staged PBIT matches editable sources | Build `-Check`, template `-Check`, ZIP byte comparison |
| Fixture runner / CI | Real deliberate false M assertion must exit 1; missing case selection fails; process exit and every result checked; staged template parity included | `tests/Run-Tests.ps1 -ProbeFailure`, CI |
| Filtered Test Runs partition | Actual shipped M evaluated; failed/no-fact IDs kept, historical Continuous IDs excluded; older connector data-presence fallback | M-engine `05_template_partition.pq` |
| Success rates / name slicers | Active Tests-to-Filtered-Test-Runs context; finished timestamp required in numerator/denominator; failed/no-measurement runs included; legacy disconnected selection intersected with loaded IDs | Model/measure review only; DAX not run |
| Zeros / blanks / accounts / gauges | Numeric COUNT distinguishes missing vs zero; nonblank distinct account IDs; one-run gauge gate and BLANK for none/multiple | Static only; Desktop scenario acceptance pending |
| Weighting | Additive weighted value identifiers return BLANK pending authoritative count population; legacy bucket means retained | Static; no weighting acceptance |
| Template structure | 34 tables, 319 columns, 33 relationships; 70 original measures retained, 13 added; all visual references resolve | Static only, not DAX or Desktop acceptance |

Independent findings, baseline reproduction, sanitized live evidence and exact limitations: [INDEPENDENT-AUDIT.md](INDEPENDENT-AUDIT.md). Final fixture counts are in [evidence/m-tests.txt](evidence/m-tests.txt). The initial independent 11-check fixture failed all 11 at f503293; the expanded final file covers additional hardening. The deliberate failure evidence is expected to show FAIL.

Swagger gives default count 100 and no maximum. Production 1000 was accepted on sampled routes. Large stable multi-page reads, tied ordering, populated aggregate boundaries, Continuous aggregates and platform collection remain live acceptance dependencies. Swagger describes aggregate count only as Count; this does not establish observation weighting. Application aggregated session metrics have no reviewed endpoint. Raw extrema cannot be inferred from bucket means.
