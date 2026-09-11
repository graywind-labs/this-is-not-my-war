extends SceneTree

const NPCPromptProfile = preload("res://scripts/core/NPCPromptProfile.gd")
const PROFILE_PATH := "res://data/npc_profiles.json"
const APPEARANCE_MAP_PATH := "res://data/presentation/character_appearances.json"

const EXPECTED_ANCHORS := {
	"stableman_01": ["短粗", "棕布头带", "旧皮背心", "马刷"],
	"cook_01": ["圆肩", "光秃", "暖红", "铜勺"],
	"gardener_01": ["瘦长", "头巾", "暗绿腰布", "铁锄"],
	"blacksmith_01": ["宽肩方脸", "暗绿短衫", "铁锤", "右腰"],
	"veteran_deputy_01": ["赤褐长发", "灰蓝头带", "细长眉眼", "蓝灰轻甲"],
	"priest_01": ["灰白削发冠", "暗紫长袍", "褪色金边", "木十字架"],
	"doctor_01": ["赤褐长发", "两绺发丝", "冷青蓝", "药包"],
	"engineer_01": ["短壮", "围巾", "铜框护目镜", "折尺", "木楔"],
}


func _init() -> void:
	var profiles_value = _load_json(PROFILE_PATH)
	var appearance_map_value = _load_json(APPEARANCE_MAP_PATH)
	if not profiles_value is Array or not appearance_map_value is Dictionary:
		_fail("Appearance verification inputs must be an Array and Dictionary")
		return
	var profiles: Array = profiles_value
	var characters: Dictionary = appearance_map_value.get("characters", {})
	if profiles.size() != EXPECTED_ANCHORS.size() or characters.size() != EXPECTED_ANCHORS.size():
		_fail("Expected 8 NPC profiles and 8 production appearance mappings")
		return

	var seen_texts := {}
	for profile_value in profiles:
		if not profile_value is Dictionary:
			_fail("NPC profile entry must be a Dictionary")
			return
		var profile: Dictionary = profile_value
		var npc_id := str(profile.get("id", ""))
		if not EXPECTED_ANCHORS.has(npc_id):
			_fail("Unexpected NPC profile: %s" % npc_id)
			return
		var appearance := str(profile.get("appearance", ""))
		if appearance.is_empty() or seen_texts.has(appearance):
			_fail("%s appearance must be non-empty and unique" % npc_id)
			return
		seen_texts[appearance] = true
		for anchor_value in EXPECTED_ANCHORS[npc_id]:
			var anchor := str(anchor_value)
			if not appearance.contains(anchor):
				_fail("%s appearance lost production-art anchor: %s" % [npc_id, anchor])
				return
		var prompt_setting: Dictionary = NPCPromptProfile.build_setting(profile)
		if str(prompt_setting.get("appearance", "")) != appearance:
			_fail("%s npc_setting appearance diverged from the shared profile" % npc_id)
			return
		var mapping: Dictionary = characters.get(npc_id, {})
		var scene_path := str(mapping.get("scene", ""))
		if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
			_fail("%s production character scene is missing: %s" % [npc_id, scene_path])
			return

	var cook_appearance := _appearance_for(profiles, "cook_01")
	if cook_appearance.contains("短发") or not cook_appearance.contains("光秃"):
		_fail("Bruno must match the bald production model instead of the old short-hair placeholder")
		return
	if not _appearance_for(profiles, "blacksmith_01").contains("闲时"):
		_fail("Glen's static profile must qualify the hammer's changing work pose")
		return
	if not _appearance_for(profiles, "engineer_01").contains("装配时"):
		_fail("Owen's static profile must qualify the goggles' changing work pose")
		return

	print("verify_t0158r1_npc_appearance_profiles: PASS")
	quit(0)


func _load_json(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


func _appearance_for(profiles: Array, npc_id: String) -> String:
	for profile_value in profiles:
		if profile_value is Dictionary and str(profile_value.get("id", "")) == npc_id:
			return str(profile_value.get("appearance", ""))
	return ""


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
