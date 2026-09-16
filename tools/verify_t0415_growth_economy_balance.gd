extends SceneTree


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn could not be loaded")
		return
	root.add_child(packed.instantiate())
	await process_frame
	await physics_frame
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var merchant := root.get_node_or_null("Main/Systems/MerchantSystem")
	var horse := root.get_node_or_null("Main/Systems/HorseSystem")
	var piety := root.get_node_or_null("Main/Systems/PietySystem")
	var buildings := root.get_node_or_null("Main/Systems/BuildingSystem")
	if npc_system == null or merchant == null or horse == null or piety == null or buildings == null:
		_fail("Required systems are missing")
		return

	var buy_prices := {"grain": 3, "wood": 4, "stone": 5, "iron": 6}
	var sell_prices := {"grain": 2, "wood": 3, "stone": 4, "iron": 5, "wine": 2}
	for resource_id in buy_prices:
		if int(merchant.get_buy_offer(resource_id).get("unit_price", 0)) != buy_prices[resource_id]:
			_fail("Buy price mismatch: %s" % resource_id)
			return
	for resource_id in sell_prices:
		if int(merchant.get_sell_offer(resource_id).get("unit_price", 0)) != sell_prices[resource_id]:
			_fail("Sell price mismatch: %s" % resource_id)
			return

	if not is_equal_approx(float(horse.get_balance_snapshot().get("birth_probability_gain_per_care_minute", 0.0)), 0.000025):
		_fail("Horse care breeding rate is not 50% of the prior value")
		return
	if not is_equal_approx(float(piety.get_piety_snapshot().get("piety_per_prayer_hour", 0.0)), 1.625):
		_fail("Piety rate is not 65% of the prior value")
		return

	var profiles: Dictionary = npc_system.get("_profiles")
	var skill_npc_id := "blacksmith_01"
	var profile: Dictionary = profiles[skill_npc_id]
	var skills: Dictionary = profile.get("skills", {}).duplicate(true)
	skills["打铁"] = 0
	profile["skills"] = skills
	profile["progression"] = {}
	profiles[skill_npc_id] = profile
	for index in 10:
		npc_system.increase_npc_skill(skill_npc_id, "打铁", 1, false)
	var skill_progression: Dictionary = npc_system.get_npc_progression(skill_npc_id)
	if int(npc_system.get_npc(skill_npc_id).get("skills", {}).get("打铁", -1)) != 7 or int(skill_progression.get("total_experience", -1)) != 7:
		_fail("Ten unit skill gains did not settle to seven")
		return

	var total_npc_id := "priest_01"
	profile = profiles[total_npc_id]
	profile["progression"] = {}
	profiles[total_npc_id] = profile
	for index in 10:
		npc_system.increase_npc_total_experience(total_npc_id, 1, false)
	if int(npc_system.get_npc_progression(total_npc_id).get("total_experience", -1)) != 7:
		_fail("Ten unit total-only gains did not settle to seven")
		return

	for building_id in buildings.get_building_ids():
		var building: Dictionary = buildings.get_building(building_id)
		var upgrade: Dictionary = building.get("upgrade", {})
		if upgrade.is_empty() or int(building.get("level", 1)) >= int(upgrade.get("max_level", 1)):
			continue
		var resolved: Dictionary = buildings._resolve_upgrade_level_effect(building, int(building.get("level", 1)) + 1)
		var configured := float(resolved.get("duration_seconds", 3600.0))
		if not resolved.has("duration_seconds"):
			configured = 3600.0 * (1.0 + float(int(building.get("level", 1)) - 1) * 0.35)
		var actual := float(buildings._calculate_upgrade_duration_seconds(building, resolved))
		if not is_equal_approx(actual, configured + 7200.0):
			_fail("Upgrade duration surcharge mismatch: %s" % building_id)
			return

	print("T0415 growth and economy balance verified")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
