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

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var reflection_system := root.get_node_or_null("Main/Systems/DailyReflectionSystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel")
	var game_state := root.get_node_or_null("GameState")
	if (
		npc_system == null
		or action_system == null
		or memory_system == null
		or reflection_system == null
		or llm_bridge == null
		or npc_panel == null
		or game_state == null
	):
		push_error("Daily reflection verification required nodes not found")
		quit(1)
		return

	game_state.set_time(1, 22, 0, 0)
	if llm_bridge.has_method("set_backend_base_url"):
		llm_bridge.set_backend_base_url("reflection-verify-invalid://backend")
	llm_bridge.request_timeout_seconds = 0.2

	var npc_id := "cook_01"
	if not npc_system.debug_enter_location_immediately(npc_id, "dormitory"):
		push_error("Failed to place cook in dormitory")
		quit(1)
		return

	memory_system.debug_record_player_money_given(npc_id, 1, "private")
	var memory_before: Dictionary = memory_system.get_npc_short_term_memory(npc_id)
	if int(memory_before.get("event_count", 0)) <= 0:
		push_error("Reflection test needs at least one short-term event before sleep")
		quit(1)
		return

	if not action_system.debug_assign_sleep(npc_id):
		push_error("Failed to assign sleep action")
		quit(1)
		return
	await process_frame

	var long_memory: Dictionary = npc_system.get_npc_long_memory(npc_id)
	var diary: Array = long_memory.get("diary", [])
	var initial_diary_count := diary.size()
	if initial_diary_count < 3:
		push_error("Cook should start with at least three seeded historical diary slices, got %d" % initial_diary_count)
		quit(1)
		return

	var event_bus := root.get_node_or_null("EventBus")
	if event_bus == null:
		push_error("EventBus not found")
		quit(1)
		return
	event_bus.logical_time_tick.emit(3000.0, 1.0)
	await process_frame
	diary = (npc_system.get_npc_long_memory(npc_id).get("diary", []) as Array)
	if diary.size() != initial_diary_count:
		push_error("First sleep summary should not append before one game hour, got %d" % diary.size())
		quit(1)
		return

	event_bus.logical_time_tick.emit(1000.0, 1.0)
	if not await _wait_for_reflection(npc_system, llm_bridge, npc_id, initial_diary_count + 1):
		quit(1)
		return
	long_memory = npc_system.get_npc_long_memory(npc_id)
	diary = long_memory.get("diary", [])
	if diary.size() != initial_diary_count + 1:
		push_error("First sleep after one game hour should append exactly one diary entry, got %d" % diary.size())
		quit(1)
		return
	var diary_entry: Dictionary = diary[diary.size() - 1]
	if str(diary_entry.get("entry", "")).is_empty():
		push_error("Diary entry should not be empty")
		quit(1)
		return
	if diary_entry.has("memory_summary") or reflection_system.get_last_reflection_result().has("memory_summary"):
		push_error("Daily reflection should retain only the first-person diary and knowledge graph")
		quit(1)
		return

	var graph: Dictionary = long_memory.get("knowledge_graph", {})
	var by_subject: Dictionary = graph.get("by_subject", {}) if (graph.get("by_subject", {}) is Dictionary) else {}
	var station_graph: Dictionary = by_subject.get("station", {}) if (by_subject.get("station", {}) is Dictionary) else {}
	var pressure_record: Dictionary = station_graph.get("daily_pressure", {}) if (station_graph.get("daily_pressure", {}) is Dictionary) else {}
	var first_pressure_value := str(pressure_record.get("value", ""))
	if first_pressure_value.is_empty():
		push_error("Daily reflection should write a replace-style knowledge graph key station.daily_pressure")
		quit(1)
		return

	var memory_after: Dictionary = memory_system.get_npc_short_term_memory(npc_id)
	if int(memory_after.get("event_count", -1)) != 0 or int(memory_after.get("witness_count", -1)) != 0:
		push_error("Daily reflection should clear NPC short-term memory after writing diary: %s" % JSON.stringify(memory_after))
		quit(1)
		return
	if not reflection_system.has_reflected_today(npc_id, 1):
		push_error("DailyReflectionSystem should remember that the NPC already reflected today")
		quit(1)
		return

	var second: Dictionary = reflection_system.generate_daily_reflection_for_npc(npc_id, {"day": 1})
	if str(second.get("status", "")) != "already_reflected":
		push_error("Second non-forced reflection should be skipped")
		quit(1)
		return
	if (npc_system.get_npc_long_memory(npc_id).get("diary", []) as Array).size() != initial_diary_count + 1:
		push_error("Skipped reflection should not append a second diary entry")
		quit(1)
		return

	var replacement := {
		"ok": true,
		"npc_id": npc_id,
		"day": 1,
		"diary_entry": "我又把今天的压力想了一遍。",
		"memory_summary": "兼容输入也不得再保存。",
		"knowledge_graph_updates": [
			{
				"subject": "station",
				"relation": "daily_pressure",
				"value": "第二次总结覆盖了同一键的当前压力判断",
				"confidence": 0.9,
				"subject_label": "驿站",
				"relation_label": "当日压力",
				"value_label": "第二次总结覆盖了同一键的当前压力判断"
			},
			{
				"subject": "station",
				"relation": "status",
				"value": "busy",
				"confidence": 0.8
			},
			{
				"subject": "guard_officer",
				"relation": "order_style",
				"value": "命令急迫，但会听取解释",
				"confidence": 0.7
			},
			{
				"subject": "cook_01",
				"relation": "availability",
				"value": "今晚已经休息",
				"confidence": 0.8
			},
			{
				"subject": "promise:food_after_battle",
				"relation": "promise",
				"value": "战斗结束后补足食物",
				"confidence": 0.6
			},
			{
				"subject": "unmapped_subject_key",
				"relation": "unmapped_relation_key",
				"value": "无法归入现有分类的信息",
				"confidence": 0.5
			}
		],
		"source": "verify_replacement"
	}
	var replace_result: Dictionary = npc_system.apply_daily_reflection(npc_id, replacement)
	if not bool(replace_result.get("ok", false)):
		push_error("Direct reflection application for replacement check failed: %s" % JSON.stringify(replace_result))
		quit(1)
		return
	long_memory = npc_system.get_npc_long_memory(npc_id)
	diary = long_memory.get("diary", [])
	if diary.size() != initial_diary_count + 2:
		push_error("Diary should append reflection entries, got %d" % diary.size())
		quit(1)
		return
	if (diary[diary.size() - 1] as Dictionary).has("memory_summary"):
		push_error("Legacy reflection summary input must not be persisted into diary records")
		quit(1)
		return
	graph = long_memory.get("knowledge_graph", {})
	by_subject = graph.get("by_subject", {}) if (graph.get("by_subject", {}) is Dictionary) else {}
	station_graph = by_subject.get("station", {}) if (by_subject.get("station", {}) is Dictionary) else {}
	pressure_record = station_graph.get("daily_pressure", {}) if (station_graph.get("daily_pressure", {}) is Dictionary) else {}
	if str(pressure_record.get("value", "")) != "第二次总结覆盖了同一键的当前压力判断":
		push_error("Knowledge graph should replace station.daily_pressure instead of appending patches: %s" % JSON.stringify(graph))
		quit(1)
		return
	if graph.has("patches"):
		push_error("Knowledge graph should no longer store append-only patches: %s" % JSON.stringify(graph))
		quit(1)
		return

	npc_panel.show_npc(npc_id)
	await process_frame
	var diary_button := npc_panel.find_child("NPCDiaryButton", true, false) as Button
	var knowledge_button := npc_panel.find_child("NPCKnowledgeButton", true, false) as Button
	if diary_button == null or knowledge_button == null:
		push_error("NPCPanel diary or knowledge button not found")
		quit(1)
		return
	if npc_panel.find_child("NPCDiaryBox", true, false) != null:
		push_error("NPCPanel should not display an inline diary box")
		quit(1)
		return
	diary_button.pressed.emit()
	await process_frame
	var detail_popup := root.find_child("NPCMemoryDetailPopup", true, false) as Control
	var detail_title := root.find_child("NPCMemoryDetailTitle", true, false) as Label
	var detail_text := root.find_child("NPCMemoryDetailText", true, false) as TextEdit
	var detail_close := root.find_child("NPCMemoryDetailCloseButton", true, false) as Button
	if detail_popup == null or detail_title == null or detail_text == null or detail_close == null:
		push_error("NPCPanel long-term detail popup not found")
		quit(1)
		return
	if not detail_popup.visible or not detail_title.text.contains("日记") or detail_text.text.find(str(diary_entry.get("entry", ""))) < 0:
		push_error("NPCPanel diary popup should display generated diary entries")
		quit(1)
		return
	detail_close.pressed.emit()
	await process_frame
	knowledge_button.pressed.emit()
	await process_frame
	if (
		not detail_popup.visible
		or not detail_title.text.contains("知识图谱")
		or not detail_text.text.contains("【驿站】")
		or not detail_text.text.contains("当日压力")
		or not detail_text.text.contains("第二次总结覆盖")
		or not detail_text.text.contains("【守备官】")
		or not detail_text.text.contains("命令方式")
		or not detail_text.text.contains("【布鲁诺（厨子）】")
		or not detail_text.text.contains("可用情况")
		or not detail_text.text.contains("【承诺：战后食物】")
		or not detail_text.text.contains("【其他对象】")
		or not detail_text.text.contains("其他认知")
		or not detail_text.text.contains("忙碌")
		or detail_text.text.contains("可信度")
		or detail_text.text.contains("更新于")
	):
		push_error("NPCPanel knowledge popup should display Chinese labels without internal confidence/time metadata: %s" % detail_text.text)
		quit(1)
		return
	for raw_key in ["daily_pressure", "guard_officer", "order_style", "cook_01", "availability", "promise:food_after_battle", "unmapped_subject_key", "unmapped_relation_key", "busy"]:
		if detail_text.text.contains(raw_key):
			push_error("NPCPanel knowledge popup exposed a raw technical key '%s': %s" % [raw_key, detail_text.text])
			quit(1)
			return
	var legacy_value_text: String = npc_panel._format_knowledge_graph_block({
		"by_subject": {"station": {"status": "busy"}}
	})
	if legacy_value_text.contains("busy") or not legacy_value_text.contains("忙碌"):
		push_error("NPCPanel exposed a legacy English knowledge value: %s" % legacy_value_text)
		quit(1)
		return
	if detail_text.text.contains("记忆摘要："):
		push_error("NPCPanel diary/knowledge flow should not render a separate memory summary")
		quit(1)
		return

	print("Daily reflection system verification passed.")
	quit(0)


func _wait_for_reflection(
	npc_system: Node,
	llm_bridge: Node,
	npc_id: String,
	expected_diary_count: int
) -> bool:
	for _step in range(300):
		await create_timer(0.01).timeout
		var diary: Array = npc_system.get_npc_long_memory(npc_id).get("diary", [])
		var runtime: Dictionary = llm_bridge.debug_get_llm_runtime_snapshot()
		if diary.size() == expected_diary_count and int(runtime.get("async_request_count", 0)) == 0:
			return true
	push_error("Timed out waiting for async daily reflection completion")
	return false
