extends SceneTree


const EXPECTED_WAVE_COUNTS := [8, 16, 24, 36, 48]
const EXPECTED_WAVE_GROUP_COUNTS := [
	[8],
	[12, 4],
	[18, 6],
	[8, 16, 8, 4],
	[8, 4, 20, 10, 6]
]
const EXPECTED_RECIPE_CONTRACT := {
	"craft_iron_helmet": [3, {"iron": 2}, true],
	"craft_iron_bracers": [3, {"iron": 2}, true],
	"craft_polearm": [4, {"iron": 2, "wood": 1}, true],
	"craft_iron_greaves": [4, {"iron": 3}, true],
	"craft_sword_shield": [5, {"iron": 3, "wood": 1}, true],
	"craft_mail_chest": [8, {"iron": 6}, true],
	"craft_bow": [3, {"wood": 2}, true],
	"craft_crossbow": [5, {"iron": 1, "wood": 3}, true],
	"craft_wall_ballista": [9, {"iron": 2, "wood": 6}, true],
	"craft_wall_arrow_tower": [12, {"iron": 2, "wood": 8}, true]
}
const EXPECTED_REPAIR_HP := {
	"main_hall": 25,
	"dormitory": 25,
	"dining_hall": 30,
	"warehouse": 25,
	"wall": 20,
	"front_gate": 40,
	"back_gate": 25,
	"tavern": 25,
	"garden": 20,
	"blacksmith": 25,
	"training_ground": 20,
	"stable": 25,
	"chapel": 25,
	"clinic": 25,
	"workshop": 25
}


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	root.add_child(main_scene.instantiate())
	await process_frame
	await physics_frame

	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var crafting_system := root.get_node_or_null("Main/Systems/CraftingSystem")
	var defense_device_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var merchant_system := root.get_node_or_null("Main/Systems/MerchantSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var piety_system := root.get_node_or_null("Main/Systems/PietySystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	if (
		action_system == null
		or building_system == null
		or combat_system == null
		or crafting_system == null
		or defense_device_system == null
		or merchant_system == null
		or npc_system == null
		or piety_system == null
		or resource_system == null
	):
		_fail("T0121 balance verification required systems are missing")
		return

	if not _verify_actions(action_system):
		return
	if not _verify_recipes(crafting_system):
		return
	if not _verify_wave_schedule_and_composition(combat_system):
		return
	if not _verify_economy(resource_system, merchant_system):
		return
	if not _verify_repairs(building_system):
		return
	if not _verify_growth(npc_system, combat_system):
		return
	if not _verify_combat_support(defense_device_system, piety_system):
		return

	print("T0121 unified game-balance contract verification passed.")
	quit(0)


func _verify_actions(action_system: Node) -> bool:
	var dining: Dictionary = action_system.get_action("work_dining_hall")
	if int((dining.get("output_resources", {}) as Dictionary).get("meal", 0)) != 2:
		return _fail("Dining hall must turn one grain into two meals")
	for action_id in ["work_blacksmith", "work_workshop"]:
		if int(action_system.get_action(action_id).get("duration_seconds", 0)) != 5400:
			return _fail("%s must use the confirmed 5400-second base stage" % action_id)
	return true


func _verify_recipes(crafting_system: Node) -> bool:
	for recipe_id in EXPECTED_RECIPE_CONTRACT.keys():
		var expected: Array = EXPECTED_RECIPE_CONTRACT[recipe_id]
		var recipe: Dictionary = crafting_system.get_recipe(str(recipe_id))
		if (recipe.get("stages", []) as Array).size() != int(expected[0]):
			return _fail("Recipe stage count mismatch for %s" % recipe_id)
		if _sum_recipe_cost(recipe) != (expected[1] as Dictionary):
			return _fail("Recipe material total mismatch for %s: %s" % [recipe_id, JSON.stringify(_sum_recipe_cost(recipe))])
		if bool(recipe.get("available", true)) != bool(expected[2]):
			return _fail("Recipe availability mismatch for %s" % recipe_id)
	return true


func _verify_wave_schedule_and_composition(combat_system: Node) -> bool:
	for index in range(EXPECTED_WAVE_COUNTS.size()):
		var wave_number := index + 1
		var wave: Dictionary = combat_system.get_wave_config(wave_number)
		if int(wave.get("trigger_day", 0)) != wave_number + 2 or int(wave.get("trigger_hour", -1)) != 18:
			return _fail("Wave %d must arrive on day %d at 18:00" % [wave_number, wave_number + 2])
		var group_counts: Array[int] = []
		var total := 0
		for raw_group in (wave.get("enemies", []) as Array):
			var count := int((raw_group as Dictionary).get("count", 0))
			group_counts.append(count)
			total += count
		if total != EXPECTED_WAVE_COUNTS[index] or group_counts != EXPECTED_WAVE_GROUP_COUNTS[index]:
			return _fail("Wave %d composition mismatch: %s" % [wave_number, str(group_counts)])
	return true


func _verify_economy(resource_system: Node, merchant_system: Node) -> bool:
	var expected_initial := {"money": 30, "grain": 18, "meal": 0, "wood": 12, "stone": 8, "iron": 5}
	for resource_id in expected_initial.keys():
		if int(resource_system.get_resource(str(resource_id))) != int(expected_initial[resource_id]):
			return _fail("Initial resource mismatch for %s" % resource_id)
	var expected_buy := {"grain": 2, "wood": 3, "stone": 4, "iron": 5}
	var expected_sell := {"grain": 1, "wood": 2, "stone": 3, "iron": 4, "wine": 4}
	for resource_id in expected_buy.keys():
		var buy_price := int(merchant_system.get_buy_offer(str(resource_id)).get("unit_price", 0))
		var sell_price := int(merchant_system.get_sell_offer(str(resource_id)).get("unit_price", 0))
		if buy_price != int(expected_buy[resource_id]) or sell_price != int(expected_sell[resource_id]) or sell_price >= buy_price:
			return _fail("No-arbitrage price contract mismatch for %s" % resource_id)
	if int(merchant_system.get_sell_offer("wine").get("unit_price", 0)) != 4 or not merchant_system.get_buy_offer("wine").is_empty():
		return _fail("Wine must be sell-only at four dinars")
	return true


func _verify_repairs(building_system: Node) -> bool:
	for building_id in EXPECTED_REPAIR_HP.keys():
		var building: Dictionary = building_system.get_building(str(building_id))
		if int((building.get("repair", {}) as Dictionary).get("hp_restore", 0)) != int(EXPECTED_REPAIR_HP[building_id]):
			return _fail("Repair hp_restore mismatch for %s" % building_id)
	building_system.debug_damage_building("wall", 60)
	var quote: Dictionary = building_system.get_repair_quote("wall")
	if int(quote.get("repair_batches", 0)) != 3 or int((quote.get("cost", {}) as Dictionary).get("stone", 0)) != 3:
		return _fail("Sixty missing wall HP must quote three stone batches: %s" % JSON.stringify(quote))
	return true


func _verify_growth(npc_system: Node, combat_system: Node) -> bool:
	var npc_id := "cook_01"
	var profile: Dictionary = npc_system.get_npc(npc_id)
	profile["progression"] = {
		"total_experience": 100,
		"next_skill_point_xp": 10,
		"unspent_skill_points": 10,
		"spent_skill_points": 0,
		"skill_experience": {"厨艺": 100, "剑盾": 0, "长杆": 0, "弓": 0, "弩": 0, "骑术": 0}
	}
	npc_system._profiles[npc_id] = profile
	if int(combat_system.get_npc_combat_level(npc_id)) != 1:
		return _fail("Professional experience must not raise combat level")
	var progression: Dictionary = profile.get("progression", {})
	var skill_experience: Dictionary = progression.get("skill_experience", {})
	skill_experience["剑盾"] = 20
	progression["skill_experience"] = skill_experience
	profile["progression"] = progression
	npc_system._profiles[npc_id] = profile
	if int(combat_system.get_npc_combat_level(npc_id)) != 3:
		return _fail("Twenty experience in one weapon track must produce combat level three")
	return true


func _verify_combat_support(defense_device_system: Node, piety_system: Node) -> bool:
	var ballista: Dictionary = defense_device_system.get_device_definition("wall_ballista")
	var effect: Dictionary = ballista.get("effect", {})
	if int(effect.get("damage", 0)) != 44 or not is_equal_approx(float(effect.get("attack_interval", 0.0)), 4.25):
		return _fail("Ballista must use 44 damage and a 4.25-second interval")
	var piety_snapshot: Dictionary = piety_system.get_piety_snapshot()
	var meteor: Dictionary = piety_system.get_meteor_config()
	if (
		not is_equal_approx(float(piety_snapshot.get("max_piety", 0.0)), 100.0)
		or not is_equal_approx(float(piety_snapshot.get("piety_per_prayer_hour", 0.0)), 2.5)
		or int(meteor.get("impact_max_targets", 0)) != 12
	):
		return _fail("Piety must use 100 cap, 2.5 base prayer rate, and 12 impact targets")
	return true


func _sum_recipe_cost(recipe: Dictionary) -> Dictionary:
	var result := {}
	for raw_stage in (recipe.get("stages", []) as Array):
		var stage: Dictionary = raw_stage
		for raw_resource_id in (stage.get("cost", {}) as Dictionary).keys():
			var resource_id := str(raw_resource_id)
			result[resource_id] = int(result.get(resource_id, 0)) + int((stage.get("cost", {}) as Dictionary)[raw_resource_id])
	return result


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
