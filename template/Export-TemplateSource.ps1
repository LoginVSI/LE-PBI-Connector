<#
.SYNOPSIS
  Exports the editable text source (DAX measures, M partitions) of a .pbit so changes can be reviewed in git.
.DESCRIPTION
  Writes template/source/measures/<Table>/<Measure>.dax and template/source/partitions/<Table>.m.
  Run against the ORIGINAL binary to create the baseline, or against a Desktop-saved .pbit at acceptance to
  re-baseline the source from what Desktop actually produced.
#>
[CmdletBinding()]
param(
    [string]$Pbit = (Join-Path $PSScriptRoot 'Login Enterprise.pbit'),
    [string]$OutDir = (Join-Path $PSScriptRoot 'source')
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
. (Join-Path $PSScriptRoot 'TemplateCommon.ps1')

$model = Read-PbitModel $Pbit
function Safe([string]$n) { ($n -replace '[\/:*?"<>|]', '_').Trim() }
$exportRoot = [IO.Path]::GetFullPath($OutDir).TrimEnd([IO.Path]::DirectorySeparatorChar)
foreach ($d in 'measures', 'partitions') {
    $p = [IO.Path]::GetFullPath((Join-Path $exportRoot $d))
    if (-not $p.StartsWith($exportRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Export cleanup escaped the named output directory.' }
    if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force }
    New-Item -ItemType Directory -Force $p | Out-Null
}

foreach ($t in $model['model']['tables']) {
    $tn = [string]$t['name']
    if ($tn -like 'LocalDateTable*' -or $tn -like 'DateTableTemplate*') { continue }
    foreach ($part in @($t['partitions'])) {
        if ($part['source']['type'].ToString() -eq 'm') {
            $text = Join-Lines $part['source']['expression']
            Write-LfFile (Join-Path $OutDir "partitions/$(Safe $tn).m") $text
        }
    }
    if ($t['measures']) {
        $dir = Join-Path $OutDir "measures/$(Safe $tn)"; New-Item -ItemType Directory -Force $dir | Out-Null
        foreach ($m in $t['measures']) {
            $format = if ($m['formatString']) { ' ' + [string]$m['formatString'] } else { '' }
            $description = if ($m['description']) { ' ' + (Join-Lines $m['description']) } else { '' }
            $hdr = "-- table: $tn`n-- name: $($m['name'])`n-- format:$format`n-- description:$description`n"
            Write-LfFile (Join-Path $dir "$(Safe ([string]$m['name'])).dax") ($hdr + (Join-Lines $m['expression']).Trim("`n") + "`n")
        }
    }
}
# Export only date descriptions; never export parameter values or credentials here.
$descriptions = [JsonObject]::new()
foreach ($name in @('StartDateParam', 'EndDateParam')) {
    $parameterMatches = @($model['model']['expressions'] | Where-Object { [string]$_['name'] -ceq $name })
    if ($parameterMatches.Count -ne 1) { throw "Parameter not uniquely defined: $name" }
    $descriptions.Add($name, $parameterMatches[0]['description'].DeepClone())
}
$opts = [System.Text.Json.JsonSerializerOptions]::new(); $opts.WriteIndented = $true
Write-LfFile (Join-Path $OutDir 'parameter-descriptions.json') ($descriptions.ToJsonString($opts) + "`n")
Write-Host "Exported to $OutDir"
