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
 $arguments=@('--path',$projectRoot,'res://scenes/amd201_boot.tscn')
 if($SmokeTest){$Headless=$true;$arguments=@('--path',$projectRoot,'--script','res://tests/test_amd_launcher.gd')}
 if($Headless){$arguments=@('--headless')+$arguments}
 & $GodotPath @arguments
 if($LASTEXITCODE -ne 0){throw "Godot exited with code $LASTEXITCODE. Keep logs; a successful API test does not prove engine stability."}
}finally{foreach($key in $old.Keys){[Environment]::SetEnvironmentVariable($key,$old[$key],'Process')}}
