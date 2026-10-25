param([string]$EnginePath='',[switch]$NormalProgression,[switch]$ResetProfile,[switch]$SmokeTest,[string]$EvidenceRoot='')
$ErrorActionPreference='Stop'
$teamProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if(-not $EnginePath){$EnginePath=$env:GODOT_BIN}
if(-not $EnginePath){$teamCommand=Get-Command godot,Godot_v4.7.2-stable_win64 -ErrorAction SilentlyContinue|Select-Object -First 1;if($teamCommand){$EnginePath=$teamCommand.Source}}
if(-not $EnginePath -or -not (Test-Path -LiteralPath $EnginePath -PathType Leaf)){throw 'Set GODOT_BIN to the Godot4.7.2 executable, or pass -EnginePath. No engine download/install is performed.'}
$teamVersion=(& $EnginePath --version|Out-String).Trim()
if($teamVersion -notlike '4.7.2.*'){throw ('Use Godot4.7.2 for this snapshot; detected '+$teamVersion)}
$teamData=[IO.Path]::GetFullPath((Join-Path $teamProject 'TeamTestData'))
New-Item -ItemType Directory -Path $teamData -Force|Out-Null
Set-Content -LiteralPath (Join-Path $teamData '.gdignore') -Value '' -NoNewline -Encoding utf8
$teamMode=if($NormalProgression){'normal_progression'}else{'sandbox'}
$teamRoot=[IO.Path]::GetFullPath((Join-Path $teamData $teamMode))
if(-not $teamRoot.StartsWith($teamData+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Profile path must stay inside TeamTestData'}
if($ResetProfile -and (Test-Path -LiteralPath $teamRoot)){
 $teamArchive=Join-Path $teamData ($teamMode+'_backup_'+[DateTime]::UtcNow.ToString('yyyyMMddHHmmssfff'))
 Move-Item -LiteralPath $teamRoot -Destination $teamArchive
}
New-Item -ItemType Directory -Path (Join-Path $teamRoot 'app'),(Join-Path $teamRoot 'local') -Force|Out-Null
$teamPrevious=@{}
foreach($teamKey in @('APPDATA','LOCALAPPDATA','XDG_DATA_HOME','TEAM_TEST_DATA_ROOT','DUNGEON_QA_DATA_ROOT')){$teamPrevious[$teamKey]=[Environment]::GetEnvironmentVariable($teamKey,'Process')}
try{
 $env:APPDATA=Join-Path $teamRoot 'app';$env:LOCALAPPDATA=Join-Path $teamRoot 'local';$env:XDG_DATA_HOME=Join-Path $teamRoot 'app';$env:TEAM_TEST_DATA_ROOT=$teamRoot;$env:DUNGEON_QA_DATA_ROOT=$teamRoot
 $teamArgs=@('--path',$teamProject,'--rendering-method','gl_compatibility')
 if(-not $NormalProgression){$teamArgs+='res://scenes/team_test_lab.tscn'}
 if($SmokeTest){
  if(-not $EvidenceRoot -or (Test-Path -LiteralPath $EvidenceRoot)){throw 'SmokeTest requires a fresh EvidenceRoot'}
  New-Item -ItemType Directory -Path $EvidenceRoot|Out-Null
  $teamOut=Join-Path $EvidenceRoot 'stdout.log';$teamErr=Join-Path $EvidenceRoot 'stderr.log'
  $teamArgs+=@('--audio-driver','Dummy','--position','9000,100','--resolution','1152x648','--quit-after','300')
  $teamQuoted=@($teamArgs|ForEach-Object{if($_ -match '\s'){'"'+$_+'"'}else{$_}})
  $teamProcess=Start-Process -FilePath $EnginePath -ArgumentList $teamQuoted -WorkingDirectory $teamProject -WindowStyle Hidden -RedirectStandardOutput $teamOut -RedirectStandardError $teamErr -PassThru
  if(-not $teamProcess.WaitForExit(45000)){
   $teamOwned=Get-Process -Id $teamProcess.Id -ErrorAction SilentlyContinue
   if($teamOwned -and $teamOwned.Path -eq [IO.Path]::GetFullPath($EnginePath)){Stop-Process -Id $teamProcess.Id;$teamProcess.WaitForExit()}
   throw 'Owned smoke exceeded45seconds; raw logs preserved'
  }
  $teamProcess.Refresh()
  $teamRaw=@(Get-Content -LiteralPath $teamOut)+@(Get-Content -LiteralPath $teamErr)
  $teamDiagnostics=@($teamRaw|Where-Object{$_ -match '(?i)ERROR:|WARNING:|SCRIPT ERROR|FAIL:'})
  $teamStarted=[bool]($teamRaw -match $(if($NormalProgression){'PORTAL_BUILD='}else{'TEAM_TEST_READY'}))
  $teamResult=[ordered]@{passed=($teamProcess.ExitCode -eq 0 -and $teamDiagnostics.Count -eq 0 -and $teamStarted);started=$teamStarted;exitCode=$teamProcess.ExitCode;project=$teamProject;profileRoot=$teamRoot;mode=$teamMode;diagnostics=$teamDiagnostics;pid=$teamProcess.Id;ownedChildDead=$teamProcess.HasExited;engineVersion=$teamVersion}
  $teamResult|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $EvidenceRoot 'result.json') -Encoding utf8
  $teamResult|ConvertTo-Json -Compress|Write-Output
  if(-not $teamResult.passed){throw 'TEAM TEST smoke failed; raw logs preserved'}
 }else{& $EnginePath @teamArgs}
}finally{
 foreach($teamKey in $teamPrevious.Keys){[Environment]::SetEnvironmentVariable($teamKey,$teamPrevious[$teamKey],'Process')}
}
