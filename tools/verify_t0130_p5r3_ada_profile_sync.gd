extends SceneTree


const NPCPromptProfile = preload("res://scripts/core/NPCPromptProfile.gd")
const NPC_ID := "veteran_deputy_01"
const EXPECTED_APPEARANCE := "赤褐色头发用灰蓝头带束起，眉眼利落，蓝灰色轻甲和护腕收拾得一丝不乱。"


func _init() -> void:
	var file := FileAccess.open("res://data/npc_profiles.json", FileAccess.READ)
	if file == null:
		_fail("npc_profiles.json unavailable")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Array:
		_fail("npc_profiles.json root is not an array")
		return
	var ada: Dictionary = {}
	for profile_value in parsed:
		var profile: Dictionary = profile_value if profile_value is Dictionary else {}
		if str(profile.get("id", "")) == NPC_ID:
			ada = profile
			break
	if ada.is_empty():
		_fail("Ada profile unavailable")
		return
	if str(ada.get("appearance", "")) != EXPECTED_APPEARANCE:
		_fail("Ada appearance does not match the current ShieldMaiden art")
		return
	if str(ada.get("background_story", "")).is_empty():
		_fail("Ada background story was damaged")
		return
	var setting := NPCPromptProfile.build_setting(ada)
	if str(setting.get("appearance", "")) != EXPECTED_APPEARANCE:
		_fail("Ada appearance did not reach npc_setting")
		return
	if setting.has("signature_lines"):
		_fail("Ada npc_setting reintroduced fixed signature lines")
		return
	print("T0130-P5R3 Ada profile sync verification passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
