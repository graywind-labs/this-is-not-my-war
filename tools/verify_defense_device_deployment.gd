extends SceneTree


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var device_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var presenter := root.get_node_or_null("Main/WorldRoot/Station/DefenseDevices")
	var building_panel := root.get_node_or_null("Main/UI/BuildingPanel")
	if device_system == null or combat_system == null or resource_system == null or memory_system == null or npc_system == null or action_system == null or building_system == null or presenter == null or building_panel == null:
		_fail("T1508 required nodes or systems are missing")
		return

	if not device_system.get_device_ids().has("wall_ballista") or not device_system.get_device_ids().has("wall_arrow_tower"):
		_fail("Ballista or arrow-tower definition is missing")
		return
	if device_system.get_device_ids().has("wall_barricade"):
		_fail("Removed barricade definition is still available")
		return
	if device_system.get_device_definition("wall_ballista").get("inventory_cost", {}) != {"item_wall_ballista": 1}:
		_fail("Ballista definition does not use its exact item inventory")
		return
	if device_system.get_device_definition("wall_arrow_tower").get("inventory_cost", {}) != {"item_wall_arrow_tower": 1}:
		_fail("Arrow-tower definition does not use its exact item inventory")
		return
	var ballista_definition: Dictionary = device_system.get_device_definition("wall_ballista")
	var arrow_definition: Dictionary = device_system.get_device_definition("wall_arrow_tower")
	var ballista_effect: Dictionary = ballista_definition.get("effect", {})
	var arrow_effect: Dictionary = arrow_definition.get("effect", {})
	if (
		int(ballista_definition.get("tier", 0)) != int(arrow_definition.get("tier", -1))
		or float(ballista_effect.get("damage", 0.0)) <= float(arrow_effect.get("damage", 0.0))
		or float(ballista_effect.get("penetration", 0.0)) <= float(arrow_effect.get("penetration", 0.0))
		or float(ballista_effect.get("range", 0.0)) <= float(arrow_effect.get("range", 0.0))
		or float(ballista_effect.get("attack_speed", 0.0)) >= float(arrow_effect.get("attack_speed", 0.0))
		or int(ballista_definition.get("max_hp", 0)) >= int(arrow_definition.get("max_hp", 0))
	):
		_fail("Ballista and arrow-tower horizontal balance contract is invalid")
		return
	var wall_slots: Array = device_system.get_slots_for_building("wall", true)
	var main_hall_slots: Array = device_system.get_slots_for_building("main_hall", true)
	if wall_slots.size() != 4 or main_hall_slots.size() != 4:
		_fail("Wall and main hall should each load four configured deployment slots")
		return
	for building_id in ["wall", "main_hall"]:
		var expected_curve: Array = (
			[1, 1, 2, 2, 3, 4]
			if building_id == "main_hall"
			else [1, 2, 2, 3, 3, 4]
		)
		for level in range(1, 7):
			_set_building_level_for_slot_test(building_system, building_id, level)
			var expected_unlocked := int(expected_curve[level - 1])
			if device_system.get_slots_for_building(building_id, false).size() != expected_unlocked:
				_fail("%s Lv.%d should unlock %d deployment slots" % [building_id, level, expected_unlocked])
				return
		_set_building_level_for_slot_test(building_system, building_id, 1)
	wall_slots = device_system.get_slots_for_building("wall", true)
	main_hall_slots = device_system.get_slots_for_building("main_hall", true)
	for raw_slot in wall_slots + main_hall_slots:
		var slot: Dictionary = raw_slot
		var allowed: Array = slot.get("allowed_device_ids", [])
		if not allowed.has("wall_ballista") or not allowed.has("wall_arrow_tower"):
			_fail("Deployment slots should be generic for both same-tier devices: %s" % JSON.stringify(slot))
			return
	for slot_id in device_system.get_slot_ids():
		if str(slot_id).contains("barricade"):
			_fail("Removed barricade slot is still available")
			return

	var workshop_action: Dictionary = action_system.get_action("work_workshop")
	if str(workshop_action.get("skill", "")) != "工程" or str(workshop_action.get("stat", "")) != "intelligence":
		_fail("T0805 engineering and intelligence manufacturing efficiency contract regressed")
		return
	var engineer_duration: float = action_system._get_effective_action_duration_seconds(workshop_action, "engineer_01")
	var blacksmith_duration: float = action_system._get_effective_action_duration_seconds(workshop_action, "blacksmith_01")
	if not engineer_duration < blacksmith_duration:
		_fail("Engineering skill no longer improves defense-device manufacturing efficiency")
		return

	building_panel.show_building("wall")
	await process_frame
	var device_section := building_panel.find_child("DefenseDeviceSection", true, false) as Control
	if device_section == null or not device_section.visible:
		_fail("Wall building panel does not expose the defense-device deployment UI")
		return
	for label_node in device_section.find_children("*", "Label", true, false):
		if label_node is Label and (label_node as Label).text.contains("部署者"):
			_fail("Wall deployment UI still exposes a deployer selector")
			return

	var unrelated_npc_id := "engineer_01"
	var plaza_witness_id := "priest_01"
	npc_system.debug_enter_location_immediately(plaza_witness_id, "plaza")
	# Deprecated aggregate stock is a sentinel and must never be consumed.
	resource_system.add_resource("defense_devices", 3)
	resource_system.add_resource("item_wall_ballista", 2)
	resource_system.add_resource("item_wall_arrow_tower", 1)
	var legacy_inventory_before: int = resource_system.get_resource("defense_devices")
	var inventory_before: int = resource_system.get_resource("item_wall_ballista")
	var unrelated_events_before: int = memory_system.get_npc_daily_events(unrelated_npc_id).size()
	var plaza_witness_before: int = memory_system.get_npc_witness_events(plaza_witness_id).size()
	var global_events_before: int = memory_system.get_all_events().size()
	var wall_level_one_slot_id := _find_slot_id(wall_slots, 1)
	var wall_level_two_slot_id := _find_slot_id(wall_slots, 2)
	var main_hall_level_one_slot_id := _find_slot_id(main_hall_slots, 1)
	if wall_level_one_slot_id.is_empty() or wall_level_two_slot_id.is_empty() or main_hall_level_one_slot_id.is_empty():
		_fail("Could not resolve configured wall/main-hall deployment slots")
		return
	var locked_result: Dictionary = device_system.deploy_device("wall_arrow_tower", wall_level_two_slot_id)
	if bool(locked_result.get("ok", false)) or str(locked_result.get("code", "")) != "slot_locked":
		_fail("A slot above the host building level should reject deployment")
		return

	var ballista_result: Dictionary = device_system.deploy_device("wall_ballista", wall_level_one_slot_id)
	if not bool(ballista_result.get("ok", false)):
		_fail("Ballista deployment failed: %s" % str(ballista_result))
		return
	if resource_system.get_resource("item_wall_ballista") != inventory_before - 1:
		_fail("Ballista deployment did not consume exactly one item_wall_ballista")
		return
	if resource_system.get_resource("defense_devices") != legacy_inventory_before:
		_fail("Ballista deployment consumed deprecated defense_devices inventory")
		return
	var deploy_event := _find_latest_event(memory_system.get_all_events(), "defense_device_deployed")
	if deploy_event.is_empty() or str(deploy_event.get("payload", {}).get("slot_id", "")) != wall_level_one_slot_id:
		_fail("Deployment event did not enter the global structured event log")
		return
	if not str(deploy_event.get("summary", "")).contains("弩床"):
		_fail("Deployment event does not have a deterministic device summary")
		return
	if str(deploy_event.get("subject_npc_id", "")) != "guard_officer" or deploy_event.get("payload", {}).has("deployer_npc_id"):
		_fail("Deployment event still depends on a deployer NPC")
		return
	if str(deploy_event.get("payload", {}).get("inventory_resource_id", "")) != "item_wall_ballista" or int(deploy_event.get("payload", {}).get("inventory_cost", 0)) != 1:
		_fail("Ballista deployment event did not preserve its exact item cost")
		return
	if memory_system.get_npc_daily_events(unrelated_npc_id).size() != unrelated_events_before:
		_fail("Player deployment unexpectedly entered an NPC event log")
		return
	if memory_system.get_all_events().size() != global_events_before + 1:
		_fail("Ballista deployment created an unexpected number of global events")
		return
	if memory_system.get_npc_witness_events(plaza_witness_id).size() != plaza_witness_before + 1:
		_fail("Ballista deployment was not broadcast through the plaza information node")
		return

	var inventory_before_duplicate: int = resource_system.get_resource("item_wall_ballista")
	var events_before_duplicate: int = memory_system.get_all_events().size()
	var duplicate_result: Dictionary = device_system.deploy_device("wall_ballista", wall_level_one_slot_id)
	if bool(duplicate_result.get("ok", false)) or str(duplicate_result.get("code", "")) != "slot_occupied":
		_fail("Occupied wall slot did not reject a duplicate deployment")
		return
	if resource_system.get_resource("item_wall_ballista") != inventory_before_duplicate or memory_system.get_all_events().size() != events_before_duplicate:
		_fail("Failed duplicate deployment changed inventory or event state")
		return

	var main_hall_ballista_result: Dictionary = device_system.deploy_device("wall_ballista", main_hall_level_one_slot_id)
	if not bool(main_hall_ballista_result.get("ok", false)):
		_fail("Main-hall ballista deployment failed: %s" % str(main_hall_ballista_result))
		return
	var wall_ballista: Dictionary = device_system.get_deployment(str(ballista_result.get("deployment_id", "")))
	var main_hall_ballista: Dictionary = device_system.get_deployment(str(main_hall_ballista_result.get("deployment_id", "")))
	var wall_range := float(wall_ballista.get("effect", {}).get("range", 0.0))
	var main_hall_range := float(main_hall_ballista.get("effect", {}).get("range", 0.0))
	if wall_range <= 0.0 or not is_equal_approx(main_hall_range, wall_range * 2.0):
		_fail("Main-hall deployment should double the same device's effective range")
		return
	if int(wall_ballista.get("hp", 0)) != int(ballista_definition.get("max_hp", 0)):
		_fail("Deployed defense device should expose configured HP")
		return

	_set_building_level_for_slot_test(building_system, "wall", 2)
	var arrow_tower_inventory_before := int(resource_system.get_resource("item_wall_arrow_tower"))
	var arrow_tower_result: Dictionary = device_system.deploy_device("wall_arrow_tower", wall_level_two_slot_id)
	if not bool(arrow_tower_result.get("ok", false)):
		_fail("Arrow-tower deployment failed: %s" % str(arrow_tower_result))
		return
	if int(resource_system.get_resource("item_wall_arrow_tower")) != arrow_tower_inventory_before - 1:
		_fail("Arrow tower deployment did not consume item_wall_arrow_tower")
		return
	if int(resource_system.get_resource("item_wall_ballista")) != 0 or int(resource_system.get_resource("defense_devices")) != legacy_inventory_before:
		_fail("Device deployments mixed concrete inventories or changed the deprecated aggregate")
		return
	var arrow_deploy_event := _find_latest_event(memory_system.get_all_events(), "defense_device_deployed")
	if str(arrow_deploy_event.get("payload", {}).get("inventory_resource_id", "")) != "item_wall_arrow_tower":
		_fail("Arrow-tower deployment event did not preserve its exact item id")
		return

	await process_frame
	if presenter.get_view_count() != 3:
		_fail("Defense-device presenter did not create one view per deployment")
		return
	var ballista_view: Node3D = presenter.get_view_for_deployment(str(ballista_result.get("deployment_id", "")))
	if ballista_view == null or ballista_view.get_node_or_null("ModelMount") == null or ballista_view.get_node("ModelMount").get_child_count() == 0:
		_fail("DefenseDeviceView model contract or placeholder presentation is missing")
		return
	var arrow_tower_view: Node3D = presenter.get_view_for_deployment(str(arrow_tower_result.get("deployment_id", "")))
	if arrow_tower_view == null or arrow_tower_view.get_node_or_null("ModelMount") == null or arrow_tower_view.get_node("ModelMount").get_child_count() == 0:
		_fail("Arrow-tower placeholder or model contract is missing")
		return

	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)) or combat_system.get_active_enemy_count() <= 0:
		_fail("Could not spawn an enemy wave for ballista verification")
		return
	var hp_before_attack := _sum_enemy_hp(combat_system.get_active_enemies())
	var device_step: Dictionary = device_system.debug_advance_defense_devices(60.0)
	var hp_after_attack := _sum_enemy_hp(combat_system.get_active_enemies())
	if (device_step.get("actions", []) as Array).is_empty() or hp_after_attack >= hp_before_attack:
		_fail("Deployed defense devices did not automatically damage an enemy")
		return
	if _find_device_action(device_step.get("actions", []), "wall_ballista").is_empty():
		_fail("Deployed ballista did not execute an automatic attack")
		return
	if _find_device_action(device_step.get("actions", []), "wall_arrow_tower").is_empty():
		_fail("Deployed arrow tower did not execute an automatic attack")
		return
	var trigger_event := _find_latest_event(memory_system.get_all_events(), "defense_device_triggered")
	if trigger_event.is_empty() or int(trigger_event.get("payload", {}).get("damage", 0)) <= 0:
		_fail("Defense-device attack did not create a structured action event")
		return
	if str(trigger_event.get("subject_npc_id", "")) != "guard_officer" or trigger_event.get("payload", {}).has("deployer_npc_id"):
		_fail("Defense-device trigger event still depends on a deployer NPC")
		return

	print("T0036 concrete defense-device inventory verification passed.")
	quit(0)


func _find_slot_id(slots: Array, required_level: int) -> String:
	for raw_slot in slots:
		var slot: Dictionary = raw_slot if raw_slot is Dictionary else {}
		if int(slot.get("required_building_level", 0)) == required_level:
			return str(slot.get("id", ""))
	return ""


func _set_building_level_for_slot_test(building_system: Node, building_id: String, level: int) -> void:
	var buildings: Dictionary = building_system.get("_buildings")
	var building: Dictionary = buildings.get(building_id, {})
	building["level"] = level
	buildings[building_id] = building
	building_system.set("_buildings", buildings)


func _find_latest_event(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event: Variant = events[index]
		if event is Dictionary and str(event.get("type", "")) == event_type:
			return event
	return {}


func _find_device_action(actions: Array, device_id: String) -> Dictionary:
	for raw_action in actions:
		if raw_action is Dictionary and str(raw_action.get("device_id", "")) == device_id and int(raw_action.get("attack_count", 0)) > 0:
			return raw_action
	return {}


func _sum_enemy_hp(enemies: Array) -> int:
	var total := 0
	for raw_enemy in enemies:
		if raw_enemy is Dictionary:
			total += int(raw_enemy.get("hp", 0))
	return total


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
