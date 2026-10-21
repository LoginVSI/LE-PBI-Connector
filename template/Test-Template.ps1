<#
.SYNOPSIS
  Static integrity checks for a template (.pbit): structure, compatibility with the original, DAX reference resolution.
.DESCRIPTION
  This is a STATIC check (zip/JSON parsing, bracket balance, name resolution). It does NOT evaluate DAX and does NOT
  prove Power BI Desktop can open or refresh the file. Desktop acceptance is a separate step (docs/ACCEPTANCE.md).
#>
[CmdletBinding()]
param(
    [string]$Original = (Join-Path $PSScriptRoot 'Login Enterprise.pbit'),
    [string]$Candidate = (Join-Path $PSScriptRoot 'candidate/Login Enterprise 1.1.0.2-candidate.pbit')
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'TemplateCommon.ps1')
$problems = New-Object Collections.Generic.List[string]
function Fail([string]$m) { $script:problems.Add($m) | Out-Null; Write-Host "FAIL: $m" -ForegroundColor Red }
function Ok([string]$m) { Write-Host "ok:   $m" }

# --- package structure ---------------------------------------------------------
$zo = [IO.Compression.ZipFile]::OpenRead($Original); $zc = [IO.Compression.ZipFile]::OpenRead($Candidate)
$on = @($zo.Entries.FullName); $cn = @($zc.Entries.FullName)
$zo.Dispose(); $zc.Dispose()
if (($on -join '|') -eq ($cn -join '|')) { Ok "same $($on.Count) entries in the same order" } else { Fail 'entry list differs from original' }
$allowedChanged = @('DataModelSchema', 'Report/Layout')
foreach ($e in $on) {
    $a = Read-ZipEntryBytes $Original $e; $b = Read-ZipEntryBytes $Candidate $e
    $same = ($a.Length -eq $b.Length) -and ([Linq.Enumerable]::SequenceEqual([byte[]]$a, [byte[]]$b))
    if (-not $same -and $allowedChanged -notcontains $e) { Fail "entry changed unexpectedly: $e" }
}
Ok "all entries other than $($allowedChanged -join ', ') are byte-identical"

# --- model compatibility ---------------------------------------------------------
$mo = Read-PbitModel $Original; $mc = Read-PbitModel $Candidate
function Items($a) { if ($null -eq $a) { return ,@() } else { return ,@($a) } }
function Names($arr) { @($arr | ForEach-Object { [string]$_['name'] }) }
$tabO = Names $mo['model']['tables']; $tabC = Names $mc['model']['tables']
if (($tabO -join '|') -eq ($tabC -join '|')) { Ok "$($tabC.Count) tables unchanged (names/order)" } else { Fail 'table list changed' }
function Rels($m) { @($m['model']['relationships'] | ForEach-Object { "$($_['fromTable']).$($_['fromColumn'])>$($_['toTable']).$($_['toColumn'])|$($_['crossFilteringBehavior'])|$($_['isActive'])" }) }
if ((Rels $mo) -join ';' -eq (Rels $mc) -join ';') { Ok "$((Rels $mc).Count) relationships unchanged" } else { Fail 'relationships changed' }
$colsO = @(); $colsC = @(); $measO = @{}; $measC = @{}
foreach ($t in $mo['model']['tables']) { foreach ($c in (Items $t['columns'])) { $colsO += "$($t['name']).$($c['name'])" }; foreach ($x in (Items $t['measures'])) { $measO["$($t['name']).$($x['name'])"] = 1 } }
foreach ($t in $mc['model']['tables']) { foreach ($c in (Items $t['columns'])) { $colsC += "$($t['name']).$($c['name'])" }; foreach ($x in (Items $t['measures'])) { $measC["$($t['name']).$($x['name'])"] = 1 } }
if (($colsO -join '|') -eq ($colsC -join '|')) { Ok "$($colsC.Count) columns unchanged" } else { Fail 'columns changed' }
$lost = @($measO.Keys | Where-Object { -not $measC.ContainsKey($_) })
if ($lost.Count -eq 0) { Ok "all $($measO.Count) original measure identifiers retained; $($measC.Count - $measO.Count) added" } else { Fail "original measures missing: $($lost -join ', ')" }
$dupes = @($measC.Keys | Group-Object { ($_ -split '\.', 2)[1] } | Where-Object Count -gt 1)
if ($dupes.Count -eq 0) { Ok 'measure names unique across tables' } else { Fail "duplicate measure names: $($dupes.Name -join ', ')" }

