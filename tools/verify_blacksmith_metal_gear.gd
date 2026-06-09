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

	var blacksmith_action: Dictionary = action_system.get_action("work_blacksmith")
	if str(blacksmith_action.get("location_required", "")) != "blacksmith":
		push_error("Blacksmith work action is not bound to blacksmith")
		quit(1)
		return
	if str(blacksmith_action.get("skill", "")) != "打铁":
		push_error("Blacksmith work should use smithing skill")
		quit(1)
		return
	if str(blacksmith_action.get("stat", "")) != "strength":
		push_error("Blacksmith work should use strength as its attribute")
		quit(1)
		return
	if int(blacksmith_action.get("input_resources", {}).get("iron", 0)) != 2:
		push_error("Blacksmith work should consume 2 iron")
		quit(1)
		return
	if int(blacksmith_action.get("input_resources", {}).get("wood", 0)) != 0:
		push_error("Blacksmith work should not consume wood for metal gear")
		quit(1)
		return
	if int(blacksmith_action.get("output_resources", {}).get("weapons", 0)) != 1:
		push_error("Blacksmith work should output 1 weapons inventory item")
		quit(1)
		return
	if int(blacksmith_action.get("output_resources", {}).get("armor", 0)) != 1:
		push_error("Blacksmith work should output 1 armor inventory item")
		quit(1)
		return

	var blacksmith_id := "blacksmith_01"
	var engineer_id := "engineer_01"
	_set_debug_move_speed(blacksmith_id, 100.0)

	var base_duration := float(blacksmith_action.get("duration_seconds", 3600.0))
	var blacksmith_duration_level_1: float = action_system._get_effective_action_duration_seconds(blacksmith_action, blacksmith_id)
	var engineer_duration: float = action_system._get_effective_action_duration_seconds(blacksmith_action, engineer_id)
	if not (blacksmith_duration_level_1 < engineer_duration and blacksmith_duration_level_1 < base_duration):
		push_error("Smithing skill and strength did not shorten blacksmith work duration")
		quit(1)
		return

	if not building_system.upgrade_building("blacksmith"):
		push_error("Failed to start blacksmith upgrade for efficiency verification")
		quit(1)
		return
	building_system._on_logical_time_tick(99999.0, 1.0)
	var blacksmith_building_after_upgrade: Dictionary = building_system.get_building("blacksmith")
	if int(blacksmith_building_after_upgrade.get("level", 1)) < 2:
		push_error("Blacksmith upgrade did not complete")
		quit(1)
		return
	var blacksmith_duration_level_2: float = action_system._get_effective_action_duration_seconds(blacksmith_action, blacksmith_id)
	if not blacksmith_duration_level_2 < blacksmith_duration_level_1:
		push_error("Blacksmith level did not improve work efficiency")
		quit(1)
		return

	resource_system.add_resource("iron", 10)
	resource_system.add_resource("weapons", -9999)
	resource_system.add_resource("armor", -9999)
	var iron_before := int(resource_system.get_resource("iron"))
	var weapons_before := int(resource_system.get_resource("weapons"))
	var armor_before := int(resource_system.get_resource("armor"))
	var events_before := int(memory_system.get_npc_daily_events(blacksmith_id).size())

	npc_system.debug_enter_location_immediately(blacksmith_id, "blacksmith")
	npc_system.update_npc_state(blacksmith_id, {"satiety": 80, "fatigue": 20, "last_action_result": ""})
	if not action_system.debug_assign_work(blacksmith_id, "blacksmith"):
		push_error("Failed to assign blacksmith work")
		quit(1)
		return
	if not await _wait_until_current_action(npc_system, blacksmith_id, "work_blacksmith"):
		push_error("Blacksmith work did not start")
		quit(1)
		return

	action_system._on_logical_time_tick(blacksmith_duration_level_2 + 1.0, 1.0)
	if not await _wait_until_action_result(npc_system, blacksmith_id, "completed_work_blacksmith"):
		push_error("Blacksmith work did not complete")
		quit(1)
		return
	if int(resource_system.get_resource("iron")) != iron_before - 2:
		push_error("Blacksmith work did not consume exactly 2 iron")
		quit(1)
		return
	if int(resource_system.get_resource("weapons")) != weapons_before + 1:
		push_error("Blacksmith work did not add weapons inventory")
		quit(1)
		return
	if int(resource_system.get_resource("armor")) != armor_before + 1:
		push_error("Blacksmith work did not add armor inventory")
		quit(1)
		return

	var work_completed := _find_event(_events_after(memory_system.get_npc_daily_events(blacksmith_id), events_before), "work_completed")
	if work_completed.is_empty() or str(work_completed.get("payload", {}).get("action_id", "")) != "work_blacksmith":
		push_error("Blacksmith completion event missing from NPC event log")
		quit(1)
		return
	if int(work_completed.get("payload", {}).get("input_resources", {}).get("iron", 0)) != 2:
		push_error("Blacksmith completion event missing iron input")
		quit(1)
		return
	if int(work_completed.get("payload", {}).get("output_resources", {}).get("weapons", 0)) != 1:
		push_error("Blacksmith completion event missing weapons output")
		quit(1)
		return
	if int(work_completed.get("payload", {}).get("output_resources", {}).get("armor", 0)) != 1:
		push_error("Blacksmith completion event missing armor output")
		quit(1)
		return

	resource_system.add_resource("iron", -9999)
	npc_system.update_npc_state(blacksmith_id, {"last_action_result": ""})
	if action_system.debug_assign_work(blacksmith_id, "blacksmith"):
		push_error("Blacksmith work should fail immediately when iron is missing")
		quit(1)
		return
	var state_after_failure: Dictionary = npc_system.get_npc_state(blacksmith_id)
	if str(state_after_failure.get("last_action_result", "")) != "work_failed_no_resources":
		push_error("Missing iron did not set work_failed_no_resources")
		quit(1)
		return

	print("T0804 blacksmith metal gear verification passed.")
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
