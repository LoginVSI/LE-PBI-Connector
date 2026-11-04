<#
Opens ONE acceptance template (.pbit) in Power BI Desktop and drives only its parameter dialog via UI Automation:
fills the FQDN from a private host file (never printed), accepts the date defaults already set in the Key copy, and clicks Load.
It does not type any credential. If Desktop asks for a credential, it stops and says so (the owner enters it locally).
Waits until a queryable model exists, then exits 0. Run only when this session owns the Desktop slot.
Usage: pwsh tools/Open-TemplateInDesktop.ps1 -File <pbit> -HostFile <private host file> [-TimeoutMinutes 8] [-DumpOnly]
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$File, [Parameter(Mandatory)][string]$HostFile, [int]$TimeoutMinutes = 8, [switch]$DumpOnly)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
if (Get-Process PBIDesktop -ErrorAction SilentlyContinue) { throw 'Power BI Desktop is already running; refusing to touch an existing instance.' }
$fqdn = (Get-Content -LiteralPath $HostFile -Raw).Trim()
$proc = Start-Process -FilePath (Resolve-Path -LiteralPath $File) -PassThru
$root = [Windows.Automation.AutomationElement]::RootElement
function Get-DesktopWindows { $ids = @(Get-Process PBIDesktop -ErrorAction SilentlyContinue | ForEach-Object { $_.Id }); foreach ($w in $root.FindAll('Children', [Windows.Automation.Condition]::TrueCondition)) { if ($w.Current.ProcessId -in $ids) { $w } } }
function Find-All($el, $type) { $c = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::ControlTypeProperty, $type); $el.FindAll('Descendants', $c) }
$deadline = (Get-Date).AddMinutes($TimeoutMinutes); $loaded = $false; $filled = $false
while ((Get-Date) -lt $deadline) {
    Start-Sleep 4
    foreach ($w in Get-DesktopWindows) {
        $edits = @(Find-All $w ([Windows.Automation.ControlType]::Edit))
        $buttons = @(Find-All $w ([Windows.Automation.ControlType]::Button))
        $loadBtn = $buttons | Where-Object { $_.Current.Name -eq 'Load' } | Select-Object -First 1
        $names = ($w.FindAll('Descendants', [Windows.Automation.Condition]::TrueCondition) | ForEach-Object { $_.Current.Name } | Where-Object { $_ }) -join ' | '
        if ($names -match 'corrupted|unrecognized') { throw 'Desktop rejected the file (corrupted/unrecognized).' }
        if ($names -match 'Enter credentials|Sign in|Access Web content|credentials' -and -not $loadBtn) { Write-Output 'Desktop is asking for a credential: owner must enter it locally. Stopping.'; exit 3 }
        if ($DumpOnly) { "WINDOW: $($w.Current.Name)"; $edits | ForEach-Object { "  EDIT name='$($_.Current.Name.Substring(0,[Math]::Min(60,$_.Current.Name.Length)))' id=$($_.Current.AutomationId)" }; $buttons | ForEach-Object { "  BUTTON '$($_.Current.Name)'" }; continue }
        if ($loadBtn -and -not $filled) {
            $fq = $edits | Where-Object { $_.Current.Name -like 'FQDN*' } | Select-Object -First 1
            if (-not $fq) { throw 'Parameter dialog found but the FQDN field was not identified; nothing was typed.' }
            $vp = $fq.GetCurrentPattern([Windows.Automation.ValuePattern]::Pattern); $vp.SetValue($fqdn); $filled = $true
            Start-Sleep 1
            $loadBtn.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern).Invoke(); $loaded = $true
            Write-Output 'Parameter dialog filled (FQDN from private file) and Load clicked.'
        }
    }
    if ($DumpOnly) { break }
    if ($loaded) {
        $ms = @(Get-CimInstance Win32_Process -Filter "Name='msmdsrv.exe'")
        if ($ms.Count -ge 1) { Start-Sleep 20; Write-Output 'Model server present.'; exit 0 }
    }
}
if (-not $DumpOnly) { throw 'Timed out waiting for the template to load.' }
