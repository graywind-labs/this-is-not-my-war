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
		llm_bridge.set_backend_base_url("http://127.0.0.1:5999")
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
	if diary.size() != 0:
		push_error("First sleep summary should wait one game hour before writing diary, got %d" % diary.size())
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
	if diary.size() != 0:
		push_error("First sleep summary should not run before one game hour, got %d" % diary.size())
		quit(1)
		return

	event_bus.logical_time_tick.emit(1000.0, 1.0)
	await process_frame
	long_memory = npc_system.get_npc_long_memory(npc_id)
	diary = long_memory.get("diary", [])
	if diary.size() != 1:
		push_error("First sleep after one game hour should write exactly one diary entry, got %d" % diary.size())
		quit(1)
		return
	var diary_entry: Dictionary = diary[0]
	if str(diary_entry.get("entry", "")).is_empty():
		push_error("Diary entry should not be empty")
		quit(1)
		return

	var graph: Dictionary = long_memory.get("knowledge_graph", {})
	if not graph.has("patches") or (graph.get("patches", []) as Array).is_empty():
		push_error("Daily reflection should update the knowledge graph placeholder")
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
	if (npc_system.get_npc_long_memory(npc_id).get("diary", []) as Array).size() != 1:
		push_error("Skipped reflection should not append a second diary entry")
		quit(1)
		return

	npc_panel.show_npc(npc_id)
	await process_frame
	var diary_label := npc_panel.find_child("NPCDiaryLabel", true, false) as Label
	var diary_text := npc_panel.find_child("NPCDiaryText", true, false) as TextEdit
	if diary_label == null or diary_text == null:
		push_error("NPCPanel diary controls not found")
		quit(1)
		return
	if not diary_label.text.contains("日记：1 条") or diary_text.text.find(str(diary_entry.get("entry", ""))) < 0:
		push_error("NPCPanel should display the generated diary entry")
		quit(1)
		return

	print("Daily reflection system verification passed.")
	quit(0)
