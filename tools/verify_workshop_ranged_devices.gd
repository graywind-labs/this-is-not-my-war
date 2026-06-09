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

	var workshop_action: Dictionary = action_system.get_action("work_workshop")
	if str(workshop_action.get("location_required", "")) != "workshop":
		push_error("Workshop work action is not bound to workshop")
		quit(1)
		return
	if str(workshop_action.get("skill", "")) != "工程":
		push_error("Workshop work should use engineering skill")
		quit(1)
		return
	if str(workshop_action.get("stat", "")) != "intelligence":
		push_error("Workshop work should use intelligence as its attribute")
		quit(1)
		return
	if int(workshop_action.get("input_resources", {}).get("wood", 0)) != 2:
		push_error("Workshop work should consume 2 wood")
		quit(1)
		return
	if int(workshop_action.get("input_resources", {}).get("iron", 0)) != 0:
		push_error("Workshop T0805 work should not consume iron")
		quit(1)
		return
	if int(workshop_action.get("output_resources", {}).get("weapons", 0)) != 1:
		push_error("Workshop work should output 1 weapons inventory item for bows/crossbows")
		quit(1)
		return
	if int(workshop_action.get("output_resources", {}).get("defense_devices", 0)) != 1:
		push_error("Workshop work should output 1 defense device inventory item")
		quit(1)
		return

	var engineer_id := "engineer_01"
	var blacksmith_id := "blacksmith_01"
	_set_debug_move_speed(engineer_id, 100.0)

	var base_duration := float(workshop_action.get("duration_seconds", 3600.0))
	var engineer_duration_level_1: float = action_system._get_effective_action_duration_seconds(workshop_action, engineer_id)
	var blacksmith_duration: float = action_system._get_effective_action_duration_seconds(workshop_action, blacksmith_id)
	if not (engineer_duration_level_1 < blacksmith_duration and engineer_duration_level_1 < base_duration):
		push_error("Engineering skill and intelligence did not shorten workshop work duration")
		quit(1)
		return

	_set_profile_skill_and_intelligence(npc_system, blacksmith_id, 82, 4)
	var low_int_duration: float = action_system._get_effective_action_duration_seconds(workshop_action, blacksmith_id)
	if not engineer_duration_level_1 < low_int_duration:
		push_error("Intelligence did not improve workshop efficiency when engineering skill is comparable")
		quit(1)
		return

	if not building_system.upgrade_building("workshop"):
		push_error("Failed to start workshop upgrade for efficiency verification")
		quit(1)
		return
	building_system._on_logical_time_tick(99999.0, 1.0)
	var workshop_building_after_upgrade: Dictionary = building_system.get_building("workshop")
	if int(workshop_building_after_upgrade.get("level", 1)) < 2:
		push_error("Workshop upgrade did not complete")
		quit(1)
		return
	var engineer_duration_level_2: float = action_system._get_effective_action_duration_seconds(workshop_action, engineer_id)
	if not engineer_duration_level_2 < engineer_duration_level_1:
		push_error("Workshop level did not improve work efficiency")
		quit(1)
		return

	resource_system.add_resource("wood", 10)
	resource_system.add_resource("weapons", -9999)
	resource_system.add_resource("defense_devices", -9999)
	var wood_before := int(resource_system.get_resource("wood"))
	var weapons_before := int(resource_system.get_resource("weapons"))
	var devices_before := int(resource_system.get_resource("defense_devices"))
	var events_before := int(memory_system.get_npc_daily_events(engineer_id).size())

	npc_system.debug_enter_location_immediately(engineer_id, "workshop")
	npc_system.update_npc_state(engineer_id, {"satiety": 80, "fatigue": 20, "last_action_result": ""})
	if not action_system.debug_assign_work(engineer_id, "workshop"):
		push_error("Failed to assign workshop work")
		quit(1)
		return
	if not await _wait_until_current_action(npc_system, engineer_id, "work_workshop"):
		push_error("Workshop work did not start")
		quit(1)
		return

	action_system._on_logical_time_tick(engineer_duration_level_2 + 1.0, 1.0)
	if not await _wait_until_action_result(npc_system, engineer_id, "completed_work_workshop"):
		push_error("Workshop work did not complete")
		quit(1)
		return
	if int(resource_system.get_resource("wood")) != wood_before - 2:
		push_error("Workshop work did not consume exactly 2 wood")
		quit(1)
		return
	if int(resource_system.get_resource("weapons")) != weapons_before + 1:
		push_error("Workshop work did not add weapons inventory")
		quit(1)
		return
	if int(resource_system.get_resource("defense_devices")) != devices_before + 1:
		push_error("Workshop work did not add defense device inventory")
		quit(1)
		return

	var work_completed := _find_event(_events_after(memory_system.get_npc_daily_events(engineer_id), events_before), "work_completed")
	if work_completed.is_empty() or str(work_completed.get("payload", {}).get("action_id", "")) != "work_workshop":
		push_error("Workshop completion event missing from NPC event log")
		quit(1)
		return
	if int(work_completed.get("payload", {}).get("input_resources", {}).get("wood", 0)) != 2:
		push_error("Workshop completion event missing wood input")
		quit(1)
		return
	if int(work_completed.get("payload", {}).get("output_resources", {}).get("weapons", 0)) != 1:
		push_error("Workshop completion event missing weapons output")
		quit(1)
		return
	if int(work_completed.get("payload", {}).get("output_resources", {}).get("defense_devices", 0)) != 1:
		push_error("Workshop completion event missing defense device output")
		quit(1)
		return

	resource_system.add_resource("wood", -9999)
	npc_system.update_npc_state(engineer_id, {"last_action_result": ""})
	if action_system.debug_assign_work(engineer_id, "workshop"):
		push_error("Workshop work should fail immediately when wood is missing")
		quit(1)
		return
	var state_after_failure: Dictionary = npc_system.get_npc_state(engineer_id)
	if str(state_after_failure.get("last_action_result", "")) != "work_failed_no_resources":
		push_error("Missing wood did not set work_failed_no_resources")
		quit(1)
		return

	print("T0805 workshop ranged weapons and defense devices verification passed.")
	quit(0)


func _set_profile_skill_and_intelligence(npc_system: Node, npc_id: String, engineering_skill: int, intelligence: int) -> void:
	var profile: Dictionary = npc_system._profiles.get(npc_id, {}).duplicate(true)
	var skills: Dictionary = profile.get("skills", {}).duplicate(true)
	skills["工程"] = engineering_skill
	profile["skills"] = skills
	var stats: Dictionary = profile.get("stats", {}).duplicate(true)
	stats["intelligence"] = intelligence
	profile["stats"] = stats
	npc_system._profiles[npc_id] = profile


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


func _events_after(events: Array, start_index: int) -> Array:
	var result: Array = []
	for index in range(start_index, events.size()):
		result.append(events[index])
	return result


func _find_event(events: Array, event_type: String) -> Dictionary:
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
