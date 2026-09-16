extends SceneTree

const HP_MULTIPLIER := 1.3
const ATTACK_MULTIPLIER := 1.5
const EXPECTED_FORMAL_BASELINES := {
	"wave_01/raider_sword": {"hp": 33, "attack_power": 4},
	"wave_02/raider_sword": {"hp": 34, "attack_power": 4},
	"wave_02/raider_polearm": {"hp": 30, "attack_power": 5},
	"wave_03/raider_sword": {"hp": 36, "attack_power": 5},
	"wave_03/raider_archer": {"hp": 24, "attack_power": 4},
	"wave_04/raider_sword": {"hp": 34, "attack_power": 4},
	"wave_04/raider_polearm": {"hp": 34, "attack_power": 6},
	"wave_04/raider_crossbow": {"hp": 26, "attack_power": 6},
	"wave_04/raider_cavalry": {"hp": 42, "attack_power": 7},
	"wave_05/raider_sword": {"hp": 34, "attack_power": 4},
	"wave_05/raider_polearm": {"hp": 30, "attack_power": 5},
	"wave_05/raider_sword_veteran": {"hp": 44, "attack_power": 7},
	"wave_05/raider_crossbow": {"hp": 28, "attack_power": 7},
	"wave_05/raider_mounted_archer": {"hp": 36, "attack_power": 6}
}
const EXPECTED_TUTORIAL_STATS := {
	"tutorial_raid_prologue/tutorial_raider_sword": {"hp": 52, "attack_power": 6}
}


func _init() -> void:
	var formal_data := _load_json_array("res://data/enemy_waves.json")
	if formal_data.is_empty():
		_fail("Formal enemy wave data could not be loaded.")
		return
	var formal_groups: Array[Dictionary] = []
	for raw_wave in formal_data:
		var wave: Dictionary = raw_wave if raw_wave is Dictionary else {}
		var wave_id := str(wave.get("id", ""))
		for raw_enemy in (wave.get("enemies", []) as Array):
			var enemy: Dictionary = raw_enemy if raw_enemy is Dictionary else {}
			formal_groups.append({
				"key": "%s/%s" % [wave_id, str(enemy.get("enemy_type_id", ""))],
				"enemy": enemy
			})
	if not _verify_groups(formal_groups, EXPECTED_FORMAL_BASELINES, "formal"):
		return

	var tutorial_data := _load_json_dictionary("res://data/tutorial_config.json")
	if tutorial_data.is_empty():
		_fail("Tutorial config could not be loaded.")
		return
	var tutorial_raid: Dictionary = tutorial_data.get("tutorial_raid", {})
	var tutorial_groups: Array[Dictionary] = []
	for raw_enemy in (tutorial_raid.get("enemies", []) as Array):
		var enemy: Dictionary = raw_enemy if raw_enemy is Dictionary else {}
		tutorial_groups.append({
			"key": "%s/%s" % [str(tutorial_raid.get("id", "")), str(enemy.get("enemy_type_id", ""))],
			"enemy": enemy
		})
	if not _verify_exact_groups(tutorial_groups, EXPECTED_TUTORIAL_STATS, "tutorial"):
		return

	print("T0414 enemy stat increase verification passed: %d formal groups and %d tutorial groups." % [
		formal_groups.size(),
		tutorial_groups.size()
	])
	quit(0)


func _verify_groups(groups: Array[Dictionary], baselines: Dictionary, scope: String) -> bool:
	if groups.size() != baselines.size():
		_fail("T0414 %s enemy group count changed: expected=%d actual=%d" % [scope, baselines.size(), groups.size()])
		return false
	var seen := {}
	for group in groups:
		var key := str(group.get("key", ""))
		var enemy: Dictionary = group.get("enemy", {})
		if not baselines.has(key):
			_fail("T0414 found an untracked %s enemy group: %s" % [scope, key])
			return false
		if seen.has(key):
			_fail("T0414 found a duplicate %s enemy group: %s" % [scope, key])
			return false
		seen[key] = true
		var baseline: Dictionary = baselines[key]
		var expected_hp := int(round(float(baseline.get("hp", 0)) * HP_MULTIPLIER))
		var expected_attack := int(round(float(baseline.get("attack_power", 0)) * ATTACK_MULTIPLIER))
		var hp := int(enemy.get("hp", 0))
		var max_hp := int(enemy.get("max_hp", 0))
		var attack_power := int(enemy.get("attack_power", 0))
		if hp != expected_hp or max_hp != expected_hp or attack_power != expected_attack:
			_fail(
				"T0414 %s stats mismatch: expected hp/max_hp=%d attack=%d, actual hp/max_hp=%d/%d attack=%d" % [
					key,
					expected_hp,
					expected_attack,
					hp,
					max_hp,
					attack_power
				]
			)
			return false
	return true


func _verify_exact_groups(groups: Array[Dictionary], expected_stats: Dictionary, scope: String) -> bool:
	if groups.size() != expected_stats.size():
		_fail("T0414 %s enemy group count changed: expected=%d actual=%d" % [scope, expected_stats.size(), groups.size()])
		return false
	var seen := {}
	for group in groups:
		var key := str(group.get("key", ""))
		var enemy: Dictionary = group.get("enemy", {})
		if not expected_stats.has(key) or seen.has(key):
			_fail("T0414 found an untracked or duplicate %s enemy group: %s" % [scope, key])
			return false
		seen[key] = true
		var expected: Dictionary = expected_stats[key]
		var hp := int(enemy.get("hp", 0))
		var max_hp := int(enemy.get("max_hp", 0))
		var attack_power := int(enemy.get("attack_power", 0))
		if hp != int(expected.get("hp", 0)) or max_hp != hp or attack_power != int(expected.get("attack_power", 0)):
			_fail("T0414 %s current stats mismatch: %s" % [scope, str(enemy)])
			return false
	return true


func _load_json_array(path: String) -> Array:
	var parsed = _load_json(path)
	return parsed if parsed is Array else []


func _load_json_dictionary(path: String) -> Dictionary:
	var parsed = _load_json(path)
	return parsed if parsed is Dictionary else {}


func _load_json(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
