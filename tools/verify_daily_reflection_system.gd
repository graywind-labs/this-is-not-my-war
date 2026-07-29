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
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel")
	var game_state := root.get_node_or_null("GameState")
	if (
		npc_system == null
		or action_system == null
		or memory_system == null
		or reflection_system == null
		or llm_bridge == null
		or time_system == null
		or daily_plan_system == null
		or dialog_system == null
		or npc_panel == null
		or game_state == null
	):
		push_error("Daily reflection verification required nodes not found")
		quit(1)
		return

	time_system.set_time_scale(0.0)
	game_state.set_time(1, 22, 0, 0)
	if llm_bridge.has_method("set_backend_base_url"):
		llm_bridge.set_backend_base_url("http://127.0.0.1:1")
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
	var post_snapshot_event: Dictionary = memory_system.debug_record_player_money_given(
		npc_id,
		2,
		"private"
	)
	var post_snapshot_event_id := str(post_snapshot_event.get("event_id", ""))
	if post_snapshot_event_id.is_empty():
		push_error("Could not create a post-snapshot memory event")
		quit(1)
		return
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
	if (
		str(diary_entry.get("record_label", "")) != "接到守备命令的第1天"
		or str(diary_entry.get("summary_window_key", "")) != "night_1_2100"
		or int(diary_entry.get("trigger_day", 0)) != 1
	):
		push_error("Diary entry lost its guard-notice night attribution: %s" % JSON.stringify(diary_entry))
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
	var remaining_event_ids: Array = memory_system.get_npc_daily_event_ids(npc_id)
	if (
		int(memory_after.get("event_count", -1)) != 1
		or int(memory_after.get("witness_count", -1)) != 0
		or not remaining_event_ids.has(post_snapshot_event_id)
	):
		push_error("Daily reflection must clear only its request snapshot watermark: %s ids=%s" % [
			JSON.stringify(memory_after),
			JSON.stringify(remaining_event_ids)
		])
		quit(1)
		return
	var first_reflection_result: Dictionary = reflection_system.get_last_reflection_result()
	var first_period: Dictionary = first_reflection_result.get("reflection_period", {})
	if (
		int(first_period.get("start", {}).get("day", 0)) != 1
		or str(first_period.get("start", {}).get("time", "")) != "06:00:00"
		or int(first_period.get("end", {}).get("day", 0)) != 1
		or str(first_period.get("end", {}).get("time", "")) != "22:10:00"
		or int(first_reflection_result.get("cleared_short_term_memory", {}).get(
			"remaining_event_count",
			-1
		)) != 1
	):
		push_error("First reflection period/watermark was incorrect: %s" % JSON.stringify(first_reflection_result))
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
	action_system.interrupt_npc_action(
		npc_id,
		"verify_primary_reflection_finished",
		true
	)

	if not await _verify_cross_night_sleep_window(
		npc_system,
		action_system,
		reflection_system,
		llm_bridge,
		time_system,
		daily_plan_system,
		dialog_system
	):
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


