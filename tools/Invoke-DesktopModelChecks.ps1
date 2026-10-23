[CmdletBinding()]
param([string]$QueryFile, [string]$OutputPath)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
if(-not $QueryFile){$QueryFile=Join-Path $root 'template/acceptance/ModelChecks.dax'}
if(-not $OutputPath){$OutputPath=Join-Path $root '.cache/desktop-acceptance-20261021/modelchecks.raw.json'}
$allServers=@(Get-CimInstance Win32_Process -Filter "name='msmdsrv.exe'")
$desktopIds=@(Get-Process PBIDesktop -ErrorAction SilentlyContinue | Where-Object {$_.MainWindowTitle -like 'LE-acceptance-*'} | ForEach-Object {$_.Id})
$ownedServers=@($allServers | Where-Object {$_.ParentProcessId -in $desktopIds})
$servers=if($ownedServers.Count){$ownedServers}else{@($allServers | Where-Object {$_.CommandLine -like '*AnalysisServicesWorkspace*'})}
if($servers.Count -ne 1){Write-Output 'Waiting for exactly one open Desktop model; no query executed.';exit 2}
$match=[regex]::Match($servers[0].CommandLine,'-s "([^"]+)"')
if($match.Success){
 $portFile=Join-Path $match.Groups[1].Value 'msmdsrv.port.txt'
 $portBytes=[IO.File]::ReadAllBytes($portFile)
 $port=if($portBytes.Length -gt 1 -and $portBytes[1] -eq 0){[Text.Encoding]::Unicode.GetString($portBytes)}else{[Text.Encoding]::UTF8.GetString($portBytes)}
 $port=$port.Trim([char]0).Trim().Trim([char]0xFEFF)
}else{
 # Some Desktop processes hide CommandLine. Only use a loopback listener whose
 # server is the unique child of a named acceptance window. Never select an unrelated model.
 if($ownedServers.Count -ne 1){throw 'Desktop workspace could not be identified; no model queried.'}
 $ports=@(Get-NetTCPConnection -State Listen -OwningProcess $servers[0].ProcessId | Where-Object {$_.LocalAddress -in @('127.0.0.1','::1')} | Select-Object -ExpandProperty LocalPort -Unique)
 if($ports.Count -ne 1){throw 'Expected one loopback model listener; no model queried.'}
 $port=[string]$ports[0]
}
if($port -notmatch '^\d+$'){throw 'Unexpected local model port.'}
[Reflection.Assembly]::LoadFrom('C:/Program Files/Microsoft Power BI Desktop/bin/Microsoft.PowerBI.AdomdClient.dll') | Out-Null
$connection=New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection("Data Source=localhost:$port")
try{
 $connection.Open();$cmd=$connection.CreateCommand();$cmd.CommandTimeout=120
 $cmd.CommandText='SELECT [CATALOG_NAME] FROM $SYSTEM.DBSCHEMA_CATALOGS';$reader=$cmd.ExecuteReader();$catalogs=@()
 while($reader.Read()){$catalogs+=$reader.GetString(0)};$reader.Close()
 if($catalogs.Count -ne 1){throw 'Expected one Desktop catalog; no model queried.'}
 $connection.Close();$connection.ConnectionString="Data Source=localhost:$port;Initial Catalog=$($catalogs[0])";$connection.Open()
 $cmd=$connection.CreateCommand();$cmd.CommandTimeout=120
 $cmd.CommandText='SELECT [Name] FROM $SYSTEM.TMSCHEMA_TABLES';$reader=$cmd.ExecuteReader();$names=@()
 while($reader.Read()){$names+=$reader.GetString(0)};$reader.Close()
 foreach($required in @('Filtered Test Runs','Measurements','User Sessions','Tests')){if($required -notin $names){throw 'Open model is not the LE-PBI template; refusing to query it.'}}
 $cmd.CommandText=[IO.File]::ReadAllText((Resolve-Path -LiteralPath $QueryFile))
 $reader=$cmd.ExecuteReader();$sets=@();$counts=@()
 do{
  $rows=@();while($reader.Read()){$row=[ordered]@{};for($i=0;$i -lt $reader.FieldCount;$i++){$value=$reader.GetValue($i);if($value -is [DBNull]){$value=$null};$row[$reader.GetName($i)]=$value};$rows+=$row}
  $sets+=,@($rows);$counts+=$rows.Count
 }while($reader.NextResult())
 $reader.Close()
 New-Item -ItemType Directory -Force (Split-Path -Parent $OutputPath) | Out-Null
 [ordered]@{dateUtc=[DateTime]::UtcNow.ToString('o');querySha256=(Get-FileHash -LiteralPath $QueryFile).Hash;resultSets=$sets;acceptance='Model query execution only; refresh and visual acceptance must be recorded separately.'} | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath $OutputPath -Encoding utf8
 [ordered]@{status='executed-on-Desktop-model';resultSetRowCounts=$counts;privateOutput=$OutputPath} | ConvertTo-Json -Depth 5
}finally{$connection.Dispose()}
