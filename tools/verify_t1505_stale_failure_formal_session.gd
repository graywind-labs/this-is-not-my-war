extends SceneTree


const NPC_ID := "blacksmith_01"

var _observed_states: Array[Dictionary] = []


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Could not load Main.tscn")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var event_bus := root.get_node_or_null("EventBus")
	if npc_system == null or daily_plan_system == null or event_bus == null:
		_fail("Required systems are missing")
		return
	daily_plan_system.set_auto_execution_enabled(false)
	if npc_system.has_method("end_formal_workstation_action"):
		npc_system.end_formal_workstation_action(NPC_ID, "verify_reset", false)

	npc_system.call("_set_npc_state_without_signal", NPC_ID, {
		"last_action_result": "work_failed_crafting_target_missing",
		"last_action_failure_context": {
			"failure_id": "work_failed_crafting_target_missing",
			"reason": "crafting_target_missing",
			"building_id": "blacksmith"
		}
	})
	event_bus.npc_state_changed.connect(_capture_state.bind(npc_system))
	var location_id := str(npc_system.get_npc_state(NPC_ID).get("current_location", "plaza"))
	var begin_result: Dictionary = npc_system.begin_formal_location_action(
		NPC_ID,
		"talk_to_npc",
		location_id
	)
	if not bool(begin_result.get("ok", false)):
		_fail("Formal dialogue-location session did not start: %s" % JSON.stringify(begin_result))
		return
	if _observed_states.is_empty():
		_fail("Formal session start did not publish a state")
		return
	for observed_state in _observed_states:
		if (
			str(observed_state.get("last_action_result", ""))
			!= "formal_action_started_talk_to_npc"
			or not (observed_state.get("last_action_failure_context", {}) as Dictionary).is_empty()
		):
			_fail("Formal session exposed the preceding failure: %s" % JSON.stringify(observed_state))
			return

	print("T1505-P6R48 stale failure formal-session verification passed.")
	quit(0)


func _capture_state(changed_npc_id: String, npc_system: Node) -> void:
	if changed_npc_id == NPC_ID:
		_observed_states.append(npc_system.get_npc_state(NPC_ID))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
