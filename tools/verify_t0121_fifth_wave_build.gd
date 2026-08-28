extends SceneTree


const COMBATANT_LOADOUTS := {
	"veteran_deputy_01": "",
	"stableman_01": "bow",
	"cook_01": "polearm",
	"blacksmith_01": "sword_shield",
	"engineer_01": "crossbow",
	"gardener_01": "polearm",
	"doctor_01": "bow"
}

const ARMOR_LOADOUTS := {
	"veteran_deputy_01": ["iron_helmet", "mail_chest", "iron_bracers", "iron_greaves"],
	"cook_01": ["iron_helmet", "iron_greaves"],
	"blacksmith_01": ["iron_helmet", "iron_bracers"]
}


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var device_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var game_state := root.get_node_or_null("/root/GameState")
	if (
		combat_system == null
		or npc_system == null
		or resource_system == null
		or equipment_system == null
		or horse_system == null
		or building_system == null
		or device_system == null
		or game_state == null
	):
		_fail("T0121 fifth-wave build requires all combat/equipment/device systems")
		return

	# This fixture starts at the confirmed day-7 checkpoint. It validates the
	# resulting build in the real combat loop; production feasibility is covered
	# separately by verify_t0121_game_balance.gd and the recipe pipeline tests.
	for npc_id in COMBATANT_LOADOUTS:
		if not npc_system.set_npc_recruited(npc_id, true):
			_fail("Could not recruit %s for the fifth-wave fixture" % npc_id)
			return

	var stock := {
		"item_polearm": 2,
		"item_bow": 2,
		"item_sword_shield": 1,
		"item_crossbow": 1,
		"item_iron_helmet": 3,
		"item_mail_chest": 1,
		"item_iron_bracers": 2,
		"item_iron_greaves": 2,
		"item_wall_ballista": 1,
		"item_wall_arrow_tower": 3
	}
	for resource_id in stock:
		resource_system.add_resource(resource_id, int(stock[resource_id]))

	for npc_id in COMBATANT_LOADOUTS:
		var weapon_id := str(COMBATANT_LOADOUTS[npc_id])
		if weapon_id.is_empty():
			continue
		var weapon_result: Dictionary = equipment_system.equip_npc_main_weapon(npc_id, weapon_id, "private")
		if not bool(weapon_result.get("ok", false)):
			_fail("Could not equip %s with %s: %s" % [npc_id, weapon_id, JSON.stringify(weapon_result)])
			return

	for npc_id in ARMOR_LOADOUTS:
		for armor_id in ARMOR_LOADOUTS[npc_id]:
			var armor_def: Dictionary = equipment_system.get_armor_def(str(armor_id))
			var slot_id := str(armor_def.get("slot", ""))
			var armor_result: Dictionary = equipment_system.equip_npc_armor(npc_id, slot_id, str(armor_id), "private")
			if not bool(armor_result.get("ok", false)):
				_fail("Could not equip %s with %s: %s" % [npc_id, armor_id, JSON.stringify(armor_result)])
				return

	var available_horses: Array = horse_system.get_available_horses_for_npc("veteran_deputy_01")
	if available_horses.size() < 2:
		_fail("The confirmed build requires the two initial adult horses")
		return
	for index in range(2):
		var rider_id := "veteran_deputy_01" if index == 0 else "stableman_01"
		var horse_id := str((available_horses[index] as Dictionary).get("horse_id", ""))
		var mount_result: Dictionary = horse_system.assign_horse_to_npc(rider_id, horse_id, "private")
		if not bool(mount_result.get("ok", false)):
			_fail("Could not assign horse %s to %s: %s" % [horse_id, rider_id, JSON.stringify(mount_result)])
			return

	_set_building_level(building_system, "wall", 2)
	_set_building_level(building_system, "main_hall", 3)
	var deployments := [
		["wall_ballista", "wall_slot_01"],
		["wall_arrow_tower", "wall_slot_02"],
		["wall_arrow_tower", "main_hall_slot_01"],
		["wall_arrow_tower", "main_hall_slot_02"]
	]
	for deployment in deployments:
		var deploy_result: Dictionary = device_system.deploy_device(str(deployment[0]), str(deployment[1]))
		if not bool(deploy_result.get("ok", false)):
			_fail("Could not deploy %s in %s: %s" % [deployment[0], deployment[1], JSON.stringify(deploy_result)])
			return

	var front_index := 0
	var back_index := 0
	for npc_id in COMBATANT_LOADOUTS:
		var unit_type := str(equipment_system.get_npc_unit_type(npc_id))
		var is_ranged := ["archer", "crossbowman", "mounted_ranged"].has(unit_type)
		var position := Vector3(float((back_index if is_ranged else front_index) - 2) * 2.1, 0.0, 14.2 if is_ranged else 16.2)
		if is_ranged:
			back_index += 1
		else:
			front_index += 1
		_set_npc_world_position(npc_system, npc_id, position)
		var strategy_id := "max_output" if is_ranged else "attack"
		var strategy_result: Dictionary = combat_system.set_npc_combat_strategy(npc_id, strategy_id, "private", "verify_t0121_fifth_wave")
		if not bool(strategy_result.get("ok", false)):
			_fail("Could not set %s strategy for %s: %s" % [strategy_id, npc_id, JSON.stringify(strategy_result)])
			return

	# This is a confirmed-build combat fixture rather than a long-route travel
	# test. Reuse the explicit GM near-gate spawn so its simulated seconds cover
	# the 48-enemy fight itself after the formal-world coordinate migration.
	var spawn_result: Dictionary = combat_system.debug_spawn_wave(5, true, true)
	if not bool(spawn_result.get("ok", false)) or combat_system.get_active_enemy_count() != 48:
		_fail("The day-7 fifth wave must spawn exactly 48 enemies: %s" % JSON.stringify(spawn_result))
		return

	for npc_id in COMBATANT_LOADOUTS:
		var mode_result: Dictionary = npc_system.set_npc_behavior_mode(npc_id, "combat", "verify_t0121_fifth_wave", {
			"state_changes": {
				"current_action": "combat_ready",
				"combat_attack_cooldown": 0.0
			},
			"request_plan_reevaluation": false
		})
		if not bool(mode_result.get("ok", false)):
			_fail("Could not put %s into combat mode: %s" % [npc_id, JSON.stringify(mode_result)])
			return

	var elapsed_combat_seconds := 0
	while combat_system.get_active_enemy_count() > 0 and not bool(game_state.get("game_over")) and elapsed_combat_seconds < 3600:
		combat_system.debug_step_enemy_ai(60.0)
		# Formal combatants are CharacterBody3D actors. Let the physics server
		# publish their requested movement before sweeping the newly released
		# projectile paths, matching the order used by the live scene.
		await physics_frame
		combat_system.debug_advance_combat_projectiles(1.0)
		device_system.debug_advance_defense_devices(60.0)
		elapsed_combat_seconds += 1

	if str(game_state.get("game_result")) == "failure":
		_fail("The confirmed fifth-wave build failed: %s" % str(game_state.get("failure_reason")))
		return
	if combat_system.get_active_enemy_count() != 0:
		_fail("The confirmed fifth-wave build did not clear all enemies within 3600 combat seconds")
		return
	if str(game_state.get("game_result")) != "victory" or str(game_state.get("game_over_reason")) != "five_waves_survived":
		_fail("Clearing the confirmed fifth-wave build should produce the five-wave victory result")
		return
	var main_hall: Dictionary = building_system.get_building("main_hall")
	if int(main_hall.get("hp", 0)) <= 0:
		_fail("The confirmed fifth-wave build cleared enemies only after the main hall was destroyed")
		return

	var conscious_count := 0
	for npc_id in COMBATANT_LOADOUTS:
		if not bool(npc_system.get_npc_state(npc_id).get("unconscious", false)):
			conscious_count += 1
	print("T0121 fifth-wave build verification passed: enemies=48 elapsed=%ds main_hall=%d/%d conscious=%d/7" % [
		elapsed_combat_seconds,
		int(main_hall.get("hp", 0)),
		int(main_hall.get("max_hp", 0)),
		conscious_count
	])
	quit(0)


func _set_building_level(building_system: Node, building_id: String, level: int) -> void:
	var buildings: Dictionary = building_system.get("_buildings")
	var building: Dictionary = buildings.get(building_id, {})
	building["level"] = level
	buildings[building_id] = building
	building_system.set("_buildings", buildings)


func _set_npc_world_position(npc_system: Node, npc_id: String, position: Vector3) -> void:
	var npc_paths: Dictionary = npc_system.get("_npc_nodes")
	var npc_node := npc_system.get_node_or_null(npc_paths.get(npc_id, NodePath(""))) as Node3D
	if npc_node != null:
		npc_node.global_position = position


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
