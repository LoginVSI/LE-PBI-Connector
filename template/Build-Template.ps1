<#
.SYNOPSIS
  Builds a CANDIDATE .pbit from the original binary plus the reviewed text source in template/source.
.DESCRIPTION
  The original template/Login Enterprise.pbit is never modified. The candidate patches only:
    * DataModelSchema: measure expressions/new measures from source/measures/**.dax M partitions from source/partitions/*.m, and date help from source/parameter-descriptions.json
    * Report/Layout: exact-string renames from source/layout-renames.json (counts asserted)
    * UnappliedChanges: M, lineage and help synchronized with DataModelSchema
  Everything else (relationships, columns, pages, visual layout, resources, SecurityBindings, Settings, ...) is copied byte-for-byte.
  This is a structurally derived file, NOT a Desktop-validated one. Open it in Power BI Desktop, check, and re-save
  (see docs/ACCEPTANCE.md); then re-baseline with Export-TemplateSource.ps1.
#>
[CmdletBinding()]
param(
    [string]$Original = (Join-Path $PSScriptRoot 'Login Enterprise.pbit'),
    [string]$SourceDir = (Join-Path $PSScriptRoot 'source'),
    [string]$Output = (Join-Path $PSScriptRoot 'candidate/Login Enterprise 1.1.0.2-candidate.pbit'),
    [switch]$Check
)
$ErrorActionPreference = 'Stop'
if ($Check) {
    $scratch = Join-Path ([IO.Path]::GetTempPath()) ('le-template-' + [guid]::NewGuid().ToString('N') + '.pbit')
    try {
        & $PSCommandPath -Original $Original -SourceDir $SourceDir -Output $scratch
        if ((Get-FileHash -LiteralPath $scratch).Hash -ne (Get-FileHash -LiteralPath $Output).Hash) {
            throw 'Staged template differs from editable sources. Rebuild and commit the candidate.'
        }
        Write-Host 'OK: staged template matches source rebuild byte-for-byte'
    } finally { if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Force } }
    return
}
. (Join-Path $PSScriptRoot 'TemplateCommon.ps1')
Add-Type -AssemblyName System.IO.Compression

$model = Read-PbitModel $Original
$tables = @{}
foreach ($t in $model['model']['tables']) { $tables[[string]$t['name']] = $t }

# ---- measures -------------------------------------------------------------
$changed = 0; $added = 0
foreach ($f in Get-ChildItem (Join-Path $SourceDir 'measures') -Recurse -Filter *.dax | Sort-Object FullName) {
    $m = Read-MeasureFile $f.FullName
    if (-not $m['table'] -or -not $m['name']) { throw "Missing header in $($f.FullName)" }
    if (-not $tables.ContainsKey($m['table'])) { throw "Unknown table '$($m['table'])' in $($f.Name)" }
    $t = $tables[$m['table']]
    $existing = $null
    foreach ($x in $t['measures']) { if ([string]$x['name'] -eq $m['name']) { $existing = $x; break } }
    if ($existing) {
        $cur = (Join-Lines $existing['expression']).Trim("`n")
        if ($cur -ne $m['expression']) {
            Set-JsonProp $existing 'expression' (Split-ToJsonArray $m['expression']); $changed++
        }
        if ($m['description'] -and -not ($existing['description'] -and [string]$existing['description'] -eq $m['description'])) {
            Set-JsonProp $existing 'description' $m['description']
        }
    } else {
        $o = [System.Text.Json.Nodes.JsonObject]::new()
        Set-JsonProp $o 'name' $m['name']
        Set-JsonProp $o 'expression' (Split-ToJsonArray $m['expression'])
        if ($m['format']) { Set-JsonProp $o 'formatString' $m['format'] }
        if ($m['description']) { Set-JsonProp $o 'description' $m['description'] }
        Set-JsonProp $o 'lineageTag' (New-DeterministicGuid "$($m['table'])|$($m['name'])")
        [void]$t['measures'].Add([JsonNode]$o); $added++
    }
}

# ---- date parameter help (metadata only; identities and Date expressions stay intact) ----
$descriptionPath = Join-Path $SourceDir 'parameter-descriptions.json'
if (Test-Path -LiteralPath $descriptionPath) {
    $descriptions = [JsonNode]::Parse([IO.File]::ReadAllText($descriptionPath))
    foreach ($item in $descriptions) {
        if ($item.Key -cnotin @('StartDateParam', 'EndDateParam')) { throw "Unexpected parameter description: $($item.Key)" }
        $parameterMatches = @($model['model']['expressions'] | Where-Object { [string]$_['name'] -ceq $item.Key })
        if ($parameterMatches.Count -ne 1) { throw "Parameter not uniquely defined: $($item.Key)" }
        if ($parameterMatches[0]['description'].ToJsonString() -ne $item.Value.ToJsonString()) {
            Set-JsonProp $parameterMatches[0] 'description' $item.Value.DeepClone()
        }
    }
}

# ---- partitions -----------------------------------------------------------
$partChanged = 0
foreach ($f in Get-ChildItem (Join-Path $SourceDir 'partitions') -Filter *.m) {
    $tn = [IO.Path]::GetFileNameWithoutExtension($f.Name)
    if (-not $tables.ContainsKey($tn)) { throw "Unknown table for partition $($f.Name)" }
    foreach ($p in $tables[$tn]['partitions']) {
        if ($p['source']['type'].ToString() -eq 'm') {
            $new = ([IO.File]::ReadAllText($f.FullName) -replace "`r`n", "`n").TrimEnd("`n")
            if ((Join-Lines $p['source']['expression']).TrimEnd("`n") -ne $new) { Set-JsonProp $p['source'] 'expression' (Split-ToJsonArray $new); $partChanged++ }
        }
    }
}
$ann = [System.Text.Json.Nodes.JsonObject]::new(); Set-JsonProp $ann 'name' 'LE-PBI-Connector.TemplateCandidate'; Set-JsonProp $ann 'value' '1.1.0.2-candidate (structurally derived; not Desktop-validated)'
[void]$model['model']['annotations'].Add([JsonNode]$ann)

$opts = [System.Text.Json.JsonSerializerOptions]::new(); $opts.WriteIndented = $true
$opts.Encoder = [System.Text.Encodings.Web.JavaScriptEncoder]::UnsafeRelaxedJsonEscaping
$modelJson = $model.ToJsonString($opts)
$persisted = [JsonNode]::Parse((ConvertFrom-Utf16Bytes (Read-ZipEntryBytes $Original 'UnappliedChanges')))
Sync-PersistedQueries $model $persisted

# ---- layout ----------------------------------------------------------------
$layout = ConvertFrom-Utf16Bytes (Read-ZipEntryBytes $Original 'Report/Layout')
foreach ($r in (Get-Content (Join-Path $SourceDir 'layout-renames.json') -Raw | ConvertFrom-Json)) {
    $count = ([regex]::Matches($layout, [regex]::Escape($r.old))).Count
    if ($count -ne $r.expected) { throw "Layout rename '$($r.old)' matched $count times, expected $($r.expected)" }
    $layout = $layout.Replace($r.old, $r.new)
}

# ---- write package -----------------------------------------------------------
$origBytesModel = Read-ZipEntryBytes $Original 'DataModelSchema'
$hasBom = ($origBytesModel[0] -eq 0xFF -and $origBytesModel[1] -eq 0xFE)
function To-Utf16([string]$s) { $b = [Text.Encoding]::Unicode.GetBytes($s); if ($hasBom) { return ,([byte[]](0xFF, 0xFE) + $b) } else { return ,$b } }
$replacements = @{ 'DataModelSchema' = (To-Utf16 $modelJson); 'Report/Layout' = (To-Utf16 $layout); 'UnappliedChanges' = (To-Utf16 $persisted.ToJsonString($opts)) }

New-Item -ItemType Directory -Force (Split-Path -Parent $Output) | Out-Null
if (Test-Path $Output) { Remove-Item $Output -Force }
$src = [IO.Compression.ZipFile]::OpenRead($Original)
$dst = [IO.Compression.ZipFile]::Open($Output, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($e in $src.Entries) {
        $ne = $dst.CreateEntry($e.FullName, [IO.Compression.CompressionLevel]::NoCompression)
        $ne.LastWriteTime = $e.LastWriteTime
        $os = $ne.Open()
        if ($replacements.ContainsKey($e.FullName)) { $b = $replacements[$e.FullName]; $os.Write($b, 0, $b.Length) }
        else { $is = $e.Open(); $is.CopyTo($os); $is.Dispose() }
        $os.Dispose()
    }
} finally { $dst.Dispose(); $src.Dispose() }
Write-Host "Candidate written: $Output"
Write-Host "  measures changed=$changed added=$added; partitions changed=$partChanged; layout renames applied"
Write-Host "  size $((Get-Item $Output).Length) bytes (original $((Get-Item $Original).Length))"
