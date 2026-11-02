# Open items and owner actions

Current phase (2026-10-28): backlog matrix in [BACKLOG.md](BACKLOG.md). Open for 1.2.0.0: Desktop acceptance of the native overview additions (ACCEPTANCE.md section G), gateway/Service runtime ([GATEWAY.md](GATEWAY.md)), independent review of the delta ([REVIEW-HANDOFF.md](REVIEW-HANDOFF.md)). Items 1-5 below remain as written.

Independent review and repairs: [INDEPENDENT-AUDIT.md](INDEPENDENT-AUDIT.md). The exercised Desktop scope has qualified acceptance; PR #4 is merged as a community preview, with no published release.

1. Revoke/rotate the credential-like literal in public history (`089200f` and earlier). It was not used for this audit. Removing it from the tree does not revoke it; history was not rewritten. The owner must decide separately whether history should be rewritten.
2. The owner accepted the qualified [Desktop acceptance](ACCEPTANCE.md) and [merge handoff](MERGE-HANDOFF.md) limits before merging. Key import/Load/Refresh and exact fixed-window model parity pass, including all 11,549 measurements and all 83 measures. Key moved-visual save/reopen/refresh passes. Remaining other interactions, older saved-model compatibility and unobserved cases are tracked separately. Final legacy native export/rebaseline is complete. Direct Desktop source-path display is unavailable: label hides it and PBIDS export is unsupported; SDK FQDN-only scope evidence is separate. No older PBIX was available. Native UI control remains unavailable.
3. Confirm licensing/ownership. No LICENSE file exists; the Toolkit's licence was not copied here.
4. Establish each aggregate `count` population from authoritative implementation/vendor evidence or raw-to-bucket reconciliation on existing results. Weighted measures return BLANK until then.
5. Extend read-only appliance coverage to populated EUX/session aggregates, Continuous results, platform metrics and large stable multi-page results. Swagger supplies no `count` maximum. Size 1000 was accepted on sampled endpoints, not proven universal. Tied ordering and snapshot consistency are not guaranteed.

The elapsed guard is a 300-second cooperative request budget, not a hard overall refresh deadline. It cannot preempt requests, decoding or other engine work, and separate evaluations have separate budgets. Request timeouts, retries and page caps provide additional bounds. Exact details are in the independent audit.

Application-test aggregated session metrics remain unimplemented because no matching endpoint exists in the reviewed contract. Raw min/max cannot be inferred from aggregate buckets. Legacy CPU/Memory averages remain unweighted bucket means with legacy labels; Desktop acceptance should confirm units and label extrema as bucket extrema.

The legacy token parameter remains in the template for compatibility and is stored in clear text. The additive Key path now has actual Desktop Load/Refresh and fixed-window parity evidence as well as SDK checks. Gateway deployment, Service scheduled refresh, incremental ingestion and other optional integrations stay in the backlog.

## Accepted acquisition limitation

The first Desktop Load failed with thirteen blocked queries. The snapshot-acquisition repair was installed with backups and an unchanged Toolkit connector. The successful retry is followed by populated-model DAX/source reconciliation; see [DESKTOP-ACCEPTANCE.md](DESKTOP-ACCEPTANCE.md) for its scope and preserved initial empty readback. A selected window containing a broken historical snapshot remains an appliance-side dependency; no error is hidden as empty data. The owner verified ISO entry in en-US Desktop fields. Both date descriptions and setup examples are updated and the candidate rebuilt; the in-progress report is preserved.
