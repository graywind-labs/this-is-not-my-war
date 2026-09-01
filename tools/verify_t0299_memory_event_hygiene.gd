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

	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if memory_system == null or npc_system == null or llm_bridge == null:
		_fail("MemorySystem, NPCSystem, or LLMBridge not found")
		return
	memory_system.clear_event_log()

	var count_before := int(memory_system.get_event_count())
	var rejected_mode_event: Dictionary = memory_system.add_event({
		"type": "npc_mode_changed",
		"subject_npc_id": "cook_01",
		"actor_ids": ["system"],
		"target_ids": ["cook_01", "work"],
		"location_id": "plaza",
		"visibility": "local_public",
		"payload": {
			"npc_id": "cook_01",
			"from_mode": "escaped",
			"to_mode": "work",
			"reason": "escape_intervention_stayed"
		}
	})
	if not rejected_mode_event.is_empty() or int(memory_system.get_event_count()) != count_before:
		_fail("Developer-only npc_mode_changed event was recorded")
		return
	for target_mode in ["rally", "combat", "avoid_combat", "unconscious", "work"]:
		var mode_result: Dictionary = npc_system.set_npc_behavior_mode("cook_01", target_mode, "verify_internal_%s" % target_mode, {
			"interrupt": false,
			"request_plan_reevaluation": false
		})
		if not bool(mode_result.get("ok", false)) or not (mode_result.get("event", {}) as Dictionary).is_empty():
			_fail("Behavior mode transition failed or returned a memory event: %s" % JSON.stringify(mode_result))
			return
	if int(memory_system.get_event_count()) != count_before:
		_fail("Behavior mode state machine wrote developer-only events")
		return
	var mode_snapshot: Dictionary = npc_system.get_npc_behavior_mode_snapshot("cook_01")
	if str(mode_snapshot.get("reason", "")) != "verify_internal_work":
		_fail("Runtime behavior snapshot lost its internal diagnostic reason")
		return

	var work_event: Dictionary = memory_system.add_event({
		"type": "work_failed",
		"subject_npc_id": "cook_01",
		"actor_ids": ["cook_01"],
		"location_id": "dining_hall",
		"visibility": "private",
		"payload": {
			"action_id": "internal_unknown_action_id",
			"reason": "work_failed_no_resources"
		}
	})
	if not _expect_clean_summary(work_event, ["internal_unknown_action_id", "work_failed_no_resources"], ["当前行动", "行动条件不满足"]):
		return
	if str(work_event.get("payload", {}).get("reason", "")) != "行动条件不满足":
		_fail("Work failure payload retained an internal reason")
		return
	if JSON.stringify(llm_bridge.build_compact_memory_event(work_event)).contains("work_failed_no_resources"):
		_fail("Work failure internal reason leaked into compact LLM memory")
		return

	var prayer_event: Dictionary = memory_system.add_event({
		"type": "prayer_failed",
		"subject_npc_id": "priest_01",
		"actor_ids": ["priest_01"],
		"location_id": "chapel",
		"visibility": "private",
		"payload": {
			"action_id": "pray_at_chapel",
			"reason": "prayer_workstation_commit_failed"
		}
	})
	if not _expect_clean_summary(prayer_event, ["prayer_workstation_commit_failed"], ["行动条件不满足"]):
		return
	if str(prayer_event.get("payload", {}).get("reason", "")) != "行动条件不满足":
		_fail("Prayer failure payload retained an internal reason")
		return

	var plan_event: Dictionary = memory_system.add_event({
		"type": "plan_revised",
		"subject_npc_id": "doctor_01",
		"actor_ids": ["doctor_01"],
		"location_id": "clinic",
		"visibility": "private",
		"payload": {
			"plan_day": 1,
			"items": [],
			"reason": "work_failed_no_resources",
			"source": "rule",
			"summary": "escape_intervention_stayed",
			"work_phase_count": 0
		}
	})
	if not _expect_clean_summary(plan_event, ["escape_intervention_stayed", "work_failed_no_resources"], ["原计划已经不再适用"]):
		return
	var plan_payload: Dictionary = plan_event.get("payload", {})
	if str(plan_payload.get("reason", "")) != "原计划需要重新评估" or str(plan_payload.get("summary", "")) != "原计划已经不再适用":
		_fail("Plan revision payload retained internal reason or summary tokens")
		return
	var compact_plan_text := JSON.stringify(llm_bridge.build_compact_memory_event(plan_event))
	if compact_plan_text.contains("escape_intervention_stayed") or compact_plan_text.contains("work_failed_no_resources"):
		_fail("Plan revision internal tokens leaked into compact LLM memory")
		return

	var natural_event: Dictionary = memory_system.add_event({
		"type": "work_failed",
		"subject_npc_id": "blacksmith_01",
		"actor_ids": ["blacksmith_01"],
		"location_id": "blacksmith",
		"visibility": "private",
		"payload": {
			"action_id": "work_blacksmith",
			"reason": "仓库里已经没有足够的材料。"
		}
	})
	if not _expect_clean_summary(natural_event, [], ["仓库里已经没有足够的材料"]):
		return

	for raw_event in memory_system.get_all_events():
		var event: Dictionary = raw_event
		if str(event.get("type", "")) == "npc_mode_changed":
			_fail("npc_mode_changed appeared in global event memory")
			return

	print("T0299 memory event hygiene verification passed.")
	quit(0)


func _expect_clean_summary(event: Dictionary, forbidden: Array[String], required: Array[String]) -> bool:
	if event.is_empty():
		_fail("Expected narrative event was not recorded")
		return false
	var summary := str(event.get("summary", ""))
	for needle in forbidden:
		if summary.contains(needle):
			_fail("Developer token leaked into summary: %s" % summary)
			return false
	for needle in required:
		if not summary.contains(needle):
			_fail("Polished summary is missing '%s': %s" % [needle, summary])
			return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
