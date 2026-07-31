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
	var crafting_system := root.get_node_or_null("Main/Systems/CraftingSystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if action_system == null or npc_system == null or building_system == null or resource_system == null or memory_system == null or crafting_system == null or llm_bridge == null:
		push_error("Required systems not found")
		quit(1)
		return
	if llm_bridge._normalize_plan_failure_type("work_failed_storage_capacity") != "resource_insufficient":
		push_error("Storage-capacity work failure must enter resource-insufficient plan revision")
		quit(1)
		return

	var gardener_id := "gardener_01"
	var stableman_id := "stableman_01"
	var cook_id := "cook_01"
	var priest_id := "priest_01"
	var engineer_id := "engineer_01"
	_set_debug_move_speed(gardener_id, 100.0)
	_set_debug_move_speed(stableman_id, 100.0)
	_set_debug_move_speed(cook_id, 100.0)
	_set_debug_move_speed(engineer_id, 100.0)

	var garden_action: Dictionary = action_system.get_action("work_garden")
	var base_duration := float(garden_action.get("duration_seconds", 3600.0))
	var gardener_duration: float = action_system._get_effective_action_duration_seconds(garden_action, gardener_id)
	var stableman_duration: float = action_system._get_effective_action_duration_seconds(garden_action, stableman_id)
	if not (gardener_duration < stableman_duration and gardener_duration < base_duration):
		push_error("Work efficiency did not shorten high-skill NPC duration")
		quit(1)
		return

	if not npc_system.debug_enter_location_immediately(priest_id, "garden"):
		push_error("Failed to place witness in garden")
		quit(1)
		return
	var priest_witness_before: int = memory_system.get_npc_witness_events(priest_id).size()
	var gardener_events_before: int = memory_system.get_npc_daily_events(gardener_id).size()
	var grain_before := int(resource_system.get_resource("grain"))
	npc_system.update_npc_state(gardener_id, {"satiety": 80, "fatigue": 20, "last_action_result": ""})
	if not action_system.debug_assign_work(gardener_id, "garden"):
		push_error("Failed to assign gardener work")
		quit(1)
		return
	if not await _wait_until_current_action(npc_system, gardener_id, "work_garden"):
		push_error("Gardener work did not start")
		quit(1)
		return

	var garden_after_start: Dictionary = building_system.get_building("garden")
	if not _is_workstation_occupied_by(garden_after_start.get("workstations", []), gardener_id):
		push_error("Garden workstation was not occupied by worker")
		quit(1)
		return
	var priest_witnesses_after_start := _events_after(memory_system.get_npc_witness_events(priest_id), priest_witness_before)
	var workstation_witness := _find_location_state_event(priest_witnesses_after_start, "building_internal_state_changed")
	if workstation_witness.is_empty():
		push_error("Workstation occupation did not broadcast location internal state")
		quit(1)
		return
	var changed_workstations: Array = workstation_witness.get("payload", {}).get("changed_workstations", [])
	if not _has_workstation_change(changed_workstations, gardener_id, "occupied"):
		push_error("Workstation occupation broadcast did not name occupying worker")
		quit(1)
		return

	npc_system.update_npc_state(stableman_id, {"satiety": 80, "fatigue": 20, "last_action_result": ""})
	if not action_system.debug_assign_work(stableman_id, "garden"):
		push_error("Second worker should be able to use the second initial garden workstation")
		quit(1)
		return
	if not await _wait_until_current_action(npc_system, stableman_id, "work_garden"):
		push_error("Second worker did not start work on the second garden workstation")
		quit(1)
		return

	npc_system.update_npc_state(cook_id, {"satiety": 80, "fatigue": 20, "last_action_result": ""})
	if not action_system.debug_assign_work(cook_id, "garden"):
		push_error("Third worker should at least move toward garden before workstation rejection")
		quit(1)
		return
	if not await _wait_until_action_result(npc_system, cook_id, "work_failed_no_workstation"):
		push_error("Third worker was not rejected when both initial garden workstations were occupied")
		quit(1)
		return

	action_system._on_logical_time_tick(gardener_duration + 1.0, 1.0)
	if not await _wait_until_action_result(npc_system, gardener_id, "completed_work_garden"):
		push_error("Gardener work did not complete using effective duration")
		quit(1)
		return
	var garden_after_complete: Dictionary = building_system.get_building("garden")
	if _is_workstation_occupied_by(garden_after_complete.get("workstations", []), gardener_id):
		push_error("Garden workstation was not released after completion")
		quit(1)
		return
	var expected_grain_output: int = int(action_system._get_work_output_resources(garden_action, gardener_id).get("grain", 0))
	if int(resource_system.get_resource("grain")) != grain_before + expected_grain_output:
		push_error("Garden work output mismatch after completion")
		quit(1)
		return

	var gardener_events := _events_after(memory_system.get_npc_daily_events(gardener_id), gardener_events_before)
	if _count_events(gardener_events, "work_started") != 1 or _count_events(gardener_events, "work_completed") != 1:
		push_error("Work event log should contain one start and one completion for the work unit")
		quit(1)
		return
	var completion_event := _find_event(gardener_events, "work_completed")
	if float(completion_event.get("payload", {}).get("efficiency_multiplier", 1.0)) <= 1.0:
		push_error("Work completion payload did not include efficiency multiplier")
		quit(1)
		return

	var grain_capacity: int = resource_system.get_resource_capacity("grain")
	var grain_fill_amount: int = grain_capacity - int(resource_system.get_resource("grain"))
	if grain_fill_amount <= 0 or not resource_system.add_resource("grain", grain_fill_amount):
		push_error("Failed to prepare full grain storage for work-output capacity check")
		quit(1)
		return
	npc_system.update_npc_state(
		gardener_id,
		{"satiety": 80, "fatigue": 20, "last_action_result": ""}
	)
	if not action_system.debug_assign_work(gardener_id, "garden"):
		push_error("Gardener should be able to start a work cycle before its output check")
		quit(1)
		return
	if not await _wait_until_current_action(npc_system, gardener_id, "work_garden"):
		push_error("Capacity-check garden work did not start")
		quit(1)
		return
	action_system._on_logical_time_tick(gardener_duration + 1.0, 1.0)
	if not await _wait_until_action_result(
		npc_system,
		gardener_id,
		"work_failed_storage_capacity"
	):
		push_error("Full warehouse did not reject completed garden output")
		quit(1)
		return
	if (
		resource_system.get_resource("grain") != grain_capacity
		or _is_workstation_occupied_by(
			building_system.get_building("garden").get("workstations", []),
			gardener_id
		)
	):
		push_error("Storage-capacity work failure changed inventory or kept the workstation")
		quit(1)
		return

	var workshop_target: Dictionary = crafting_system.set_target("workshop", "craft_bow", false)
	if not bool(workshop_target.get("ok", false)):
		push_error("Failed to select workshop target for resource-shortage verification")
		quit(1)
		return
	resource_system.add_resource("wood", -9999)
	npc_system.debug_enter_location_immediately(engineer_id, "workshop")
	npc_system.update_npc_state(engineer_id, {"satiety": 80, "fatigue": 20, "last_action_result": ""})
	if action_system.debug_assign_work(engineer_id, "workshop"):
		push_error("Workshop work should fail immediately when input resources are missing")
		quit(1)
		return
	var engineer_state: Dictionary = npc_system.get_npc_state(engineer_id)
	if str(engineer_state.get("last_action_result", "")) != "work_failed_insufficient_stage_resources":
		push_error("Crafting stage resource shortage did not set work_failed_insufficient_stage_resources")
		quit(1)
		return
	var workshop_after_failure: Dictionary = building_system.get_building("workshop")
	if _is_workstation_occupied_by(workshop_after_failure.get("workstations", []), engineer_id):
		push_error("Resource-shortage failure should not occupy a workstation")
		quit(1)
		return

	print("T0801 work output framework verification passed.")
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


func _find_location_state_event(events: Array, reason: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event = events[index]
		if not event is Dictionary:
			continue
		if str(event.get("type", "")) != "location_status_changed":
			continue
		if str(event.get("payload", {}).get("reason", "")) == reason:
			return event
	return {}


func _count_events(events: Array, event_type: String) -> int:
	var count := 0
	for event in events:
		if event is Dictionary and str(event.get("type", "")) == event_type:
			count += 1
	return count


func _is_workstation_occupied_by(workstations: Array, npc_id: String) -> bool:
	for raw_workstation in workstations:
		if not raw_workstation is Dictionary:
			continue
		var workstation: Dictionary = raw_workstation
		if str(workstation.get("occupied_by", "")) == npc_id:
			return true
	return false


func _has_workstation_change(workstations: Array, npc_id: String, status: String) -> bool:
	for raw_workstation in workstations:
		if not raw_workstation is Dictionary:
			continue
		var workstation: Dictionary = raw_workstation
		if str(workstation.get("occupied_by", "")) == npc_id and str(workstation.get("status", "")) == status:
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
