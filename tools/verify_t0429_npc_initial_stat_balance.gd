extends SceneTree

const PROFILE_PATH := "res://data/npc_profiles.json"
const SKILL_KEYS := ["养马", "厨艺", "耕种", "打铁", "教练", "酿酒", "医术", "工程", "剑盾", "长杆", "弓", "弩", "骑术"]
const EXPECTED := {
	"stableman_01": {"stats": [6, 5], "skills": [75, 5, 8, 6, 10, 5, 4, 8, 5, 8, 5, 0, 48], "core": "养马", "hp": 83},
	"cook_01": {"stats": [6, 5], "skills": [5, 78, 8, 5, 8, 50, 6, 5, 8, 5, 3, 0, 4], "core": "厨艺", "hp": 87},
	"gardener_01": {"stats": [5, 6], "skills": [8, 15, 80, 4, 6, 8, 20, 6, 3, 15, 5, 0, 5], "core": "耕种", "hp": 75},
	"blacksmith_01": {"stats": [7, 5], "skills": [10, 4, 5, 80, 12, 5, 3, 18, 26, 18, 0, 5, 4], "core": "打铁", "hp": 100},
	"veteran_deputy_01": {"stats": [7, 5], "skills": [8, 6, 5, 8, 35, 4, 10, 12, 42, 22, 12, 8, 22], "core": "剑盾", "hp": 95},
	"priest_01": {"stats": [3, 8], "skills": [5, 15, 12, 0, 10, 58, 30, 5, 0, 0, 0, 0, 2], "core": "酿酒", "hp": 60},
	"doctor_01": {"stats": [3, 8], "skills": [4, 8, 22, 0, 8, 5, 84, 4, 0, 0, 10, 0, 2], "core": "医术", "hp": 63},
	"engineer_01": {"stats": [4, 8], "skills": [6, 5, 5, 15, 12, 3, 5, 82, 0, 5, 22, 28, 4], "core": "工程", "hp": 69},
}
const EXPECTED_COMBAT_BASE := {
	"stableman_01": [4.5, 1.0, 0.6, 1.05],
	"cook_01": [4.2, 0.8, 0.4, 0.96],
	"gardener_01": [3.4, 0.6, 0.5, 1.10],
	"blacksmith_01": [5.0, 1.5, 1.0, 0.92],
	"veteran_deputy_01": [5.5, 2.0, 1.5, 1.08],
	"priest_01": [2.4, 0.5, 0.2, 0.90],
	"doctor_01": [2.5, 0.7, 0.2, 1.00],
	"engineer_01": [3.6, 0.8, 1.2, 0.98],
}

func _initialize() -> void:
	var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file == null:
		_fail("Cannot open NPC profiles")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Array or parsed.size() != EXPECTED.size():
		_fail("NPC profile set mismatch")
		return
	var seen := {}
	var minimum_skill_total := 1000
	var maximum_skill_total := 0
	for raw_profile in parsed:
		if not raw_profile is Dictionary:
			_fail("NPC profile entry must be an object")
			return
		var profile: Dictionary = raw_profile
		var npc_id := str(profile.get("id", ""))
		if not EXPECTED.has(npc_id):
			_fail("Unexpected NPC id: %s" % npc_id)
			return
		var expected: Dictionary = EXPECTED[npc_id]
		var stats: Dictionary = profile.get("stats", {})
		var expected_stats: Array = expected["stats"]
		if [int(stats.get("strength", -1)), int(stats.get("intelligence", -1))] != expected_stats:
			_fail("%s attribute mismatch: %s" % [npc_id, stats])
			return
		var attribute_total := int(stats.get("strength", 0)) + int(stats.get("intelligence", 0))
		if attribute_total < 11 or attribute_total > 12:
			_fail("%s attribute budget out of range: %d" % [npc_id, attribute_total])
			return
		var skills: Dictionary = profile.get("skills", {})
		if skills.size() != SKILL_KEYS.size():
			_fail("%s must have exactly 13 skills" % npc_id)
			return
		var skill_total := 0
		var expected_skills: Array = expected["skills"]
		for index in SKILL_KEYS.size():
			var skill_name: String = SKILL_KEYS[index]
			if int(skills.get(skill_name, -1)) != int(expected_skills[index]):
				_fail("%s %s mismatch" % [npc_id, skill_name])
				return
			skill_total += int(skills[skill_name])
		var core_skill := str(expected["core"])
		for skill_name in SKILL_KEYS:
			if skill_name != core_skill and int(skills[skill_name]) > int(skills[core_skill]):
				_fail("%s core skill is not strongest: %s" % [npc_id, core_skill])
				return
		minimum_skill_total = mini(minimum_skill_total, skill_total)
		maximum_skill_total = maxi(maximum_skill_total, skill_total)
		var states: Dictionary = profile.get("states", {})
		if int(states.get("hp", -1)) != int(expected["hp"]) or int(states.get("max_hp", -1)) != int(expected["hp"]):
			_fail("%s HP changed unexpectedly" % npc_id)
			return
		var combat_base: Dictionary = profile.get("combat_base", {})
		var expected_combat: Array = EXPECTED_COMBAT_BASE[npc_id]
		var actual_combat := [float(combat_base.get("attack_power", -1.0)), float(combat_base.get("defense", -1.0)), float(combat_base.get("penetration", -1.0)), float(combat_base.get("attack_speed_multiplier", -1.0))]
		if actual_combat != expected_combat:
			_fail("%s combat_base changed unexpectedly" % npc_id)
			return
		var initial_equipment: Dictionary = profile.get("initial_equipment", {}) if profile.get("initial_equipment", {}) is Dictionary else {}
		if (npc_id == "veteran_deputy_01") != (str(initial_equipment.get("main_weapon", "")) == "sword_shield"):
			_fail("Initial sword-and-shield boundary changed for %s" % npc_id)
			return
		seen[npc_id] = true
	if seen.size() != EXPECTED.size() or minimum_skill_total != 137 or maximum_skill_total != 194:
		_fail("Balanced roster totals mismatch: min=%d max=%d" % [minimum_skill_total, maximum_skill_total])
		return
	print("T0429 NPC initial stat balance verification passed")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
