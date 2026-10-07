param([string]$SuiteLog = 'docs/verification/hades_juice_strict_suite.log')
$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
function Get-Entries {
    param([string]$Directory, [string]$Suffix)
    @(& rg --files (Join-Path $projectRoot $Directory)) |
        Where-Object { $_.EndsWith($Suffix) } |
        Sort-Object |
        ForEach-Object {
            [ordered]@{
                path = [System.IO.Path]::GetRelativePath($projectRoot, $_).Replace('\', '/')
                sha256 = (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        }
}
$manifest = [ordered]@{
    date = '2026-10-01'
    engine = '4.7.2.stable.official.ed1daf0bf'
    milestone = 'Procedural Animation, Dynamic Combat Feel, Weighted Audio and Save Transactions'
    product_scripts = @(Get-Entries 'scripts' '.gd')
    scenes = @(Get-Entries 'scenes' '.tscn')
    resources = @(Get-Entries 'data' '.tres')
    presentation_resources = @(Get-Entries 'assets/presentation' '.tres')
    presentation_pngs = @(Get-Entries 'assets/presentation' '.png')
    sprite_pngs = @(Get-Entries 'assets/sprites' '.png')
    ui_pngs = @(Get-Entries 'assets/ui' '.png')
    audio_resources = @(Get-Entries 'assets/audio' '.tres')
    environment_pngs = @(Get-Entries 'assets/environment' '.png')
    environment_resources = @(Get-Entries 'assets/environment' '.tres')
    shaders = @(Get-Entries 'shaders' '.gdshader')
    tests = @(Get-Entries 'tests' '.gd')
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $projectRoot 'docs/verification/content_manifest.json') -Encoding utf8
$lastSuite = ''
$results = @(
    foreach ($line in Get-Content -LiteralPath (Join-Path $projectRoot $SuiteLog)) {
        if ($line -match '^PASS (\w+) \(exit 0\)') { $lastSuite = $Matches[1] }
        if ($line -match '^RESULT: (\d+) checks, (\d+) failures') {
            [pscustomobject][ordered]@{suite=$lastSuite;checks=[int]$Matches[1];failures=[int]$Matches[2]}
        }
    }
)
$legacy = @('resonance', 'content_data')
foreach ($hz in @(60,120)) {
    foreach ($name in @('movement','combat','milestone','alpha','gear','storyteller','conditions','crafting','sanctuary','weapon_content','spell_matrix','relics','campaign')) {
        $legacy += "${name}_$hz"
    }
}
$legacyTotal = ($results | Where-Object { $_.suite -in $legacy } | Measure-Object -Property checks -Sum).Sum
$total = ($results | Measure-Object -Property checks -Sum).Sum
$fullVisualSuites = @()
foreach ($hz in @(60,120)) {
    foreach ($name in @('player_polish','enemy_art','combat_polish','full_visual_props','full_visual_hud')) {
        $fullVisualSuites += "${name}_$hz"
    }
}
$dynamicPolishSuites = @()
foreach ($hz in @(60,120)) {
    foreach ($name in @('procedural_actors','combat_juice','audio_weight','dynamic_vfx','save_transaction')) {
        $dynamicPolishSuites += "${name}_$hz"
    }
}
$previousMilestoneTotal = ($results | Where-Object { $_.suite -notin $fullVisualSuites -and $_.suite -notin $dynamicPolishSuites } | Measure-Object -Property checks -Sum).Sum
$fullVisualTotal = ($results | Where-Object { $_.suite -in $fullVisualSuites } | Measure-Object -Property checks -Sum).Sum
$preservedFullVisualTotal = ($results | Where-Object { $_.suite -notin $dynamicPolishSuites } | Measure-Object -Property checks -Sum).Sum
$evidence = [ordered]@{
    date='2026-10-01'
    strict_log=$SuiteLog
    all_strict_gates_passed=[bool]((Get-Content -LiteralPath (Join-Path $projectRoot $SuiteLog)) -contains 'ALL HEADLESS CHECKS PASSED')
    preserved_legacy_assertion_executions=$legacyTotal
    preserved_previous_milestone_assertion_executions=$previousMilestoneTotal
    added_full_visual_assertion_executions=$fullVisualTotal
    preserved_full_visual_assertion_executions=$preservedFullVisualTotal
    added_dynamic_polish_assertion_executions=$total-$preservedFullVisualTotal
    total_assertion_executions=$total
    added_assertion_executions=$total-$legacyTotal
    results=$results
}
$evidence | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $projectRoot 'docs/verification/polish_test_summary.json') -Encoding utf8
Write-Output "Manifest scripts=$($manifest.product_scripts.Count) scenes=$($manifest.scenes.Count) data=$($manifest.resources.Count); legacy=$legacyTotal total=$total"
