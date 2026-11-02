# Metadata regressions, not Desktop or DAX acceptance.
[CmdletBinding()]
param([string]$Candidate = (Join-Path $PSScriptRoot 'candidate/Login Enterprise 1.2.0.0-candidate.pbit'))
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'TemplateCommon.ps1')
$model = Read-PbitModel $Candidate
$persisted = [System.Text.Json.Nodes.JsonNode]::Parse((ConvertFrom-Utf16Bytes (Read-ZipEntryBytes $Candidate 'UnappliedChanges')))
if (@(Get-PersistedQueryProblems $model $persisted).Count) { throw 'Baseline persisted metadata is inconsistent.' }
function Expect-Problem($m, $p, [string]$pattern) {
    if (-not (@(Get-PersistedQueryProblems $m $p) -match $pattern)) { throw "Metadata regression was not detected: $pattern" }
}
$bad = $persisted.DeepClone(); Set-JsonProp $bad['queries'][0] 'lineageTag' '00000000-0000-0000-0000-000000000001'
Expect-Problem $model $bad '^Persisted lineage differs:'
$bad = $persisted.DeepClone(); Set-JsonProp $bad['queries'][0] 'text' (Split-ToJsonArray 'error "stale persisted query"')
Expect-Problem $model $bad '^Persisted M differs:'
$bad = $persisted.DeepClone(); Set-JsonProp $bad['queries'][0] 'lastLoadedAsTableFormulaText' 'let x = 1 in x'
Expect-Problem $model $bad '^Persisted loaded JSON invalid:'
$bad = $persisted.DeepClone(); $loaded = [System.Text.Json.Nodes.JsonNode]::Parse([string]$bad['queries'][0]['lastLoadedAsTableFormulaText'])
Set-JsonProp $loaded 'RootFormulaText' 'error "stale loaded query"'; Set-JsonProp $bad['queries'][0] 'lastLoadedAsTableFormulaText' $loaded.ToJsonString()
Expect-Problem $model $bad '^Persisted loaded M differs:'
$bad = $persisted.DeepClone(); $date = @($bad['queries'] | Where-Object { [string]$_['name'] -eq 'EndDateParam' })[0]
Set-JsonProp $date 'description' 'stale date help'
Expect-Problem $model $bad '^Persisted description differs: EndDateParam$'
$removed = $model.DeepClone(); $token = @($removed['model']['expressions'] | Where-Object { [string]$_['name'] -eq 'APIToken' })[0]
[void]$removed['model']['expressions'].Remove($token)
Expect-Problem $removed $persisted '^Persisted query has no model owner: APIToken$'
$fixed = $persisted.DeepClone(); Sync-PersistedQueries $removed $fixed -RemovedQueryNames @('APIToken')
if (@(Get-PersistedQueryProblems $removed $fixed).Count -or @($fixed['queries'] | Where-Object { [string]$_['name'] -eq 'APIToken' }).Count) { throw 'Removed parameter still has persisted metadata.' }
Write-Host 'PASS: 7 persisted-query regressions (lineage, M, nested JSON, loaded M, help, orphan detection, explicit removal)'