func _verify_cross_night_sleep_window(
	npc_system: Node,
	action_system: Node,
	reflection_system: Node,
	llm_bridge: Node,
	time_system: Node,
	daily_plan_system: Node,
	dialog_system: Node
) -> bool:
	const NPC_ID := "stableman_01"
	var event_bus := root.get_node_or_null("EventBus")
	var day_started_callback := Callable(daily_plan_system, "_on_day_started")
	if (
		event_bus != null
		and event_bus.day_started.is_connected(day_started_callback)
	):
		# This专项 isolates the reflection window; cross-day plan batching has its
		# own tests and would deliberately replace the installed deterministic plan.
		event_bus.day_started.disconnect(day_started_callback)
	time_system.set_current_time(1, 23, 30, 0)
	if not daily_plan_system.set_npc_daily_plan(
		NPC_ID,
		_make_all_sleep_plan(),
		false,
		"verify_cross_night_sleep_window"
	):
		push_error("Could not install the cross-night sleep plan")
		return false
	if not npc_system.debug_enter_location_immediately(NPC_ID, "dormitory"):
		push_error("Could not place stableman in dormitory for cross-night verification")
		return false
	if not action_system.debug_assign_sleep(NPC_ID):
		push_error("Could not start stableman sleep for cross-night verification")
		return false
	await process_frame

	var initial_diary_count := (
		npc_system.get_npc_long_memory(NPC_ID).get("diary", []) as Array
	).size()
	if not time_system.debug_advance_game_seconds(1800.0):
		push_error("Could not advance the first half-hour across midnight")
		return false
	await process_frame
	if int(root.get_node("GameState").current_day) != 2:
		push_error("Cross-night verification did not reach day 2 midnight")
		return false
	var first_half_snapshot: Dictionary = reflection_system.get_async_reflection_snapshot()
	var first_half_window: Dictionary = (
		first_half_snapshot.get("sleep_window_states_by_npc", {}).get(NPC_ID, {})
		if first_half_snapshot.get("sleep_window_states_by_npc", {}) is Dictionary
		else {}
	)
	if (
		int(first_half_snapshot.get("summary_window_anchor", {}).get("hour", -1)) != 21
		or str(first_half_window.get("window_key", "")) != "night_1_2100"
		or absf(float(first_half_window.get("accumulated_sleep_seconds", 0.0)) - 1800.0) > 0.1
	):
		push_error("Midnight sleep accumulation did not stay in the 21:00 window: %s" % JSON.stringify(first_half_snapshot))
		return false

	var dialogue_start: Dictionary = dialog_system.start_player_dialogue(NPC_ID)
	if not bool(dialogue_start.get("ok", false)):
		push_error("Could not open sleep interruption dialogue: %s" % JSON.stringify(dialogue_start))
		return false
	var activation: Dictionary = dialog_system.call(
		"_activate_player_dialogue_draft",
		"verify_sleep_interruption_context"
	)
	var effect: Dictionary = dialog_system.call(
		"_ensure_player_dialogue_effect_started",
		"verify_sleep_interruption_context"
	)
	if (
		not bool(activation.get("ok", false))
		or not bool(effect.get("interrupted_action", false))
		or str(effect.get("interrupted_action_id", "")) != "sleep_in_dormitory"
	):
		push_error("Player dialogue did not interrupt the active sleep action: %s / %s state=%s runtime=%s plan=%s" % [
			JSON.stringify(activation),
			JSON.stringify(effect),
			JSON.stringify(npc_system.get_npc_state(NPC_ID)),
			JSON.stringify(action_system.get_runtime_action_snapshot(NPC_ID)),
			JSON.stringify(daily_plan_system.get_current_plan_item(NPC_ID))
		])
		return false
	var interrupted_context: Dictionary = (
		dialog_system.get_dialogue_state().get("interrupted_activity_context", {})
		if dialog_system.get_dialogue_state().get("interrupted_activity_context", {}) is Dictionary
		else {}
	)
	var formal_payload: Dictionary = llm_bridge.build_npc_dialogue_payload(
		NPC_ID,
		"你刚才在干什么，谈完以后准备做什么？",
		{
			"dialogue_kind": "player_npc",
			"current_round": 1,
			"max_rounds": 999999,
			"conversation_history": [],
			"interrupted_activity_context": interrupted_context,
			"dialogue_state": {
				"visibility": "private",
				"location_id": "dormitory",
				"location_name": "宿舍",
				"participants": ["guard_officer", NPC_ID]
			}
		}
	)
	var before_activity: Dictionary = (
		formal_payload.get("interrupted_activity_context", {}).get(
			"activity_before_interruption",
			{}
		)
		if formal_payload.get("interrupted_activity_context", {}) is Dictionary
		else {}
	)
	var expected_activity: Dictionary = (
		formal_payload.get("interrupted_activity_context", {}).get(
			"expected_activity_after_dialogue",
			{}
		)
		if formal_payload.get("interrupted_activity_context", {}) is Dictionary
		else {}
	)
	if (
		str(formal_payload.get("npc_state", {}).get("current_action", "")) != "talk_to_guard_officer"
		or str(before_activity.get("action_id", "")) != "sleep_in_dormitory"
		or str(expected_activity.get("action_id", "")) != "sleep_in_dormitory"
		or not bool(formal_payload.get("interrupted_activity_context", {}).get(
			"private_to_target_npc",
			false
		))
	):
		push_error("Formal dialogue payload lost target-private sleep interruption context: %s" % JSON.stringify(formal_payload))
		return false

	if not time_system.debug_advance_game_seconds(1800.0):
		push_error("Could not advance time while the sleep dialogue was active")
		return false
	var interrupted_snapshot: Dictionary = reflection_system.get_async_reflection_snapshot()
	var interrupted_window: Dictionary = interrupted_snapshot.get(
		"sleep_window_states_by_npc",
		{}
	).get(NPC_ID, {})
	if absf(float(interrupted_window.get("accumulated_sleep_seconds", 0.0)) - 1800.0) > 0.1:
		push_error("Dialogue time incorrectly counted as sleep: %s" % JSON.stringify(interrupted_window))
		return false
	var cancel_result: Dictionary = dialog_system.cancel_displayed_dialogue()
	if not bool(cancel_result.get("ok", false)):
		push_error("Could not end sleep interruption dialogue: %s" % JSON.stringify(cancel_result))
		return false
	await process_frame
	if str(action_system.get_runtime_action_id(NPC_ID)) != "sleep_in_dormitory":
		push_error("Unchanged sleep plan did not resume after dialogue")
		return false

	if not time_system.debug_advance_game_seconds(1800.0):
		push_error("Could not advance resumed sleep to the one-hour threshold")
		return false
	if not await _wait_for_reflection(
		npc_system,
		llm_bridge,
		NPC_ID,
		initial_diary_count + 1
	):
		return false
	var first_night_diary: Array = npc_system.get_npc_long_memory(NPC_ID).get("diary", [])
	var first_night_entry: Dictionary = first_night_diary[first_night_diary.size() - 1]
	if (
		int(first_night_entry.get("day", 0)) != 1
		or int(first_night_entry.get("trigger_day", 0)) != 2
		or str(first_night_entry.get("record_label", "")) != "接到守备命令的第1天"
		or not reflection_system.has_completed_summary_window(NPC_ID, "night_1_2100")
	):
		push_error("Cross-night summary must use the 21:00 anchor attribution and retain its trigger day: %s" % JSON.stringify(first_night_entry))
		return false

	# The next 21:00 anchor creates a new eligible window even though the previous
	# window also completed on calendar day 2.
	time_system.set_current_time(2, 21, 0, 0)
	if not time_system.debug_advance_game_seconds(3600.0):
		push_error("Could not advance the next evening sleep window")
		return false
	if not await _wait_for_reflection(
		npc_system,
		llm_bridge,
		NPC_ID,
		initial_diary_count + 2
	):
		return false
	var next_night_snapshot: Dictionary = reflection_system.get_async_reflection_snapshot()
	var next_night_window: Dictionary = next_night_snapshot.get(
		"sleep_window_states_by_npc",
		{}
	).get(NPC_ID, {})
	if (
		str(next_night_window.get("window_key", "")) != "night_2_2100"
		or str(next_night_window.get("summary_status", "")) != "completed"
		or not reflection_system.has_completed_summary_window(NPC_ID, "night_2_2100")
	):
		push_error("Next evening did not receive an independent summary window: %s" % JSON.stringify(next_night_snapshot))
		return false
	var next_night_diary: Array = npc_system.get_npc_long_memory(NPC_ID).get("diary", [])
	var next_night_entry: Dictionary = next_night_diary[next_night_diary.size() - 1]
	var next_period: Dictionary = next_night_entry.get("reflection_period", {})
	if (
		int(next_night_entry.get("day", 0)) != 2
		or str(next_night_entry.get("record_label", "")) != "接到守备命令的第2天"
		or int(next_period.get("start", {}).get("day", 0)) != 2
		or int(next_period.get("end", {}).get("day", 0)) != 2
	):
		push_error("Next night did not continue from the previous successful snapshot: %s" % JSON.stringify(next_night_entry))
		return false
	return true


func _make_all_sleep_plan() -> Array:
	var plan: Array = []
	for hour in range(24):
		plan.append({
			"hour": hour,
			"action_id": "sleep_in_dormitory",
			"action_name": "睡觉",
			"source": "verify_cross_night_sleep_window",
			"target": {},
			"priority": 50,
			"reason": "验证跨夜睡眠窗口累计。",
			"dialogue_goal": ""
		})
	return plan


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
	var reflection_system := root.get_node_or_null("Main/Systems/DailyReflectionSystem")
	push_error("Timed out waiting for async daily reflection completion: expected=%d actual=%d runtime=%s reflection=%s" % [
		expected_diary_count,
		(npc_system.get_npc_long_memory(npc_id).get("diary", []) as Array).size(),
		JSON.stringify(llm_bridge.debug_get_llm_runtime_snapshot()),
		JSON.stringify(
			reflection_system.get_async_reflection_snapshot()
			if reflection_system != null
			else {}
		)
	])
	return false
