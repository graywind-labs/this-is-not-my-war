param(
    [string]$GodotPath = "godot"
)

$ErrorActionPreference = "Stop"

$verificationScripts = @(
    "verify_t0129c_a3a_production_navigation.gd",
    "verify_t0130_d1_npc_dev_lab.gd",
    "verify_t0141_formal_enemy_dev_lab_reuse.gd",
    "verify_t0142_combat_animation_timeline.gd",
    "verify_t0143_physical_ranged_projectiles.gd",
    "verify_t0144_melee_model_contact.gd",
    "verify_t0145_projectile_attack_id.gd",
    "verify_t0146_ranged_combat_matrix.gd",
    "verify_t0147_defense_device_physical_attack.gd",
    "verify_t0148_defense_device_host_proxy.gd",
    "verify_t0149_enemy_attack_position_leases.gd",
    "verify_t0150_enemy_target_priority.gd",
    "verify_t0151_attack_range_indicator.gd",
    "verify_t0152_formal_dialogue_gestures.gd",
    "verify_t0153_proactive_talk_gestures.gd",
    "verify_t0154_portrait_and_dialogue_hit_feedback.gd",
    "verify_t0155_npc_locomotion_modes.gd",
    "verify_combat_flow.gd",
    "verify_combat_damage.gd",
    "verify_combat_pacing.gd",
    "verify_combat_strategies.gd",
    "verify_t0107_combat_foundation.gd",
    "verify_five_wave_victory.gd",
    "verify_main_hall_failure.gd",
    "verify_no_available_combatants_failure.gd",
    "verify_t0121_fifth_wave_build.gd",
    "verify_t0129c_a4_p7_dynamic_combat_pressure.gd",
    "verify_t0129c_a5_p2_default_fifth_wave_pressure.gd",
    "verify_t0129c_a5_p8_formal_spatial_save.gd",
    "verify_mounted_combat_lifecycle.gd",
    "verify_mounted_fall_animation.gd",
    "verify_enemy_mounted_defeat_escape.gd",
    "verify_gm_panel.gd"
)

$failedScripts = @()
foreach ($scriptName in $verificationScripts) {
    Write-Output "RUN $scriptName"
    & $GodotPath --headless --path . --script "res://tools/$scriptName"
    if ($LASTEXITCODE -ne 0) {
        $failedScripts += $scriptName
        Write-Output "FAIL $scriptName"
    }
    else {
        Write-Output "PASS $scriptName"
    }
}

if ($failedScripts.Count -gt 0) {
    Write-Error "T0156 regression failed: $($failedScripts -join ', ')"
    exit 1
}

Write-Output "T0156 FULL REGRESSION PASS ($($verificationScripts.Count) scripts)"
exit 0
