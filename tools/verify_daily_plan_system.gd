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
	await process_frame
	await process_frame

	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	if (
		time_system == null
		or npc_system == null
		or action_system == null
		or memory_system == null
		or daily_plan_system == null
	):
		push_error("Required systems not found")
		quit(1)
		return

	var npc_id := "gardener_01"
	_set_debug_move_speed(npc_id, 120.0)
	var plan: Array = daily_plan_system.generate_rule_plan_for_npc(npc_id)
	if plan.size() != 24:
		push_error("Rule daily plan should contain 24 hourly items")
		quit(1)
		return
	if _count_work_phases(action_system, plan) < 6:
		push_error("Rule daily plan should contain at least 6 work phases")
		quit(1)
		return
	if str(plan[7].get("action_id", "")) != "work_garden":
		push_error("Gardener rule plan should assign garden work during work hours")
		quit(1)
		return

	var plan_event := _find_latest_event(memory_system.get_npc_daily_events(npc_id), "plan_created")
	if plan_event.is_empty():
		push_error("Rule plan generation should write plan_created event")
		quit(1)
		return
	if int(plan_event.get("payload", {}).get("work_phase_count", 0)) < 6:
		push_error("plan_created payload should record work phase count")
		quit(1)
		return

	var unordered_plan := plan.duplicate(true)
	var hour_six_item: Dictionary = unordered_plan[6]
	unordered_plan[6] = unordered_plan[7]
	unordered_plan[7] = hour_six_item
	if not daily_plan_system.set_npc_daily_plan(npc_id, unordered_plan, false, "rule_unordered_test"):
		push_error("A complete plan returned out of array order should normalize by each item's hour")
		quit(1)
		return
	var reordered_plan: Array = daily_plan_system.get_npc_daily_plan(npc_id)
	for expected_hour in range(24):
		if int(reordered_plan[expected_hour].get("hour", -1)) != expected_hour:
			push_error("Normalized plan is not indexed by its declared hour: %s" % str(reordered_plan))
			quit(1)
			return
		if str(reordered_plan[expected_hour].get("action_id", "")) != str(plan[expected_hour].get("action_id", "")):
			push_error("Out-of-order plan changed the action assigned to hour %d" % expected_hour)
			quit(1)
			return
	var duplicate_hour_plan := plan.duplicate(true)
	duplicate_hour_plan[1]["hour"] = 0
	if daily_plan_system.set_npc_daily_plan(npc_id, duplicate_hour_plan, false, "rule_duplicate_hour_test"):
		push_error("A plan with duplicate declared hours must be rejected")
		quit(1)
		return
	var missing_hour_plan := plan.duplicate(true)
	missing_hour_plan[0].erase("hour")
	if daily_plan_system.set_npc_daily_plan(npc_id, missing_hour_plan, false, "rule_missing_hour_test"):
		push_error("A plan item without a declared hour must be rejected")
		quit(1)
		return
	var out_of_range_hour_plan := plan.duplicate(true)
	out_of_range_hour_plan[23]["hour"] = 24
	if daily_plan_system.set_npc_daily_plan(npc_id, out_of_range_hour_plan, false, "rule_out_of_range_hour_test"):
		push_error("A plan item with an out-of-range hour must be rejected")
		quit(1)
		return

	if not npc_system.debug_enter_location_immediately(npc_id, "garden"):
		push_error("Failed to place gardener at garden")
		quit(1)
		return
	time_system.set_current_time(1, 7, 0, 0)
	if not await _wait_until_current_action(npc_system, npc_id, "work_garden"):
		push_error("Hourly plan tick should start planned garden work")
		quit(1)
		return

	action_system._on_logical_time_tick(3600.0, 1.0)
	await process_frame
	var after_repeat: Dictionary = npc_system.get_npc_state(npc_id)
	if str(after_repeat.get("current_action", "")) != "work_garden":
		push_error("Completed repeatable work must immediately start its next cycle")
		quit(1)
		return
	var same_slot_result: Dictionary = daily_plan_system.execute_current_plan_for_npc(npc_id, false)
	if str(same_slot_result.get("status", "")) != "already_running":
		push_error("Repeated work cycle was not adopted idempotently: %s" % str(same_slot_result))
		quit(1)
		return

	var cook_id := "cook_01"
	_set_debug_move_speed(cook_id, 120.0)
	daily_plan_system.generate_rule_plan_for_npc(cook_id)
	action_system.interrupt_npc_action(cook_id, "verify_cleanup")
	if not npc_system.debug_enter_location_immediately(cook_id, "dormitory"):
		push_error("Failed to place cook at dormitory")
		quit(1)
		return
	if not action_system.debug_assign_sleep(cook_id):
		push_error("Failed to start sleep before plan interruption")
		quit(1)
		return
	if not await _wait_until_current_action(npc_system, cook_id, "sleep_in_dormitory"):
		push_error("Cook sleep action did not start")
		quit(1)
		return
	var interrupt_result: Dictionary = daily_plan_system.execute_current_plan_for_npc(cook_id, true)
	if not bool(interrupt_result.get("ok", false)):
		push_error("Forced plan execution should interrupt a different active action")
		quit(1)
		return
	var cook_state: Dictionary = npc_system.get_npc_state(cook_id)
	if str(cook_state.get("current_action", "")) == "sleep_in_dormitory":
		push_error("Plan execution should replace sleep when current hour plan differs")
		quit(1)
		return

	var low_work_schema_plan: Array = []
	for hour in range(24):
		low_work_schema_plan.append({
			"hour": hour,
			"action_kind": "idle",
			"action_id": "idle",
			"location_id": null,
			"target_id": null,
			"priority": 50,
			"reason": "现场需要休整",
			"dialogue_goal": ""
		})
	var low_work_result: Dictionary = daily_plan_system._apply_daily_plan_response(
		npc_id,
		{
			"npc_id": npc_id,
			"plan_day": 1,
			"plan": low_work_schema_plan,
			"summary": "现场条件支持暂时休整。",
			"debug_reason": "验证工作阶段软建议。",
			"model_provider": "mock",
			"model_name": "verification",
			"model_fallback_used": false
		},
		false,
		false
	)
	if (
		not bool(low_work_result.get("ok", false))
		or int(daily_plan_system._count_work_phases(
			daily_plan_system.get_npc_daily_plan(npc_id)
		)) != 0
	):
		push_error(
			"A complete low-work plan should pass the soft work recommendation: %s"
			% JSON.stringify(low_work_result)
		)
		quit(1)
		return

	print("T1001/T0085 daily plan system verification passed.")
	quit(0)


func _count_work_phases(action_system: Node, plan: Array) -> int:
	var count := 0
	for raw_item in plan:
		if not raw_item is Dictionary:
			continue
		var action: Dictionary = action_system.get_action(str((raw_item as Dictionary).get("action_id", "")))
		if ["work", "clinic_doctor", "training_instructor"].has(str(action.get("type", ""))):
			count += 1
	return count


func _find_latest_event(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event = events[index]
		if event is Dictionary and str(event.get("type", "")) == event_type:
			return event
	return {}


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
