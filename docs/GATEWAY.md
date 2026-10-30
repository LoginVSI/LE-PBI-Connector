# Scheduled refresh through the on-premises data gateway

Unsupported community preview. **Runtime status: pending.** No gateway, workspace or tenant was available or authorised in this phase, so nothing here has been run in the Power BI service. Ordinary Desktop use stays per-user and needs none of this.

Official guidance used: Microsoft Learn, [Use custom data connectors with the on-premises data gateway](https://learn.microsoft.com/en-us/power-bi/connect-data/service-gateway-custom-connectors) and [Gateway support for Power Query connectors](https://learn.microsoft.com/en-us/power-query/handling-gateway-support). Use Microsoft's standard on-premises data gateway (Import mode). This project ships no gateway.

## What the connector already provides

- `TestConnection` for both data source kinds. The Key kind accepts a plain FQDN or a JSON data source path; the legacy kind reads the JSON path. Each returns the shared function and arguments, and the invoked function performs a real small authenticated request, so a bad URL, certificate or token fails credential setup instead of the first refresh. Covered by tests 03 and 04 on the real engine.
- Key authentication (`LoginEnterprise_PBI_Key`): the data source path is the FQDN; the token is the credential. One credential covers every query that uses the same FQDN. **Use the Key kind for the gateway.** The legacy kind puts the token in the data source path.
- Errors name the route and HTTP status and never include the token.

## Administrator checklist (separate from the connector)

1. Preflight (read-only, changes nothing): `pwsh tools/Test-GatewayReadiness.ps1 -Fqdn <appliance> -ConnectorFolder <folder>`.
2. Gateway host: standard (not personal) gateway, installed per Microsoft's instructions. Network: outbound HTTPS 443 from the gateway host to the appliance FQDN.
3. Connector folder: a folder the **gateway service account** can read (default `NT SERVICE\PBIEgwService`). Folders under a user profile usually fail. Put only `LE-PBI-Connector.mez` there; the gateway loads every `.mez` in the folder. Verify the SHA256 against [SHA256SUMS.txt](SHA256SUMS.txt).
4. Gateway app, Connectors: load custom connectors from that folder; restart the gateway service.
5. TLS: the appliance certificate must chain to a CA trusted by the **LocalMachine** store of the gateway host. Install the CA; never disable validation.
6. Power BI service, gateway settings: allow custom connectors for the cluster; add a data source of kind *Login Enterprise (Key credential)* with the FQDN and a read-only API token (authentication Key). Map the semantic model's data source to it. Credentials, privacy level and tenant/workspace choices belong to the owner and administrator.
7. Token permissions: read access to tests, test runs, measurements, events, user sessions, applications and environments.
8. Time zone: datetimes follow the refreshing machine's zone (see README, Date windows). Set the gateway host zone deliberately.

## Refresh cost

The native overview adds one sequential GET per Load run overlapping the window, on top of the existing per-run requests. Large windows make refresh slower, and one failing request fails the whole refresh by design (no partial data). Keep gateway windows bounded.

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
| Connector missing in gateway app | Folder unreadable by the service, or service not restarted | Fix the ACL for the service account, restart the service |
| Data source creation fails at test | TLS not trusted on the host, firewall, wrong FQDN, bad token | Run the preflight; read the error text (route and status) |
| Refresh worked, now 401 | Token revoked or expired | Update the data source credential (Key) |
| Refresh fails on one run | A broken historical snapshot on the appliance | Narrow the window; see DESKTOP-LOAD-FAILURE.md |
| Dates differ from Desktop | Different machine zone | Compare in UTC |
| Roll back the connector | n/a | Put the previous `.mez` (`bin/archive/1.1.0.2`) in the folder, restart the service |

## Not validated

Publication, on-demand refresh, repeated scheduled refresh, source reconciliation after refresh and recovery have **not** been run. Incremental refresh is assessed in [BACKLOG.md](BACKLOG.md); it is not implemented.
