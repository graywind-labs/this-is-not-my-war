extends SceneTree


func _init() -> void:
	var file := FileAccess.open("res://data/tutorial_config.json", FileAccess.READ)
	var config = JSON.parse_string(file.get_as_text()) if file != null else null
	if not config is Dictionary:
		_fail("T0444 could not load tutorial configuration")
		return
	var raid: Dictionary = (config as Dictionary).get("tutorial_raid", {})
	if raid.has("defense_device_damage_multiplier"):
		_fail("T0444 tutorial device damage multiplier still exists")
		return
	var combat_source := FileAccess.get_file_as_string("res://scripts/systems/CombatSystem.gd")
	if combat_source.contains("defense_device_damage_multiplier") or combat_source.contains("tutorial_defense_device_damage_multiplier"):
		_fail("T0444 CombatSystem still contains a tutorial device damage multiplier path")
		return
	var enemies: Array = raid.get("enemies", [])
	if enemies.is_empty():
		_fail("T0444 tutorial enemy configuration is missing")
		return
	var attack_power := float((enemies[0] as Dictionary).get("attack_power", 0.0))
	var defense := 3.0
	var penetration := float((enemies[0] as Dictionary).get("penetration", 0.0))
	var effective_defense := maxf(0.0, defense - penetration)
	var damage := maxi(1, int(round(attack_power * 20.0 / (20.0 + effective_defense))))
	if damage != 5 or ceili(15.0 / float(damage)) != 3:
		_fail("T0444 expected 5 damage per hit and destruction on hit 3")
		return
	print("T0444 tutorial device damage verified: 5 per hit, destroyed on hit 3")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
