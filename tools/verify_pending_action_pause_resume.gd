extends SceneTree


var _speaker_state_signal_count := 0
var _counted_speaker_id := ""


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var event_bus := root.get_node_or_null("EventBus")
	if (
		action_system == null
		or npc_system == null
		or building_system == null
		or resource_system == null
		or time_system == null
		or event_bus == null
	):
		_fail("Pending lifecycle verification required systems not found")
		return
	if daily_plan_system != null and daily_plan_system.has_method("set_auto_execution_enabled"):
		daily_plan_system.set_auto_execution_enabled(false)
	time_system.set_paused(true)

	if not _verify_catalog_pause_gate(action_system, npc_system, building_system, time_system):
		return
	if not await _verify_arrival_edge_commit(
		action_system,
		npc_system,
		building_system,
		resource_system,
		time_system,
		event_bus
	):
		return
	if not await _verify_route_resume(
		action_system,
		npc_system,
		time_system
	):
		return
	if not await _verify_precise_target_invalidation(
		action_system,
		npc_system,
		time_system,
		event_bus
	):
		return

	print("Pending action pause/resume verification passed.")
	quit(0)


func _verify_catalog_pause_gate(
	action_system: Node,
	npc_system: Node,
	building_system: Node,
	time_system: Node
) -> bool:
	var fixed_action_ids: Array[String] = []
	for raw_action_id in action_system.get_action_ids():
		var action_id := str(raw_action_id)
		var action: Dictionary = action_system.get_action(action_id)
		var location_id := str(action.get("location_required", ""))
		if location_id.is_empty():
			continue
		var action_type := str(action.get("type", ""))
		if not [
			"work",
			"eat",
			"sleep",
			"pray",
			"clinic_doctor",
			"clinic_patient",
			"training_instructor",
			"training_student"
		].has(action_type):
			_fail("Fixed-location action has no audited commit family: %s (%s)" % [
				action_id,
				action_type
			])
			return false
		fixed_action_ids.append(action_id)
	var expected_fixed := [
		"work_garden",
		"work_dining_hall",
		"work_stable",
		"work_tavern",
		"work_blacksmith",
		"work_workshop",
		"work_training_instructor",
		"receive_weapon_training",
		"work_clinic_doctor",
		"receive_clinic_treatment",
		"eat_at_dining_hall",
		"sleep_in_dormitory",
		"pray_at_chapel",
		"lead_mass"
	]
	for action_id in expected_fixed:
		if not fixed_action_ids.has(action_id):
			_fail("Expected fixed-location action missing from pending audit: %s" % action_id)
			return false

	var actor_id := "engineer_01"
	time_system.set_paused(true)
	for action_id in fixed_action_ids:
		_clear_runtime(action_system, npc_system, actor_id)
		var action: Dictionary = action_system.get_action(action_id)
		var location_id := str(action.get("location_required", ""))
		npc_system.debug_enter_location_immediately(actor_id, location_id)
		npc_system.update_npc_state(actor_id, {
			"current_action": "idle",
			"movement_target": "",
			"movement_target_name": ""
		})
		_seed_pending(action_system, actor_id, action_id)
		action_system._try_execute_pending_action(actor_id)
		action_system._on_logical_time_tick(7200.0, 1.0)
		if (
			action_system.get_pending_action_id(actor_id) != action_id
			or action_system.has_active_action(actor_id)
			or _is_npc_occupying_any_workstation(building_system, actor_id)
		):
			_fail("Paused fixed action committed early: %s runtime=%s" % [
				action_id,
				JSON.stringify(action_system.get_runtime_action_snapshot(actor_id))
			])
			return false

	var dynamic_cases := [
		{"action_id": "assist_repair", "target": "wall"},
		{"action_id": "assist_upgrade", "target": "wall"},
		{"action_id": "assist_heal", "target": "cook_01"},
		{"action_id": "visit_location", "target": "chapel"},
		{"action_id": "talk_to_npc", "target": "cook_01"}
	]
	for dynamic_case in dynamic_cases:
		var action_id := str(dynamic_case.get("action_id", ""))
		_clear_runtime(action_system, npc_system, actor_id)
		npc_system.debug_enter_location_immediately(actor_id, "plaza")
		npc_system.update_npc_state(actor_id, {
			"current_action": "idle",
			"movement_target": "",
			"movement_target_name": ""
		})
		_seed_pending(
			action_system,
			actor_id,
			action_id,
			str(dynamic_case.get("target", ""))
		)
		action_system._try_execute_pending_action(actor_id)
		if (
			action_system.get_pending_action_id(actor_id) != action_id
			or action_system.has_active_action(actor_id)
			or _is_npc_occupying_any_workstation(building_system, actor_id)
		):
			_fail("Paused target-aware action committed early: %s" % action_id)
			return false
	_clear_runtime(action_system, npc_system, actor_id)
	return true


