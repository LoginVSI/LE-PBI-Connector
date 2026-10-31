<#
Opens ONE acceptance copy in Power BI Desktop, waits until its model answers, runs the native checks and reconciles.
You still do the Desktop clicks (Load / enter the Key credential / Refresh). Nothing is changed in the file by this script.
Usage: pwsh tools/Start-AcceptanceFile.ps1 -File <pbix|pbit> -Window A_2025-06-30 [-NoLaunch] [-TimeoutMinutes 20]
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$File, [Parameter(Mandatory)][string]$Window, [switch]$NoLaunch, [int]$TimeoutMinutes = 20)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root ('.cache/desktop-acceptance-20261028/raw-{0}.private.json' -f $Window)
if (-not $NoLaunch) { Start-Process -FilePath (Resolve-Path -LiteralPath $File) }
Write-Output 'Do the Desktop steps now. This script polls for a refreshed model (Ctrl+C to stop).'
$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 20
    $r = & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Invoke-DesktopModelChecks.ps1') -QueryFile (Join-Path $root 'template/acceptance/NativeOverviewChecks.dax') -OutputPath $out 2>&1
    if ($LASTEXITCODE -eq 0 -and (Test-Path $out) -and (Get-Item $out).LastWriteTime -gt (Get-Date).AddMinutes(-1)) {
        & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Reconcile-NativeChecks.ps1') -Raw $out -Expected (Join-Path $root '.cache/desktop-acceptance-20261028/expected.private.json') -Window $Window
        exit $LASTEXITCODE
    }
}
throw 'Timed out waiting for a queryable model.'
