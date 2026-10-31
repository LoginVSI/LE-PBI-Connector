<#
.SYNOPSIS
  Static integrity checks for a template (.pbit): structure, compatibility with the original, DAX reference resolution.
.DESCRIPTION
  This is a STATIC check (zip/JSON parsing, bracket balance, name resolution). It does NOT evaluate DAX and does NOT
  prove Power BI Desktop can open or refresh the file. Desktop acceptance is a separate step (docs/ACCEPTANCE.md).
#>
[CmdletBinding()]
param(
    [string]$Original = (Join-Path $PSScriptRoot 'base/Login Enterprise Desktop 2026-10.pbit'),
    [string]$Candidate = (Join-Path $PSScriptRoot 'candidate/Login Enterprise 1.2.0.0-candidate.pbit')
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
$pbirEditPath0 = Join-Path $PSScriptRoot 'source/pbir-edits.json'
if ((Test-Path $pbirEditPath0) -and ($on -contains 'SecurityBindings')) { $on = @($on | Where-Object { $_ -ne 'SecurityBindings' }) }  # intentionally dropped when report files are edited
if (($on -join '|') -eq ($cn -join '|')) { Ok "same $($on.Count) entries in the same order (SecurityBindings intentionally absent when report files are edited)" } else { Fail 'entry list differs from original (beyond the intentional SecurityBindings removal)' }
if ($cn -contains 'SecurityBindings' -and (Test-Path $pbirEditPath0)) { Fail 'SecurityBindings must be absent when PBIR visuals are edited' }
$pbirEditPath = Join-Path $PSScriptRoot 'source/pbir-edits.json'
$allowedChanged = @('DataModelSchema', 'Report/Layout', 'UnappliedChanges') + @(if (Test-Path $pbirEditPath) { (Get-Content $pbirEditPath -Raw | ConvertFrom-Json).entry | Select-Object -Unique })
foreach ($e in $on) {
    $a = Read-ZipEntryBytes $Original $e; $b = Read-ZipEntryBytes $Candidate $e
    $same = ($a.Length -eq $b.Length) -and ([Linq.Enumerable]::SequenceEqual([byte[]]$a, [byte[]]$b))
    if (-not $same -and $allowedChanged -notcontains $e) { Fail "entry changed unexpectedly: $e" }
}
Ok "all entries other than $($allowedChanged -join ', ') are byte-identical"

# --- model compatibility ---------------------------------------------------------
$mo = Read-PbitModel $Original; $mc = Read-PbitModel $Candidate
$persisted = [System.Text.Json.Nodes.JsonNode]::Parse((ConvertFrom-Utf16Bytes (Read-ZipEntryBytes $Candidate 'UnappliedChanges')))
$persistedProblems = @(Get-PersistedQueryProblems $mc $persisted)
foreach ($problem in $persistedProblems) { Fail $problem }
if (-not $persistedProblems.Count) { Ok 'persisted query lineage, M and descriptions match the model' }
function Items($a) { if ($null -eq $a) { return ,@() } else { return ,@($a) } }
function Names($arr) { @($arr | ForEach-Object { [string]$_['name'] }) }
$tabO = Names $mo['model']['tables']; $tabC = Names $mc['model']['tables']
$addedSpec = @((Get-Content (Join-Path $PSScriptRoot 'source/new-tables.json') -Raw | ConvertFrom-Json).tables)
$addedNames = @($addedSpec | ForEach-Object { $_.name })
if (($tabO -join '|') + '|' + ($addedNames -join '|') -eq ($tabC -join '|')) { Ok "$($tabO.Count) base tables unchanged (names/order); added: $($addedNames -join ', ')" } else { Fail 'table list differs from base plus documented additions' }
function Rels($m) { @($m['model']['relationships'] | ForEach-Object { "$($_['fromTable']).$($_['fromColumn'])>$($_['toTable']).$($_['toColumn'])|$($_['crossFilteringBehavior'])|$($_['isActive'])" }) }
$addedRels = @($addedSpec | ForEach-Object { "$($_.name).$($_.relationship.fromColumn)>$($_.relationship.toTable).$($_.relationship.toColumn)||" })
if (((Rels $mo) + $addedRels) -join ';' -eq (Rels $mc) -join ';') { Ok "$((Rels $mo).Count) base relationships unchanged; $($addedRels.Count) added" } else { Fail 'relationships differ from base plus documented additions' }
$colsO = @(); $colsC = @(); $measO = @{}; $measC = @{}
foreach ($t in $mo['model']['tables']) { foreach ($c in (Items $t['columns'])) { $colsO += "$($t['name']).$($c['name'])" }; foreach ($x in (Items $t['measures'])) { $measO["$($t['name']).$($x['name'])"] = 1 } }
foreach ($t in $mc['model']['tables']) { foreach ($c in (Items $t['columns'])) { $colsC += "$($t['name']).$($c['name'])" }; foreach ($x in (Items $t['measures'])) { $measC["$($t['name']).$($x['name'])"] = 1 } }
$addedCols = @($addedSpec | ForEach-Object { $t = $_; $t.columns | ForEach-Object { "$($t.name).$($_.name)" } })
if (($colsO + $addedCols) -join '|' -eq ($colsC -join '|')) { Ok "$($colsO.Count) base columns unchanged; $($addedCols.Count) added" } else { Fail 'columns differ from base plus documented additions' }
$lost = @($measO.Keys | Where-Object { -not $measC.ContainsKey($_) })
if ($lost.Count -eq 0) { Ok "all $($measO.Count) original measure identifiers retained; $($measC.Count - $measO.Count) added" } else { Fail "original measures missing: $($lost -join ', ')" }
# The native Desktop base adds an automatic date table; also retain the original customer schema.
$legacy = Read-PbitModel (Join-Path $PSScriptRoot 'Login Enterprise.pbit')
$currentTables = @{}; foreach ($t in $mc['model']['tables']) { $currentTables[[string]$t['name']] = $t }
$legacyColumns = 0; $legacyMeasures = 0
$typeRefinements = @((Get-Content (Join-Path $PSScriptRoot 'source/desktop-base.json') -Raw | ConvertFrom-Json).columnTypeRefinements)
foreach ($t in $legacy['model']['tables']) {
    $name = [string]$t['name']
    if (-not $currentTables.ContainsKey($name)) { Fail "legacy table missing: $name"; continue }
    foreach ($column in $t['columns']) {
        $matches = @($currentTables[$name]['columns'] | Where-Object { [string]$_['name'] -ceq [string]$column['name'] })
        if ($matches.Count -ne 1) { Fail "legacy column missing: $name.$($column['name'])" }
        elseif ([string]$matches[0]['dataType'] -cne [string]$column['dataType']) {
            $approved = @($typeRefinements | Where-Object { $_.table -ceq $name -and $_.column -ceq [string]$column['name'] -and $_.before -ceq [string]$column['dataType'] -and $_.after -ceq [string]$matches[0]['dataType'] })
            if ($approved.Count -ne 1) { Fail "unexpected legacy column type change: $name.$($column['name'])" }
        }
        $legacyColumns++
    }
    foreach ($measure in $t['measures']) { if (-not $measC.ContainsKey("$name.$($measure['name'])")) { Fail "legacy measure missing: $name.$($measure['name'])" }; $legacyMeasures++ }
}
function Semantic-Rels($model) {
    foreach ($r in $model['model']['relationships']) {
        $cross = if ($null -eq $r['crossFilteringBehavior']) { 'oneDirection' } else { [string]$r['crossFilteringBehavior'] }
        $active = if ($null -eq $r['isActive']) { $true } else { $r['isActive'].GetValue[bool]() }
        "$($r['fromTable']).$($r['fromColumn'])>$($r['toTable']).$($r['toColumn'])|$cross|$active"
    }
}
$currentRels = @(Semantic-Rels $mc)
foreach ($rel in @(Semantic-Rels $legacy)) { if ($rel -cnotin $currentRels) { Fail 'Original relationship semantics changed.' } }
Ok "legacy schema checked: $legacyColumns columns, $legacyMeasures measures and original relationships retained"
Ok "$($typeRefinements.Count) documented native type refinements checked against the original schema"
$dupes = @($measC.Keys | Group-Object { ($_ -split '\.', 2)[1] } | Where-Object Count -gt 1)
if ($dupes.Count -eq 0) { Ok 'measure names unique across tables' } else { Fail "duplicate measure names: $($dupes.Name -join ', ')" }

# --- parameter compatibility and canonical help --------------------------------
foreach ($name in @('StartDateParam', 'EndDateParam')) {
    $before = @($mo['model']['expressions'] | Where-Object { [string]$_['name'] -ceq $name })
    $after = @($mc['model']['expressions'] | Where-Object { [string]$_['name'] -ceq $name })
    if ($before.Count -ne 1 -or $after.Count -ne 1) { Fail "date parameter missing/duplicated: $name"; continue }
    $beforeIdentity = $before[0].DeepClone(); [void]$beforeIdentity.Remove('description')
    $afterIdentity = $after[0].DeepClone(); [void]$afterIdentity.Remove('description')
    if ($beforeIdentity.ToJsonString() -ne $afterIdentity.ToJsonString()) { Fail "date parameter identity/type/default changed: $name" }
    else { Ok "$name identifier, Date expression, defaults and metadata retained" }
}
$helpPath = Join-Path $PSScriptRoot 'source/parameter-descriptions.json'
if (Test-Path -LiteralPath $helpPath) {
    $help = [System.Text.Json.Nodes.JsonNode]::Parse([IO.File]::ReadAllText($helpPath))
    foreach ($item in $help) {
        $parameter = @($mc['model']['expressions'] | Where-Object { [string]$_['name'] -ceq $item.Key })
        if ($parameter.Count -ne 1 -or $parameter[0]['description'].ToJsonString() -ne $item.Value.ToJsonString()) { Fail "date help differs from source: $($item.Key)" }
        else { Ok "$($item.Key) help matches canonical source" }
    }
}

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
$zip = [IO.Compression.ZipFile]::OpenRead($Candidate)
try { $hasLegacyLayout = $null -ne $zip.GetEntry('Report/Layout'); $visualEntries = @($zip.Entries.FullName | Where-Object { $_ -match '^Report/definition/pages/[^/]+/visuals/[^/]+/visual.json$' }); $pageEntries = @($zip.Entries.FullName | Where-Object { $_ -match '^Report/definition/pages/[^/]+/page.json$' }) } finally { $zip.Dispose() }
if ($hasLegacyLayout) {
    $layout = ConvertFrom-Utf16Bytes (Read-ZipEntryBytes $Candidate 'Report/Layout')
    $props = [regex]::Matches($layout, '\\"Measure\\":\{\\"Expression\\":\{\\"SourceRef\\":\{\\"(?:Source|Entity)\\":\\"[^\\]+\\"\}\},\\"Property\\":\\"([^\\]+)\\"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
} else {
    if ($pageEntries.Count -ne 9 -or $visualEntries.Count -ne 220) { Fail 'PBIR page/visual inventory changed' } else { Ok 'PBIR contains 9 pages and 220 visuals' }
    function Find-MeasureBindings($node) {
        if ($node -is [System.Text.Json.Nodes.JsonObject]) {
            foreach ($item in $node) {
                if ($item.Key -eq 'Measure' -and $null -ne $item.Value['Property']) { [string]$item.Value['Property'] }
                Find-MeasureBindings $item.Value
            }
        } elseif ($node -is [System.Text.Json.Nodes.JsonArray]) { foreach ($item in $node) { Find-MeasureBindings $item } }
    }
    $props = @($visualEntries | ForEach-Object { $json = [Text.Encoding]::UTF8.GetString((Read-ZipEntryBytes $Candidate $_)).TrimStart([char]0xFEFF); Find-MeasureBindings ([System.Text.Json.Nodes.JsonNode]::Parse($json)) } | Sort-Object -Unique)
}
$missing = @($props | Where-Object { -not $measSet.ContainsKey($_) })
if ($missing.Count -eq 0) { Ok "all $($props.Count) measures bound by visuals exist in the model" } else { Fail "visuals bind to missing measures: $($missing -join ', ')" }

if ($problems.Count -gt 0) { Write-Host "`n$($problems.Count) problem(s)" -ForegroundColor Red; exit 1 }
Write-Host "`nStatic template checks passed (NOT a Desktop validation)."
