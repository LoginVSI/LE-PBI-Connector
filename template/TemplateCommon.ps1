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
    if ($expr -is [JsonArray]) { return (($expr | ForEach-Object { $_.GetValue[string]() }) -join "`n") }
    return $expr.GetValue[string]()
}
function Split-ToJsonArray([string]$text) {
    $arr = [JsonArray]::new()
    foreach ($l in ($text.TrimEnd("`n") -split "`n")) { $arr.Add($l) }
    return $arr
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
