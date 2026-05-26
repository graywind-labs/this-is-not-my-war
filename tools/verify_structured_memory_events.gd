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
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	if action_system == null or npc_system == null or resource_system == null or memory_system == null:
		push_error("Required systems not found")
		quit(1)
		return

	var npc_id := "gardener_01"
	_set_debug_move_speed(npc_id, 80.0)
	npc_system.update_npc_state(npc_id, {"satiety": 80, "fatigue": 20, "last_action_result": ""})
	var grain_before: int = resource_system.get_resource("grain")
	if not action_system.debug_assign_work(npc_id, "garden"):
		push_error("Failed to assign garden work")
		quit(1)
		return
	if not await _wait_until_current_action(npc_system, npc_id, "work_garden"):
		push_error("Garden work did not start")
		quit(1)
		return
	action_system._on_logical_time_tick(3600.0, 1.0)
	if not await _wait_until_action_result(npc_system, npc_id, "completed_work_garden"):
		push_error("Garden work did not complete")
		quit(1)
		return
	if resource_system.get_resource("grain") != grain_before + 2:
		push_error("Garden work resource result mismatch")
		quit(1)
		return

	var eater_id := "veteran_deputy_01"
	_set_debug_move_speed(eater_id, 80.0)
	npc_system.update_npc_state(eater_id, {"satiety": 40, "fatigue": 70, "last_action_result": ""})
	if not action_system.debug_assign_eat(eater_id):
		push_error("Failed to assign eat action")
		quit(1)
		return
	if not await _wait_until_current_action(npc_system, eater_id, "eat_at_dining_hall"):
		push_error("Eat action did not start")
		quit(1)
		return
	action_system._on_logical_time_tick(1200.0, 1.0)
	if not await _wait_until_action_result(npc_system, eater_id, "completed_eat"):
		push_error("Eat action did not complete")
		quit(1)
		return

	npc_system.update_npc_state(eater_id, {"fatigue": 70, "last_action_result": ""})
	if not action_system.debug_assign_sleep(eater_id):
		push_error("Failed to assign sleep action")
		quit(1)
		return
	if not await _wait_until_current_action(npc_system, eater_id, "sleep_in_dormitory"):
		push_error("Sleep action did not start")
		quit(1)
		return
	action_system._on_logical_time_tick(23400.0, 1.0)
	if not await _wait_until_action_result(npc_system, eater_id, "completed_sleep"):
		push_error("Sleep action did not complete")
		quit(1)
		return

	resource_system.spend_resources({"iron": resource_system.get_resource("iron"), "wood": resource_system.get_resource("wood")})
	var blacksmith_id := "blacksmith_01"
	_set_debug_move_speed(blacksmith_id, 80.0)
	npc_system.update_npc_state(blacksmith_id, {"last_action_result": ""})
	if not action_system.debug_assign_work(blacksmith_id, "blacksmith"):
		push_error("Failed to assign blacksmith work")
		quit(1)
		return
	if not await _wait_until_action_result(npc_system, blacksmith_id, "work_failed_no_resources"):
		push_error("Work failure did not complete")
		quit(1)
		return

	var all_events: Array = memory_system.debug_get_all_events()
	if all_events.size() < 8:
		push_error("Structured global event index is too small")
		quit(1)
		return

	var gardener_events: Array = memory_system.debug_get_npc_events(npc_id)
	if not _has_event(gardener_events, "location_entered") or not _has_event(gardener_events, "work_started") or not _has_event(gardener_events, "work_completed"):
		push_error("NPC daily event log missing movement or work events")
		quit(1)
		return

	var eat_events: Array = memory_system.debug_get_npc_events(eater_id)
	if not _has_event(eat_events, "eat_completed") or not _has_event(eat_events, "sleep_ended"):
		push_error("NPC daily event log missing eat or sleep event")
		quit(1)
		return

	var blacksmith_events: Array = memory_system.debug_get_npc_events(blacksmith_id)
	if not _has_event(blacksmith_events, "work_failed"):
		push_error("NPC daily event log missing work_failed event")
		quit(1)
		return

	var plaza_events_before: int = memory_system.debug_get_plaza_events().size()
	var public_event: Dictionary = memory_system.add_event({
		"type": "combat_started",
		"subject_npc_id": npc_id,
		"actor_ids": ["system"],
		"target_ids": ["plaza"],
		"location_id": "plaza",
		"visibility": "local_public",
		"importance": 70,
		"payload": {"wave_id": "debug_wave"}
	})
	if public_event.is_empty() or memory_system.debug_get_plaza_events().size() != plaza_events_before + 1:
		push_error("Plaza local public event query failed")
		quit(1)
		return

	var indoor_public_event: Dictionary = memory_system.add_event({
		"type": "combat_started",
		"subject_npc_id": npc_id,
		"actor_ids": ["system"],
		"target_ids": ["chapel"],
		"location_id": "chapel",
		"visibility": "local_public",
		"importance": 70,
		"payload": {"wave_id": "debug_indoor_wave"}
	})
	if indoor_public_event.is_empty() or memory_system.debug_get_plaza_events().size() != plaza_events_before + 1:
		push_error("Plaza event query should only include local public events at plaza")
		quit(1)
		return

	if not _event_has_required_shape(all_events[0]):
		push_error("Structured event is missing required common fields")
		quit(1)
		return

	var required_payload_fields: Array = memory_system.get_required_payload_fields("work_completed")
	for field in ["action_id", "input_resources", "output_resources"]:
		if not required_payload_fields.has(field):
			push_error("work_completed payload schema missing %s" % field)
			quit(1)
			return

	print("T0402 structured memory event verification passed.")
	quit(0)


func _has_event(events: Array, event_type: String) -> bool:
	for event in events:
		if event is Dictionary and str(event.get("type", "")) == event_type:
			if str(event.get("subject_npc_id", "")).is_empty():
				return false
			if str(event.get("location_id", "")).is_empty():
				return false
			if str(event.get("visibility", "")).is_empty():
				return false
			if not event.get("payload", {}) is Dictionary:
				return false
			if str(event.get("summary", "")).is_empty():
				return false
			return true
	return false


func _event_has_required_shape(event: Dictionary) -> bool:
	for field in [
		"event_id", "day", "time", "type", "subject_npc_id", "actor_ids", "target_ids",
		"location_id", "visibility", "importance", "summary", "payload"
	]:
		if not event.has(field):
			return false
	return event["actor_ids"] is Array and event["target_ids"] is Array and event["payload"] is Dictionary


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


func _set_debug_move_speed(npc_id: String, speed: float) -> void:
	var npc_root := root.get_node_or_null("Main/WorldRoot/Station/NPCs")
	if npc_root == null:
		return

	for npc_node in npc_root.get_children():
		if str(npc_node.get_meta("npc_id", "")) == npc_id and "move_speed" in npc_node:
			npc_node.move_speed = speed
			return
