# Open items, limitations and owner decisions

## Owner actions
1. **Revoke/rotate the credential-like literal** that was in the old `LoginEnterprise_PBI.query.pq` in public history (`089200f` and earlier). Removing it from the current tree does not invalidate it and repository history was not rewritten. The value was not printed, copied or tested during this work. Only its owner can revoke it. Decide separately whether history needs rewriting.
2. Desktop acceptance (docs/ACCEPTANCE.md) when the shared host is free.
3. Licensing/ownership: the repository has no `LICENSE` file. The MIT decision for Results Toolkit was **not** assumed to apply here. Confirm upstream ownership and the licence for this connector/template before describing it as open source.
4. Confirm API limits against the appliance Swagger (docs/CHANGE-TEST-MATRIX.md "Unverified").

## Not done / deferred
- Actual Power BI Desktop validation of the MEZ (discovery, UI, credential dialogs), the candidate PBIT (opens, renders, refreshes, saves) and any Service/gateway refresh.
- DAX execution. No Analysis Services engine could be used without touching the shared Power BI installation; template DAX is statically checked only. Acceptance includes explicit DAX queries.
- Key-credential migration is implemented additively but is **not** the template default and has only run in the Power Query SDK harness. Until accepted, do not describe legacy parameter storage as secure.
- Wall-clock deadline for paging: not possible in M (`LocalNow` is fixed per evaluation). Page-count and completeness limits are used instead.
- Application-test session-metric branch: not implemented (no documented endpoint reviewed).
- Raw min/max CPU/memory/EUX: not available from aggregate endpoints; labelled, not invented.
- Layout label edits beyond the Active Sessions cards (e.g. "Min CPU" wording) were not made; do them in Desktop.
- Independent review: per the instructions for this session no nested Claude audit was run; see docs/AUDIT-HANDOFF.md for the focused Codex review brief.
- Test Runs table remains unfiltered (all runs ever, paged) – may be slow on very large estates.

## Known compatibility notes
- Template candidate requires connector 1.1.0.2 for the failed-run feature; with an older connector the partition falls back to the old behaviour.
- Table timestamps are local time of the refreshing machine (Power Query behaviour), windows are UTC.
