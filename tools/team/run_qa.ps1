param(
    [Parameter(Mandatory=$true)][string]$EnginePath,
    [ValidateSet('Import','Smoke','Test','Play')][string]$Mode = 'Smoke',
    [string]$Script = '',
    [string]$QaDataRoot = '',
    [ValidateRange(1,60)][int]$TimeoutSeconds = 60
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$engineExe = [IO.Path]::GetFullPath($EnginePath)
if (-not (Test-Path -LiteralPath $engineExe -PathType Leaf)) { throw "Engine missing: $engineExe" }
$version = (& $engineExe --version | Out-String).Trim()
if ($version -notmatch '^4\.7\.2\.stable') { throw "Expected Godot 4.7.2 stable, got: $version" }
if ($QaDataRoot -eq '') { $QaDataRoot = Join-Path ([IO.Path]::GetTempPath()) ('DungeonTeamQA_' + [guid]::NewGuid().ToString('N')) }
$QaDataRoot = [IO.Path]::GetFullPath($QaDataRoot)
if ($QaDataRoot.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or $QaDataRoot -eq $projectRoot) { throw 'QA save directory must be outside the project.' }
$arguments = @('--path', $projectRoot)
switch ($Mode) {
    'Import' { $arguments += @('--headless','--editor','--import') }
    'Smoke' { $arguments += @('--headless','--quit-after','12') }
    'Test' {
        if ($Script -notmatch '^res://tests/[a-zA-Z0-9_/-]+\.gd$') { throw 'Use a res://tests/...gd script path.' }
        $testPath = Join-Path $projectRoot $Script.Substring(6)
        if (-not (Test-Path -LiteralPath $testPath -PathType Leaf)) { throw "Test missing: $Script" }
        $arguments += @('--headless','--script',$Script)
    }
    'Play' { }
}
$appDataDir = Join-Path $QaDataRoot 'AppData'
$localDataDir = Join-Path $QaDataRoot 'LocalAppData'
$evidenceDir = Join-Path $QaDataRoot 'evidence'
New-Item -ItemType Directory -Path $appDataDir,$localDataDir,$evidenceDir -Force | Out-Null
$savedEnvironment = @{}
foreach ($key in @('APPDATA','LOCALAPPDATA','DUNGEON_QA_DATA_ROOT','DUNGEON_QA_EVIDENCE_ROOT')) {
    $savedEnvironment[$key] = [Environment]::GetEnvironmentVariable($key,'Process')
}
$stdoutPath = Join-Path $evidenceDir ($Mode + '.stdout.log')
$stderrPath = Join-Path $evidenceDir ($Mode + '.stderr.log')
$started = [DateTimeOffset]::UtcNow
try {
    $env:APPDATA = $appDataDir
    $env:LOCALAPPDATA = $localDataDir
    $env:DUNGEON_QA_DATA_ROOT = $QaDataRoot
    $env:DUNGEON_QA_EVIDENCE_ROOT = $evidenceDir
    $quoted = $arguments | ForEach-Object { '"' + $_ + '"' }
    $process = Start-Process -FilePath $engineExe -ArgumentList $quoted -WorkingDirectory $projectRoot -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru
    if ($Mode -eq 'Play') {
        Write-Output "QA game PID=$($process.Id); save/evidence=$QaDataRoot"
        Write-Output 'Bring this QA game to the secondary screen manually; close it normally when done.'
        return
    }
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) {
        $owned = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
        if ($owned -and $owned.Path -eq $engineExe) { Stop-Process -Id $owned.Id }
        $process.WaitForExit()
    }
    $process.Refresh()
    $raw = @(Get-Content -LiteralPath $stdoutPath) + @(Get-Content -LiteralPath $stderrPath)
    $raw | Write-Output
    $diagnostics = @($raw | Where-Object { $_ -match '(?i)(ERROR:|WARNING:|SCRIPT ERROR|FAIL:)' })
    $receipt = [ordered]@{
        mode=$Mode; engine=$version; engine_sha256=(Get-FileHash -LiteralPath $engineExe -Algorithm SHA256).Hash.ToLower()
        project=$projectRoot; main='res://scenes/maps/prologue_hub.tscn'; script=$Script
        qa_data_root=$QaDataRoot; args=$arguments; started_utc=$started.ToString('o')
        exit_code=$process.ExitCode; timeout=$timedOut; diagnostics=$diagnostics
        stdout=$stdoutPath; stderr=$stderrPath
    }
    $receipt | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $evidenceDir ($Mode + '.receipt.json')) -Encoding utf8
    if ($timedOut -or $process.ExitCode -ne 0 -or $diagnostics.Count -ne 0) { throw "QA $Mode failed; inspect raw logs in $evidenceDir" }
    Write-Output "QA $Mode passed; raw logs/receipt=$evidenceDir"
}
finally {
    foreach ($key in $savedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($key,$savedEnvironment[$key],'Process') }
}
