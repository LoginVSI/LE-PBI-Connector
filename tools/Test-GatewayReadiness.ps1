<#
.SYNOPSIS
  Read-only preflight for refreshing the Login Enterprise connector through the standard on-premises data gateway.
.DESCRIPTION
  Run on the gateway host (or any host in the same network position) BEFORE the administrator configures anything.
  It changes nothing: no install, no ACL or trust change, no credential, no Login Enterprise API call.
  Checks: connector file and optional checksum; whether the gateway service identity (default NT SERVICE\PBIEgwService)
  can read the connector folder; TCP 443 and TLS trust of the appliance as seen from THIS host's certificate store;
  host time zone (Power Query shows UTC timestamps converted to the refreshing machine's zone).
  It opens one TCP/TLS connection to the appliance FQDN on port 443 and makes no API call. It does not prove the gateway, the Service or a refresh works; see docs/GATEWAY.md.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Fqdn,
    [Parameter(Mandatory)][string]$ConnectorFolder,
    [string]$ServiceAccount = 'NT SERVICE\PBIEgwService',
    [string]$ExpectedSha256
)
$ErrorActionPreference = 'Stop'
$failed = 0
function Report([string]$level, [string]$text) { Write-Host ("{0,-5} {1}" -f $level, $text); if ($level -eq 'FAIL') { $script:failed++ } }

if ($Fqdn -notmatch '^(?=.{1,253}$)([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,}$') { throw 'Fqdn must be a bare host name (no scheme, path or port).' }

# 1. Connector file
$mez = Join-Path $ConnectorFolder 'LE-PBI-Connector.mez'
if (-not (Test-Path -LiteralPath $mez)) { Report FAIL "LE-PBI-Connector.mez not found in $ConnectorFolder" }
else {
    $hash = (Get-FileHash -LiteralPath $mez -Algorithm SHA256).Hash
    Report ok "connector present, SHA256 $hash"
    if ($ExpectedSha256) { if ($hash -ieq $ExpectedSha256) { Report ok 'checksum matches the expected value' } else { Report FAIL 'checksum differs from the expected value' } }
    if (Get-ChildItem -LiteralPath $ConnectorFolder -Filter '*.mez' | Where-Object Name -ne 'LE-PBI-Connector.mez') { Report warn 'other .mez files share this folder; the gateway loads all of them' }
}

# 2. Folder access for the service identity (read-only ACL inspection)
try {
    $acl = Get-Acl -LiteralPath $ConnectorFolder
    $readers = @($acl.Access | Where-Object { $_.AccessControlType -eq 'Allow' -and (($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::ReadAndExecute) -eq [Security.AccessControl.FileSystemRights]::ReadAndExecute) -and
        ($_.IdentityReference.Value -ieq $ServiceAccount -or $_.IdentityReference.Value -in @('BUILTIN\Users', 'NT AUTHORITY\Authenticated Users', 'Everyone')) })
    if ($readers.Count) { Report ok ("read access is granted through: " + (($readers.IdentityReference.Value | Select-Object -Unique) -join ', ') + ' (an inherited or group entry only; confirm the service account is named or a member, because membership and Deny entries are not evaluated)') }
    elseif ($false) { }
    else { Report FAIL "no ACL entry grants read to $ServiceAccount or a broad group; a folder under a user profile is typically not readable by the gateway service" }
    if (($ConnectorFolder -split '[\/]') -contains 'Users') { Report warn 'the folder is under a user profile; Microsoft documents that such folders are usually not accessible to the gateway service' }
    if (@($acl.Access | Where-Object { $_.AccessControlType -eq 'Deny' }).Count) { Report warn 'the folder has Deny entries; they are not evaluated here' }
} catch { Report FAIL "cannot read the folder ACL: $($_.Exception.Message)" }

# 3. Network and TLS as seen from this host
try {
    $client = [Net.Sockets.TcpClient]::new()
    $connect = $client.ConnectAsync($Fqdn, 443); if (-not $connect.Wait(10000)) { throw 'TCP 443 timed out after 10 s' }
    $errors = $null
    $ssl = [Net.Security.SslStream]::new($client.GetStream(), $false, { param($s, $c, $ch, $e) $script:errors = $e; $true })
    $ssl.AuthenticateAsClient($Fqdn)
    $cert = [Security.Cryptography.X509Certificates.X509Certificate2]::new($ssl.RemoteCertificate)
    if ($script:errors -eq [Net.Security.SslPolicyErrors]::None) { Report ok "TLS ($($ssl.SslProtocol)) trusted by this host; certificate expires $($cert.NotAfter.ToString('yyyy-MM-dd'))" }
    else { Report FAIL "TLS certificate is not trusted by this host ($script:errors). Install the issuing CA in the LocalMachine store (the gateway service uses it); do not disable validation." }
    $client.Dispose()
} catch { Report FAIL "cannot reach https://$Fqdn : $($_.Exception.Message)" }

# 4. Time zone (information)
Report info "host time zone is $((Get-TimeZone).Id); datetimes in the refreshed model follow the refreshing machine's zone, so set it deliberately or use UTC"
if ($failed) { Write-Host "`n$failed problem(s). Nothing was changed."; exit 1 }
Write-Host "`nPreflight passed. This is not a gateway or refresh validation."
