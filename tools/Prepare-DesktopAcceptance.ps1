[CmdletBinding()]
param([switch]$Install)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$work=Join-Path $root '.cache/desktop-acceptance-20261021'
$folder=Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Power BI Desktop\Custom Connectors'
$candidate=Join-Path $root 'bin/AnyCPU/Debug/LE-PBI-Connector.mez'
$expected=(Get-Content (Join-Path $root 'docs/evidence/artifacts.json') -Raw | ConvertFrom-Json).artifacts | Where-Object path -eq 'bin/AnyCPU/Debug/LE-PBI-Connector.mez'
foreach($artifact in (Get-Content (Join-Path $root 'docs/evidence/artifacts.json') -Raw | ConvertFrom-Json).artifacts){if((Get-FileHash -LiteralPath (Join-Path $root $artifact.path)).Hash -ne $artifact.sha256){throw 'Artifact checksum mismatch; nothing installed.'}}
$actual=(Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash
if($actual -ne $expected.sha256){throw 'Candidate checksum mismatch; nothing installed.'}
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Get-MezVersion([string]$path){
 $zip=[IO.Compression.ZipFile]::OpenRead($path)
 try{$entry=$zip.GetEntry('LoginEnterprise_PBI.pq');if(-not $entry){return 'unknown'};$reader=[IO.StreamReader]::new($entry.Open());try{$source=$reader.ReadToEnd();$m=[regex]::Match($source,'\[Version\s*=\s*"([^"]+)"\]');if($m.Success){return $m.Groups[1].Value};return 'unknown'}finally{$reader.Dispose()}}finally{$zip.Dispose()}
}
$installed=Join-Path $folder 'LE-PBI-Connector.mez'
$toolkit=Join-Path $folder 'ResultsToolkit.mez'
$record=[ordered]@{dateUtc=[DateTime]::UtcNow.ToString('o');connectorFolder=$folder;desktopVersion=(Get-Item 'C:/Program Files/Microsoft Power BI Desktop/bin/PBIDesktop.exe').VersionInfo.FileVersion;utcOffset=[TimeZoneInfo]::Local.GetUtcOffset([DateTime]::Now).ToString();candidateVersion=(Get-MezVersion $candidate);candidateSha256=$actual;installedBeforeVersion=(Get-MezVersion $installed);installedBeforeSha256=(Get-FileHash -LiteralPath $installed).Hash;toolkitBeforeSha256=(Get-FileHash -LiteralPath $toolkit).Hash;desktopProcessesBefore=@(Get-Process PBIDesktop -ErrorAction SilentlyContinue).Count;installed=$false}
if($Install){
 if($record.desktopProcessesBefore -ne 0){throw 'Desktop is running; preserve open work before installing.'}
 $backup=Join-Path $work 'backup/LE-PBI-Connector.original.mez'
 New-Item -ItemType Directory -Force (Split-Path -Parent $backup) | Out-Null
 if(-not (Test-Path -LiteralPath $backup)){Copy-Item -LiteralPath $installed -Destination $backup}
 # Never overwrite the original backup. Preserve each installed revision separately before replacement.
 $currentBackup=Join-Path $work ('backup/LE-PBI-Connector.' + $record.installedBeforeSha256 + '.mez')
 if(-not (Test-Path -LiteralPath $currentBackup)){Copy-Item -LiteralPath $installed -Destination $currentBackup}
 if((Get-FileHash -LiteralPath $currentBackup).Hash -ne $record.installedBeforeSha256){throw 'Installed-revision backup verification failed.'}
 $record['previousRevisionBackupPath']=$currentBackup
 Copy-Item -LiteralPath $candidate -Destination $installed -Force
 if((Get-FileHash -LiteralPath $installed).Hash -ne $actual){throw 'Installed candidate differs.'}
 $record['backupPath']=$backup;$record['backupSha256']=(Get-FileHash -LiteralPath $backup).Hash
 $record['toolkitAfterSha256']=(Get-FileHash -LiteralPath $toolkit).Hash
 if($record.toolkitAfterSha256 -ne $record.toolkitBeforeSha256){throw 'Toolkit hash changed unexpectedly.'}
 $record.installed=$true
 if(-not (Test-Path (Join-Path $work 'LE-acceptance-candidate.pbit'))){Copy-Item -LiteralPath (Join-Path $root 'template/candidate/Login Enterprise 1.1.0.2-candidate.pbit') -Destination (Join-Path $work 'LE-acceptance-candidate.pbit')}
 if(-not (Test-Path (Join-Path $work 'LE-acceptance-legacy-template.pbit'))){Copy-Item -LiteralPath (Join-Path $root 'template/Login Enterprise.pbit') -Destination (Join-Path $work 'LE-acceptance-legacy-template.pbit')}
 $historyPath=Join-Path $root ('docs/evidence/desktop-installation-' + $actual.Substring(0,12) + '.json')
 $record | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $historyPath -Encoding utf8
 if(-not (Test-Path (Join-Path $root 'docs/evidence/desktop-installation.json'))){$record | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $root 'docs/evidence/desktop-installation.json') -Encoding utf8}
}
$record | ConvertTo-Json -Depth 5
