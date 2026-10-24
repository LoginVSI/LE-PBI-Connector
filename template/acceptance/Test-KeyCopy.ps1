# Static Key-copy checks, including parameter-dialog defaults. Not Desktop acceptance.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Candidate, [Parameter(Mandatory)][string]$StartDate, [Parameter(Mandatory)][string]$EndDate)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../TemplateCommon.ps1')
$model = Read-PbitModel $Candidate
$persisted = [System.Text.Json.Nodes.JsonNode]::Parse((ConvertFrom-Utf16Bytes (Read-ZipEntryBytes $Candidate 'UnappliedChanges')))
$issues = [Collections.Generic.List[string]]::new()
foreach ($problem in @(Get-PersistedQueryProblems $model $persisted)) { $issues.Add($problem) }
$expressions = @{}
foreach ($expression in $model['model']['expressions']) { $expressions[[string]$expression['name']] = Join-Lines $expression['expression'] }
if ($expressions.ContainsKey('APIToken')) { $issues.Add('Token parameter remains.') }
foreach ($name in @('DaysBack', 'UseDateRange')) {
    $expected = if ($name -eq 'DaysBack') { '7' } else { 'true' }
    $text = $expressions[$name]
    if ($text -cnotmatch ('^' + $expected + '\s+meta\s')) { $issues.Add("Wrong effective value: $name") }
    $default = [regex]::Match($text, '\bDefaultValue\s*=\s*(true|false|\d+)')
    if (-not $default.Success -or $default.Groups[1].Value -cne $expected) { $issues.Add("DefaultValue disagrees with fixed acceptance scope: $name") }
}
foreach ($item in @(@{ name='StartDateParam'; date=$StartDate }, @{ name='EndDateParam'; date=$EndDate })) {
    $date = [datetime]::ParseExact($item.date, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture)
    $pattern = '^#date\(' + $date.Year + ',\s*' + $date.Month + ',\s*' + $date.Day + '\)\s+meta\s'
    if ($expressions[$item.name] -cnotmatch $pattern) { $issues.Add("Wrong date value: $($item.name)") }
}
$keyCalls = 0; $legacyCalls = 0
foreach ($table in $model['model']['tables']) {
    foreach ($partition in $table['partitions']) {
        if ([string]$partition['source']['type'] -eq 'm') {
            $text = Join-Lines $partition['source']['expression']
            $keyCalls += [regex]::Matches($text, 'LoginEnterprise_PBI\.ContentsKey\(').Count
            $legacyCalls += [regex]::Matches($text, 'LoginEnterprise_PBI\.Contents\(').Count
        }
    }
}
if ($keyCalls -ne 12 -or $legacyCalls -ne 0) { $issues.Add('Connector call migration is incomplete.') }
if ($issues.Count) { foreach ($issue in $issues) { Write-Host "FAIL: $issue" }; exit 1 }
Write-Host 'PASS: Key copy has matching persisted metadata, 12 Key calls, no token parameter, and consistent fixed-window values/defaults.'
