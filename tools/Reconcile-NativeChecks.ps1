<#
Compares the output of tools/Invoke-DesktopModelChecks.ps1 -QueryFile template/acceptance/NativeOverviewChecks.dax
with a private expectations file (runs keyed by testName + counter). Read-only; prints PASS/FAIL per run.
Usage: pwsh tools/Reconcile-NativeChecks.ps1 -Raw <modelchecks.raw.json> -Expected <expected.private.json> -Window A_2025-06-30
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Raw, [Parameter(Mandatory)][string]$Expected, [Parameter(Mandatory)][string]$Window)
$ErrorActionPreference = 'Stop'
$data = Get-Content -LiteralPath $Raw -Raw | ConvertFrom-Json
$exp = (Get-Content -LiteralPath $Expected -Raw | ConvertFrom-Json).$Window
if (-not $exp) { throw "Window '$Window' not in expectations." }
$rows = @($data.resultSets[0] | Where-Object { $_ }); $fail = 0
function Near($a, $b) { if ($null -eq $a -and $null -eq $b) { return $true }; if ($null -eq $a -or $null -eq $b) { return $false }; [Math]::Abs([double]$a - [double]$b) -lt 0.051 }
foreach ($e in $exp) {
    $m = @($rows | Where-Object { $_.'Load Test Overview[testName]' -eq $e.testName -and [int]$_.'Load Test Overview[counter]' -eq $e.counter })
    $why = @()
    if ($m.Count -ne 1) { $why += "rows=$($m.Count) (expected 1)" }
    else {
        $r = $m[0]
        if ($r.'[nativeRows]' -ne 1) { $why += 'nativeRows!=1' }
        if (-not (Near $r.'[nativeScore]' $e.nativeScore)) { $why += "score $($r.'[nativeScore]') vs $($e.nativeScore)" }
        if (-not (Near $r.'[nativeBaseline]' $e.nativeBaseline)) { $why += 'baseline' }
        if (-not (Near $r.'[nativeSteady]' $e.nativeSteady)) { $why += 'steady' }
        if ($r.'[euxState]' -ne $e.euxState) { $why += 'euxState' }
        if ($r.'[vsiState]' -ne $e.vsiState) { $why += 'vsiState' }
        if (-not (Near $r.'[aggregateMean]' $e.aggMeanInWindow)) { $why += "aggMean $($r.'[aggregateMean]') vs $($e.aggMeanInWindow)" }
        if ($e.vsiState -eq 'aboveThreshold' -and "$($r.'[vsiDisplay]')" -notmatch 'bound, aboveThreshold') { $why += 'vsi bound text' }
        if ($null -eq $e.nativeScore -and "$($r.'[scoreDisplay]')" -ne 'No Data') { $why += 'null score must display No Data' }
    }
    $tag = if ($why) { $fail++; 'FAIL ' + ($why -join '; ') } else { 'PASS' }
    '{0} #{1}: {2}' -f $e.testName, $e.counter, $tag
}
$dups = @($data.resultSets[2] | Where-Object { $_ }).Count
$multi = @($data.resultSets[1]) | ForEach-Object { $_ } | Select-Object -First 1
'duplicate overview rows: {0}; multi-run display: {1}; multi native blank: {2}' -f $dups, $multi.'[display]', ($null -eq $multi.'[nativeScoreMulti]')
if ($dups -ne 0 -or $multi.'[display]' -ne 'Select one run' -or $null -ne $multi.'[nativeScoreMulti]') { $fail++ }
if ($fail) { "RESULT: $fail failure(s)"; exit 1 } else { 'RESULT: all reconciled' }