func _verify_arrival_edge_commit(
	action_system: Node,
	npc_system: Node,
	building_system: Node,
	resource_system: Node,
	time_system: Node,
	event_bus: Node
) -> bool:
	const NPC_ID := "gardener_01"
	const ACTION_ID := "work_garden"
	_clear_runtime(action_system, npc_system, NPC_ID)
	npc_system.debug_enter_location_immediately(NPC_ID, "plaza")
	time_system.set_paused(false)
	var started_events_before := _count_npc_events_by_type(
		root.get_node("Main/Systems/MemorySystem"),
		NPC_ID,
		"work_started"
	)
	if not action_system.debug_assign_action(NPC_ID, ACTION_ID):
		_fail("Could not assign arrival-edge work action")
		return false
	await process_frame
	if action_system.get_pending_action_id(NPC_ID) != ACTION_ID:
		_fail("Travelling work action was not pending")
		return false

	time_system.set_paused(true)
	var npc_node := _find_npc_node(NPC_ID)
	if npc_node == null:
		_fail("Could not find gardener scene node")
		return false
	npc_node.stop_movement()
	npc_system._on_npc_movement_arrived(NPC_ID, "garden")
	await process_frame
	var grain_before := int(resource_system.get_resource("grain"))
	event_bus.logical_time_tick.emit(7200.0, 1.0)
	await process_frame
	if (
		action_system.get_pending_action_id(NPC_ID) != ACTION_ID
		or action_system.has_active_action(NPC_ID)
		or _is_npc_occupying_any_workstation(building_system, NPC_ID)
		or int(resource_system.get_resource("grain")) != grain_before
	):
		_fail("Arrival-edge pause started or settled work early: %s" % JSON.stringify(
			action_system.get_runtime_action_snapshot(NPC_ID)
		))
		return false

	time_system.set_paused(false)
	await process_frame
	await process_frame
	if (
		action_system.has_pending_action(NPC_ID)
		or action_system.get_active_action_id(NPC_ID) != ACTION_ID
		or not _is_npc_occupying_any_workstation(building_system, NPC_ID)
	):
		_fail("Pending work did not commit once after resume: %s" % JSON.stringify(
			action_system.get_runtime_action_snapshot(NPC_ID)
		))
		return false
	var started_events_after := _count_npc_events_by_type(
		root.get_node("Main/Systems/MemorySystem"),
		NPC_ID,
		"work_started"
	)
	if started_events_after != started_events_before + 1:
		_fail("Arrival-edge resume emitted duplicate work starts: before=%d after=%d" % [
			started_events_before,
			started_events_after
		])
		return false
	action_system.interrupt_npc_action(NPC_ID, "verify_arrival_edge_complete", true)
	return true


func _verify_route_resume(
	action_system: Node,
	npc_system: Node,
	time_system: Node
) -> bool:
	const NPC_ID := "stableman_01"
	const TARGET_ID := "dormitory"
	_clear_runtime(action_system, npc_system, NPC_ID)
	npc_system.debug_enter_location_immediately(NPC_ID, "plaza")
	var npc_node := _find_npc_node(NPC_ID)
	if npc_node == null:
		_fail("Could not find stableman scene node")
		return false
	npc_node.move_speed = 1.0
	time_system.set_paused(false)
	if not action_system.assign_visit_location(NPC_ID, TARGET_ID):
		_fail("Could not assign pending visit")
		return false
	await process_frame
	var state_before_pause: Dictionary = npc_system.get_npc_state(NPC_ID)
	var position_before_pause: Vector3 = npc_node.global_position
	time_system.set_paused(true)
	for frame in range(8):
		await process_frame
	var paused_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	if (
		npc_node.global_position.distance_to(position_before_pause) > 0.001
		or action_system.get_pending_action_id(NPC_ID) != "visit_location"
		or str(paused_state.get("movement_target", "")) != TARGET_ID
		or str(paused_state.get("movement_target", "")) != str(state_before_pause.get(
			"movement_target",
			""
		))
	):
		_fail("Pause did not preserve the visit route: before=%s paused=%s" % [
			JSON.stringify(state_before_pause),
			JSON.stringify(paused_state)
		])
		return false

	npc_node.move_speed = 1000.0
	time_system.set_paused(false)
	for frame in range(120):
		await process_frame
		if action_system.get_active_action_id(NPC_ID) == "visit_location":
			break
	if (
		action_system.get_active_action_id(NPC_ID) != "visit_location"
		or str(npc_system.get_npc_state(NPC_ID).get("current_location", "")) != TARGET_ID
	):
		_fail("Visit did not resume along the same route and start after arrival: %s" % JSON.stringify(
			action_system.get_runtime_action_snapshot(NPC_ID)
		))
		return false
	action_system.interrupt_npc_action(NPC_ID, "verify_route_resume_complete", true)
	return true


