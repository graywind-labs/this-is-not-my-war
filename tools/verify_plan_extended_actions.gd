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
	if action_system == null or daily_plan_system == null or npc_system == null or memory_system == null:
		_fail("Required systems not found")
		return

	daily_plan_system.set_auto_execution_enabled(false)
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
	if not npc_system.debug_enter_location_immediately(VISITOR_ID, "chapel"):
		_fail("Failed to simulate arrival at the visit target")
		return
	await process_frame
	if action_system.get_active_action_id(VISITOR_ID) != "visit_location":
		_fail("Visit did not start after the NPC arrived at the planned target")
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


func _find_latest_event(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var raw_event = events[index]
		if raw_event is Dictionary and str((raw_event as Dictionary).get("type", "")) == event_type:
			return (raw_event as Dictionary).duplicate(true)
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
