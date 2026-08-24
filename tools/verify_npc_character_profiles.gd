extends SceneTree

const NPCPromptProfile = preload("res://scripts/core/NPCPromptProfile.gd")

const EXPECTED_IDENTITIES := {
	"stableman_01": {"name": "托马", "job": "马夫", "keywords": ["马", "马厩", "照料", "草料"]},
	"cook_01": {"name": "布鲁诺", "job": "厨子", "keywords": ["食堂", "饭", "餐食", "口粮"]},
	"gardener_01": {"name": "伊沃", "job": "园丁", "keywords": ["菜园", "土壤", "收成", "耕种"]},
	"blacksmith_01": {"name": "格伦", "job": "铁匠", "keywords": ["铁", "工序", "装备", "修理"]},
	"veteran_deputy_01": {
		"name": "艾达",
		"job": "老兵副官",
		"keywords": ["风险", "命令", "职责", "安排"],
		"appearance": "赤褐色头发用灰蓝头带束起，眉眼利落，蓝灰色轻甲和护腕收拾得一丝不乱。",
	},
	"priest_01": {"name": "马塞尔", "job": "神父", "keywords": ["祈祷", "弥撒", "信仰", "残酷"]},
	"doctor_01": {"name": "莉娜", "job": "医生", "keywords": ["伤", "病人", "药", "治疗"]},
	"engineer_01": {"name": "欧文", "job": "工程师", "keywords": ["结构", "材料", "尺寸", "返工"]}
}

const FORBIDDEN_OPAQUE_STYLE_MARKERS: Array[String] = [
	"仿佛",
	"宛如",
	"如同",
	"好像",
	"像个",
	"像一",
	"季节没有耳朵",
	"国王的餐桌",
	"作比"
]


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if npc_system == null or llm_bridge == null:
		_fail("NPC character profile verification required nodes not found")
		return

	var npc_ids: Array = npc_system.get_npc_ids()
	if npc_ids.size() != EXPECTED_IDENTITIES.size():
		_fail("Expected %d NPC profiles, got %d" % [EXPECTED_IDENTITIES.size(), npc_ids.size()])
		return

	for npc_id_value in EXPECTED_IDENTITIES.keys():
		var npc_id := str(npc_id_value)
		var expected: Dictionary = EXPECTED_IDENTITIES[npc_id]
		var npc: Dictionary = npc_system.get_npc(npc_id)
		if npc.is_empty():
			_fail("Missing NPC profile: %s" % npc_id)
			return
		if str(npc.get("name", "")) != str(expected.get("name", "")):
			_fail("%s name mismatch: %s" % [npc_id, str(npc.get("name", ""))])
			return
		if str(npc.get("background_job", "")) != str(expected.get("job", "")):
			_fail("%s background_job mismatch: %s" % [npc_id, str(npc.get("background_job", ""))])
			return
		if expected.has("appearance") and str(npc.get("appearance", "")) != str(expected.get("appearance", "")):
			_fail("%s appearance no longer matches the current production art" % npc_id)
			return
		if str(npc.get("religion", "")) != "天主教":
			_fail("%s religion must be the concise shared value 天主教" % npc_id)
			return

		for field_name in ["personality", "desires", "fears", "boundaries"]:
			var values: Array = npc.get(field_name, [])
			if values.is_empty():
				_fail("%s must define non-empty %s" % [npc_id, field_name])
				return

		var background_story := str(npc.get("background_story", ""))
		var speech_style := str(npc.get("speech_style", ""))
		if background_story.is_empty() or background_story.length() > 120:
			_fail("%s background_story must stay concise" % npc_id)
			return
		if speech_style.is_empty() or speech_style.length() > 80:
			_fail("%s speech_style must be present and concise" % npc_id)
			return
		if npc.has("signature_lines"):
			_fail("%s must not retain a fixed signature-lines section" % npc_id)
			return
		var voice_text := background_story + speech_style
		if not _contains_any(voice_text, expected.get("keywords", [])):
			_fail("%s voice content does not reflect its profession" % npc_id)
			return

		for world_text in [background_story, speech_style, JSON.stringify(npc.get("fears", []))]:
			if str(world_text).contains("玩家"):
				_fail("%s world-facing profile text must use 守备官 instead of 玩家" % npc_id)
				return
			for marker in FORBIDDEN_OPAQUE_STYLE_MARKERS:
				if str(world_text).contains(marker):
					_fail("%s profile keeps an opaque or repetitive metaphor marker: %s" % [npc_id, marker])
					return

		var payload: Dictionary = llm_bridge.build_npc_dialogue_payload(npc_id, "你在驿站负责什么？", {})
		var npc_setting: Dictionary = payload.get("npc_setting", {})
		var identity: Dictionary = payload.get("target_npc", {}).get("identity", {})
		if npc_setting != NPCPromptProfile.build_setting(npc):
			_fail("%s dialogue npc_setting diverged from the shared prompt profile" % npc_id)
			return
		if str(npc_setting.get("appearance", "")) != str(npc.get("appearance", "")):
			_fail("%s dialogue npc_setting lost the profile appearance" % npc_id)
			return
		if npc_setting.get("speech_style", "") != speech_style or npc_setting.has("signature_lines"):
			_fail("%s dialogue npc_setting did not keep the broad voice profile boundary" % npc_id)
			return
		if str(npc_setting.get("religion", "")) != "天主教":
			_fail("%s dialogue npc_setting lost the religion field" % npc_id)
			return
		if identity.get("speech_style", "") != speech_style or identity.has("signature_lines"):
			_fail("%s shared NPC identity did not keep the broad voice profile boundary" % npc_id)
			return
		if str(identity.get("religion", "")) != "天主教":
			_fail("%s shared NPC identity lost the religion field" % npc_id)
			return

	var priest: Dictionary = npc_system.get_npc("priest_01")
	if not str(priest.get("background_story", "")).contains("擅长酿酒"):
		_fail("Marcel profile must briefly state that he is skilled at brewing")
		return

	var prompt_file := FileAccess.open("res://data/prompts/dialogue_system_prompt.txt", FileAccess.READ)
	if prompt_file == null:
		_fail("Failed to read dialogue_system_prompt.txt")
		return
	var prompt_text := prompt_file.get_as_text()
	prompt_file.close()
	for required_text in [
		"speech_style",
		"职业经验",
		"自然、直白",
		"不要为了显得有个性",
		"不是固定句式或台词模板"
	]:
		if not prompt_text.contains(required_text):
			_fail("Dialogue prompt missing character voice rule: %s" % required_text)
			return
	if prompt_text.contains("signature_lines"):
		_fail("Dialogue prompt still exposes fixed signature lines")
		return

	print("T0061/T0100 NPC character profile verification passed.")
	quit(0)


func _contains_any(text: String, keywords_value: Variant) -> bool:
	var keywords: Array = keywords_value if keywords_value is Array else []
	for keyword_value in keywords:
		if text.contains(str(keyword_value)):
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
