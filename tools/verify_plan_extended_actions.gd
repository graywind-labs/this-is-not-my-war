extends SceneTree

const MAIN_SCENE := "res://scenes/main/Main.tscn"
const PRIEST_ID := "priest_01"
const VISITOR_ID := "engineer_01"


func _init() -> void:
	var main_scene := load(MAIN_SCENE) as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	await process_frame

	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if action_system == null or daily_plan_system == null or npc_system == null or memory_system == null or time_system == null:
		_fail("Required systems not found")
		return

	daily_plan_system.set_auto_execution_enabled(false)
	time_system.set_paused(false)
	_prepare_idle_npc(action_system, npc_system, PRIEST_ID, "chapel")
	var prayer_item: Dictionary = daily_plan_system.call("_plan_item_from_schema", {
		"hour": 8,
		"action_id": "pray_at_chapel",
		"action_kind": "pray",
		"location_id": "chapel",
		"target_id": null,
		"priority": 50,
		"reason": "去礼拜堂祈祷。",
	}, "verify_plan_extended_actions", PRIEST_ID)
	if prayer_item.is_empty() or not bool(daily_plan_system.call("_assign_plan_item", PRIEST_ID, prayer_item)):
		_fail("DailyPlanSystem failed to execute pray_at_chapel")
		return
	if not await _wait_for_active(action_system, time_system, PRIEST_ID, "pray_at_chapel"):
		_fail("Prayer actor did not physically reach a chapel seat")
		return
	if action_system.get_active_action_id(PRIEST_ID) != "pray_at_chapel":
		_fail("Prayer did not become the priest's active runtime action")
		return
	if _find_latest_event(memory_system.get_all_events(), "prayer_started").is_empty():
		_fail("Prayer start was not written to structured memory")
		return
	action_system._on_logical_time_tick(100000.0, 1.0)
	await process_frame
	if str(npc_system.get_npc_state(PRIEST_ID).get("last_action_result", "")) != "completed_prayer":
		_fail("Prayer did not complete through logical-time progression")
		return
	if _find_latest_event(memory_system.get_all_events(), "prayer_completed").is_empty():
		_fail("Prayer completion was not written to structured memory")
		return

	_prepare_idle_npc(action_system, npc_system, VISITOR_ID, "plaza")
	_set_debug_move_speed(npc_system, VISITOR_ID, 5.0)
	var visit_item: Dictionary = daily_plan_system.call("_plan_item_from_schema", {
		"hour": 9,
		"action_id": "visit_location",
		"action_kind": "visit",
		"location_id": "chapel",
		"target_id": "chapel",
		"priority": 50,
		"reason": "去礼拜堂找人。",
	}, "verify_plan_extended_actions", VISITOR_ID)
	if visit_item.is_empty() or not bool(daily_plan_system.call("_assign_plan_item", VISITOR_ID, visit_item)):
		_fail("DailyPlanSystem failed to dispatch visit_location")
		return
	if action_system.get_pending_action_id(VISITOR_ID) != "visit_location":
		_fail("Visit did not enter the movement-aware pending state")
		return
	if not await _wait_for_active(action_system, time_system, VISITOR_ID, "visit_location", 2400):
		_fail("Visit did not start after the NPC physically reached the planned target")
		return
	if str(npc_system.get_npc_state(VISITOR_ID).get("current_action", "")) != "visit_location_chapel":
		_fail("Visit runtime state does not expose the target location")
		return
	if _find_latest_event(memory_system.get_all_events(), "visit_started").is_empty():
		_fail("Visit start was not written to structured memory")
		return
	action_system._on_logical_time_tick(100000.0, 1.0)
	await process_frame
	if str(npc_system.get_npc_state(VISITOR_ID).get("last_action_result", "")) != "completed_visit_chapel":
		_fail("Visit did not complete through logical-time progression")
		return
	if _find_latest_event(memory_system.get_all_events(), "visit_completed").is_empty():
		_fail("Visit completion was not written to structured memory")
		return

	print("T0025 extended plan action runtime verification passed.")
	main.queue_free()
	await process_frame
	quit(0)


func _wait_for_active(action_system: Node, time_system: Node, npc_id: String, action_id: String, max_frames: int = 1800) -> bool:
	for _frame in range(max_frames):
		time_system.set_paused(false)
		await physics_frame
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
		if str(runtime.get("phase", "")) == "active" and str(runtime.get("action_id", "")) == action_id:
			return true
	return false


func _prepare_idle_npc(action_system: Node, npc_system: Node, npc_id: String, location_id: String) -> void:
	action_system.interrupt_npc_action(npc_id, "verify_plan_extended_actions_setup")
	npc_system.update_npc_state(npc_id, {
		"behavior_mode": "work",
		"current_action": "idle",
		"last_action_result": "verify_plan_extended_actions_setup",
		"unconscious": false,
		"escaped": false,
	})
	npc_system.debug_enter_location_immediately(npc_id, location_id)


func _set_debug_move_speed(npc_system: Node, npc_id: String, speed: float) -> void:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	var npc_node := npc_system.get_node_or_null(node_paths.get(npc_id, NodePath("")))
	if npc_node != null and "move_speed" in npc_node:
		npc_node.move_speed = speed


func _find_latest_event(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var raw_event = events[index]
		if raw_event is Dictionary and str((raw_event as Dictionary).get("type", "")) == event_type:
			return (raw_event as Dictionary).duplicate(true)
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
