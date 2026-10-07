param(
    [string]$EnginePath = 'D:\dowload\Godot_v4.7.2-stable_win64_console.exe',
    [switch]$IncludeLegacy,
    [switch]$IncludeComposition
)
$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$logDirectory = Join-Path $projectRoot 'docs\verification'
$previousAppData = $env:APPDATA
$previousLocalData = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $projectRoot 'isolated_appdata'
    $env:LOCALAPPDATA = Join-Path $projectRoot 'isolated_localdata'
    New-Item -ItemType Directory -Path $env:APPDATA,$env:LOCALAPPDATA,$logDirectory -Force | Out-Null
    function Invoke-FocusedCheck {
        param([string]$Name, [string[]]$EngineArgs)
        $output = & $EnginePath @EngineArgs 2>&1 | ForEach-Object { $_.ToString() }
        $exitStatus = $LASTEXITCODE
        $output | Set-Content -LiteralPath (Join-Path $logDirectory "$Name.log") -Encoding utf8
        $problems = $output | Select-String -Pattern '^(SCRIPT ERROR|ERROR|WARNING|FAIL):'
        if ($exitStatus -ne 0 -or $problems) {
            $output | Write-Output
            throw "$Name failed (exit $exitStatus); raw log retained"
        }
        Write-Output "PASS $Name (exit $exitStatus)"
        $output | Select-String -Pattern '^(RESULT|VALIDATE|METRICS|ISOLATED_USER)' | ForEach-Object { Write-Output $_.Line }
    }
    Invoke-FocusedCheck 'cultivation_validate' @('--headless','--path',$projectRoot,'--script','res://tests/validate_project.gd')
    foreach ($hz in @(60,120)) {
        Invoke-FocusedCheck "cultivation_styles_$hz" @('--headless','--path',$projectRoot,'--fixed-fps',"$hz",'--script','res://tests/cultivation_styles_test.gd','--',"--hz=$hz")
        if ($IncludeLegacy) {
            foreach ($suite in @('world_enemy','movement','combat','gear')) {
                Invoke-FocusedCheck "cultivation_legacy_${suite}_$hz" @('--headless','--path',$projectRoot,'--fixed-fps',"$hz",'--script',"res://tests/${suite}_test.gd",'--',"--hz=$hz")
            }
        }
        if ($IncludeComposition) {
            foreach ($suite in @('resonance','spell_matrix')) {
                Invoke-FocusedCheck "cultivation_composition_${suite}_$hz" @('--headless','--path',$projectRoot,'--fixed-fps',"$hz",'--script',"res://tests/${suite}_test.gd",'--',"--hz=$hz")
            }
        }
    }
    Write-Output 'FOCUSED HEADLESS CHECKS PASSED; full strict gate and GPU/playtest are separate checks'
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalData
}
