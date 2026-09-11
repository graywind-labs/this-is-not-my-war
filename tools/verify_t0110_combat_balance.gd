extends SceneTree


func _init() -> void:
	root.size = Vector2i(1280, 720)
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main.tscn failed to load.")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var device_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var building_panel := root.get_node_or_null("Main/UI/BuildingPanel")
	if [
		combat_system,
		npc_system,
		equipment_system,
		building_system,
		device_system,
		building_panel
	].has(null):
		_fail("T0110 required runtime nodes are missing.")
		return

	if not _verify_diminishing_defense_curve(combat_system):
		return
	if not _verify_weapon_and_riding_skill_roles(
		combat_system,
		npc_system,
		equipment_system
	):
		return
	if not _verify_building_slot_curves(building_system, device_system):
		return
	if not await _verify_upgrade_hint_rewards(building_system, building_panel):
		return

	print("T0110 combat balance verification passed.")
	quit(0)


func _verify_diminishing_defense_curve(combat_system: Node) -> bool:
	var effective_defense_values: Array[float] = [0.0, 2.0, 5.0, 10.0, 20.0, 40.0]
	var expected_reductions: Array[float] = [
		0.0,
		2.0 / 22.0,
		5.0 / 25.0,
		10.0 / 30.0,
		20.0 / 40.0,
		40.0 / 60.0
	]
	for index in range(effective_defense_values.size()):
		var effective_defense := effective_defense_values[index]
		var result: Dictionary = combat_system.calculate_damage_resolution(
			100.0,
			effective_defense,
			0.0
		)
		var expected_multiplier := 20.0 / (20.0 + effective_defense)
		if (
			not is_equal_approx(
				float(result.get("damage_multiplier", -1.0)),
				expected_multiplier
			)
			or not is_equal_approx(
				float(result.get("damage_reduction", -1.0)),
				expected_reductions[index]
			)
			or int(result.get("damage", 0)) != int(round(100.0 * expected_multiplier))
		):
			return _fail("Defense curve mismatch at %.1f: %s" % [
				effective_defense,
				JSON.stringify(result)
			])

	var partial_penetration: Dictionary = combat_system.calculate_damage_resolution(
		100.0,
		10.0,
		6.0
	)
	var full_penetration: Dictionary = combat_system.calculate_damage_resolution(
		100.0,
		10.0,
		12.0
	)
	if (
		not is_equal_approx(
			float(partial_penetration.get("effective_defense", -1.0)),
			4.0
		)
		or int(full_penetration.get("damage", 0)) != 100
	):
		return _fail("Penetration must be subtracted before the defense curve.")

	var defense_10: Dictionary = combat_system.calculate_damage_resolution(1000.0, 10.0, 0.0)
	var defense_20: Dictionary = combat_system.calculate_damage_resolution(1000.0, 20.0, 0.0)
	var defense_30: Dictionary = combat_system.calculate_damage_resolution(1000.0, 30.0, 0.0)
	var first_gain := (
		float(defense_20.get("damage_reduction", 0.0))
		- float(defense_10.get("damage_reduction", 0.0))
	)
	var second_gain := (
		float(defense_30.get("damage_reduction", 0.0))
		- float(defense_20.get("damage_reduction", 0.0))
	)
	if second_gain >= first_gain:
		return _fail("Equal defense increments must have diminishing reduction gains.")
	return true


