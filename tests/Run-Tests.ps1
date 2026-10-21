<#
.SYNOPSIS
  Runs the connector's M tests on the real Power Query mashup engine (PQTest from Microsoft.PowerQuery.SdkTools).
.DESCRIPTION
  Builds a TEST-ONLY MEZ (connector + tests/TestSupport.pq) and runs every tests/cases/*.pq with `PQTest run-test`.
  Tests use synthetic fixtures served through an injected fetch function; no network, credentials or Power BI Desktop
  are involved. This executes real M; it does NOT exercise Web.Contents, credential dialogs, Desktop UI or the gateway.
.PARAMETER PQTest  Path to PQTest.exe. If omitted, the pinned SDK tools package is downloaded (nuget.org) to .cache/.
#>
[CmdletBinding()]
param([string]$PQTest, [string]$Filter = '*')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$SdkVersion = '2.155.2'
$SdkSha256 = '9A924EDAF369BC7FA8F4CE9477C19236E6AF2989EF4149920CD263511651F4FF'

if (-not $PQTest) {
    $cache = Join-Path $root '.cache/sdktools'
    $PQTest = Join-Path $cache 'tools/PQTest.exe'
    if (-not (Test-Path $PQTest)) {
        New-Item -ItemType Directory -Force $cache | Out-Null
        $pkg = Join-Path $cache 'pkg.zip'
        Invoke-WebRequest "https://api.nuget.org/v3-flatcontainer/microsoft.powerquery.sdktools/$SdkVersion/microsoft.powerquery.sdktools.$SdkVersion.nupkg" -OutFile $pkg
        $actual = (Get-FileHash $pkg -Algorithm SHA256).Hash
        if ($actual -ne $SdkSha256) { throw "SDK tools package hash mismatch: expected $SdkSha256 got $actual" }
        Expand-Archive $pkg $cache -Force
    }
}
if (-not (Test-Path $PQTest)) { throw "PQTest.exe not found at $PQTest" }

$work = Join-Path ([IO.Path]::GetTempPath()) ("le-pbi-tests-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $work | Out-Null
$mez = Join-Path $work 'LE-PBI-Connector.test.mez'
& (Join-Path $root 'build/Build-Mez.ps1') -Test -Output $mez | Out-Null

$failed = 0; $total = 0
foreach ($case in (Get-ChildItem (Join-Path $root 'tests/cases') -Filter "$Filter.pq" | Sort-Object Name)) {
    $total++
    # {{FILE:relative/path}} is replaced by an M text literal holding that repo file (lets tests evaluate shipped M source).
    $src = [IO.File]::ReadAllText($case.FullName)
    $src = [regex]::Replace($src, '\{\{FILE:([^}]+)\}\}', {
        param($m)
        $content = [IO.File]::ReadAllText((Join-Path $root $m.Groups[1].Value)) -replace "`r`n", "`n"
        '"' + $content.Replace('"', '""') + '"'
    })
    $caseFile = Join-Path $work $case.Name
    [IO.File]::WriteAllText($caseFile, $src)
    $json = & $PQTest run-test -e $mez -q $caseFile 2>&1 | Out-String
    try { $res = ($json | ConvertFrom-Json)[0] } catch { $res = $null }
    if ($res -and $res.Status -eq 'Passed') {
        Write-Host ("PASS  {0}  {1}" -f $case.Name, (($res.Output | ForEach-Object { $_.Value }) -join ' '))
    } else {
        $failed++
        $msg = if ($res) { ($res.Error | ConvertTo-Json -Compress -Depth 4) } else { $json }
        Write-Host ("FAIL  {0}`n      {1}" -f $case.Name, $msg) -ForegroundColor Red
    }
}
Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
Write-Host "`n$($total - $failed)/$total test files passed"
if ($failed -gt 0) { exit 1 }
