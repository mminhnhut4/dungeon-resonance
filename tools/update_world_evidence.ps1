param([Parameter(Mandatory)][string]$SuiteLog)
$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$logPath = Join-Path $projectRoot $SuiteLog
$lines = @(Get-Content -LiteralPath $logPath)
if ($lines -notcontains 'ALL HEADLESS CHECKS PASSED' -or ($lines | Select-String -Pattern '^(SCRIPT ERROR|ERROR|WARNING|FAIL|FAILED):?')) {
    throw 'A clean complete strict gate is required before publishing passing evidence.'
}
$lastSuite = ''
$results = @(
    foreach ($line in $lines) {
        if ($line -match '^PASS (\w+) \(exit 0\)') { $lastSuite = $Matches[1] }
        if ($line -match '^RESULT: (\d+) checks, (\d+) failures') {
            [pscustomobject][ordered]@{ suite = $lastSuite; checks = [int]$Matches[1]; failures = [int]$Matches[2] }
        }
    }
)
if ($results.Count -eq 0 -or ($results | Measure-Object -Property failures -Sum).Sum -ne 0) { throw 'Missing or failing assertion results.' }
$gateNames = @($lines | Where-Object { $_ -match '^PASS \w+ \(exit 0\)' })
foreach ($requiredGate in @('import','addons','addon_entrypoints','addon_editor_scene','addon_lifecycle','validate','player_rig_editor','main_scene')) {
    if ($gateNames -notcontains "PASS $requiredGate (exit 0)") { throw "Missing complete gate: $requiredGate" }
}
foreach ($hz in @(60,120)) {
    foreach ($entry in @{movement=55; combat=100}.GetEnumerator()) {
        $matched = @($results | Where-Object { $_.suite -eq "$($entry.Key)_$hz" })
        if ($matched.Count -ne 1 -or $matched[0].checks -ne $entry.Value) { throw "Legacy count changed: $($entry.Key)_$hz" }
    }
}
$newNames = @('damage_numbers','loot_affix','economy','prologue_hub','campfire_audio','prologue_visual','world_weapons','world_enemy','world_economy','npc_dialogue')
$newResults = @($results | Where-Object { $name = $_.suite -replace '_(60|120)$',''; $name -in $newNames })
$summary = [ordered]@{
    date='2026-10-01'; engine='4.7.2.stable.official.ed1daf0bf'; milestone='Prologue Hub and World-Building Ecosystem'
    strict_log=$SuiteLog; all_strict_gates_passed=$true; strict_gate_count=$gateNames.Count
    result_count=$results.Count; total_assertion_executions=($results | Measure-Object -Property checks -Sum).Sum
    prologue_world_assertion_executions=($newResults | Measure-Object -Property checks -Sum).Sum
    failures=0; results=$results
}
function Get-Entries {
    param([string]$Directory,[string]$Suffix)
    @(& rg --files (Join-Path $projectRoot $Directory)) | Where-Object { $_.EndsWith($Suffix) } | Sort-Object | ForEach-Object {
        [ordered]@{path=[System.IO.Path]::GetRelativePath($projectRoot,$_).Replace('\','/'); sha256=(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant()}
    }
}
$manifest = [ordered]@{
    date='2026-10-01'; engine=$summary.engine; milestone=$summary.milestone; strict_log=$SuiteLog
    project=@{path='project.godot';sha256=(Get-FileHash -LiteralPath (Join-Path $projectRoot 'project.godot') -Algorithm SHA256).Hash.ToLowerInvariant()}
    product_scripts=@(Get-Entries 'scripts' '.gd'); scenes=@(Get-Entries 'scenes' '.tscn'); resources=@(Get-Entries 'data' '.tres')
    presentation_resources=@(Get-Entries 'assets/presentation' '.tres'); presentation_pngs=@(Get-Entries 'assets/presentation' '.png')
    sprite_pngs=@(Get-Entries 'assets/sprites' '.png'); sprite_resources=@(Get-Entries 'assets/sprites' '.tres')
    ui_pngs=@(Get-Entries 'assets/ui' '.png'); ui_resources=@(Get-Entries 'assets/ui' '.tres')
    audio_resources=@(Get-Entries 'assets/audio' '.tres'); environment_pngs=@(Get-Entries 'assets/environment' '.png'); environment_resources=@(Get-Entries 'assets/environment' '.tres')
    shaders=@(Get-Entries 'shaders' '.gdshader'); tests=@(Get-Entries 'tests' '.gd')
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $projectRoot 'docs/verification/content_manifest.json') -Encoding utf8
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $projectRoot 'docs/verification/world_building_test_summary.json') -Encoding utf8
Write-Output "PASS evidence: $($summary.total_assertion_executions) assertions; $($summary.strict_gate_count) strict gates; scripts=$($manifest.product_scripts.Count) scenes=$($manifest.scenes.Count) data=$($manifest.resources.Count)"
