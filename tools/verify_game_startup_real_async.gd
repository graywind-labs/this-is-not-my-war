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

	var startup_system := root.get_node_or_null("Main/Systems/GameStartupSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if startup_system == null or daily_plan_system == null or npc_system == null or memory_system == null or time_system == null:
		push_error("Required startup systems not found")
		quit(1)
		return

	startup_system.debug_apply_startup_mode(1, true, true)
	if not await _wait_for_planning_phase(startup_system):
		push_error("Formal startup did not enter the planning phase")
		quit(1)
		return
	if not bool(time_system.is_paused) or bool(daily_plan_system.auto_execution_enabled):
		push_error("Formal startup must pause time and execution while plans are pending")
		quit(1)
		return

	for npc_id in npc_system.get_npc_ids():
		if not daily_plan_system.get_npc_daily_plan(npc_id).is_empty():
			push_error("NPC received a plan before the real planning batch completed: %s" % npc_id)
			quit(1)
			return
		if str(npc_system.get_npc_state(npc_id).get("current_action", "")) != "planning_day":
			push_error("NPC should remain in planning_day while waiting: %s" % npc_id)
			quit(1)
			return

	if not await _wait_for_startup_completion(startup_system):
		push_error("Real async formal startup timed out")
		quit(1)
		return
	var startup_snapshot: Dictionary = startup_system.debug_get_startup_snapshot()
	var batch: Dictionary = startup_snapshot.get("async_llm_plan_batch", {})
	if (
		not bool(startup_snapshot.get("formal_loop_started", false))
		or int(batch.get("requested_count", 0)) != 8
		or int(batch.get("completed_count", 0)) != 8
		or int(batch.get("succeeded_count", 0)) != 8
		or int(batch.get("failed_count", 0)) != 0
		or int(batch.get("max_concurrent", 0)) != 8
		or int(batch.get("max_observed_concurrent", 0)) != 8
		or int(batch.get("max_attempts_per_npc", 0)) != 3
		or not bool(batch.get("require_real_provider", false))
	):
		push_error("Real async startup plan batch failed: %s" % str(batch))
		quit(1)
		return
	if bool(time_system.is_paused) or not bool(daily_plan_system.auto_execution_enabled):
		push_error("Formal startup should resume time only after all plans are ready")
		quit(1)
		return
	var execute_results: Dictionary = startup_snapshot.get("execute_results", {})
	for npc_id in npc_system.get_npc_ids():
		var plan: Array = daily_plan_system.get_npc_daily_plan(npc_id)
		if plan.size() != 24:
			push_error("Completed real plan missing for %s" % npc_id)
			quit(1)
			return
		for raw_item in plan:
			if not raw_item is Dictionary or str((raw_item as Dictionary).get("source", "")) != "llm_plan_day":
				push_error("Real plan source must be llm_plan_day for %s: %s" % [npc_id, str(raw_item)])
				quit(1)
				return
		var plan_result: Dictionary = batch.get("results", {}).get(npc_id, {})
		if str(plan_result.get("source", "")) != "llm_plan_day" or bool(plan_result.get("fallback_used", true)):
			push_error("Real plan result source mismatch for %s: %s" % [npc_id, str(plan_result)])
			quit(1)
			return
		var plan_event := _find_latest_event(memory_system.get_npc_daily_events(npc_id), "plan_created")
		if str(plan_event.get("payload", {}).get("source", "")) != "llm_plan_day":
			push_error("Real plan_created source mismatch for %s: %s" % [npc_id, str(plan_event)])
			quit(1)
			return
		if not bool(execute_results.get(npc_id, {}).get("ok", false)):
			push_error("NPC current-hour plan execution failed after the batch: %s" % npc_id)
			quit(1)
			return
		if str(npc_system.get_npc_state(npc_id).get("current_action", "")) in ["", "planning_day"]:
			push_error("NPC remained in the planning state after the batch: %s" % npc_id)
			quit(1)
			return

	var event_bus := root.get_node_or_null("EventBus")
	if event_bus == null:
		push_error("EventBus not found for cross-day plan verification")
		quit(1)
		return
	event_bus.day_started.emit(2)
	await process_frame
	var cross_day_started: Dictionary = daily_plan_system.get_async_plan_batch_snapshot()
	if str(cross_day_started.get("reason", "")) != "day_started" or int(cross_day_started.get("requested_count", 0)) != 8:
		push_error("Cross-day planning did not start one 8-NPC batch: %s" % str(cross_day_started))
		quit(1)
		return
	if not bool(time_system.is_paused) or bool(daily_plan_system.auto_execution_enabled):
		push_error("Cross-day planning must pause execution until all 8 real plans return")
		quit(1)
		return
	if not await _wait_for_cross_day_completion(daily_plan_system):
		push_error("Real async cross-day planning timed out")
		quit(1)
		return
	var cross_day_batch: Dictionary = daily_plan_system.get_async_plan_batch_snapshot()
	if (
		not bool(cross_day_batch.get("plans_ready", false))
		or int(cross_day_batch.get("requested_count", 0)) != 8
		or int(cross_day_batch.get("succeeded_count", 0)) != 8
		or int(cross_day_batch.get("failed_count", 0)) != 0
		or int(cross_day_batch.get("max_concurrent", 0)) != 8
		or int(cross_day_batch.get("max_observed_concurrent", 0)) != 8
		or not bool(cross_day_batch.get("require_real_provider", false))
	):
		push_error("Real async cross-day plan batch failed: %s" % str(cross_day_batch))
		quit(1)
		return
	for npc_id in npc_system.get_npc_ids():
		var cross_day_result: Dictionary = cross_day_batch.get("results", {}).get(npc_id, {})
		if str(cross_day_result.get("source", "")) != "llm_plan_day" or bool(cross_day_result.get("fallback_used", true)):
			push_error("Cross-day plan source mismatch for %s: %s" % [npc_id, str(cross_day_result)])
			quit(1)
			return
	if bool(time_system.is_paused) or not bool(daily_plan_system.auto_execution_enabled):
		push_error("Cross-day planning should resume only after all 8 plans are ready")
		quit(1)
		return

	print("T0019/T0024 real async startup and cross-day planning verification passed.")
	quit(0)


func _wait_for_planning_phase(startup_system: Node) -> bool:
	for _frame in range(300):
		var snapshot: Dictionary = startup_system.debug_get_startup_snapshot()
		if str(snapshot.get("status", "")) == "awaiting_daily_plans":
			return true
		await process_frame
	return false


func _wait_for_startup_completion(startup_system: Node) -> bool:
	for _step in range(1200):
		var snapshot: Dictionary = startup_system.debug_get_startup_snapshot()
		if bool(snapshot.get("completed", false)) and not bool(snapshot.get("running", false)):
			return true
		await create_timer(0.1).timeout
	return false


func _wait_for_cross_day_completion(daily_plan_system: Node) -> bool:
	for _step in range(1800):
		var snapshot: Dictionary = daily_plan_system.get_async_plan_batch_snapshot()
		if str(snapshot.get("reason", "")) == "day_started" and str(snapshot.get("status", "")) in ["completed", "failed"]:
			return true
		await create_timer(0.1).timeout
	return false


func _find_latest_event(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event = events[index]
		if event is Dictionary and str(event.get("type", "")) == event_type:
			return event
	return {}
