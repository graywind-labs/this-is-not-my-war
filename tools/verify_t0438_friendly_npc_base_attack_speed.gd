extends SceneTree

const DEFINITIONS_PATH := "res://data/weapon_defs.json"
const OLD_INTERVALS := {"sword_shield": 1.35, "polearm": 1.65, "bow": 1.5, "crossbow": 2.4}


func _init() -> void:
	var file := FileAccess.open(DEFINITIONS_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	if not parsed is Array:
		_fail("Could not parse weapon definitions")
		return
	var by_id := {}
	for value: Variant in parsed:
		if value is Dictionary:
			by_id[str(value.get("id", ""))] = value
	for weapon_id: String in OLD_INTERVALS:
		var definition: Dictionary = by_id.get(weapon_id, {})
		var actual_interval := float(definition.get("attack_interval", 0.0))
		var expected_speed := 1.0 / float(OLD_INTERVALS[weapon_id]) - 0.1
		if actual_interval <= 0.0 or not is_equal_approx(1.0 / actual_interval, expected_speed):
			_fail("%s base speed was not reduced by exactly 0.1 attacks/s" % weapon_id)
			return
	print("T0438 friendly NPC base attack-speed verification passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
