extends SceneTree


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var reflection_system := root.get_node_or_null("Main/Systems/DailyReflectionSystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if npc_system == null or memory_system == null or reflection_system == null or llm_bridge == null:
		_fail("Required daily reflection systems not found")
		return

	var health: Dictionary = llm_bridge.debug_check_health()
	var adapter: Dictionary = health.get("body", {}).get("model_adapter", {}) if health.get("body", {}) is Dictionary else {}
	var provider := str(adapter.get("provider", "")).to_lower()
	if not bool(health.get("ok", false)) or provider.is_empty() or provider == "mock" or not bool(adapter.get("configured", false)) or bool(adapter.get("fallback_to_mock", false)):
		_fail("Real provider is required for daily reflection concurrency verification: %s" % str(health))
		return

	var npc_ids: Array[String] = npc_system.get_npc_ids()
	if npc_ids.size() != 8:
		_fail("Expected exactly 8 initial NPCs, got %d" % npc_ids.size())
		return
	var diary_count_before: Dictionary = {}
	for npc_id in npc_ids:
		diary_count_before[npc_id] = (npc_system.get_npc_long_memory(npc_id).get("diary", []) as Array).size()
		memory_system.add_event({
			"type": "work_started",
			"subject_npc_id": npc_id,
			"actor_ids": [npc_id],
			"target_ids": [],
			"location_id": "plaza",
			"visibility": "private",
			"importance": 60,
			"summary": "%s 在睡前回想今天的工作与驿站压力。" % npc_id,
			"payload": {
				"action_id": "verify_real_reflection",
				"building_id": "plaza",
				"workstation_id": "verify_real_reflection"
			}
		})

	for npc_id in npc_ids:
		var start_result: Dictionary = reflection_system.generate_daily_reflection_for_npc(npc_id, {
			"day": 1,
			"force": true,
			"lock_summary": false,
			"trigger": "verify_real_eight_concurrent"
		})
		if not bool(start_result.get("ok", false)) or not bool(start_result.get("pending", false)):
			_fail("Failed to start real reflection for %s: %s" % [npc_id, str(start_result)])
			return

	var started_snapshot: Dictionary = reflection_system.get_async_reflection_snapshot()
	if (
		int(started_snapshot.get("max_concurrent", 0)) != 8
		or int(started_snapshot.get("active_count", 0)) != 8
		or int(started_snapshot.get("max_observed_concurrent", 0)) != 8
		or int(started_snapshot.get("started_count", 0)) != 8
	):
		_fail("Daily reflection did not launch 8 requests concurrently: %s" % str(started_snapshot))
		return

	if not await _wait_for_all_reflections(reflection_system):
		_fail("Timed out waiting for 8 real daily reflections")
		return
	var completed_snapshot: Dictionary = reflection_system.get_async_reflection_snapshot()
	if int(completed_snapshot.get("active_count", -1)) != 0 or int(completed_snapshot.get("completed_count", 0)) != 8 or int(completed_snapshot.get("max_observed_concurrent", 0)) != 8:
		_fail("Real daily reflection completion snapshot mismatch: %s" % str(completed_snapshot))
		return

	for npc_id in npc_ids:
		var long_memory: Dictionary = npc_system.get_npc_long_memory(npc_id)
		var diary: Array = long_memory.get("diary", []) if long_memory.get("diary", []) is Array else []
		if diary.size() != int(diary_count_before.get(npc_id, 0)) + 1:
			_fail("Real reflection did not append exactly one diary entry for %s" % npc_id)
			return
		var entry: Dictionary = diary[diary.size() - 1]
		if (
			str(entry.get("source", "")) != "llm_daily_reflection"
			or str(entry.get("model_provider", "")).to_lower() != provider
			or bool(entry.get("model_fallback_used", true))
			or str(entry.get("entry", "")).is_empty()
		):
			_fail("Real reflection provenance or content mismatch for %s: %s" % [npc_id, str(entry)])
			return
		var graph: Dictionary = long_memory.get("knowledge_graph", {}) if long_memory.get("knowledge_graph", {}) is Dictionary else {}
		var by_subject: Dictionary = graph.get("by_subject", {}) if graph.get("by_subject", {}) is Dictionary else {}
		if by_subject.is_empty():
			_fail("Real reflection returned no knowledge graph updates for %s" % npc_id)
			return

	print("T0024 real 8-way daily reflection verification passed.")
	quit(0)


func _wait_for_all_reflections(reflection_system: Node) -> bool:
	for _step in range(2400):
		var snapshot: Dictionary = reflection_system.get_async_reflection_snapshot()
		if int(snapshot.get("completed_count", 0)) == 8 and int(snapshot.get("active_count", -1)) == 0:
			return true
		await create_timer(0.1).timeout
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
