# Scheduled refresh through the on-premises data gateway

Unsupported community preview. **Runtime status: a local evaluation was run (2026-11-02 to 2026-11-04).** Two on-demand refreshes and one scheduled refresh completed through a standard gateway, and the Service model matched the source on the first checks. One scheduled run failed. This is a lab test on a single laptop, not a production deployment or a support statement. Ordinary Desktop use stays per-user and needs none of this.

Official guidance used: Microsoft Learn, [Use custom data connectors with the on-premises data gateway](https://learn.microsoft.com/en-us/power-bi/connect-data/service-gateway-custom-connectors), [Install an on-premises data gateway](https://learn.microsoft.com/en-us/data-integration/gateway/service-gateway-install) and [Gateway support for Power Query connectors](https://learn.microsoft.com/en-us/power-query/handling-gateway-support). Use Microsoft's standard on-premises data gateway (Import mode). This project ships no gateway.

## What the connector already provides

- `TestConnection` for both data source kinds. The Key kind accepts a plain FQDN or a JSON data source path; the legacy kind reads the JSON path. Each returns the shared function and arguments, and the invoked function performs a real small authenticated request, so a bad URL, certificate or token fails credential setup instead of the first refresh. Covered by tests 03 and 04 on the real engine.
- Key authentication (`LoginEnterprise_PBI_Key`): the data source path is the FQDN; the token is the credential. One credential covers every query that uses the same FQDN. In the test, the published model showed exactly **one** data source of this kind with an FQDN-only path. **Use the Key kind for the gateway.** The legacy kind puts the token in the data source path.
- Errors name the route and HTTP status and never include the token.

## Administrator checklist (separate from the connector)

1. Preflight (read-only, changes nothing): `pwsh tools/Test-GatewayReadiness.ps1 -Fqdn <appliance> -ConnectorFolder <folder>`. It checks the connector file and hash, folder permissions for the service account, TCP 443 and TLS trust, and the host time zone from the user's own process; it does not prove the gateway service can reach the appliance.
2. Gateway host: standard (not personal) gateway, installed per Microsoft's instructions by a local administrator. Network: outbound HTTPS 443 from the gateway host to the appliance FQDN. **Microsoft advises against installing a gateway on a laptop or any computer that may be off, asleep or offline.** Use an always-on machine for anything beyond a test.
3. Connector folder: a folder the **gateway service account** can read (default `NT SERVICE\PBIEgwService`), **outside any user profile**, containing only `LE-PBI-Connector.mez`. Folders created under `C:\` inherit broad permissions (any authenticated user may modify); remove inheritance and grant only Administrators, SYSTEM, the installing owner and Read and Execute to the service account. Verify the SHA256 against [SHA256SUMS.txt](SHA256SUMS.txt).
4. Gateway app, Connectors: load custom connectors from that folder; the gateway loads every `.mez` in it. Restart the gateway service when asked, and **never replace files or restart the service while a refresh is running**.
5. TLS: the appliance certificate must chain to a CA trusted by the **LocalMachine** store of the gateway host. Install the CA; never disable validation. A machine-context chain check (`X509Chain` with machine context) approximates the service's view; the gateway itself is the final proof.
6. Power BI service, gateway settings: allow custom connectors for the cluster; add a data source of kind *Login Enterprise (Key credential)* with the FQDN and a read-only API token (authentication Key). In the semantic model's settings, turn on the gateway, select the gateway and map the model's data source to that connection. Publishing from Desktop may also create a separate "(Personal mode)" connection named after the FQDN; it is not routed through the standard gateway.
7. Token permissions: read access to tests, test runs, measurements, events, user sessions, applications and environments.
8. Time zone: datetimes follow the refreshing machine's zone (see README, Date windows). Set the gateway host zone deliberately.
9. A token rotated or revoked on the appliance invalidates the key stored in the Service connection. Re-enter the new token in the connection (Manage connections and gateways, edit credentials, Key). Check a token locally with `pwsh tools/Test-ApplianceToken.ps1` (hidden prompt, one read-only request, prints only the HTTP status).

## Refresh cost

The native overview adds one sequential GET per Load run overlapping the window, on top of the existing per-run requests. Large windows make refresh slower, and one failing request fails the whole refresh by design (no partial data). Keep gateway windows bounded. For scheduled refresh prefer a fixed window (`UseDateRange` true): a rolling window is evaluated per query and can straddle midnight UTC.

## What was run and what happened (local evaluation, sanitised)

| Step | Result |
|---|---|
| Install | Microsoft's standard gateway 3000.338.2, installer Authenticode-signed by Microsoft Corporation, installed by the owner with a UAC prompt on a Windows 11 laptop; service `NT SERVICE\PBIEgwService` |
| Connector folder | Outside the profile, only the 1.2.0.0 MEZ (hash verified), inherited permissions removed, service account Read and Execute |
| Connection | Key-kind connection mapped to the gateway; status Online |
| Report | A private Key-based copy (13 Key queries, no token parameter, window 2025-06-30) published to the owner's My workspace under a unique name; nothing existing was overwritten or shared |
| On-demand refresh 1 | 2026-11-02, 2 min 1 s, Completed |
| On-demand refresh 2 | 2026-11-02, 2 min, Completed. Within seconds, six `Microsoft.Mashup.Container` child processes of the gateway service opened HTTPS connections to the appliance (local process log), so the data came through the gateway |
| Source check | A DAX query in the Service after the on-demand runs, and again after the 2026-11-04 scheduled success: 7 of 7 Load runs matched the source (native score, baseline, steady state, state, aggregate mean) both times; the run with native 3.3 and bucket mean 4.2 reads 3.3 on the report card. Both ran with connector 1.2.0.0; the values are identical because the data is a fixed June 2025 window |
| Scheduled refresh, 2026-11-02 18:01 Pacific | **Failed** after 31 min with `DM_GWPipeline_Client_GatewayUnreachable`. The gateway host was shut down at 18:18:45, mid-run. Gateway containers had connected at 18:01, 18:08 and 18:14 (about 6.5 minutes apart) |
| Scheduled refresh, 2026-11-04 13:01 Pacific | Started 13:01:33, **Completed 13:18:32** (17 min). The first two attempts (gateway containers at 13:03 and 13:10) did not get through, and the Service showed "Refresh completed with warnings" with the same error code; the third attempt (six containers at 13:16:21) completed in about 2 minutes |
| On-demand refresh, 2026-11-04 15:29 Pacific, **connector 1.2.1.0 on the gateway** | The 1.2.1.0 package replaced 1.2.0.0 in the connector folder while nothing was refreshing (full hash `05CAF70F…FD25`; backup of 1.2.0.0 kept outside the folder), the gateway service was restarted by the owner (UAC), and the key in the connection was re-entered locally. Refresh started 15:29:35, **Completed 15:31:37** (2 min). Six gateway-child containers connected to the appliance at 15:29:46 to 15:29:48. The same seven runs reconcile in the Service (native 8.1, 7.7, 4.4, 3.9, 3.7, 3.3, 8.2; aggregate means incl. 4.2 for the 3.3 run; all states completed) |
| Cleanup | Temporary schedules disabled and verified; the gateway was left installed for inspection |

How to read the two scheduled runs: on 2 Nov the host shut down while a run that needed several attempts was still in progress, which is consistent with the failure; today's run shows such a run can complete. **Why the first two scheduled attempts stalled is not established.** Gateway-side logs were not collected, the on-demand runs did not show it, and a stale key in the connection was a hypothesis that was neither confirmed nor ruled out. A rotated or revoked token was one possible cause; the token check script and a credential re-entry are the cheap tests. Do not rely on a scheduled refresh finishing at its slot: expect it to start a minute or two late and, in this test, to need around 17 minutes.

What this test does **not** establish: behaviour on an always-on server, repeated schedules over days, recovery after a real token revocation, scheduled refresh with connector 1.2.1.0 (only one on-demand refresh was run with it), fresh observations arriving from the source (the data is a fixed June 2025 window), or any production support. Refresh time is not data time: the data is a fixed June 2025 window, so a successful refresh shows no new observations.

## Three different questions

| Question | Where to look | Does not imply |
|---|---|---|
| Was a refresh attempted, and did it fail? | Service refresh history | Fresh data |
| When was the last successful refresh? | Service refresh history | New observations exist |
| What is the newest source observation? | Template measure `Newest Source Observation` | That a refresh just ran |

Refreshing a fixed historical window succeeds every time and shows no new data; that demonstrates nothing about new collection. Scheduled Import refresh is not streaming, real time or a browser page refresh; data is as old as the last successful refresh. A rolling window moves each refresh; a fixed window does not.

## Recovery

| Symptom | Likely cause | Action |
|---|---|---|
| Connector missing in gateway app | Folder unreadable by the service, or service not restarted | Fix the ACL for the service account, restart the service (not during a refresh) |
| Data source creation fails at test | TLS not trusted on the host, firewall, wrong FQDN, bad token | Run the preflight; read the error text (route and status) |
| Refresh worked, now 401 | Token revoked, rotated or expired | Check the token with `tools/Test-ApplianceToken.ps1`; update the data source credential (Key) |
| Refresh fails on one run | A broken historical snapshot on the appliance | Narrow the window; see DESKTOP-LOAD-FAILURE.md |
| Scheduled refresh stays "In progress" or shows "completed with warnings" `GatewayUnreachable` | Observed in this test: early attempts did not get through and a later retry succeeded; cause not established | Leave it running; do not restart the gateway mid-run; check Refresh history. If it fails, retry once after confirming the gateway is online and the host stayed on |
| Run fails with `DM_GWPipeline_Client_GatewayUnreachable` after about 30 minutes | The gateway host went offline mid-run (shutdown, sleep, network) | Keep the host on and awake; re-run; check host power events |
| Dates differ from Desktop | Different machine zone | Compare in UTC |
| Roll back the connector | n/a | Put the previous `.mez` (`bin/archive/1.2.0.0` or `1.1.0.2`) in the folder, restart the service when no refresh is running |

## Teardown of the local test (not performed; the gateway was left for inspection)

- Service: in the model's settings leave the schedule Off; delete the test report and semantic model from My workspace; in Manage connections and gateways delete the test Key connection and the "(Personal mode)" connection; under On-premises data gateways remove the test gateway.
- Local, from an administrator session: uninstall "On-premises data gateway" (Settings, Apps), then `Remove-Item -Recurse -Force C:\LE-PBI-GatewayConnector`. The gateway recovery key stays with its owner.

## Not validated

Always-on server hosting, multi-day scheduling, token-revocation recovery and the cause of the stalled early scheduled attempts. Incremental refresh is assessed in [BACKLOG.md](BACKLOG.md); it is not implemented.