# --- DAX static checks ---------------------------------------------------------
$colSet = @{}; $measSet = @{}; $tabSet = @{}
foreach ($t in $mc['model']['tables']) {
    $tabSet[[string]$t['name']] = 1
    foreach ($c in (Items $t['columns'])) { $colSet["$($t['name'])|$($c['name'])"] = 1 }
    foreach ($x in (Items $t['measures'])) { $measSet[[string]$x['name']] = 1; $colSet["$($t['name'])|$($x['name'])"] = 1 }
}
function Strip-Dax([string]$s) {
    $s = [regex]::Replace($s, '"(?:[^"]|"")*"', '""')          # string literals
    $s = [regex]::Replace($s, '/\*.*?\*/', ' ', 'Singleline')
    $s = [regex]::Replace($s, '(--|//)[^\n]*', ' ')
    return $s
}
$daxProblems = 0
foreach ($t in $mc['model']['tables']) {
    foreach ($x in (Items $t['measures'])) {
        $name = [string]$x['name']; $dax = Strip-Dax (Join-Lines $x['expression'])
        $stack = New-Object Collections.Generic.Stack[char]; $pairs = @{ ')' = '('; ']' = '['; '}' = '{' }; $bad = $false
        $noq = [regex]::Replace($dax, "'(?:[^']|'')*'", 'T')       # quoted table names
        foreach ($ch in $noq.ToCharArray()) {
            if ('([{'.Contains($ch)) { $stack.Push($ch) }
            elseif (')]}'.Contains($ch)) { if ($stack.Count -eq 0 -or $stack.Pop() -ne $pairs[[string]$ch]) { $bad = $true } }
        }
        if ($bad -or $stack.Count -ne 0) { Fail "unbalanced brackets in measure '$name'"; $daxProblems++ }
        foreach ($m in [regex]::Matches($dax, "(?:'((?:[^']|'')+)'|\b([A-Za-z_][A-Za-z0-9_]*))\[([^\]]+)\]")) {
            $tb = if ($m.Groups[1].Success) { $m.Groups[1].Value.Replace("''", "'") } else { $m.Groups[2].Value }
            if (-not $tabSet.ContainsKey($tb)) { Fail "measure '$name': unknown table '$tb'"; $daxProblems++; continue }
            if (-not $colSet.ContainsKey("$tb|$($m.Groups[3].Value)")) { Fail "measure '$name': unknown column/measure $tb[$($m.Groups[3].Value)]"; $daxProblems++ }
        }
        $bare = [regex]::Replace($dax, "(?:'(?:[^']|'')+'|\b[A-Za-z_][A-Za-z0-9_]*)\[[^\]]+\]", ' ')
        foreach ($m in [regex]::Matches($bare, '\[([^\]]+)\]')) {
            if (-not $measSet.ContainsKey($m.Groups[1].Value)) { Fail "measure '$name': unresolved bare reference [$($m.Groups[1].Value)]"; $daxProblems++ }
        }
    }
}
if ($daxProblems -eq 0) { Ok "DAX static checks passed for $($measC.Count) measures (brackets balanced, all table/column/measure references resolve)" }

# --- layout bindings -------------------------------------------------------------
$layout = ConvertFrom-Utf16Bytes (Read-ZipEntryBytes $Candidate 'Report/Layout')
$props = [regex]::Matches($layout, '\\"Measure\\":\{\\"Expression\\":\{\\"SourceRef\\":\{\\"(?:Source|Entity)\\":\\"[^\\]+\\"\}\},\\"Property\\":\\"([^\\]+)\\"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$missing = @($props | Where-Object { -not $measSet.ContainsKey($_) })
if ($missing.Count -eq 0) { Ok "all $($props.Count) measures bound by visuals exist in the model" } else { Fail "visuals bind to missing measures: $($missing -join ', ')" }

if ($problems.Count -gt 0) { Write-Host "`n$($problems.Count) problem(s)" -ForegroundColor Red; exit 1 }
Write-Host "`nStatic template checks passed (NOT a Desktop validation)."
