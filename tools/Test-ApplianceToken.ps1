<#
.SYNOPSIS
  Checks whether a Login Enterprise API token is accepted by the appliance. Prints only the HTTP status.
.DESCRIPTION
  Prompts locally for the appliance FQDN and the token (the token is read as a hidden secure string, never written
  to disk, never echoed, never put in a URL). Makes ONE read-only request (list one test) with the token in the
  Authorization header, using this machine's normal certificate trust. No TLS bypass.
  200 = the token is accepted. 401 = the token is invalid, rotated or revoked. 403 = accepted but lacks read access.
  Anything else = see the printed status or error type.
#>
[CmdletBinding()]
param([string]$Fqdn)
$ErrorActionPreference = 'Stop'
if (-not $Fqdn) { $Fqdn = Read-Host 'Appliance FQDN (no https://, no trailing slash)' }
$Fqdn = $Fqdn.Trim().TrimEnd('/') -replace '^https?://', ''
$secure = Read-Host 'API token (input hidden)' -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    $uri = "https://$Fqdn/publicApi/v7-preview/tests?count=1&offset=0"
    try {
        $r = Invoke-WebRequest -Uri $uri -Headers @{ Authorization = "Bearer $plain"; Accept = 'application/json' } -TimeoutSec 30 -UseBasicParsing
        "HTTP $([int]$r.StatusCode): token accepted."
    } catch {
        $resp = $_.Exception.Response
        if ($resp) { "HTTP $([int]$resp.StatusCode): $(switch ([int]$resp.StatusCode) { 401 {'token invalid, rotated or revoked.'} 403 {'token accepted but lacks read access.'} default {'unexpected status.'} })" }
        else { "No HTTP response ($($_.Exception.GetType().Name)). Check the FQDN, network and certificate trust." }
    }
} finally {
    if ($bstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    $plain = $null; $secure.Dispose()
}
