param([string]$GodotPath=$env:GODOT_EXE,[string]$ApiUrl='http://127.0.0.1:5086',[string]$DataRoot='',[switch]$Headless,[switch]$SmokeTest)
$ErrorActionPreference='Stop'
$projectRoot=$PSScriptRoot
if(-not $GodotPath){$GodotPath=Join-Path $projectRoot 'tools\engine\Godot_v4.7.2-stable_win64.exe'}
if(-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)){throw 'Set -GodotPath or GODOT_EXE to Godot 4.7.2 stable. No engine is downloaded automatically.'}
$GodotPath=(Resolve-Path -LiteralPath $GodotPath).Path
$engineVersion=(& $GodotPath --headless --version | Out-String).Trim()
if($engineVersion -notmatch '^4\.7\.2\.stable\.'){throw 'This project requires Godot 4.7.2 stable; choose the existing matching binary.'}
if(-not $DataRoot){$DataRoot=Join-Path $projectRoot 'AMD201Data'}
$DataRoot=[IO.Path]::GetFullPath($DataRoot)
$personal=[Environment]::GetFolderPath('ApplicationData')
if($DataRoot.TrimEnd('\') -eq $personal.TrimEnd('\')){throw 'Choose a dedicated data directory, not personal ApplicationData.'}
New-Item -ItemType Directory -Path $DataRoot,(Join-Path $DataRoot 'app'),(Join-Path $DataRoot 'local') -Force | Out-Null
Set-Content -LiteralPath (Join-Path $DataRoot '.gdignore') -Value ''
$old=@{}
foreach($key in @('APPDATA','LOCALAPPDATA','XDG_DATA_HOME','AMD201_DATA_ROOT','AMD201_API_URL')){$old[$key]=[Environment]::GetEnvironmentVariable($key,'Process')}
try{
 $env:APPDATA=Join-Path $DataRoot 'app';$env:LOCALAPPDATA=Join-Path $DataRoot 'local';$env:XDG_DATA_HOME=Join-Path $DataRoot 'local'
 $env:AMD201_DATA_ROOT=$DataRoot;$env:AMD201_API_URL=$ApiUrl
 # A source checkout has no class/asset cache. The incremental editor import
 # also repairs a missing cache after updates, without opening the game scene.
 Write-Host 'Checking/importing Godot source assets (first launch may take longer)...'
 $logRoot=Join-Path $DataRoot 'launcher-logs'
 New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
 $logId=[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfff')+'-'+$PID
 $importOut=Join-Path $logRoot ($logId+'-import.out.log');$importErr=Join-Path $logRoot ($logId+'-import.err.log')
 $importArguments=@('--headless','--path',('"'+$projectRoot+'"'),'--editor','--import')
 # Start-Process -Wait is required for the Windows GUI engine executable.
 $importProcess=Start-Process -FilePath $GodotPath -ArgumentList $importArguments -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $importOut -RedirectStandardError $importErr
 $importExit=$importProcess.ExitCode
 $importOutput=@(Get-Content -LiteralPath $importOut)+@(Get-Content -LiteralPath $importErr)
 if($importExit -ne 0 -or ($importOutput | Select-String -Pattern '^\s*(SCRIPT ERROR:|ERROR:)')){
  $importOutput | ForEach-Object { Write-Host $_ }
  throw "Godot import failed (exit $importExit). Game was not started. Keep logs in $logRoot and fix the reported source/import error."
 }
 if(-not (Test-Path -LiteralPath (Join-Path $projectRoot '.godot\global_script_class_cache.cfg') -PathType Leaf)){
  throw 'Godot import did not create the script class cache. Game was not started; keep the import output.'
 }
 $arguments=@('--path',$projectRoot,'res://scenes/amd201_boot.tscn')
 if($SmokeTest){$Headless=$true;$arguments=@('--path',$projectRoot,'--script','res://tests/test_amd_launcher.gd')}
 if($Headless){$arguments=@('--headless')+$arguments}
 $gameOut=Join-Path $logRoot ($logId+'-game.out.log');$gameErr=Join-Path $logRoot ($logId+'-game.err.log')
 $quotedArguments=@($arguments | ForEach-Object { if($_ -match '\s'){'"'+$_+'"'}else{$_} })
 $startOptions=@{FilePath=$GodotPath;ArgumentList=$quotedArguments;Wait=$true;PassThru=$true;RedirectStandardOutput=$gameOut;RedirectStandardError=$gameErr}
 if($Headless){$startOptions.WindowStyle='Hidden'}
 $gameProcess=Start-Process @startOptions
 if($SmokeTest){Get-Content -LiteralPath $gameOut | ForEach-Object { Write-Host $_ }}
 if($gameProcess.ExitCode -ne 0){throw "Godot exited with code $($gameProcess.ExitCode). Keep logs in $logRoot; a successful API test does not prove engine stability."}
}finally{foreach($key in $old.Keys){[Environment]::SetEnvironmentVariable($key,$old[$key],'Process')}}
