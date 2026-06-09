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

	var garden_action: Dictionary = action_system.get_action("work_garden")
	if str(garden_action.get("location_required", "")) != "garden":
		push_error("Garden work action is not bound to garden")
		quit(1)
		return
	if str(garden_action.get("skill", "")) != "耕种":
		push_error("Garden work should use farming skill")
		quit(1)
		return
	if str(garden_action.get("stat", "")) != "strength":
		push_error("Garden work should use strength as its attribute")
		quit(1)
		return
	if int(garden_action.get("output_resources", {}).get("grain", 0)) != 2:
		push_error("Garden work should have 2 base grain output")
		quit(1)
		return

	var gardener_id := "gardener_01"
	var stableman_id := "stableman_01"
	var blacksmith_id := "blacksmith_01"
	var engineer_id := "engineer_01"
	_set_debug_move_speed(gardener_id, 100.0)

	var gardener_level_1_output := int(action_system._get_work_output_resources(garden_action, gardener_id).get("grain", 0))
	var stableman_level_1_output := int(action_system._get_work_output_resources(garden_action, stableman_id).get("grain", 0))
	if not gardener_level_1_output > stableman_level_1_output:
		push_error("Farming skill should increase garden grain output")
		quit(1)
		return

	var blacksmith_output := int(action_system._get_work_output_resources(garden_action, blacksmith_id).get("grain", 0))
	var engineer_output := int(action_system._get_work_output_resources(garden_action, engineer_id).get("grain", 0))
	if not blacksmith_output > engineer_output:
		push_error("Strength should increase garden grain output when farming skill is comparable")
		quit(1)
		return

	if not building_system.upgrade_building("garden"):
		push_error("Failed to start garden upgrade for output verification")
		quit(1)
		return
	building_system._on_logical_time_tick(99999.0, 1.0)
	var garden_after_upgrade: Dictionary = building_system.get_building("garden")
	if int(garden_after_upgrade.get("level", 1)) < 2:
		push_error("Garden upgrade did not complete")
		quit(1)
		return
	var gardener_level_2_output := int(action_system._get_work_output_resources(garden_action, gardener_id).get("grain", 0))
	if not gardener_level_2_output > gardener_level_1_output:
		push_error("Garden level should increase grain output")
		quit(1)
		return

	var grain_before := int(resource_system.get_resource("grain"))
	var gardener_events_before := int(memory_system.get_npc_daily_events(gardener_id).size())
	npc_system.debug_enter_location_immediately(gardener_id, "garden")
	npc_system.update_npc_state(gardener_id, {"satiety": 80, "fatigue": 20, "last_action_result": ""})
	if not action_system.debug_assign_work(gardener_id, "garden"):
		push_error("Failed to assign garden work")
		quit(1)
		return
	if not await _wait_until_current_action(npc_system, gardener_id, "work_garden"):
		push_error("Garden work did not start")
		quit(1)
		return
	var gardener_duration: float = action_system._get_effective_action_duration_seconds(garden_action, gardener_id)
	action_system._on_logical_time_tick(gardener_duration + 1.0, 1.0)
	if not await _wait_until_action_result(npc_system, gardener_id, "completed_work_garden"):
		push_error("Garden work did not complete")
		quit(1)
		return
	if int(resource_system.get_resource("grain")) != grain_before + gardener_level_2_output:
		push_error("Garden work did not add scaled grain output")
		quit(1)
		return

	var work_completed := _find_event(_events_after(memory_system.get_npc_daily_events(gardener_id), gardener_events_before), "work_completed")
	if work_completed.is_empty() or str(work_completed.get("payload", {}).get("action_id", "")) != "work_garden":
		push_error("Garden work completion event missing from gardener event log")
		quit(1)
		return
	if int(work_completed.get("payload", {}).get("output_resources", {}).get("grain", 0)) != gardener_level_2_output:
		push_error("Garden work completion event missing scaled grain output")
		quit(1)
		return

	print("T0803 garden grain output verification passed.")
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
