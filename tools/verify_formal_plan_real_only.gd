extends SceneTree

const DEFAULT_MOCK_BACKEND_URL := "http://127.0.0.1:5056"


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var startup_system := root.get_node_or_null("Main/Systems/GameStartupSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if startup_system == null or daily_plan_system == null or npc_system == null or time_system == null or llm_bridge == null:
		_fail("Required formal-plan systems not found")
		return

	var backend_url := OS.get_environment("FORMAL_PLAN_MOCK_BACKEND_URL").strip_edges()
	if backend_url.is_empty():
		backend_url = DEFAULT_MOCK_BACKEND_URL
	llm_bridge.set_backend_base_url(backend_url)
	startup_system.debug_apply_startup_mode(1, true, true)
	if not await _wait_for_completion(startup_system):
		_fail("Formal startup did not reject mock provider in time")
		return

	var snapshot: Dictionary = startup_system.debug_get_startup_snapshot()
	if (
		str(snapshot.get("status", "")) != "failed"
		or str(snapshot.get("error_code", "")) != "real_provider_required"
		or bool(snapshot.get("formal_loop_started", false))
		or not bool(time_system.is_paused)
		or bool(daily_plan_system.auto_execution_enabled)
	):
		_fail("Formal startup accepted mock provider: %s" % str(snapshot))
		return

	for npc_id in npc_system.get_npc_ids():
		if not daily_plan_system.get_npc_daily_plan(npc_id).is_empty():
			_fail("Mock provider wrote a formal plan for %s" % npc_id)
			return
		if str(npc_system.get_npc_state(npc_id).get("current_action", "")) != "planning_day":
			_fail("NPC did not remain in planning_day after mock rejection: %s" % npc_id)
			return

	var event_bus := root.get_node_or_null("EventBus")
	if event_bus == null:
		_fail("EventBus not found for formal new-day verification")
		return
	event_bus.day_started.emit(2)
	await process_frame
	await process_frame
	var new_day_batch: Dictionary = daily_plan_system.get_async_plan_batch_snapshot()
	if (
		str(new_day_batch.get("reason", "")) != "day_started"
		or bool(new_day_batch.get("plans_ready", true))
		or not bool(time_system.is_paused)
		or bool(daily_plan_system.auto_execution_enabled)
	):
		_fail("Formal new day accepted mock provider: %s" % str(new_day_batch))
		return
	for npc_id in npc_system.get_npc_ids():
		if not daily_plan_system.get_npc_daily_plan(npc_id).is_empty():
			_fail("Mock provider wrote a formal new-day plan for %s" % npc_id)
			return
		if str(npc_system.get_npc_state(npc_id).get("current_action", "")) != "planning_day":
			_fail("NPC did not remain in planning_day after new-day mock rejection: %s" % npc_id)
			return

	var usage: Dictionary = llm_bridge.request_llm_usage()
	if not bool(usage.get("ok", false)):
		_fail("Could not inspect mock backend usage")
		return
	if int(usage.get("body", {}).get("summary", {}).get("count", -1)) != 0:
		_fail("Formal startup or new day sent plan requests to mock provider")
		return

	print("T0022 formal plan real-provider-only verification passed.")
	quit(0)


func _wait_for_completion(startup_system: Node) -> bool:
	for _step in range(300):
		var snapshot: Dictionary = startup_system.debug_get_startup_snapshot()
		if bool(snapshot.get("completed", false)) and not bool(snapshot.get("running", false)):
			return true
		await process_frame
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
