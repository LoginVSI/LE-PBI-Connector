# Prepare a separate credential-free Key copy; never modifies an existing report.
[CmdletBinding()]
param(
    [string]$Candidate = (Join-Path $PSScriptRoot '../candidate/Login Enterprise 1.1.0.2-candidate.pbit'),
    [Parameter(Mandatory)][string]$Output,
    [string]$StartDate,
    [string]$EndDate
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../TemplateCommon.ps1')
if (Test-Path -LiteralPath $Output) { throw 'Output exists; preserve the existing working copy and choose another path.' }
$model = Read-PbitModel $Candidate
$persisted = [System.Text.Json.Nodes.JsonNode]::Parse((ConvertFrom-Utf16Bytes (Read-ZipEntryBytes $Candidate 'UnappliedChanges')))
$calls = 0
foreach ($table in $model['model']['tables']) {
    foreach ($partition in $table['partitions']) {
        if ([string]$partition['source']['type'] -ne 'm') { continue }
        $text = Normalize-QueryText $partition['source']['expression']
        $old = 'LoginEnterprise_PBI.Contents(FQDN, APIToken, DaysBack, UseDateRange, StartDateParam, EndDateParam)'
        $calls += [regex]::Matches($text, [regex]::Escape($old)).Count
        Set-JsonProp $partition['source'] 'expression' (Split-ToJsonArray $text.Replace($old, 'LoginEnterprise_PBI.ContentsKey(FQDN, DaysBack, UseDateRange, StartDateParam, EndDateParam)'))
    }
}
if ($calls -ne 12) { throw 'Unexpected connector call count; refusing partial migration.' }
$token = @($model['model']['expressions'] | Where-Object { [string]$_['name'] -eq 'APIToken' })
if ($token.Count -ne 1) { throw 'Expected one token parameter.' }
$removedTag = [string]$token[0]['lineageTag']; [void]$model['model']['expressions'].Remove($token[0])
foreach ($annotation in $model['model']['annotations']) {
    if ([string]$annotation['name'] -eq 'PBI_QueryOrder') {
        $order = @(([string]$annotation['value'] | ConvertFrom-Json) | Where-Object { $_ -ne 'APIToken' })
        Set-JsonProp $annotation 'value' (ConvertTo-Json -InputObject $order -Compress)
    }
}
if ($StartDate -or $EndDate) {
    $start = [datetime]::ParseExact($StartDate, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture)
    $end = [datetime]::ParseExact($EndDate, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture)
    if ($end -lt $start) { throw 'Reversed acceptance date range.' }
    $values = @{ DaysBack = '7'; UseDateRange = 'true'; StartDateParam = "#date($($start.Year), $($start.Month), $($start.Day))"; EndDateParam = "#date($($end.Year), $($end.Month), $($end.Day))" }
    foreach ($expression in $model['model']['expressions']) {
        $name = [string]$expression['name']
        if ($values.ContainsKey($name)) {
            $parts = (Join-Lines $expression['expression']) -split ' meta ', 2
            if ($parts.Count -ne 2) { throw 'Unexpected parameter expression.' }
            Set-JsonProp $expression 'expression' ($values[$name] + ' meta ' + $parts[1])
        }
    }
}
Sync-PersistedQueries $model $persisted -RemovedQueryNames @('APIToken')
$opts = [System.Text.Json.JsonSerializerOptions]::new(); $opts.WriteIndented = $true
$opts.Encoder = [System.Text.Encodings.Web.JavaScriptEncoder]::UnsafeRelaxedJsonEscaping
$modelText = $model.ToJsonString($opts); $persistedText = $persisted.ToJsonString($opts)
if (($modelText + $persistedText).Contains('APIToken') -or ($modelText + $persistedText).Contains($removedTag)) { throw 'Stale token parameter metadata remains.' }
$replacements = @{ DataModelSchema = [Text.Encoding]::Unicode.GetBytes($modelText); UnappliedChanges = [Text.Encoding]::Unicode.GetBytes($persistedText) }
New-Item -ItemType Directory -Force (Split-Path -Parent $Output) | Out-Null
$src = [IO.Compression.ZipFile]::OpenRead($Candidate)
$dst = [IO.Compression.ZipFile]::Open($Output, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($entry in $src.Entries) {
        $next = $dst.CreateEntry($entry.FullName, [IO.Compression.CompressionLevel]::NoCompression); $next.LastWriteTime = $entry.LastWriteTime; $stream = $next.Open()
        try {
            if ($replacements.ContainsKey($entry.FullName)) { $bytes = $replacements[$entry.FullName]; $stream.Write($bytes, 0, $bytes.Length) }
            else { $inputStream = $entry.Open(); try { $inputStream.CopyTo($stream) } finally { $inputStream.Dispose() } }
        } finally { $stream.Dispose() }
    }
} finally { $dst.Dispose(); $src.Dispose() }
Write-Host 'Prepared separate Key copy: 12 migrated calls; no token parameter or orphan persisted query.'
