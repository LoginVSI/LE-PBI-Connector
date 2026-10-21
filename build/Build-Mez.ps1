<#
.SYNOPSIS
  Builds the Login Enterprise Power BI connector (.mez) deterministically from source.
.DESCRIPTION
  A .mez is a ZIP. This script writes entries in a fixed order with a fixed timestamp and no compression
  (stored), so identical source always produces a byte-identical package on any OS / .NET version.
  The file list is read from LoginEnterprise_PBI.proj (single source of truth).
.PARAMETER Output   Package path. Default: bin/AnyCPU/Debug/LE-PBI-Connector.mez (the canonical shipped path).
.PARAMETER Test     Builds a TEST-ONLY package that also exposes LoginEnterprise_PBI.TestExports (never ship).
.PARAMETER Check    Does not write; fails if -Output differs byte-for-byte from a fresh build.
#>
[CmdletBinding()]
param(
    [string]$Output,
    [switch]$Test,
    [switch]$Check
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
$root = Split-Path -Parent $PSScriptRoot
if (-not $Output) { $Output = Join-Path $root 'bin/AnyCPU/Debug/LE-PBI-Connector.mez' }

[xml]$proj = Get-Content (Join-Path $root 'LoginEnterprise_PBI.proj') -Raw
$files = @($proj.Project.ItemGroup.MezContent | ForEach-Object { $_.Include })
if ($files.Count -eq 0) { throw 'No MezContent items found in LoginEnterprise_PBI.proj' }

function Get-EntryBytes([string]$name) {
    $path = Join-Path $root $name
    $bytes = [IO.File]::ReadAllBytes($path)
    if ($Test -and $name -eq 'LoginEnterprise_PBI.pq') {
        $extra = "`n" + [IO.File]::ReadAllText((Join-Path $root 'tests/TestSupport.pq')).Replace("`r`n", "`n")
        $text = [Text.Encoding]::UTF8.GetString($bytes)
        $bytes = [Text.Encoding]::UTF8.GetBytes($text + $extra)
    }
    return ,$bytes
}

function New-PackageBytes {
    $ms = New-Object IO.MemoryStream
    $zip = New-Object IO.Compression.ZipArchive($ms, [IO.Compression.ZipArchiveMode]::Create, $true)
    foreach ($f in ($files | Sort-Object { [string]$_ } -CaseSensitive)) {
        $entry = $zip.CreateEntry($f, [IO.Compression.CompressionLevel]::NoCompression)
        $entry.LastWriteTime = [DateTimeOffset]::new(1980, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
        $s = $entry.Open()
        $b = Get-EntryBytes $f
        $s.Write($b, 0, $b.Length)
        $s.Dispose()
    }
    $zip.Dispose()
    return ,$ms.ToArray()
}

$bytes = New-PackageBytes
$sha = [BitConverter]::ToString([Security.Cryptography.SHA256]::HashData($bytes)).Replace('-', '')
if ($Check) {
    if (-not (Test-Path $Output)) { throw "Package not found: $Output" }
    $existing = [IO.File]::ReadAllBytes($Output)
    $existingSha = [BitConverter]::ToString([Security.Cryptography.SHA256]::HashData($existing)).Replace('-', '')
    if ($existingSha -ne $sha) { throw "Package $Output (sha256 $existingSha) does not match a fresh build from source (sha256 $sha). Run build/Build-Mez.ps1 and commit." }
    Write-Host "OK: $Output matches source build (sha256 $sha)"
    return
}
New-Item -ItemType Directory -Force (Split-Path -Parent $Output) | Out-Null
[IO.File]::WriteAllBytes($Output, $bytes)
Write-Host "Built $Output ($($bytes.Length) bytes) sha256 $sha"
