extends SceneTree


const DEFAULT_BACKEND_URL := "http://127.0.0.1:5012"


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

	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	if llm_bridge == null or daily_plan_system == null or npc_system == null:
		push_error("Required LLM/daily-plan/NPC systems not found")
		quit(1)
		return

	var backend_url := OS.get_environment("T0046_BACKEND_URL").strip_edges()
	if backend_url.is_empty():
		backend_url = DEFAULT_BACKEND_URL
	llm_bridge.set_backend_base_url(backend_url)

	var npc_ids: Array[String] = []
	for raw_npc_id in npc_system.get_npc_ids():
		npc_ids.append(str(raw_npc_id))
	var started: Dictionary = daily_plan_system.request_daily_plans_async(
		npc_ids,
		"reference_schedule_sampling",
		false,
		8,
		true,
		3
	)
	if not bool(started.get("ok", false)):
		push_error("Could not start real daily-plan batch: %s" % str(started))
		quit(1)
		return

	var batch: Dictionary = {}
	for _step in range(1800):
		batch = daily_plan_system.get_async_plan_batch_snapshot()
		if str(batch.get("status", "")) in ["completed", "failed"]:
			break
		await create_timer(0.1).timeout
	if str(batch.get("status", "")) != "completed":
		push_error("Real daily-plan batch timed out or failed: %s" % str(batch))
		quit(1)
		return
	if int(batch.get("succeeded_count", 0)) != npc_ids.size() or int(batch.get("failed_count", 0)) != 0:
		push_error("Not every initial NPC received a real daily plan: %s" % str(batch))
		quit(1)
		return

	var results: Dictionary = batch.get("results", {})
	var providers := {}
	var models := {}
	var fallback_used := false
	for npc_id in npc_ids:
		var npc: Dictionary = npc_system.get_npc(npc_id)
		var result: Dictionary = results.get(npc_id, {})
		var response: Dictionary = result.get("request_result", {}).get("daily_plan", {})
		providers[str(response.get("model_provider", "missing"))] = true
		models[str(response.get("model_name", "missing"))] = true
		fallback_used = fallback_used or bool(response.get("model_fallback_used", true))
		print("NPC_PLAN|%s|%s|%s" % [
			npc_id,
			str(npc.get("name", npc_id)),
			_format_plan_runs(result.get("plan", []))
		])

	print("REAL_PLAN_BATCH|provider=%s|model=%s|fallback=%s|retries=%d|count=%d" % [
		",".join(PackedStringArray(providers.keys())),
		",".join(PackedStringArray(models.keys())),
		str(fallback_used).to_lower(),
		int(batch.get("retry_count", 0)),
		int(batch.get("succeeded_count", 0))
	])
	quit(0)


func _format_plan_runs(raw_plan: Variant) -> String:
	if not raw_plan is Array or (raw_plan as Array).is_empty():
		return ""
	var plan: Array = raw_plan
	var runs: Array[String] = []
	var start_hour := int((plan[0] as Dictionary).get("hour", 0))
	var previous_hour := start_hour
	var action_name := str((plan[0] as Dictionary).get("action_name", (plan[0] as Dictionary).get("action_id", "")))
	for index in range(1, plan.size()):
		var item: Dictionary = plan[index]
		var hour := int(item.get("hour", index))
		var next_action_name := str(item.get("action_name", item.get("action_id", "")))
		if next_action_name != action_name or hour != previous_hour + 1:
			runs.append("%02d:00-%02d:00 %s" % [start_hour, previous_hour + 1, action_name])
			start_hour = hour
			action_name = next_action_name
		previous_hour = hour
	runs.append("%02d:00-%02d:00 %s" % [start_hour, previous_hour + 1, action_name])
	return "；".join(runs)
