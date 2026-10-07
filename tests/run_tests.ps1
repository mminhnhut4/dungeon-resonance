param(
    [string]$EnginePath = 'D:\dowload\Godot_v4.7.2-stable_win64_console.exe',
    [switch]$GameplayOnly,
    [switch]$CollectAllFailures,
    [string]$QaDataRoot = '',
    [int]$CheckTimeoutSeconds = 60
)
$ErrorActionPreference = 'Stop'
$checkFailures = [System.Collections.Generic.List[string]]::new()
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$logDirectory = Join-Path $projectRoot 'docs\verification'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
if (-not (Test-Path -LiteralPath $EnginePath -PathType Leaf)) {
    throw "Godot executable does not exist: $EnginePath"
}
$processEnginePath = [IO.Path]::GetFullPath($EnginePath)
if ($processEnginePath.EndsWith('_console.exe',[StringComparison]::OrdinalIgnoreCase)) {
    $mainEnginePath = $processEnginePath.Substring(0,$processEnginePath.Length-'_console.exe'.Length)+'.exe'
    if (Test-Path -LiteralPath $mainEnginePath -PathType Leaf) { $processEnginePath = $mainEnginePath }
}
if ($CheckTimeoutSeconds -lt 1 -or $CheckTimeoutSeconds -gt 60) { throw 'Check timeout must be from 1 to 60 seconds.' }
if ($QaDataRoot -eq '') { $QaDataRoot = Join-Path ([IO.Path]::GetTempPath()) ('DungeonResonanceStrict_' + [guid]::NewGuid().ToString('N')) }
$QaDataRoot = [IO.Path]::GetFullPath($QaDataRoot).TrimEnd('\','/')
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
$previousQaDataRoot = $env:DUNGEON_QA_DATA_ROOT
$previousEvidenceRoot = $env:DUNGEON_QA_EVIDENCE_ROOT
New-Item -ItemType Directory -Path (Join-Path $QaDataRoot 'AppData'),(Join-Path $QaDataRoot 'LocalAppData') -Force | Out-Null
$env:APPDATA = Join-Path $QaDataRoot 'AppData'
$env:LOCALAPPDATA = Join-Path $QaDataRoot 'LocalAppData'
$env:DUNGEON_QA_DATA_ROOT = $QaDataRoot
$env:DUNGEON_QA_EVIDENCE_ROOT = Join-Path $logDirectory 'opening_final_captures'
try {
function Invoke-GodotCheck {
    param([string]$Name, [string[]]$EngineArgs)
    $stdoutPath = Join-Path $logDirectory "$Name.stdout.log"
    $stderrPath = Join-Path $logDirectory "$Name.stderr.log"
    $quotedArguments = @($EngineArgs | ForEach-Object { if ($_ -match '\s') { '"'+$_+'"' } else { $_ } })
    $checkProcess = Start-Process -FilePath $processEnginePath -ArgumentList $quotedArguments -WorkingDirectory $projectRoot -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru
    $timedOut = -not $checkProcess.WaitForExit($CheckTimeoutSeconds * 1000)
    if ($timedOut) {
        $ownedProcess = Get-Process -Id $checkProcess.Id -ErrorAction SilentlyContinue
        if ($ownedProcess -and $ownedProcess.Path -eq $processEnginePath) { Stop-Process -Id $ownedProcess.Id }
    }
    $checkProcess.Refresh()
    $testOutput = @(Get-Content -LiteralPath $stdoutPath) + @(Get-Content -LiteralPath $stderrPath)
    $exitStatus = if ($timedOut) { -1 } else { $checkProcess.ExitCode }
    if ($timedOut) { $testOutput += "ERROR: Verification $Name exceeded $CheckTimeoutSeconds seconds; only its owned child was targeted." }
    $testOutput | Set-Content -LiteralPath (Join-Path $logDirectory "$Name.log") -Encoding utf8
    $problems = $testOutput | Select-String -Pattern '^(SCRIPT ERROR|ERROR|WARNING|FAIL):|Unicode parsing error'
    if ($exitStatus -ne 0 -or $problems) {
        if ($CollectAllFailures) {
            Write-Output "FAILED $Name (exit $exitStatus)"
            $testOutput | Write-Output
            $checkFailures.Add("$Name (exit $exitStatus)")
            return
        }
        $testOutput | Write-Output
        throw "$Name failed (exit $exitStatus)"
    }
    $summary = $testOutput | Select-String -Pattern '^(RESULT|VALIDATE|STRESS)'
    Write-Output "PASS $Name (exit $exitStatus)"
    $summary | ForEach-Object { Write-Output $_.Line }
}
if ($GameplayOnly) {
    Write-Output 'GAMEPLAY-ONLY RUN: editor plugin shutdown/import check excluded; see docs/ADDONS.md.'
} else {
    Invoke-GodotCheck 'import' @('--headless', '--path', $projectRoot, '--import', '--verbose')
    Invoke-GodotCheck 'addons' @('--headless', '--path', $projectRoot, '--script', 'res://tests/addon_test.gd')
    Invoke-GodotCheck 'addon_entrypoints' @('--headless', '--path', $projectRoot, '--script', 'res://tests/addon_cleanup_entrypoints.gd', '--verbose')
    Invoke-GodotCheck 'addon_editor_scene' @('--headless', '--path', $projectRoot, '--editor', 'res://addons/rmsmartshape/addon_cleanup_editor_fixture.tscn', '--quit-after', '60', '--verbose')
    Invoke-GodotCheck 'addon_lifecycle' @('--headless', '--path', $projectRoot, '--script', 'res://tests/addon_cleanup_lifecycle.gd', '--verbose')
}
Invoke-GodotCheck 'validate' @('--headless', '--path', $projectRoot, '--script', 'res://tests/validate_project.gd')
Invoke-GodotCheck 'player_rig_editor' @('--headless', '--path', $projectRoot, '--editor', 'res://scenes/actors/player_visual_rig.tscn', '--quit-after', '60', '--verbose')
Invoke-GodotCheck 'main_scene' @('--headless', '--path', $projectRoot, '--quit-after', '180')
Invoke-GodotCheck 'resonance' @('--headless', '--path', $projectRoot, '--script', 'res://tests/resonance_test.gd')
Invoke-GodotCheck 'content_data' @('--headless', '--path', $projectRoot, '--script', 'res://tests/content_data_test.gd')
Invoke-GodotCheck 'asset_pipeline' @('--headless', '--path', $projectRoot, '--script', 'res://tests/asset_pipeline_test.gd')
Invoke-GodotCheck 'audio_quit' @('--headless', '--path', $projectRoot, '--script', 'res://tests/audio_quit_test.gd')
Invoke-GodotCheck 'antique_icon_catalog_audit' @('--headless', '--path', $projectRoot, '--script', 'res://tests/antique_icon_catalog_audit.gd')
foreach ($tickRate in @(60, 120)) {
    foreach ($suiteName in @('movement', 'combat', 'milestone', 'alpha', 'gear', 'storyteller', 'conditions', 'crafting', 'sanctuary', 'weapon_content', 'spell_matrix', 'relics', 'campaign', 'audio', 'vfx', 'polish', 'player_rig', 'player_art', 'foyer_art', 'game_feel', 'player_polish', 'enemy_art', 'combat_polish', 'full_visual_props', 'full_visual_hud', 'procedural_actors', 'combat_juice', 'audio_weight', 'dynamic_vfx', 'save_transaction', 'inventory_equipment', 'modular_equipment', 'modular_rig', 'character_feedback', 'armor', 'starter_character', 'starter_flow', 'combat_visuals', 'movement_visual', 'hit_reaction', 'death_ground', 'affliction_visuals', 'damage_numbers', 'loot_affix', 'economy', 'prologue_hub', 'campfire_audio', 'prologue_visual', 'world_weapons', 'world_enemy', 'world_economy', 'npc_dialogue', 'travel_clocks', 'traversal_lab', 'exterior_route', 'npc_population', 'pilgrimage_presentation', 'pilgrimage_audio', 'ui_ux', 'item_icon', 'opening_qa_gate', 'opening_loop', 'slice_presentation_lifetime', 'debug_overlay_lifetime', 'npc_lived_opening', 'opening_enemy_polish', 'region_entry_card', 'region_ui_probe', 'opening_cultivation_state', 'opening_npc_life_adapter', 'opening_profile_writer', 'opening_scope_migration', 'profile_json_spans', 'opening_social_quarantine', 'opening_style_binding', 'cultivation_styles', 'opening_cultivation_gameplay', 'opening_owner_review_r2', 'antique_service_ui', 'two_column_service_ui', 'map_quest', 'opening_combined_owner', 'opening_runtime_wiring', 'opening_progression_guide', 'progression_acquisition_repro', 'opening_progression_recovery', 'campfire_ui', 'campfire_guide_coexist')) {
        $engineArguments = @('--headless', '--path', $projectRoot, '--fixed-fps', "$tickRate", '--script', "res://tests/${suiteName}_test.gd")
        if ($tickRate -eq 120) { $engineArguments += @('--', '--hz=120') }
        if ($suiteName -in @('opening_qa_gate', 'opening_loop')) {
            if ($tickRate -eq 60) { $engineArguments += '--' }
            $rootFlag = if ($suiteName -eq 'opening_qa_gate') { '--qa-user-root=' } else { '--opening-user-root=' }
            $engineArguments += $rootFlag + $QaDataRoot.Replace('\','/')
        }
        Invoke-GodotCheck "${suiteName}_$tickRate" $engineArguments
    }
}
if ($checkFailures.Count -gt 0) {
    Write-Output "STRICT CHECKS FAILED: $($checkFailures -join ', ')"
    throw 'One or more checks failed. Logs include every failure; this is not a passing gate.'
}
if ($GameplayOnly) {
    Write-Output 'ALL SOURCE AND GAMEPLAY HEADLESS CHECKS PASSED (EDITOR ADDON SHUTDOWN EXCLUDED)'
} else {
    Write-Output 'ALL HEADLESS CHECKS PASSED'
}
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
    $env:DUNGEON_QA_DATA_ROOT = $previousQaDataRoot
    $env:DUNGEON_QA_EVIDENCE_ROOT = $previousEvidenceRoot
}



