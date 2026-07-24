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
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if (
		startup_system == null
		or npc_system == null
		or memory_system == null
		or daily_plan_system == null
		or time_system == null
		or llm_bridge == null
	):
		push_error("Required startup systems not found")
		quit(1)
		return

	if int(startup_system.startup_mode) != 1:
		push_error("Main.tscn should default to gameplay without tutorial")
		quit(1)
		return
	var initial_snapshot: Dictionary = startup_system.debug_get_startup_snapshot()
	if str(initial_snapshot.get("status", "")) != "auto_start_skipped_headless":
		push_error("Headless verification should skip automatic formal startup")
		quit(1)
		return
	if not _verify_no_automatic_plans(npc_system, memory_system):
		quit(1)
		return

	var static_result: Dictionary = startup_system.debug_apply_startup_mode(0, true, false)
	if (
		not bool(static_result.get("completed", false))
		or str(static_result.get("status", "")) != "static_debug_ready"
		or bool(static_result.get("formal_loop_started", false))
	):
		push_error("Static debug startup mode should not start the formal loop")
		quit(1)
		return
	if not bool(time_system.is_paused) or bool(daily_plan_system.auto_execution_enabled):
		push_error("Static debug startup mode should pause time and automatic plan execution")
		quit(1)
		return
	if not _verify_no_automatic_plans(npc_system, memory_system):
		quit(1)
		return

	startup_system.debug_apply_startup_mode(1, true, false)
	if not await _wait_for_startup_completion(startup_system):
		push_error("Gameplay startup mode did not complete")
		quit(1)
		return
	var gameplay_snapshot: Dictionary = startup_system.debug_get_startup_snapshot()
	if (
		not bool(gameplay_snapshot.get("formal_loop_started", false))
		or int(gameplay_snapshot.get("completed_npc_count", 0)) != 8
		or bool(gameplay_snapshot.get("tutorial_requested", true))
	):
		push_error("Gameplay startup mode snapshot mismatch")
		quit(1)
		return
	if bool(time_system.is_paused) or not bool(daily_plan_system.auto_execution_enabled):
		push_error("Gameplay startup mode should resume time and automatic plan execution")
		quit(1)
		return
	if not _verify_formal_startup(npc_system, memory_system, daily_plan_system):
		quit(1)
		return

	llm_bridge.request_timeout_seconds = 0.05
	llm_bridge.set_backend_base_url("http://127.0.0.1:1")
	startup_system.debug_apply_startup_mode(1, true, true)
	if not await _wait_for_startup_completion(startup_system):
		push_error("Closed-backend formal startup did not report failure")
		quit(1)
		return
	var async_startup_snapshot: Dictionary = startup_system.debug_get_startup_snapshot()
	if (
		bool(async_startup_snapshot.get("formal_loop_started", false))
		or str(async_startup_snapshot.get("status", "")) != "failed"
		or str(async_startup_snapshot.get("error_code", "")) != "backend_health_failed"
		or not bool(time_system.is_paused)
		or bool(daily_plan_system.auto_execution_enabled)
	):
		push_error("Closed backend must fail formal startup without Mock or rule fallback: %s" % str(async_startup_snapshot))
		quit(1)
		return
	if not _verify_planning_state(npc_system, daily_plan_system):
		quit(1)
		return

	startup_system.debug_apply_startup_mode(2, true, false)
	if not await _wait_for_startup_completion(startup_system):
		push_error("Tutorial placeholder startup mode did not complete")
		quit(1)
		return
	var tutorial_snapshot: Dictionary = startup_system.debug_get_startup_snapshot()
	if (
		not bool(tutorial_snapshot.get("formal_loop_started", false))
		or not bool(tutorial_snapshot.get("tutorial_requested", false))
		or str(tutorial_snapshot.get("tutorial_status", "")) != "placeholder_not_implemented"
	):
		push_error("Tutorial startup mode should expose a non-faked placeholder")
		quit(1)
		return

	print("T0019 game startup modes verification passed.")
	quit(0)


func _verify_no_automatic_plans(npc_system: Node, memory_system: Node) -> bool:
	for npc_id in npc_system.get_npc_ids():
		if not npc_system.get_npc_plan(npc_id).is_empty():
			push_error("Static startup should not create plans for %s" % npc_id)
			return false
		if not _find_latest_event(memory_system.get_npc_daily_events(npc_id), "wake_up").is_empty():
			push_error("Static startup should not write wake_up for %s" % npc_id)
			return false
	return true


func _verify_formal_startup(npc_system: Node, memory_system: Node, daily_plan_system: Node) -> bool:
	for npc_id in npc_system.get_npc_ids():
		var plan: Array = daily_plan_system.get_npc_daily_plan(npc_id)
		if plan.size() != 24:
			push_error("Formal startup should create a 24-hour plan for %s" % npc_id)
			return false
		var wake_event := _find_latest_event(memory_system.get_npc_daily_events(npc_id), "wake_up")
		if wake_event.is_empty():
			push_error("Formal startup should write wake_up for %s" % npc_id)
			return false
		var current_action := str(npc_system.get_npc_state(npc_id).get("current_action", ""))
		if current_action.is_empty() or current_action == "idle":
			push_error("Formal startup should execute the current plan for %s" % npc_id)
			return false
	return true


func _verify_planning_state(npc_system: Node, daily_plan_system: Node) -> bool:
	for npc_id in npc_system.get_npc_ids():
		if not daily_plan_system.get_npc_daily_plan(npc_id).is_empty():
			push_error("NPC should not receive an executable plan before planning completes: %s" % npc_id)
			return false
		var current_action := str(npc_system.get_npc_state(npc_id).get("current_action", ""))
		if current_action != "planning_day":
			push_error("NPC should display planning_day before the batch completes: %s" % npc_id)
			return false
	return true


func _wait_for_startup_completion(startup_system: Node) -> bool:
	for _frame in range(600):
		await process_frame
		var snapshot: Dictionary = startup_system.debug_get_startup_snapshot()
		if bool(snapshot.get("completed", false)) and not bool(snapshot.get("running", false)):
			return true
	return false


func _wait_for_startup_planning(startup_system: Node) -> bool:
	for _frame in range(300):
		var snapshot: Dictionary = startup_system.debug_get_startup_snapshot()
		if str(snapshot.get("status", "")) == "awaiting_daily_plans":
			return true
		await process_frame
	return false


func _find_latest_event(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event: Variant = events[index]
		if event is Dictionary and str((event as Dictionary).get("type", "")) == event_type:
			return (event as Dictionary).duplicate(true)
	return {}
