# Shared helpers for template export/build/validate scripts.
using namespace System.Text.Json.Nodes
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Read-ZipEntryBytes([string]$zipPath, [string]$entry) {
    $z = [IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        $e = $z.GetEntry($entry); if (-not $e) { throw "Entry not found: $entry" }
        $s = $e.Open(); $ms = New-Object IO.MemoryStream; $s.CopyTo($ms); $s.Dispose()
        return ,$ms.ToArray()
    } finally { $z.Dispose() }
}
# PBIT model/report parts are UTF-16 LE (with BOM). Returns text without the BOM.
function ConvertFrom-Utf16Bytes([byte[]]$b) { [Text.Encoding]::Unicode.GetString($b).TrimStart([char]0xFEFF) }
function Read-PbitModel([string]$pbit) {
    return ,[JsonNode]::Parse((ConvertFrom-Utf16Bytes (Read-ZipEntryBytes $pbit 'DataModelSchema')))
}
function Join-Lines($expr) {
    if ($null -eq $expr) { return '' }
    if ($expr -is [JsonArray]) { return (($expr | ForEach-Object { $_.GetValue[string]() }) -join "`n") }
    return $expr.GetValue[string]()
}
function Split-ToJsonArray([string]$text) {
    $arr = [JsonArray]::new()
    foreach ($l in ($text.TrimEnd("`n") -split "`n")) { $arr.Add([JsonNode][JsonValue]::Create([string]$l)) }
    return ,$arr
}
function Write-LfFile([string]$path, [string]$text) {
    New-Item -ItemType Directory -Force (Split-Path -Parent $path) | Out-Null
    [IO.File]::WriteAllText($path, ($text -replace "`r`n", "`n"), (New-Object Text.UTF8Encoding($false)))
}
# Parses a measure .dax source file: leading "-- key: value" header lines, then the expression.
function Read-MeasureFile([string]$path) {
    $lines = [IO.File]::ReadAllText($path) -replace "`r`n", "`n" -split "`n"
    $h = @{}; $i = 0
    while ($i -lt $lines.Count -and $lines[$i] -match '^-- (table|name|format|description): ?(.*)$') { $h[$Matches[1]] = $Matches[2]; $i++ }
    $h['expression'] = ($lines[$i..($lines.Count - 1)] -join "`n").Trim("`n")
    return $h
}
function New-DeterministicGuid([string]$seed) {
    $md5 = [Security.Cryptography.MD5]::Create()
    $b = $md5.ComputeHash([Text.Encoding]::UTF8.GetBytes($seed))
    return ([guid]::new($b)).ToString()
}
# JsonObject property setter that works from PowerShell (string values are wrapped as JsonValue).
function Set-JsonProp($obj, [string]$name, $value) {
    if ($value -is [string]) { $value = [JsonValue]::Create([string]$value) }
    [void]$obj.Remove($name)
    $obj.Add($name, [JsonNode]$value)
}

# Desktop restores query metadata from UnappliedChanges as well as DataModelSchema.
# Keep the two representations consistent without logging expressions or parameter values.
function Get-ModelQueryMap($model) {
    $map = @{}
    foreach ($table in $model['model']['tables']) {
        $parts = @($table['partitions'] | Where-Object { [string]$_['source']['type'] -eq 'm' })
        if ($parts.Count -gt 1) { throw 'Multiple M partitions are not supported by this template builder.' }
        if ($parts.Count -eq 1) {
            $map[[string]$table['name']] = @{ owner = $table; expression = $parts[0]['source']['expression'] }
        }
    }
    foreach ($expression in $model['model']['expressions']) {
        $map[[string]$expression['name']] = @{ owner = $expression; expression = $expression['expression'] }
    }
    return $map
}
function Normalize-QueryText($expression) { return ((Join-Lines $expression) -replace "`r`n", "`n").TrimEnd("`n") }
function Get-PersistedQueryProblems($model, $persisted) {
    $map = Get-ModelQueryMap $model
    $issues = [Collections.Generic.List[string]]::new(); $seen = @{}
    foreach ($query in $persisted['queries']) {
        $name = [string]$query['name']
        if ($seen.ContainsKey($name)) { $issues.Add("Duplicate persisted query: $name"); continue }
        $seen[$name] = $true
        if (-not $map.ContainsKey($name)) { $issues.Add("Persisted query has no model owner: $name"); continue }
        $item = $map[$name]
        if ([string]$query['lineageTag'] -cne [string]$item.owner['lineageTag']) { $issues.Add("Persisted lineage differs: $name") }
        $expected = Normalize-QueryText $item.expression
        if ((Normalize-QueryText $query['text']) -cne $expected) { $issues.Add("Persisted M differs: $name") }
        if ($query.ContainsKey('lastLoadedAsTableFormulaText')) {
            try {
                $loaded = [JsonNode]::Parse([string]$query['lastLoadedAsTableFormulaText'])
                if ($loaded -isnot [JsonObject] -or $null -eq $loaded['RootFormulaText'] -or $loaded['ReferencedQueriesFormulaText'] -isnot [JsonObject]) { throw 'Invalid nested formula schema.' }
                [void]$loaded['RootFormulaText'].GetValue[string]()
                [void]$loaded['IncludesReferencedQueries'].GetValue[bool]()
                if ((Normalize-QueryText $loaded['RootFormulaText']) -cne $expected) { $issues.Add("Persisted loaded M differs: $name") }
            } catch { $issues.Add("Persisted loaded JSON invalid: $name") }
        }
        if ($null -ne $item.owner['description'] -and (Join-Lines $query['description']) -cne (Join-Lines $item.owner['description'])) { $issues.Add("Persisted description differs: $name") }
    }
    foreach ($name in $map.Keys) { if (-not $seen.ContainsKey($name)) { $issues.Add("Model query missing persisted metadata: $name") } }
    return $issues.ToArray()
}
function Sync-PersistedQueries($model, $persisted, [string[]]$RemovedQueryNames = @()) {
    $map = Get-ModelQueryMap $model
    foreach ($query in @($persisted['queries'])) {
        $name = [string]$query['name']
        if (-not $map.ContainsKey($name)) {
            if ($name -cnotin $RemovedQueryNames) { throw "Unexpected orphan persisted query: $name" }
            [void]$persisted['queries'].Remove($query); continue
        }
        $item = $map[$name]; $text = Normalize-QueryText $item.expression
        if ([string]$query['lineageTag'] -cne [string]$item.owner['lineageTag']) { throw "Unexpected lineage change: $name" }
        Set-JsonProp $query 'text' (Split-ToJsonArray $text)
        if ($query.ContainsKey('lastLoadedAsTableFormulaText')) {
            $loaded = [JsonNode]::Parse([string]$query['lastLoadedAsTableFormulaText'])
            if ($loaded -isnot [JsonObject] -or $null -eq $loaded['RootFormulaText'] -or $loaded['ReferencedQueriesFormulaText'] -isnot [JsonObject]) { throw "Invalid nested loaded-query metadata: $name" }
            [void]$loaded['RootFormulaText'].GetValue[string]()
            [void]$loaded['IncludesReferencedQueries'].GetValue[bool]()
            Set-JsonProp $loaded 'RootFormulaText' $text
            Set-JsonProp $query 'lastLoadedAsTableFormulaText' $loaded.ToJsonString()
        }
        if ($null -ne $item.owner['description']) { Set-JsonProp $query 'description' (Join-Lines $item.owner['description']) }
    }
    $issues = @(Get-PersistedQueryProblems $model $persisted)
    if ($issues.Count) { throw ($issues -join '; ') }
}
