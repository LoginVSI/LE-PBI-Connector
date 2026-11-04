# Metrics guide: what each table covers

Unsupported community preview. This page says what the connector and template return, at what grain, for which run types, and how to read the distinctions that are easy to misread. It does not define Login Enterprise's scoring formula and does not invent weighting. Where the API contract does not say something, this page says so.

API version: the connector calls the appliance's `v7-preview` routes only. There is no v8 toggle and no v8 adapter (see [BACKLOG.md](BACKLOG.md)).

## Windows and time

- Every date window is in **UTC**. A fixed window uses `StartDateParam` and `EndDateParam`: the window starts at 00:00 UTC on the start date and the end date is **inclusive** (it ends just before 00:00 UTC the next day). Start = end gives exactly one UTC day.
- `DaysBack` is a **rolling** window ending today. It moves on every refresh. A fixed window does not move: refreshing it succeeds every time and shows the same retained data.
- Datetimes in the model follow the refreshing machine's time zone (Power Query converts the appliance's UTC timestamps). In the Service, a gateway host's zone applies. Compare in UTC when in doubt.
- "Refresh time" and "data time" are different things. A successful scheduled refresh of a fixed historical window proves the pipeline works; it says nothing about new observations. `Newest Source Observation` shows the newest source timestamp, not the refresh time.

## Table coverage

| Table | Source route (v7-preview) | Grain | Run types | Notes |
|---|---|---|---|---|
| Tests | `tests` | One row per test | all | Reference list. |
| Test Runs | `tests/test-runs`, plus one snapshot request per run | One row per run | Load, Application, Continuous | Snapshot supplies workload configuration. |
| Test Runs In Window | derived | One row per run overlapping the window | all | Keeps runs with no measurements selectable. |
| Workload Steps | run snapshot | One row per workload step | per run snapshot | |
| Applications | `applications` | One row per application | n/a | |
| Environments | `environments` | One row per environment | n/a | |
| Measurements | `test-runs/{id}/measurements` | One row per measurement observation | runs with measurements | `duration` is numeric as returned by the API. |
| Events | `events` | One row per event | all | One window request, filtered to the window. |
| User Sessions | `test-runs/{id}/user-sessions` | One row per user session | runs with sessions | Counts are per loaded window; do not add counts from adjacent windows. |
| User Session Metrics | `.../aggregated-load-test-user-session-metrics`, `.../aggregated-continuous-test-user-session-metrics` | Aggregated points (Continuous uses `avgHour`) | Load, Continuous | Application runs have no such endpoint. |
| Platform Metrics | `platform-metrics` | Data points per metric | environment based | |
| Aggregated EUX Results | `test-runs/{id}/aggregated-eux-results` | **Hourly buckets** (`timestamp`, `score`, `count`) | Load, Continuous | Only buckets inside the window are loaded. |
| **Load Test Overview** (1.2.0.0) | `load-test-run-overview/{id}` | **One row per Load run, whole run** | **Load only** | Native values; see below. |

Application and Continuous runs get **no** `Load Test Overview` row. A 404 for a Load run also gives no row; any other failure fails the refresh by design (no partial data).

## Native EUX versus aggregate bucket means

- The **native** values (`euxScore`, `euxBaseline`, `euxSteadyState`, `vsiMax`) are what Login Enterprise reports for the whole run. The template shows them only when exactly one run is selected.
- The **aggregate** measures average the hourly buckets that fall inside your window. An unweighted mean of buckets is **not** the native overall score: on retained lab runs the native value was 3.3 where the bucket mean was 4.2, and 8.2 against 8.15.
- Bucket `count` semantics are not proven, so **weighted statistics stay blank**. The template does not weight by `count`.
- The scoring formula is not documented by the API; this project does not try to reproduce it.
- A run that overlaps the window is included **with its whole-run native score** even if few or none of its buckets are in the window.

## Reading states, blanks and zeros

| You see | Meaning |
|---|---|
| `Select one run` | No run or several runs are selected; native values are not defined for a group. |
| `No Data` | The appliance reports no value for the selected run (for example EUX disabled) or there is no overview row. Never a zero. A run whose state is `unavailable` can still carry a value, which is shown as is; check the state measure. |
| `0` | A genuine reported zero. Kept as zero. |
| `(bound, aboveThreshold)` next to VSImax | The appliance's state is `aboveThreshold`: the number is a **lower bound reported by the appliance, not an exact capacity**. |
| `completed`, `disabled`, `unavailable` | Appliance states for EUX (`euxState`) and VSImax (`vsiMaxState`). Observed values; the connector does not reinterpret them. |

## Accounts and sessions

- `Distinct Accounts` counts distinct account IDs in the selected scope and window. `Active Sessions Count` is a deprecated name kept for old reports; it is also a distinct account count, not concurrent sessions.
- Session and account counts depend on the loaded window. Two adjacent windows cannot simply be added: a session or account can appear in both.
- Successful versus failed session counts use only runs that finished and have the required data; runs without facts show `No Data`, not 0.

## What this project does not cover

- Application-test per-application CPU/memory metrics (no matching endpoint in the reviewed contract).
- Streaming or real-time data. Import refresh data is as old as the last successful refresh.
- Any claim about production support. This is an unsupported community preview.

See also [NATIVE-EUX.md](NATIVE-EUX.md), [GATEWAY.md](GATEWAY.md) and [ACCEPTANCE.md](ACCEPTANCE.md).