func _verify_weapon_and_riding_skill_roles(
	combat_system: Node,
	npc_system: Node,
	equipment_system: Node
) -> bool:
	var npc_id := "veteran_deputy_01"
	_set_profile_skill_without_experience(npc_system, npc_id, "剑盾", 0)
	_set_profile_skill_without_experience(npc_system, npc_id, "弓", 0)
	_set_profile_skill_without_experience(npc_system, npc_id, "骑术", 0)
	var baseline: Dictionary = combat_system.get_npc_combat_stats(npc_id)
	var baseline_final: Dictionary = baseline.get("final", {})

	_set_profile_skill_without_experience(npc_system, npc_id, "弓", 100)
	var unrelated: Dictionary = combat_system.get_npc_combat_stats(npc_id)
	var unrelated_final: Dictionary = unrelated.get("final", {})
	if (
		not is_equal_approx(
			float(unrelated_final.get("attack_speed", 0.0)),
			float(baseline_final.get("attack_speed", 0.0))
		)
		or not is_equal_approx(
			float(unrelated_final.get("penetration", 0.0)),
			float(baseline_final.get("penetration", 0.0))
		)
	):
		return _fail("An unrelated weapon proficiency must not grant generic combat stats.")

	_set_profile_skill_without_experience(npc_system, npc_id, "弓", 0)
	_set_profile_skill_without_experience(npc_system, npc_id, "剑盾", 100)
	var matching: Dictionary = combat_system.get_npc_combat_stats(npc_id)
	var matching_growth: Dictionary = matching.get("growth", {})
	var matching_final: Dictionary = matching.get("final", {})
	if (
		str(matching_growth.get("weapon_skill_name", "")) != "剑盾"
		or not is_equal_approx(
			float(matching_growth.get("weapon_skill_attack_speed_multiplier", 0.0)),
			1.35
		)
		or float(matching_final.get("attack_speed", 0.0))
			<= float(baseline_final.get("attack_speed", 0.0))
		or not is_equal_approx(
			float(matching_final.get("penetration", 0.0)),
			float(baseline_final.get("penetration", 0.0))
		)
	):
		return _fail("Matching weapon proficiency must add only corresponding weapon speed.")

	var mount_result: Dictionary = equipment_system.equip_npc_mount(npc_id, "", "private")
	if not bool(mount_result.get("ok", false)):
		return _fail("Failed to equip mount for riding-role verification: %s" % JSON.stringify(mount_result))
	npc_system._set_npc_state_without_signal(npc_id, {
		"behavior_mode": "combat",
		"combat_mounted": true,
		"combat_mount_phase": "mounted"
	})
	_set_profile_skill_without_experience(npc_system, npc_id, "骑术", 0)
	var riding_zero: Dictionary = combat_system.get_npc_combat_stats(npc_id).get("final", {})
	_set_profile_skill_without_experience(npc_system, npc_id, "骑术", 100)
	var riding_max: Dictionary = combat_system.get_npc_combat_stats(npc_id).get("final", {})
	if not is_equal_approx(
		float(riding_max.get("attack_speed", 0.0))
		/ float(riding_zero.get("attack_speed", 1.0)),
		1.08
	):
		return _fail("Riding 100 must add 8%% mounted attack speed multiplicatively: zero=%s max=%s state=%s" % [
			JSON.stringify(riding_zero),
			JSON.stringify(riding_max),
			JSON.stringify(npc_system.get_npc_state(npc_id))
		])

	combat_system.debug_clear_enemies()
	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		return _fail("Failed to spawn horse-collision verification target.")
	var enemy_id := str(combat_system.get_active_enemy_ids()[0])
	_prepare_collision_target(combat_system, enemy_id)
	var target := {"id": enemy_id}
	_set_profile_skill_without_experience(npc_system, npc_id, "骑术", 0)
	var npc: Dictionary = npc_system.get_npc(npc_id)
	var impact_zero: Dictionary = combat_system._apply_cavalry_charge_impact(
		npc_id,
		npc,
		target,
		{}
	)
	_prepare_collision_target(combat_system, enemy_id)
	_set_profile_skill_without_experience(npc_system, npc_id, "骑术", 100)
	npc = npc_system.get_npc(npc_id)
	var impact_max: Dictionary = combat_system._apply_cavalry_charge_impact(
		npc_id,
		npc,
		target,
		{}
	)
	if (
		float(impact_max.get("collision_raw_damage", 0.0))
		<= float(impact_zero.get("collision_raw_damage", 0.0))
		or not is_equal_approx(
			float(impact_max.get("collision_raw_damage", 0.0))
			- float(impact_zero.get("collision_raw_damage", 0.0)),
			5.0
		)
	):
		return _fail("Legacy horse-collision compatibility must still read riding proficiency.")
	return true


