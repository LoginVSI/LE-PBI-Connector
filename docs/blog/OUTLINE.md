# Blog C outline (private working notes – do not publish)

Follows Results Toolkit Blog B. Subject: verified LE-PBI-Connector/template updates. **No launch article yet.** Publish only claims marked VERIFIED below once Desktop acceptance (docs/ACCEPTANCE.md) is complete. No customer endorsement, identity or data without approval.

## Working title ideas
"Making the Login Enterprise Power BI template tell the truth" / "Why your success rate ignored the failed runs"

## Story arc
1. The community connector + template: unsupported, adaptable reference tooling (state it plainly).
2. Four ways numbers could lie: truncated measurements (1000/day), failed runs missing from the denominator, "No Data" on valid zeros, "today" cut off.
3. How we checked: fixture tests on the real Power Query engine; static template checks; then Desktop acceptance (say what was and was not run).
4. What changed for you: upgrade steps, one canonical `.mez`, date-window rules, Key credential option (opt-in), what stays the same (tables, columns, measure names).
5. Limits, honestly: v7-preview target, unaccepted gateway, bucket-average caveats, DAX verified in Desktop only.
6. Call to action: try it on a lab appliance, send us redacted error text.

## Claim ledger
| Claim | State |
|---|---|
| Measurements no longer truncated at 1000/run/day | Engine-verified on synthetic fixture; **appliance reconciliation pending** |
| Same date window everywhere; end day and today included | Engine-verified (synthetic); appliance pending |
| Failed requests fail loudly | Engine-verified (synthetic) |
| Success rate includes failed/no-measurement runs | DAX statically checked only; **Desktop pending** |
| Key credential keeps the token out of the report | SDK-harness only; **Desktop/Service pending** |
| Gateway works | **Not claimed** |

## Private before/after examples (synthetic fixtures – not customer data)
- 2 500 measurements in one run on one day: 1.1.0.1 logic requests `count=1000&offset=0` once → 1 000 rows; 1.1.0.2 → 2 500 rows (test 03).
- Window End Date 20 Oct: `GetUserSessions` used `to=2026-10-20T00:00:00Z` (excluded the day); now `to=2026-10-22T00:00:00Z` for End=21 Oct (test 03 guard).
- Success rate with 3 finished Load runs (2 completed, 1 aborted with no measurements): before = 2/2 = 100% (aborted run vanished); after = 2/3 = 66.7% (re-measure in Desktop before publishing the figure).
- Zero metric: all-zero CPU series → "No Data" before; blank message after.

## Screenshots to capture at acceptance (blur FQDNs/tokens/names)
1. Get Data dialog showing both entries. 2. Parameter dialog with Days Back/Use Date Range. 3. Error dialog for wrong FQDN (new text). 4. Summary page before/after success rate with a failed run selected. 5. Logon Metrics "Distinct Accounts" card. 6. Slicer list including a failed run. 7. Empty gauge with no run selected. 8. Data source settings showing the Key kind (path = FQDN only). 9. Row count reconciliation (Measurements vs API totalCount).
