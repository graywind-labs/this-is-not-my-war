extends SceneTree

const PROFILE_PATH := "res://data/npc_profiles.json"
const EXPECTED_HP := {"stableman_01": 83, "cook_01": 87, "gardener_01": 75, "blacksmith_01": 100, "veteran_deputy_01": 95, "priest_01": 60, "doctor_01": 63, "engineer_01": 69}

func _initialize() -> void:
	var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file == null:
		_fail("Cannot open NPC profiles")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Array:
		_fail("NPC profiles root must be an array")
		return
	var profiles: Array = parsed
	if profiles.size() != EXPECTED_HP.size():
		_fail("Expected %d NPCs, got %d" % [EXPECTED_HP.size(), profiles.size()])
		return
	var seen := {}
	for raw_profile in profiles:
		if not raw_profile is Dictionary:
			_fail("NPC profile entry must be an object")
			return
		var profile: Dictionary = raw_profile
		var npc_id := str(profile.get("id", ""))
		if not EXPECTED_HP.has(npc_id):
			_fail("Unexpected NPC id: %s" % npc_id)
			return
		var states: Dictionary = profile.get("states", {}) if profile.get("states", {}) is Dictionary else {}
		var expected := int(EXPECTED_HP[npc_id])
		if int(states.get("hp", -1)) != expected or int(states.get("max_hp", -1)) != expected:
			_fail("%s HP mismatch: %s" % [npc_id, states])
			return
		seen[npc_id] = true
	if seen.size() != EXPECTED_HP.size():
		_fail("Not all expected NPCs were found")
		return
	print("T0428 NPC initial HP reduction verification passed")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