func _verify_precise_target_invalidation(
	action_system: Node,
	npc_system: Node,
	time_system: Node,
	event_bus: Node
) -> bool:
	const SPEAKER_ID := "engineer_01"
	const TARGET_ID := "cook_01"
	_clear_runtime(action_system, npc_system, SPEAKER_ID)
	_clear_runtime(action_system, npc_system, TARGET_ID)
	npc_system.debug_enter_location_immediately(SPEAKER_ID, "garden")
	npc_system.debug_enter_location_immediately(TARGET_ID, "dormitory")
	time_system.set_paused(false)
	if not action_system.assign_npc_dialogue(
		SPEAKER_ID,
		TARGET_ID,
		"我得和你确认一件事。",
		2,
		false
	):
		_fail("Could not assign pending NPC dialogue")
		return false
	await process_frame
	if action_system.get_pending_action_id(SPEAKER_ID) != "talk_to_npc":
		_fail("NPC dialogue did not enter pending approach")
		return false
	time_system.set_paused(true)
	_counted_speaker_id = SPEAKER_ID
	_speaker_state_signal_count = 0
	var counter := Callable(self, "_on_npc_state_changed_counted")
	if not event_bus.npc_state_changed.is_connected(counter):
		event_bus.npc_state_changed.connect(counter)
	npc_system.update_npc_state(TARGET_ID, {
		"unconscious": true,
		"behavior_mode": "unconscious",
		"current_action": "unconscious"
	})
	await process_frame
	if event_bus.npc_state_changed.is_connected(counter):
		event_bus.npc_state_changed.disconnect(counter)
	var speaker_state: Dictionary = npc_system.get_npc_state(SPEAKER_ID)
	var failure_context: Dictionary = speaker_state.get(
		"last_action_failure_context",
		{}
	)
	if (
		action_system.has_pending_action(SPEAKER_ID)
		or str(speaker_state.get("last_action_result", "")) != "talk_to_npc_failed_target_unavailable"
		or str(failure_context.get("target_npc_id", "")) != TARGET_ID
		or _speaker_state_signal_count != 1
	):
		_fail("Paused target invalidation was not one precise failure: state=%s signals=%d" % [
			JSON.stringify(speaker_state),
			_speaker_state_signal_count
		])
		return false
	npc_system.update_npc_state(TARGET_ID, {
		"unconscious": false,
		"behavior_mode": "work",
		"current_action": "idle"
	})
	time_system.set_paused(false)
	return true


func _seed_pending(
	action_system: Node,
	npc_id: String,
	action_id: String,
	target_id: String = ""
) -> void:
	var pending_actions: Dictionary = action_system.get("_pending_actions")
	var pending_targets: Dictionary = action_system.get("_pending_action_targets")
	var pending_options: Dictionary = action_system.get("_pending_action_options")
	pending_actions[npc_id] = action_id
	if target_id.is_empty():
		pending_targets.erase(npc_id)
	else:
		pending_targets[npc_id] = target_id
	pending_options[npc_id] = {}
	action_system.set("_pending_actions", pending_actions)
	action_system.set("_pending_action_targets", pending_targets)
	action_system.set("_pending_action_options", pending_options)


func _clear_runtime(action_system: Node, npc_system: Node, npc_id: String) -> void:
	action_system.interrupt_npc_action(npc_id, "verify_pending_reset", true)
	var pending_actions: Dictionary = action_system.get("_pending_actions")
	var pending_targets: Dictionary = action_system.get("_pending_action_targets")
	var pending_options: Dictionary = action_system.get("_pending_action_options")
	pending_actions.erase(npc_id)
	pending_targets.erase(npc_id)
	pending_options.erase(npc_id)
	action_system.set("_pending_actions", pending_actions)
	action_system.set("_pending_action_targets", pending_targets)
	action_system.set("_pending_action_options", pending_options)
	npc_system.stop_npc_movement_for_system(npc_id, "verify_pending_reset", false)
	npc_system.update_npc_state(npc_id, {
		"current_action": "idle",
		"movement_target": "",
		"movement_target_name": ""
	})


func _is_npc_occupying_any_workstation(
	building_system: Node,
	npc_id: String
) -> bool:
	for raw_building_id in building_system.get_building_ids():
		var building: Dictionary = building_system.get_building(str(raw_building_id))
		for raw_workstation in building.get("workstations", []):
			if (
				raw_workstation is Dictionary
				and str((raw_workstation as Dictionary).get("occupied_by", "")) == npc_id
			):
				return true
	return false


func _count_npc_events_by_type(
	memory_system: Node,
	npc_id: String,
	event_type: String
) -> int:
	var count := 0
	for event in memory_system.get_npc_daily_events(npc_id):
		if str(event.get("type", "")) == event_type:
			count += 1
	return count


func _find_npc_node(npc_id: String) -> Node:
	var npc_root := root.get_node_or_null("Main/WorldRoot/Station/NPCs")
	if npc_root == null:
		return null
	for child in npc_root.get_children():
		if str(child.get("npc_id")) == npc_id:
			return child
	return null


func _on_npc_state_changed_counted(npc_id: String) -> void:
	if npc_id == _counted_speaker_id:
		_speaker_state_signal_count += 1


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
