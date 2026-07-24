extends RefCounted

const FIELD_DEFINITIONS: Array[Dictionary] = [
	{"key": "appearance", "label": "外貌"},
	{"key": "background_story", "label": "背景故事"},
	{"key": "background_job", "label": "职业背景"},
	{"key": "personality", "label": "性格"},
	{"key": "desires", "label": "欲望"},
	{"key": "fears", "label": "恐惧"},
	{"key": "boundaries", "label": "底线"},
	{"key": "speech_style", "label": "说话风格"},
	{"key": "abilities", "label": "能力"}
]


static func build_setting(npc: Dictionary) -> Dictionary:
	return {
		"appearance": npc.get("appearance", ""),
		"background_story": npc.get("background_story", ""),
		"background_job": npc.get("background_job", ""),
		"personality": npc.get("personality", []),
		"desires": npc.get("desires", []),
		"fears": npc.get("fears", []),
		"boundaries": npc.get("boundaries", npc.get("bottom_lines", [])),
		"speech_style": npc.get("speech_style", ""),
		"abilities": npc.get("abilities", {})
	}
