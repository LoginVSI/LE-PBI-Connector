<#
Swaps ONLY LE-PBI-Connector.mez in the user's Custom Connectors folder between the accepted 1.1.0.2 rollback package and the
1.2.0.0 build, verifying the full SHA256 after the copy. Refuses to run while Power BI Desktop is open. Never touches ResultsToolkit.mez.
Usage: pwsh tools/Swap-Connector.ps1 -To 1.1.0.2   |   pwsh tools/Swap-Connector.ps1 -To 1.2.0.0
#>
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateSet('1.1.0.2', '1.2.0.0')][string]$To)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$known = @{
    '1.1.0.2' = @{ src = Join-Path $root '.cache/desktop-install-20261028/LE-PBI-Connector.1.1.0.2.mez'; sha = '8B7EAC70A460A0EF03DEAAE650AF9DCF747849538B70EAA1CEA22E5F5F43D768' }
    '1.2.0.0' = @{ src = Join-Path $root 'bin/AnyCPU/Debug/LE-PBI-Connector.mez'; sha = 'FFF51B3E8F86FB9980B90F19F825DEBFBADCDD2B76818963C2A5511A8ACB68A9' }
}
if (Get-Process PBIDesktop -ErrorAction SilentlyContinue) { throw 'Power BI Desktop is running; close it first. Nothing changed.' }
$want = $known[$To]
if ((Get-FileHash -LiteralPath $want.src -Algorithm SHA256).Hash -ne $want.sha) { throw "Source package for $To does not match its recorded hash. Nothing changed." }
$dest = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Power BI Desktop/Custom Connectors/LE-PBI-Connector.mez'
Copy-Item -LiteralPath $want.src -Destination $dest -Force
$got = (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash
if ($got -ne $want.sha) { throw "Installed hash $got does not match $To." }
"Installed $To, full SHA256 $got"
if ($To -ne '1.2.0.0') { 'REMINDER: restore 1.2.0.0 with: pwsh tools/Swap-Connector.ps1 -To 1.2.0.0' }
