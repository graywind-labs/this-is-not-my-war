$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$godotCommand = Get-Command godot_console -ErrorAction SilentlyContinue
if ($null -eq $godotCommand) {
    $godotCommand = Get-Command godot -ErrorAction Stop
}

$slotIds = @(
    "wall_slot_01",
    "wall_slot_02",
    "wall_slot_03",
    "wall_slot_04",
    "main_hall_slot_01",
    "main_hall_slot_02",
    "main_hall_slot_03",
    "main_hall_slot_04"
)
$deviceIds = @("wall_arrow_tower", "wall_ballista")
$failedCases = [System.Collections.Generic.List[string]]::new()

try {
    foreach ($deviceId in $deviceIds) {
        foreach ($slotId in $slotIds) {
            $env:T0263_SLOT_ID = $slotId
            $env:T0263_DEVICE_ID = $deviceId
            & $godotCommand.Source --headless --path $projectRoot --script res://tools/verify_t0263_enemy_ranged_all_defense_slots.gd
            if ($LASTEXITCODE -ne 0) {
                $failedCases.Add("$slotId/$deviceId")
            }
        }
    }
}
finally {
    Remove-Item Env:T0263_SLOT_ID -ErrorAction SilentlyContinue
    Remove-Item Env:T0263_DEVICE_ID -ErrorAction SilentlyContinue
}

if ($failedCases.Count -gt 0) {
    throw "T0263 failed cases: $($failedCases -join ', ')"
}

Write-Output "T0263_ALL_16_DEFENSE_SLOT_DEVICE_CASES_OK"
