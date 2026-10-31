<#
.SYNOPSIS
  Builds a reproducible .pbit from the pinned Desktop export and editable template/source.
.DESCRIPTION
  The original template/Login Enterprise.pbit is preserved as a compatibility reference. The default input is the privacy-checked Desktop PBIR export pinned by source/desktop-base.json. The candidate patches:
    * DataModelSchema: additive tables (source/new-tables.json), measure expressions/new measures from source/measures/**.dax M partitions from source/partitions/*.m, and date help from source/parameter-descriptions.json
    * Report/Layout: exact-string renames from source/layout-renames.json (counts asserted)
    * PBIR visuals: exact-string edits from source/pbir-edits.json (counts asserted; no visual is added or removed)
    * UnappliedChanges: M, lineage and help synchronized with DataModelSchema
  Everything else (relationships, columns, pages, visual layout, resources, Settings, ...) is copied byte-for-byte. SecurityBindings is dropped when PBIR visuals are edited (the binding covers the report content; Desktop reports an edited package that keeps it as corrupted).
  The Desktop base was loaded/refreshed and exported by Desktop. Source changes still require the affected acceptance checks in docs/ACCEPTANCE.md.
#>
[CmdletBinding()]
param(
    [string]$Original = (Join-Path $PSScriptRoot 'base/Login Enterprise Desktop 2026-10.pbit'),
    [string]$SourceDir = (Join-Path $PSScriptRoot 'source'),
    [string]$Output = (Join-Path $PSScriptRoot 'candidate/Login Enterprise 1.2.0.0-candidate.pbit'),
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
$baseManifest = Join-Path $SourceDir 'desktop-base.json'
if ([IO.Path]::GetFullPath($Original) -eq [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'base/Login Enterprise Desktop 2026-10.pbit'))) {
    $manifest = Get-Content -LiteralPath $baseManifest -Raw | ConvertFrom-Json
    if ((Get-FileHash -LiteralPath $Original).Hash -ne $manifest.sha256) { throw 'Desktop base checksum mismatch.' }
}

$model = Read-PbitModel $Original
$tables = @{}
foreach ($t in $model['model']['tables']) { $tables[[string]$t['name']] = $t }

# ---- additive tables (1.2.0.0): new table, M partition placeholder, relationship ------------------------
$newTables = @()
$newTablesPath = Join-Path $SourceDir 'new-tables.json'
if (Test-Path -LiteralPath $newTablesPath) {
    foreach ($spec in (Get-Content -LiteralPath $newTablesPath -Raw | ConvertFrom-Json).tables) {
        if ($tables.ContainsKey($spec.name)) { throw "Table already exists in the base: $($spec.name)" }
        $columns = [System.Text.Json.Nodes.JsonArray]::new()
        foreach ($c in $spec.columns) {
            $col = [System.Text.Json.Nodes.JsonObject]::new()
            Set-JsonProp $col 'name' $c.name; Set-JsonProp $col 'dataType' $c.dataType; Set-JsonProp $col 'sourceColumn' $c.name
            if ($c.formatString) { Set-JsonProp $col 'formatString' $c.formatString }
            Set-JsonProp $col 'lineageTag' (New-DeterministicGuid "$($spec.name)|col|$($c.name)")
            Set-JsonProp $col 'summarizeBy' $c.summarizeBy
            $a = [System.Text.Json.Nodes.JsonObject]::new(); Set-JsonProp $a 'name' 'SummarizationSetBy'; Set-JsonProp $a 'value' 'Automatic'
            $aa = [System.Text.Json.Nodes.JsonArray]::new(); [void]$aa.Add([JsonNode]$a); Set-JsonProp $col 'annotations' $aa
            [void]$columns.Add([JsonNode]$col)
        }
        $partition = [System.Text.Json.Nodes.JsonObject]::new(); Set-JsonProp $partition 'name' $spec.name; Set-JsonProp $partition 'mode' 'import'
        $source = [System.Text.Json.Nodes.JsonObject]::new(); Set-JsonProp $source 'type' 'm'; Set-JsonProp $source 'expression' (Split-ToJsonArray 'let')
        Set-JsonProp $partition 'source' $source
        $partitions = [System.Text.Json.Nodes.JsonArray]::new(); [void]$partitions.Add([JsonNode]$partition)
        $table = [System.Text.Json.Nodes.JsonObject]::new()
        Set-JsonProp $table 'name' $spec.name
        if ($spec.description) { Set-JsonProp $table 'description' $spec.description }
        Set-JsonProp $table 'lineageTag' (New-DeterministicGuid "$($spec.name)|table")
        Set-JsonProp $table 'columns' $columns; Set-JsonProp $table 'partitions' $partitions
        Set-JsonProp $table 'measures' ([System.Text.Json.Nodes.JsonArray]::new())
        [void]$model['model']['tables'].Add([JsonNode]$table); $tables[$spec.name] = $table
        $rel = [System.Text.Json.Nodes.JsonObject]::new()
        Set-JsonProp $rel 'name' (New-DeterministicGuid "$($spec.name)|relationship|$($spec.relationship.toTable)")
        Set-JsonProp $rel 'fromTable' $spec.name; Set-JsonProp $rel 'fromColumn' $spec.relationship.fromColumn
        Set-JsonProp $rel 'toTable' $spec.relationship.toTable; Set-JsonProp $rel 'toColumn' $spec.relationship.toColumn
        [void]$model['model']['relationships'].Add([JsonNode]$rel)
        foreach ($annotation in $model['model']['annotations']) {
            if ([string]$annotation['name'] -ceq 'PBI_QueryOrder') {
                $order = @(([string]$annotation['value'] | ConvertFrom-Json)) + $spec.name
                Set-JsonProp $annotation 'value' (ConvertTo-Json -InputObject $order -Compress)
            }
        }
        $newTables += $spec.name
    }
}

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
$ann = @($model['model']['annotations'] | Where-Object { [string]$_['name'] -eq 'LE-PBI-Connector.TemplateCandidate' })
if ($ann.Count -gt 1) { throw 'Duplicate candidate annotation.' }
if ($ann.Count -eq 0) {
    $node = [System.Text.Json.Nodes.JsonObject]::new(); Set-JsonProp $node 'name' 'LE-PBI-Connector.TemplateCandidate'
    [void]$model['model']['annotations'].Add([JsonNode]$node); $ann = @($node)
}
Set-JsonProp $ann[0] 'value' '1.2.0.0-candidate (Desktop round-trip base; editable sources applied; Desktop acceptance of the additions pending; see ACCEPTANCE.md)'

$opts = [System.Text.Json.JsonSerializerOptions]::new(); $opts.WriteIndented = $true
$opts.Encoder = [System.Text.Encodings.Web.JavaScriptEncoder]::UnsafeRelaxedJsonEscaping
$modelJson = $model.ToJsonString($opts)
$persisted = [JsonNode]::Parse((ConvertFrom-Utf16Bytes (Read-ZipEntryBytes $Original 'UnappliedChanges')))
foreach ($name in $newTables) {
    $prototype = @($persisted['queries'] | Where-Object { [string]$_['name'] -ceq 'Aggregated EUX Results' })
    if ($prototype.Count -ne 1) { throw 'Persisted-query prototype not found.' }
    $query = $prototype[0].DeepClone()
    Set-JsonProp $query 'name' $name; Set-JsonProp $query 'lineageTag' ([string]$tables[$name]['lineageTag'])
    [void]$persisted['queries'].Add([JsonNode]$query)
}
Sync-PersistedQueries $model $persisted

# ---- layout ----------------------------------------------------------------
$container = [IO.Compression.ZipFile]::OpenRead($Original)
try { $legacyLayout = $null -ne $container.GetEntry('Report/Layout'); $pbir = $null -ne $container.GetEntry('Report/definition/report.json') } finally { $container.Dispose() }
if ($legacyLayout) {
    $layout = ConvertFrom-Utf16Bytes (Read-ZipEntryBytes $Original 'Report/Layout')
    foreach ($r in (Get-Content (Join-Path $SourceDir 'layout-renames.json') -Raw | ConvertFrom-Json)) {
        $count = ([regex]::Matches($layout, [regex]::Escape($r.old))).Count
        if ($count -ne $r.expected) { throw "Layout rename '$($r.old)' matched $count times, expected $($r.expected)" }
        $layout = $layout.Replace($r.old, $r.new)
    }
} elseif (-not $pbir) { throw 'Template has neither a legacy layout nor PBIR definitions.' }

# ---- PBIR visual edits (exact strings, counts asserted) -------------------------------------------
$pbirEdits = @{}
$pbirEditsPath = Join-Path $SourceDir 'pbir-edits.json'
if ($pbir -and (Test-Path -LiteralPath $pbirEditsPath)) {
    foreach ($edit in (Get-Content -LiteralPath $pbirEditsPath -Raw | ConvertFrom-Json)) {
        if (-not $pbirEdits.ContainsKey($edit.entry)) {
            $bytes = Read-ZipEntryBytes $Original $edit.entry
            $pbirEdits[$edit.entry] = @{ bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF); text = [Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF) }
        }
        $text = $pbirEdits[$edit.entry].text
        $count = ([regex]::Matches($text, [regex]::Escape($edit.old))).Count
        if ($count -ne $edit.expected) { throw "PBIR edit '$($edit.purpose)' matched $count times, expected $($edit.expected)" }
        $pbirEdits[$edit.entry].text = $text.Replace($edit.old, $edit.new)
    }
}

# ---- write package -----------------------------------------------------------
$origBytesModel = Read-ZipEntryBytes $Original 'DataModelSchema'
$hasBom = ($origBytesModel[0] -eq 0xFF -and $origBytesModel[1] -eq 0xFE)
function To-Utf16([string]$s) { $b = [Text.Encoding]::Unicode.GetBytes($s); if ($hasBom) { return ,([byte[]](0xFF, 0xFE) + $b) } else { return ,$b } }
$replacements = @{ 'DataModelSchema' = (To-Utf16 $modelJson); 'UnappliedChanges' = (To-Utf16 $persisted.ToJsonString($opts)) }
if ($legacyLayout) { $replacements['Report/Layout'] = To-Utf16 $layout }
foreach ($entry in $pbirEdits.Keys) {
    $b = [Text.Encoding]::UTF8.GetBytes($pbirEdits[$entry].text)
    $replacements[$entry] = if ($pbirEdits[$entry].bom) { ,([byte[]](0xEF, 0xBB, 0xBF) + $b) } else { ,$b }
}

New-Item -ItemType Directory -Force (Split-Path -Parent $Output) | Out-Null
if (Test-Path $Output) { Remove-Item $Output -Force }
$src = [IO.Compression.ZipFile]::OpenRead($Original)
$dst = [IO.Compression.ZipFile]::Open($Output, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($e in $src.Entries) {
        # SecurityBindings binds the original report content; Desktop rejects the package as corrupted when report
        # files are edited and the binding is kept (observed on Desktop 2.159, 2026-10-30). Drop it only in that case.
        if ($e.FullName -eq 'SecurityBindings' -and $pbirEdits.Count -gt 0) { continue }
        $ne = $dst.CreateEntry($e.FullName, [IO.Compression.CompressionLevel]::NoCompression)
        $ne.LastWriteTime = $e.LastWriteTime
        $os = $ne.Open()
        if ($replacements.ContainsKey($e.FullName)) { $b = $replacements[$e.FullName]; $os.Write($b, 0, $b.Length) }
        else { $is = $e.Open(); $is.CopyTo($os); $is.Dispose() }
        $os.Dispose()
    }
} finally { $dst.Dispose(); $src.Dispose() }
Write-Host "Candidate written: $Output"
Write-Host "  measures changed=$changed added=$added; new tables=$($newTables.Count); partitions changed=$partChanged; report format=$(if($legacyLayout){'legacy'}else{'PBIR'})"
Write-Host "  size $((Get-Item $Output).Length) bytes (original $((Get-Item $Original).Length))"
