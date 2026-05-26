extends SceneTree


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	if action_system == null or npc_system == null or building_system == null or resource_system == null or memory_system == null:
		push_error("Required systems not found")
		quit(1)
		return

	var npc_id := "veteran_deputy_01"
	_set_debug_move_speed(npc_id, 80.0)

	npc_system.update_npc_state(npc_id, {"satiety": 40, "fatigue": 70})
	var grain_before: int = resource_system.get_resource("grain")
	if not action_system.debug_assign_eat(npc_id):
		push_error("Failed to assign eat action")
		quit(1)
		return
	if not await _wait_until_current_action(npc_system, npc_id, "eat_at_dining_hall"):
		push_error("Eat action did not start")
		quit(1)
		return
	action_system._on_logical_time_tick(1200.0, 1.0)
	if not await _wait_until_action_result(npc_system, npc_id, "completed_eat"):
		push_error("Eat action did not complete")
		quit(1)
		return
	var after_grain_eat: Dictionary = npc_system.get_npc_state(npc_id)
	if int(after_grain_eat.get("satiety", 0)) != 65 or resource_system.get_resource("grain") != grain_before - 1:
		push_error("Grain eating result mismatch")
		quit(1)
		return

	resource_system.add_resource("meal", 1)
	npc_system.update_npc_state(npc_id, {"satiety": 40, "last_action_result": ""})
	if not action_system.debug_assign_eat(npc_id):
		push_error("Failed to assign meal eat action")
		quit(1)
		return
	if not await _wait_until_current_action(npc_system, npc_id, "eat_at_dining_hall"):
		push_error("Meal eat action did not start")
		quit(1)
		return
	action_system._on_logical_time_tick(600.0, 1.0)
	var mid_meal_eat: Dictionary = npc_system.get_npc_state(npc_id)
	if int(mid_meal_eat.get("satiety", 0)) != 65 or str(mid_meal_eat.get("last_action_result", "")) == "completed_eat":
		push_error("Meal eating should restore satiety over time before completion")
		quit(1)
		return
	action_system._on_logical_time_tick(600.0, 1.0)
	if not await _wait_until_action_result(npc_system, npc_id, "completed_eat"):
		push_error("Meal eat action did not complete")
		quit(1)
		return
	var after_meal_eat: Dictionary = npc_system.get_npc_state(npc_id)
	if int(after_meal_eat.get("satiety", 0)) != 90 or resource_system.get_resource("meal") != 0:
		push_error("Meal eating result mismatch")
		quit(1)
		return

	npc_system.update_npc_state(npc_id, {"fatigue": 70, "last_action_result": ""})
	if not action_system.debug_assign_sleep(npc_id):
		push_error("Failed to assign sleep action")
		quit(1)
		return
	if not await _wait_until_current_action(npc_system, npc_id, "sleep_in_dormitory"):
		push_error("Sleep action did not start")
		quit(1)
		return
	action_system._on_logical_time_tick(11700.0, 1.0)
	var mid_sleep: Dictionary = npc_system.get_npc_state(npc_id)
	if int(mid_sleep.get("fatigue", 0)) != 20 or str(mid_sleep.get("last_action_result", "")) == "completed_sleep":
		push_error("Sleep should reduce fatigue over time before completion")
		quit(1)
		return
	action_system._on_logical_time_tick(11700.0, 1.0)
	if not await _wait_until_action_result(npc_system, npc_id, "completed_sleep"):
		push_error("Sleep action did not complete")
		quit(1)
		return
	var after_sleep: Dictionary = npc_system.get_npc_state(npc_id)
	if int(after_sleep.get("fatigue", 0)) != 0:
		push_error("Sleep fatigue result mismatch")
		quit(1)
		return

	var worker_id := "gardener_01"
	_set_debug_move_speed(worker_id, 80.0)
	var grain_before_work: int = resource_system.get_resource("grain")
	npc_system.update_npc_state(worker_id, {"satiety": 80, "fatigue": 20, "last_action_result": ""})
	if not action_system.debug_assign_work(worker_id, "garden"):
		push_error("Failed to assign garden work")
		quit(1)
		return
	if not await _wait_until_current_action(npc_system, worker_id, "work_garden"):
		push_error("Garden work did not start")
		quit(1)
		return
	action_system._on_logical_time_tick(3600.0, 1.0)
	if not await _wait_until_action_result(npc_system, worker_id, "completed_work_garden"):
		push_error("Garden work did not complete")
		quit(1)
		return
	var after_work: Dictionary = npc_system.get_npc_state(worker_id)
	if resource_system.get_resource("grain") != grain_before_work + 2:
		push_error("Garden work resource output mismatch")
		quit(1)
		return
	if int(after_work.get("satiety", 0)) != 76 or int(after_work.get("fatigue", 0)) != 28:
		push_error("Garden work state delta mismatch")
		quit(1)
		return

	var cook_id := "cook_01"
	_set_debug_move_speed(cook_id, 80.0)
	var grain_before_tavern: int = resource_system.get_resource("grain")
	var wine_before: int = resource_system.get_resource("wine")
	npc_system.update_npc_state(cook_id, {"satiety": 80, "fatigue": 20, "last_action_result": ""})
	if not action_system.debug_assign_work(cook_id, "tavern"):
		push_error("Failed to assign tavern work")
		quit(1)
		return
	if not await _wait_until_current_action(npc_system, cook_id, "work_tavern"):
		push_error("Tavern work did not start")
		quit(1)
		return
	action_system._on_logical_time_tick(3600.0, 1.0)
	if not await _wait_until_action_result(npc_system, cook_id, "completed_work_tavern"):
		push_error("Tavern work did not complete")
		quit(1)
		return
	if resource_system.get_resource("grain") != grain_before_tavern - 1 or resource_system.get_resource("wine") != wine_before + 1:
		push_error("Tavern work resource result mismatch")
		quit(1)
		return

	var blacksmith_id := "blacksmith_01"
	_set_debug_move_speed(blacksmith_id, 80.0)
	var iron_before: int = resource_system.get_resource("iron")
	var wood_before_blacksmith: int = resource_system.get_resource("wood")
	var weapons_before: int = resource_system.get_resource("weapons")
	var armor_before: int = resource_system.get_resource("armor")
	npc_system.update_npc_state(blacksmith_id, {"satiety": 80, "fatigue": 20, "last_action_result": ""})
	if not action_system.debug_assign_work(blacksmith_id, "blacksmith"):
		push_error("Failed to assign blacksmith work")
		quit(1)
		return
	if not await _wait_until_current_action(npc_system, blacksmith_id, "work_blacksmith"):
		push_error("Blacksmith work did not start")
		quit(1)
		return
	action_system._on_logical_time_tick(3600.0, 1.0)
	if not await _wait_until_action_result(npc_system, blacksmith_id, "completed_work_blacksmith"):
		push_error("Blacksmith work did not complete")
		quit(1)
		return
	if resource_system.get_resource("iron") != iron_before - 1 or resource_system.get_resource("wood") != wood_before_blacksmith - 1:
		push_error("Blacksmith input resource mismatch")
		quit(1)
		return
	if resource_system.get_resource("weapons") != weapons_before + 1 or resource_system.get_resource("armor") != armor_before + 1:
		push_error("Blacksmith output resource mismatch")
		quit(1)
		return

	var engineer_id := "engineer_01"
	_set_debug_move_speed(engineer_id, 80.0)
	var wood_before_workshop: int = resource_system.get_resource("wood")
	var devices_before: int = resource_system.get_resource("defense_devices")
	npc_system.update_npc_state(engineer_id, {"satiety": 80, "fatigue": 20, "last_action_result": ""})
	if not action_system.debug_assign_work(engineer_id, "workshop"):
		push_error("Failed to assign workshop work")
		quit(1)
		return
	if not await _wait_until_current_action(npc_system, engineer_id, "work_workshop"):
		push_error("Workshop work did not start")
		quit(1)
		return
	action_system._on_logical_time_tick(3600.0, 1.0)
	if not await _wait_until_action_result(npc_system, engineer_id, "completed_work_workshop"):
		push_error("Workshop work did not complete")
		quit(1)
		return
	if resource_system.get_resource("wood") != wood_before_workshop - 2 or resource_system.get_resource("defense_devices") != devices_before + 1:
		push_error("Workshop resource result mismatch")
		quit(1)
		return

	var wall_before: Dictionary = building_system.get_building("wall")
	var wall_max_hp := int(wall_before.get("max_hp", 0))
	building_system.debug_damage_building("wall", 30)
	var stone_before_wall: int = resource_system.get_resource("stone")
	if not building_system.repair_building("wall"):
		push_error("Failed to start wall repair")
		quit(1)
		return
	if resource_system.get_resource("stone") != stone_before_wall - 1:
		push_error("Wall repair did not spend stone up front")
		quit(1)
		return
	npc_system.update_npc_state(engineer_id, {"satiety": 80, "fatigue": 20, "last_action_result": ""})
	if not action_system.debug_assign_repair_assist(engineer_id, "wall"):
		push_error("Failed to assign wall repair assist")
		quit(1)
		return
	if not await _wait_until_action_result(npc_system, engineer_id, "assist_repair_started_wall"):
		push_error("Wall repair assist did not start")
		quit(1)
		return
	var engineer_repair_started: Dictionary = npc_system.get_npc_state(engineer_id)
	if str(engineer_repair_started.get("current_location", "")) != "plaza":
		push_error("Repair assist should happen from plaza, not inside the target building")
		quit(1)
		return
	var repair_event := _find_latest_event(memory_system.get_all_events(), "repair_assist_started")
	if str(repair_event.get("location_id", "")) != "plaza" or str(repair_event.get("visibility", "")) != "local_public":
		push_error("Repair assist event should be local_public at plaza")
		quit(1)
		return
	var repair_status: Dictionary = building_system.get_repair_status("wall")
	if int(repair_status.get("helper_count", 0)) != 1 or float(repair_status.get("speed_multiplier", 1.0)) <= 1.0:
		push_error("Wall repair assist did not speed up repair")
		quit(1)
		return

	if not npc_system.debug_enter_location_immediately(engineer_id, "garden"):
		push_error("Failed to move repair helper away from wall")
		quit(1)
		return
	repair_status = building_system.get_repair_status("wall")
	if int(repair_status.get("helper_count", 0)) != 0 or float(repair_status.get("speed_multiplier", 1.0)) != 1.0:
		push_error("Repair helper speed bonus remained after NPC left plaza")
		quit(1)
		return

	npc_system.update_npc_state(engineer_id, {"last_action_result": ""})
	if not action_system.debug_assign_repair_assist(engineer_id, "wall"):
		push_error("Failed to reassign wall repair assist")
		quit(1)
		return
	if not await _wait_until_action_result(npc_system, engineer_id, "assist_repair_started_wall"):
		push_error("Wall repair assist did not restart")
		quit(1)
		return
	building_system._on_logical_time_tick(900.0, 1.0)
	var wall_after: Dictionary = building_system.get_building("wall")
	if int(wall_after.get("hp", 0)) != wall_max_hp:
		push_error("Wall repair did not finish with assisted time progress")
		quit(1)
		return
	var engineer_after_repair: Dictionary = npc_system.get_npc_state(engineer_id)
	if str(engineer_after_repair.get("last_action_result", "")) != "completed_assist_repair_wall":
		push_error("Repair helper NPC was not released after repair")
		quit(1)
		return

	var wall_before_upgrade: Dictionary = building_system.get_building("wall")
	var stone_before_upgrade: int = resource_system.get_resource("stone")
	if not building_system.upgrade_building("wall"):
		push_error("Failed to start wall upgrade")
		quit(1)
		return
	if resource_system.get_resource("stone") != stone_before_upgrade - 3:
		push_error("Wall upgrade did not spend stone up front")
		quit(1)
		return
	npc_system.update_npc_state(engineer_id, {"satiety": 80, "fatigue": 20, "last_action_result": ""})
	if not action_system.debug_assign_upgrade_assist(engineer_id, "wall"):
		push_error("Failed to assign wall upgrade assist")
		quit(1)
		return
	if not await _wait_until_action_result(npc_system, engineer_id, "assist_upgrade_started_wall"):
		push_error("Wall upgrade assist did not start")
		quit(1)
		return
	var engineer_upgrade_started: Dictionary = npc_system.get_npc_state(engineer_id)
	if str(engineer_upgrade_started.get("current_location", "")) != "plaza":
		push_error("Upgrade assist should happen from plaza, not inside the target building")
		quit(1)
		return
	var upgrade_event := _find_latest_event(memory_system.get_all_events(), "upgrade_assist_started")
	if str(upgrade_event.get("location_id", "")) != "plaza" or str(upgrade_event.get("visibility", "")) != "local_public":
		push_error("Upgrade assist event should be local_public at plaza")
		quit(1)
		return
	var upgrade_status: Dictionary = building_system.get_upgrade_status("wall")
	if int(upgrade_status.get("helper_count", 0)) != 1 or float(upgrade_status.get("speed_multiplier", 1.0)) <= 1.0:
		push_error("Wall upgrade assist did not speed up upgrade")
		quit(1)
		return
	building_system._on_logical_time_tick(3600.0, 1.0)
	var wall_after_upgrade: Dictionary = building_system.get_building("wall")
	if int(wall_after_upgrade.get("level", 0)) != int(wall_before_upgrade.get("level", 0)) + 1:
		push_error("Wall upgrade did not finish with assisted time progress")
		quit(1)
		return
	var engineer_after_upgrade: Dictionary = npc_system.get_npc_state(engineer_id)
	if str(engineer_after_upgrade.get("last_action_result", "")) != "completed_assist_upgrade_wall":
		push_error("Upgrade helper NPC was not released after upgrade")
		quit(1)
		return

	if memory_system.get_event_count() < 8:
		push_error("Action events were not written to structured event log")
		quit(1)
		return

	print("T0305 basic action system verification passed.")
	quit(0)


func _wait_until_action_result(npc_system: Node, npc_id: String, expected_result: String) -> bool:
	for frame in range(600):
		await process_frame
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		if str(state.get("last_action_result", "")) == expected_result:
			return true
	return false


func _wait_until_current_action(npc_system: Node, npc_id: String, expected_action: String) -> bool:
	for frame in range(600):
		await process_frame
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		if str(state.get("current_action", "")) == expected_action:
			return true
	return false


func _find_latest_event(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event = events[index]
		if event is Dictionary and str(event.get("type", "")) == event_type:
			return event
	return {}


func _set_debug_move_speed(npc_id: String, speed: float) -> void:
	var npc_root := root.get_node_or_null("Main/WorldRoot/Station/NPCs")
	if npc_root == null:
		return

	for npc_node in npc_root.get_children():
		if str(npc_node.get_meta("npc_id", "")) == npc_id and "move_speed" in npc_node:
			npc_node.move_speed = speed
			return
