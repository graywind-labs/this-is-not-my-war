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
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if action_system == null or npc_system == null or building_system == null or resource_system == null or memory_system == null or daily_plan_system == null or time_system == null:
		push_error("Required systems not found")
		quit(1)
		return
	daily_plan_system.set_auto_execution_enabled(false)
	time_system.set_paused(false)

	var cook_id := "cook_01"
	var stableman_id := "stableman_01"
	var eater_id := "veteran_deputy_01"
	_set_debug_move_speed(cook_id, 5.0)
	# Formal indoor navigation is validated at production speed; extreme debug
	# velocity can skip narrow door/seat tolerances and is no longer representative.
	_set_debug_move_speed(eater_id, 5.0)

	var dining_action: Dictionary = action_system.get_action("work_dining_hall")
	if str(dining_action.get("location_required", "")) != "dining_hall":
		push_error("Dining hall work action is not bound to dining_hall")
		quit(1)
		return
	if str(dining_action.get("skill", "")) != "厨艺":
		push_error("Dining hall work should use cooking skill")
		quit(1)
		return
	if int(dining_action.get("input_resources", {}).get("grain", 0)) != 1:
		push_error("Dining hall work should consume 1 grain")
		quit(1)
		return
	if int(dining_action.get("output_resources", {}).get("meal", 0)) != 2:
		push_error("Dining hall work should output 2 meals")
		quit(1)
		return

	var base_duration := float(dining_action.get("duration_seconds", 3600.0))
	var cook_duration_level_1: float = action_system._get_effective_action_duration_seconds(dining_action, cook_id)
	var stableman_duration: float = action_system._get_effective_action_duration_seconds(dining_action, stableman_id)
	if not (cook_duration_level_1 < stableman_duration and cook_duration_level_1 < base_duration):
		push_error("Cooking skill did not shorten dining hall work duration")
		quit(1)
		return

	if not building_system.upgrade_building("dining_hall"):
		push_error("Failed to start dining hall upgrade for efficiency verification")
		quit(1)
		return
	building_system._on_logical_time_tick(99999.0, 1.0)
	var dining_after_upgrade: Dictionary = building_system.get_building("dining_hall")
	if int(dining_after_upgrade.get("level", 1)) < 2:
		push_error("Dining hall upgrade did not complete")
		quit(1)
		return
	var cook_duration_level_2: float = action_system._get_effective_action_duration_seconds(dining_action, cook_id)
	if not cook_duration_level_2 < cook_duration_level_1:
		push_error("Dining hall level did not improve work efficiency")
		quit(1)
		return

	resource_system.add_resource("grain", 5)
	resource_system.add_resource("meal", -9999)
	var grain_before_work := int(resource_system.get_resource("grain"))
	var meal_before_work := int(resource_system.get_resource("meal"))
	var cook_events_before := int(memory_system.get_npc_daily_events(cook_id).size())
	npc_system.update_npc_state(cook_id, {"satiety": 80, "fatigue": 20, "last_action_result": ""})
	if not action_system.debug_assign_work(cook_id, "dining_hall"):
		push_error("Failed to assign dining hall work")
		quit(1)
		return
	if not await _wait_until_current_action(npc_system, cook_id, "work_dining_hall"):
		push_error("Dining hall work did not start")
		quit(1)
		return
	action_system._on_logical_time_tick(cook_duration_level_2 + 1.0, 1.0)
	if not await _wait_until_action_result(npc_system, cook_id, "completed_work_dining_hall"):
		push_error("Dining hall work did not complete")
		quit(1)
		return
	if int(resource_system.get_resource("grain")) != grain_before_work - 1:
		push_error("Dining hall work did not consume exactly 1 grain")
		quit(1)
		return
	if int(resource_system.get_resource("meal")) != meal_before_work + 2:
		push_error("Dining hall work did not produce exactly 2 meals")
		quit(1)
		return
	var cook_events := _events_after(memory_system.get_npc_daily_events(cook_id), cook_events_before)
	var work_completed := _find_event(cook_events, "work_completed")
	if work_completed.is_empty() or str(work_completed.get("payload", {}).get("action_id", "")) != "work_dining_hall":
		push_error("Dining hall work completion event missing from cook event log")
		quit(1)
		return
	if int(work_completed.get("payload", {}).get("input_resources", {}).get("grain", 0)) != 1:
		push_error("Dining hall work completion event missing grain input")
		quit(1)
		return
	if int(work_completed.get("payload", {}).get("output_resources", {}).get("meal", 0)) != 2:
		push_error("Dining hall work completion event missing meal output")
		quit(1)
		return

	resource_system.add_resource("meal", 1)
	resource_system.add_resource("grain", 5)
	var meal_before_eat := int(resource_system.get_resource("meal"))
	var grain_before_meal_eat := int(resource_system.get_resource("grain"))
	var eater_events_before := int(memory_system.get_npc_daily_events(eater_id).size())
	npc_system.update_npc_state(eater_id, {"satiety": 30, "fatigue": 20, "last_action_result": ""})
	if not action_system.debug_assign_eat(eater_id):
		push_error("Failed to assign meal eating")
		quit(1)
		return
	if not await _wait_until_current_action(npc_system, eater_id, "eat_at_dining_hall"):
		push_error("Meal eating did not start")
		quit(1)
		return
	if int(resource_system.get_resource("meal")) != meal_before_eat - 1:
		push_error("Eating should consume meal first when available")
		quit(1)
		return
	if int(resource_system.get_resource("grain")) != grain_before_meal_eat:
		push_error("Eating consumed grain even though meal was available")
		quit(1)
		return
	# Freeze unrelated NeedsSystem clock drift after the real walk/seat commit,
	# then validate the exact remainder of this action's progressive recovery.
	time_system.set_paused(true)
	var meal_active: Dictionary = action_system.get("_active_actions").get(eater_id, {})
	var meal_satiety_before_completion := int(npc_system.get_npc_state(eater_id).get("satiety", 0))
	var meal_already_applied := int(meal_active.get("applied_state_deltas", {}).get("satiety", 0))
	action_system._advance_active_action(eater_id, 1200.0)
	if not await _wait_until_action_result(npc_system, eater_id, "completed_eat"):
		push_error("Meal eating did not complete")
		quit(1)
		return
	var after_meal_eat: Dictionary = npc_system.get_npc_state(eater_id)
	if int(after_meal_eat.get("satiety", 0)) != meal_satiety_before_completion + 50 - meal_already_applied:
		push_error("Meal eating should restore 50 satiety")
		quit(1)
		return
	var meal_eat_event := _find_event(_events_after(memory_system.get_npc_daily_events(eater_id), eater_events_before), "eat_completed")
	if str(meal_eat_event.get("payload", {}).get("resource_id", "")) != "meal" or int(meal_eat_event.get("payload", {}).get("satiety_restore", 0)) != 50:
		push_error("Meal eating event payload mismatch")
		quit(1)
		return

	resource_system.add_resource("meal", -9999)
	time_system.set_paused(false)
	var grain_before_grain_eat := int(resource_system.get_resource("grain"))
	eater_events_before = int(memory_system.get_npc_daily_events(eater_id).size())
	npc_system.update_npc_state(eater_id, {"satiety": 30, "last_action_result": ""})
	if not action_system.debug_assign_eat(eater_id):
		push_error("Failed to assign grain eating")
		quit(1)
		return
	if not await _wait_until_current_action(npc_system, eater_id, "eat_at_dining_hall"):
		push_error("Grain eating did not start")
		quit(1)
		return
	if int(resource_system.get_resource("grain")) != grain_before_grain_eat - 1:
		push_error("Grain eating should consume 1 grain when meal is unavailable")
		quit(1)
		return
	time_system.set_paused(true)
	var grain_active: Dictionary = action_system.get("_active_actions").get(eater_id, {})
	var grain_satiety_before_completion := int(npc_system.get_npc_state(eater_id).get("satiety", 0))
	var grain_already_applied := int(grain_active.get("applied_state_deltas", {}).get("satiety", 0))
	action_system._advance_active_action(eater_id, 1200.0)
	if not await _wait_until_action_result(npc_system, eater_id, "completed_eat"):
		push_error("Grain eating did not complete")
		quit(1)
		return
	var after_grain_eat: Dictionary = npc_system.get_npc_state(eater_id)
	if int(after_grain_eat.get("satiety", 0)) != grain_satiety_before_completion + 25 - grain_already_applied:
		push_error("Grain eating should restore 25 satiety")
		quit(1)
		return
	var grain_eat_event := _find_event(_events_after(memory_system.get_npc_daily_events(eater_id), eater_events_before), "eat_completed")
	if str(grain_eat_event.get("payload", {}).get("resource_id", "")) != "grain" or int(grain_eat_event.get("payload", {}).get("satiety_restore", 0)) != 25:
		push_error("Grain eating event payload mismatch")
		quit(1)
		return

	print("T0802 dining hall meal verification passed.")
	quit(0)


func _wait_until_action_result(npc_system: Node, npc_id: String, expected_result: String) -> bool:
	for frame in range(600):
		await process_frame
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		if str(state.get("last_action_result", "")) == expected_result:
			return true
	return false


func _wait_until_current_action(npc_system: Node, npc_id: String, expected_action: String) -> bool:
	for frame in range(1800):
		await physics_frame
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
