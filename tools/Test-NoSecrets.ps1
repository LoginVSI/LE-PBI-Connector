<#
.SYNOPSIS  Fails if tracked text files contain token-shaped literals (JWTs, long bearer values, long base64-ish query args).
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$files = git -C $root ls-files | Where-Object { $_ -match '\.(pq|ps1|md|yml|yaml|json|dax|m|proj|resx|txt)$' }
$patterns = @(
    'eyJ[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{10,}',                      # JWT
    '(?i)bearer\s+[A-Za-z0-9._~+/-]{24,}',                             # long bearer literal
    '(?i)(api[_-]?token|apikey|secret|password)\s*[=:]\s*["''][A-Za-z0-9._~+/-]{20,}["'']',
    '\bLoginEnterprise_PBI\.Contents\(\s*"[^"]+"\s*,\s*"[A-Za-z0-9._~+/-]{20,}"'  # token literal passed to the connector
)
$bad = @()
foreach ($f in $files) {
    if ($f -like 'tests/*') { continue }   # fixtures use obvious fake values
    $text = Get-Content (Join-Path $root $f) -Raw -ErrorAction SilentlyContinue
    if (-not $text) { continue }
    foreach ($p in $patterns) { if ($text -match $p) { $bad += "$f matches /$p/" } }
}
if ($bad) { $bad | ForEach-Object { Write-Host "FAIL: $_" -ForegroundColor Red }; exit 1 }
Write-Host "ok: no token-shaped literals in $($files.Count) tracked text files"