func _verify_building_slot_curves(building_system: Node, device_system: Node) -> bool:
	var expected_curves := {
		"wall": [1, 2, 2, 3, 3, 4],
		"main_hall": [1, 1, 2, 2, 3, 4]
	}
	var expected_unlock_levels := {
		"wall": [1, 2, 4, 6],
		"main_hall": [1, 3, 5, 6]
	}
	var expected_non_slot_levels := {
		"wall": [3, 5],
		"main_hall": [2, 4]
	}
	for building_id in expected_curves.keys():
		var building: Dictionary = building_system.get_building(building_id)
		var upgrade: Dictionary = building.get("upgrade", {})
		if int(upgrade.get("max_level", 0)) != 6:
			return _fail("%s must use a six-level upgrade curve." % building_id)
		var required_levels: Array[int] = []
		for raw_slot in device_system.get_slots_for_building(building_id, true):
			var slot: Dictionary = raw_slot
			required_levels.append(int(slot.get("required_building_level", 0)))
		required_levels.sort()
		if required_levels != expected_unlock_levels[building_id]:
			return _fail("%s unlock levels mismatch: %s" % [
				building_id,
				str(required_levels)
			])

		var previous_slots := 1
		var previous_duration := 0.0
		var previous_cost_units := 0
		for target_level in range(2, 7):
			var effect: Dictionary = building_system.get_upgrade_level_effect(
				building_id,
				target_level
			)
			var curve: Array = expected_curves[building_id]
			var target_slots := int(curve[target_level - 1])
			var slot_delta := target_slots - previous_slots
			if slot_delta < 0 or slot_delta > 1:
				return _fail("%s Lv.%d unlocks an invalid slot delta: %d" % [
					building_id,
					target_level,
					slot_delta
				])
			if (
				(expected_non_slot_levels[building_id] as Array).has(target_level)
				and slot_delta != 0
			):
				return _fail("%s Lv.%d should not unlock a deployment slot." % [
					building_id,
					target_level
				])
			var expected_range_bonus := (
				0.05
				if building_id == "wall" and [3, 5].has(target_level)
				else 0.0
			)
			if not is_equal_approx(
				float(effect.get("defense_device_range_bonus", 0.0)),
				expected_range_bonus
			):
				return _fail("%s Lv.%d defense-device range reward mismatch." % [
					building_id,
					target_level
				])
			var duration := float(effect.get("duration_seconds", 0.0))
			var max_hp_bonus := int(effect.get("max_hp_bonus", 0))
			var cost: Dictionary = effect.get("cost", {})
			var cost_units := 0
			for amount in cost.values():
				cost_units += int(amount)
			if (
				duration <= previous_duration
				or cost_units <= previous_cost_units
				or max_hp_bonus <= 0
			):
				return _fail("%s Lv.%d must have progressive cost/time and HP value." % [
					building_id,
					target_level
				])
			previous_slots = target_slots
			previous_duration = duration
			previous_cost_units = cost_units
		if previous_slots != 4:
			return _fail("%s must reach exactly four slots at Lv.6." % building_id)
	return true


func _verify_upgrade_hint_rewards(building_system: Node, building_panel: Node) -> bool:
	_set_building_level(building_system, "wall", 2)
	building_panel.show_building("wall")
	await process_frame
	var wall_durability_hint := str(building_panel._format_upgrade_hint())
	if (
		not wall_durability_hint.contains("升级至 Lv.3")
		or not wall_durability_hint.contains("Max HP +45")
		or not wall_durability_hint.contains("器械射程：+5%")
		or not wall_durability_hint.contains("部署槽：本级不增加（2/4）")
		or not wall_durability_hint.contains("工期：")
	):
		return _fail("Wall durability-level hint is incomplete: %s" % wall_durability_hint)

	_set_building_level(building_system, "wall", 3)
	building_panel.show_building("wall")
	await process_frame
	var wall_slot_hint := str(building_panel._format_upgrade_hint())
	if not wall_slot_hint.contains("部署槽：+1（解锁至 3/4）"):
		return _fail("Wall slot-level hint is incomplete: %s" % wall_slot_hint)

	_set_building_level(building_system, "main_hall", 1)
	building_panel.show_building("main_hall")
	await process_frame
	var hall_hint := str(building_panel._format_upgrade_hint())
	if (
		not hall_hint.contains("升级至 Lv.2")
		or not hall_hint.contains("Max HP +40")
		or not hall_hint.contains("部署槽：本级不增加（1/4）")
	):
		return _fail("Main hall durability-level hint is incomplete: %s" % hall_hint)
	return true


func _set_profile_skill_without_experience(
	npc_system: Node,
	npc_id: String,
	skill_name: String,
	value: int
) -> void:
	var profiles: Dictionary = npc_system.get("_profiles")
	var profile: Dictionary = profiles.get(npc_id, {})
	var skills: Dictionary = profile.get("skills", {})
	skills[skill_name] = clampi(value, 0, 100)
	profile["skills"] = skills
	profiles[npc_id] = profile
	npc_system.set("_profiles", profiles)


func _prepare_collision_target(combat_system: Node, enemy_id: String) -> void:
	var active_enemies: Dictionary = combat_system.get("_active_enemies")
	var enemy: Dictionary = active_enemies.get(enemy_id, {})
	enemy["hp"] = 1000
	enemy["max_hp"] = 1000
	enemy["defense"] = 0.0
	enemy["stagger_remaining"] = 0.0
	enemy["attack_windup_remaining"] = 0.0
	active_enemies[enemy_id] = enemy
	combat_system.set("_active_enemies", active_enemies)


func _set_building_level(building_system: Node, building_id: String, level: int) -> void:
	var buildings: Dictionary = building_system.get("_buildings")
	var building: Dictionary = buildings.get(building_id, {})
	building["level"] = level
	building["hp"] = int(building.get("max_hp", building.get("hp", 1)))
	buildings[building_id] = building
	building_system.set("_buildings", buildings)


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
