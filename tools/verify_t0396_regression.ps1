param([string]$GodotPath = "godot", [string]$BaselineCombatPath = "", [string[]]$Scripts = @(
    "verify_t0396_combat_optimization.gd",
    "verify_t0243_guided_attack_zones.gd",
    "verify_t0141_formal_enemy_dev_lab_reuse.gd",
    "verify_t0142_combat_animation_timeline.gd",
    "verify_t0185_combat_presentation_time_contract.gd",
    "verify_t0133_combat_art_completion.gd",
    "verify_t0133_r1_enemy_corpse_linger.gd",
    "verify_t0236_enemy_locomotion_presentation.gd",
    "verify_combat_damage.gd",
    "verify_t0262_enemy_ranged_main_hall_device_hit.gd",
    "verify_t0186_melee_engagement_stability.gd",
    "verify_t0129c_a5_p2_default_fifth_wave_pressure.gd",
    "verify_five_wave_victory.gd",
    "verify_main_hall_failure.gd"
))

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$outputRoot = Join-Path $projectRoot "artifacts/performance/t0396/regression"
if ($BaselineCombatPath) { $outputRoot = Join-Path $projectRoot "artifacts/performance/t0396/regression_baseline" }
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
$runArguments = @()
if ($BaselineCombatPath) {
    $baseline = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $BaselineCombatPath), [Text.Encoding]::UTF8)
    $baseline = $baseline -replace '(?m)^class_name CombatSystem\r?\n', ''
    [IO.File]::WriteAllText((Join-Path $outputRoot "CombatSystem.gd"), $baseline, [Text.UTF8Encoding]::new($false))
    $runArguments = @("--", "--baseline-combat")
}
$results = @()
foreach ($scriptName in $Scripts) {
    if ($scriptName -notmatch '^verify_[a-zA-Z0-9_]+\.gd$') { throw "Invalid fixture name" }
    $original = Join-Path $PSScriptRoot $scriptName
    $source = [IO.File]::ReadAllText($original, [Text.Encoding]::UTF8)
    if ($source -notmatch '^extends SceneTree') { throw "Not a SceneTree fixture: $scriptName" }
    # Mechanical test-only copy: assertions and gameplay fixture are unchanged.
    $source = $source -replace '^extends SceneTree', 'extends "res://tools/T0396OfflineSceneTree.gd"'
    $generated = Join-Path $outputRoot $scriptName
    [IO.File]::WriteAllText($generated, $source, [Text.UTF8Encoding]::new($false))
    Write-Output "RUN $scriptName"
    $log = Join-Path $outputRoot ($scriptName + ".log")
    $ErrorActionPreference = "Continue" # Native stderr warnings are not fixture exit failures.
    & $GodotPath --headless --path $projectRoot --script $generated @runArguments 2>&1 | Tee-Object -FilePath $log
    $code = $LASTEXITCODE
    $ErrorActionPreference = "Stop"
    $results += [PSCustomObject]@{ script = $scriptName; exit_code = $code; log = $log }
    Write-Output "RESULT $scriptName exit=$code"
}
$results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $outputRoot "results.json") -Encoding UTF8
if (@($results | Where-Object { $_.exit_code -ne 0 }).Count -gt 0) { exit 1 }
exit 0
