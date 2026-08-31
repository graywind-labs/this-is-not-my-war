extends SceneTree


const NORMAL_FILL := "71865aff"
const DANGER_FILL := "a7433bff"
const DANGER_LABEL := "dc6157ff"


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	root.size = Vector2i(1152, 648)
	DisplayServer.window_set_size(root.size)
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var game_state := root.get_node_or_null("GameState")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel") as Control
	var building_panel := root.get_node_or_null("Main/UI/BuildingPanel") as Control
	var dialog_panel := root.get_node_or_null("Main/UI/DialogPanel") as Control
	var order_panel := root.get_node_or_null("Main/UI/OrderPanel") as Control
	if npc_system == null or building_system == null or memory_system == null or daily_plan_system == null or time_system == null or game_state == null or npc_panel == null or building_panel == null or dialog_panel == null or order_panel == null:
		push_error("Required systems or panels not found")
		quit(1)
		return
	npc_panel.call("debug_set_layout_viewport_override", Vector2(1152, 648))
	building_panel.call("debug_set_layout_viewport_override", Vector2(1152, 648))
	var npc_id := "veteran_deputy_01"
	if not npc_system.debug_select_npc(npc_id):
		push_error("Failed to select NPC")
		quit(1)
		return
	await process_frame
	await process_frame
	await process_frame

	if not npc_panel.visible:
		push_error("NPCPanel did not open after NPC selection")
		quit(1)
		return

	var hp_label := npc_panel.find_child("NPCHPLabel", true, false) as Label
	if hp_label == null or hp_label.text != "HP：120 / 120":
		push_error("NPCPanel HP text mismatch: %s" % (hp_label.text if hp_label != null else "<missing>"))
		quit(1)
		return

	var content := npc_panel.find_child("Content", true, false)
	var panel_container := root.get_node_or_null("Main/UI/NPCPanel/PanelContainer") as Control
	var header := npc_panel.find_child("Header", true, false) as HBoxContainer
	var name_label := npc_panel.find_child("NPCNameLabel", true, false) as Label
	var background_button := npc_panel.find_child("NPCBackgroundButton", true, false) as Button
	var header_action_label := npc_panel.find_child("NPCActionLabel", true, false) as Label
	var behavior_mode_label := npc_panel.find_child("NPCBehaviorModeLabel", true, false) as Label
	var hp_experience_row := npc_panel.find_child("NPCHPExperienceRow", true, false) as HBoxContainer
	var experience_label := npc_panel.find_child("NPCExperienceLabel", true, false) as Label
	var attributes_label := npc_panel.find_child("NPCAttributesLabel", true, false) as Label
	var attribute_point_row := npc_panel.find_child("NPCAttributePointRow", true, false) as HBoxContainer
	var strength_point_button := npc_panel.find_child("NPCStrengthPointButton", true, false) as Button
	var intelligence_point_button := npc_panel.find_child("NPCIntelligencePointButton", true, false) as Button
	var strength_value_label := npc_panel.find_child("NPCStrengthValueLabel", true, false) as Label
	var intelligence_value_label := npc_panel.find_child("NPCIntelligenceValueLabel", true, false) as Label
	var combat_stats_label := npc_panel.find_child("NPCCombatStatsLabel", true, false) as Label
	var satiety_label := npc_panel.find_child("NPCSatietyLabel", true, false) as Label
	var fatigue_label := npc_panel.find_child("NPCFatigueLabel", true, false) as Label
	var satiety_progress := npc_panel.find_child("NPCSatietyProgress", true, false) as ProgressBar
	var fatigue_progress := npc_panel.find_child("NPCFatigueProgress", true, false) as ProgressBar
	var equipment_label := npc_panel.find_child("NPCEquipmentLabel", true, false) as Label
	var specialties_label := npc_panel.find_child("NPCJobLabel", true, false) as Label
	var panel_scroll := npc_panel.find_child("NPCPanelScroll", true, false) as ScrollContainer
	var long_term_button_row := npc_panel.find_child("NPCLongTermInfoButtonRow", true, false) as HBoxContainer
	var current_plan_button := npc_panel.find_child("NPCCurrentPlanButton", true, false) as Button
	var diary_button := npc_panel.find_child("NPCDiaryButton", true, false) as Button
	var knowledge_button := npc_panel.find_child("NPCKnowledgeButton", true, false) as Button
	var event_log_label := npc_panel.find_child("NPCEventLogLabel", true, false) as Label
	var witness_log_label := npc_panel.find_child("NPCWitnessLogLabel", true, false) as Label
	var event_log_box := npc_panel.find_child("NPCEventLogBox", true, false) as PanelContainer
	var witness_log_box := npc_panel.find_child("NPCWitnessLogBox", true, false) as PanelContainer
	var event_log_text := npc_panel.find_child("NPCEventLogText", true, false) as TextEdit
	var witness_log_text := npc_panel.find_child("NPCWitnessLogText", true, false) as TextEdit
	if header == null or name_label == null or background_button == null or background_button.get_parent() != header or background_button.get_index() != name_label.get_index() + 1:
		push_error("NPC background button should be placed beside the NPC name in the top header")
		quit(1)
		return
	if (
		header_action_label == null
		or behavior_mode_label == null
		or header_action_label.get_parent() != header
		or behavior_mode_label.get_parent() != header
		or header_action_label.get_index() != background_button.get_index() + 1
		or behavior_mode_label.get_index() != header_action_label.get_index() + 1
		or header_action_label.text.contains("当前行动")
		or behavior_mode_label.text.contains("行为模式")
		or behavior_mode_label.modulate.r >= header_action_label.modulate.r
	):
		push_error("NPC action and dimmed behavior mode should follow the background button in the header")
		quit(1)
		return
	if hp_experience_row == null or hp_label.get_parent() != hp_experience_row:
		push_error("NPCPanel HP and experience should share one row")
		quit(1)
		return
	if experience_label == null or not experience_label.text.begins_with("经验：") or not experience_label.text.contains(" / "):
		push_error("NPCPanel experience text mismatch: %s" % (experience_label.text if experience_label != null else "<missing>"))
		quit(1)
		return
	if attributes_label == null or attributes_label.visible or not attributes_label.text.is_empty():
		push_error("NPCPanel attributes text mismatch: %s" % (attributes_label.text if attributes_label != null else "<missing>"))
		quit(1)
		return
	if attribute_point_row == null or strength_point_button == null or intelligence_point_button == null:
		push_error("NPCPanel attribute point controls not found")
		quit(1)
		return
	if strength_value_label == null or strength_value_label.text != "力量 7":
		push_error("NPCPanel strength inline text mismatch")
		quit(1)
		return
	if intelligence_value_label == null or intelligence_value_label.text != "智力 6":
		push_error("NPCPanel intelligence inline text mismatch")
		quit(1)
		return
	if (
		combat_stats_label == null
		or not combat_stats_label.text.begins_with("攻击 ")
		or combat_stats_label.text.contains("战斗")
		or combat_stats_label.text.contains("Lv.")
		or not combat_stats_label.text.contains("穿透")
		or not combat_stats_label.text.contains("攻速")
	):
		push_error("NPCPanel combat stats text mismatch: %s" % (combat_stats_label.text if combat_stats_label != null else "<missing>"))
		quit(1)
		return
	if (
		satiety_label == null
		or fatigue_label == null
		or satiety_progress == null
		or fatigue_progress == null
		or satiety_label.get_parent() != satiety_progress.get_parent()
		or fatigue_label.get_parent() != fatigue_progress.get_parent()
		or satiety_label.get_index() >= satiety_progress.get_index()
		or fatigue_label.get_index() >= fatigue_progress.get_index()
		or not satiety_label.text.begins_with("饱食度 ")
		or not fatigue_label.text.begins_with("疲劳度 ")
	):
		push_error("NPCPanel need labels should sit above their progress bars")
		quit(1)
		return
	if equipment_label == null or equipment_label.visible or not equipment_label.text.is_empty():
		push_error("NPCPanel should not retain the old current-equipment summary")
		quit(1)
		return
	npc_system.update_npc_state(npc_id, {"satiety": 19, "fatigue": 81})
	await process_frame
	if not _verify_need_progress(satiety_progress, satiety_label, true, "low satiety") or not _verify_need_progress(fatigue_progress, fatigue_label, true, "high fatigue"):
		quit(1)
		return
	npc_system.update_npc_state(npc_id, {"satiety": 20, "fatigue": 80})
	await process_frame
	if not _verify_need_progress(satiety_progress, satiety_label, false, "satiety boundary") or not _verify_need_progress(fatigue_progress, fatigue_label, false, "fatigue boundary"):
		quit(1)
		return
	if specialties_label == null or not specialties_label.text.begins_with("专长："):
		push_error("NPCPanel specialties text mismatch: %s" % (specialties_label.text if specialties_label != null else "<missing>"))
		quit(1)
		return
	if content == null:
		push_error("NPCPanel content node not found")
		quit(1)
		return
	if panel_container == null or panel_scroll == null or long_term_button_row == null or current_plan_button == null or diary_button == null or knowledge_button == null or event_log_label == null or witness_log_label == null or event_log_box == null or witness_log_box == null or event_log_text == null or witness_log_text == null:
		push_error("NPCPanel memory scroll verification nodes not found")
		quit(1)
		return
	if current_plan_button.get_parent() != long_term_button_row or diary_button.get_parent() != long_term_button_row or knowledge_button.get_parent() != long_term_button_row:
		push_error("Current plan, diary, and knowledge buttons should share one row")
		quit(1)
		return
	if knowledge_button.text != "认识" or event_log_label.text != "事件" or witness_log_label.text != "见闻":
		push_error("NPCPanel should use concise recognition/event/witness labels without counts")
		quit(1)
		return
	if npc_panel.find_child("NPCDiaryBox", true, false) != null or npc_panel.find_child("NPCDiaryText", true, false) != null:
		push_error("Diary should no longer render inline inside NPCPanel")
		quit(1)
		return
	if abs(current_plan_button.size.x - diary_button.size.x) > 2.0 or abs(current_plan_button.size.x - knowledge_button.size.x) > 2.0:
		push_error("Current plan, diary, and knowledge buttons should use equal one-third widths")
		quit(1)
		return
	if event_log_label.get_signal_connection_list("gui_input").is_empty() or witness_log_text.get_signal_connection_list("gui_input").is_empty():
		push_error("NPCPanel memory log controls should connect gui_input for detail popup opening")
		quit(1)
		return
	if npc_panel.find_child("NPCPanelBody", true, false) != null or npc_panel.find_child("NPCStatusGrid", true, false) != null or npc_panel.find_child("NPCMemorySummaryRow", true, false) != null:
		push_error("NPCPanel must remain a single-column vertical information panel")
		quit(1)
		return
	if hp_experience_row.get_parent() != content or attribute_point_row.get_parent() != content or specialties_label.get_parent() != content:
		push_error("NPCPanel overview fields should stay in the main single-column content flow")
		quit(1)
		return
	if long_term_button_row.get_parent() != content or event_log_box.get_parent() != content or witness_log_box.get_parent() != content:
		push_error("NPCPanel long-term information should stay in the main single-column content flow")
		quit(1)
		return
	if event_log_box.get_index() != long_term_button_row.get_index() + 1 or witness_log_box.get_index() != event_log_box.get_index() + 1:
		push_error("NPCPanel memory summaries should follow the long-term buttons vertically")
		quit(1)
		return
	if panel_container.size.y <= panel_container.size.x:
		push_error("NPCPanel information column should remain taller than it is wide: %s" % panel_container.size)
		quit(1)
		return
	var default_available_height := 616.0
	var default_natural_height: float = float(content.get_combined_minimum_size().y) + 24.0
	var default_expected_height: float = minf(default_available_height, default_natural_height)
	if absf(npc_panel.size.y - default_expected_height) > 3.0:
		push_error("NPCPanel default-window height should follow content with a viewport cap: actual=%.2f expected=%.2f natural=%.2f" % [npc_panel.size.y, default_expected_height, default_natural_height])
		quit(1)
		return
	var settled_npc_height := npc_panel.size.y
	npc_panel.call("_queue_panel_fit")
	await process_frame
	if npc_panel.size.y > settled_npc_height + 3.0:
		push_error("NPCPanel fit should not expose a temporary full-height dark block: before=%.2f during=%.2f" % [settled_npc_height, npc_panel.size.y])
		quit(1)
		return
	await process_frame

	root.size = Vector2i(2048, 1109)
	DisplayServer.window_set_size(root.size)
	npc_panel.call("debug_set_layout_viewport_override", Vector2(2048, 1109))
	building_panel.call("debug_set_layout_viewport_override", Vector2(2048, 1109))
	await process_frame
	await process_frame
	await process_frame
	var large_available_height := 1077.0
	var large_natural_height: float = float(content.get_combined_minimum_size().y) + 24.0
	var large_expected_height: float = minf(large_available_height, large_natural_height)
	if panel_container.size.y <= panel_container.size.x or absf(npc_panel.size.y - large_expected_height) > 3.0:
		push_error("NPCPanel large-window responsive size mismatch: panel=%s expected_height=%.2f natural=%.2f" % [npc_panel.size, large_expected_height, large_natural_height])
		quit(1)
		return
	if absf((npc_panel.position.x + npc_panel.size.x) - 2032.0) > 2.0:
		push_error("NPCPanel should preserve the 16px right safe margin after resizing")
		quit(1)
		return
	if large_natural_height <= large_available_height + 0.5 and panel_scroll.get_v_scroll_bar().visible:
		push_error("NPCPanel should remove outer scrolling when all content fits the enlarged window")
		quit(1)
		return

	root.size = Vector2i(1152, 648)
	DisplayServer.window_set_size(root.size)
	npc_panel.call("debug_set_layout_viewport_override", Vector2(1152, 648))
	building_panel.call("debug_set_layout_viewport_override", Vector2(1152, 648))
	await process_frame
	await process_frame
	await process_frame

	var panel_height_before := panel_container.size.y
	for index in range(40):
		memory_system.add_event({
			"type": "work_started",
			"subject_npc_id": npc_id,
			"actor_ids": [npc_id],
			"target_ids": ["test_memory_%02d" % index],
			"location_id": "plaza",
			"visibility": "private",
			"importance": 10,
			"summary": "测试事件摘要内容变长 %02d" % index,
			"payload": {
				"action_id": "verify_memory_scroll",
				"building_id": "plaza",
				"workstation_id": "verify_event_scroll"
			}
		})
		var witness_event: Dictionary = memory_system.add_event({
			"type": "work_started",
			"subject_npc_id": "cook_01",
			"actor_ids": ["cook_01"],
			"target_ids": ["test_witness_%02d" % index],
			"location_id": "plaza",
			"visibility": "private",
			"importance": 10,
			"summary": "测试见闻摘要内容变长 %02d" % index,
			"payload": {
				"action_id": "verify_witness_scroll",
				"building_id": "plaza",
				"workstation_id": "verify_witness_scroll"
			}
		})
		memory_system.add_witness_event(npc_id, str(witness_event.get("event_id", "")))
	await process_frame
	await process_frame
	await process_frame
	if npc_panel.global_position.y < -0.5:
		push_error("NPCPanel grew upward outside the viewport: %.2f" % npc_panel.global_position.y)
		quit(1)
		return
	if panel_container.global_position.y < npc_panel.global_position.y - 0.5:
		push_error("NPCPanel content grew upward past the panel top: %.2f < %.2f" % [panel_container.global_position.y, npc_panel.global_position.y])
		quit(1)
		return
	if panel_container.size.y > panel_height_before + 4.0:
		push_error("NPCPanel should not grow after many memory events: before=%.2f after=%.2f" % [panel_height_before, panel_container.size.y])
		quit(1)
		return
	if event_log_box.size.y > 170.0 or witness_log_box.size.y > 170.0:
		push_error("NPC memory boxes should stay compact. event=%.2f witness=%.2f" % [event_log_box.size.y, witness_log_box.size.y])
		quit(1)
		return
	if not _is_text_edit_scrolled_near_bottom(event_log_text):
		push_error("Event log should be scrollable and auto-scroll to the latest event. lines=%d scroll=%d max=%.2f size=%.2f" % [
			event_log_text.get_line_count(),
			event_log_text.scroll_vertical,
			event_log_text.get_v_scroll_bar().max_value,
			event_log_text.size.y
		])
		quit(1)
		return
	if not _is_text_edit_scrolled_near_bottom(witness_log_text):
		push_error("Witness log should be scrollable and auto-scroll to the latest event. lines=%d scroll=%d max=%.2f size=%.2f" % [
			witness_log_text.get_line_count(),
			witness_log_text.scroll_vertical,
			witness_log_text.get_v_scroll_bar().max_value,
			witness_log_text.size.y
		])
		quit(1)
		return

	background_button.pressed.emit()
	await process_frame
	var memory_detail_popup := root.find_child("NPCMemoryDetailPopup", true, false) as Control
	var memory_detail_title := root.find_child("NPCMemoryDetailTitle", true, false) as Label
	var memory_detail_text := root.find_child("NPCMemoryDetailText", true, false) as TextEdit
	var memory_detail_close := root.find_child("NPCMemoryDetailCloseButton", true, false) as Button
	if memory_detail_popup == null or memory_detail_title == null or memory_detail_text == null or memory_detail_close == null:
		push_error("NPC detail popup nodes not found")
		quit(1)
		return
	var veteran_profile: Dictionary = npc_system.get_npc(npc_id)
	var required_profile_fields: Array[String] = ["appearance", "background_story", "background_job", "religion", "personality", "desires", "fears", "boundaries", "speech_style", "abilities"]
	if not memory_detail_popup.visible or not memory_detail_title.text.contains("人物背景"):
		push_error("NPC background button did not open the character background popup")
		quit(1)
		return
	if veteran_profile.has("signature_lines") or memory_detail_text.text.contains("代表性表达"):
		push_error("NPC background popup still exposes fixed representative expressions")
		quit(1)
		return
	for field_name in required_profile_fields:
		var raw_value: Variant = veteran_profile.get(field_name)
		var expected_values: Array = raw_value if raw_value is Array else [raw_value]
		for expected_value in expected_values:
			var expected_text := str(expected_value).strip_edges()
			if not expected_text.is_empty() and not memory_detail_text.text.contains(expected_text):
				push_error("NPC background popup omitted prompt profile field %s: %s" % [field_name, expected_text])
				quit(1)
				return
	var veteran_story := str(veteran_profile.get("background_story", ""))
	memory_detail_close.pressed.emit()
	if not npc_system.debug_select_npc("cook_01"):
		push_error("Failed to switch NPC for background popup verification")
		quit(1)
		return
	await process_frame
	background_button.pressed.emit()
	await process_frame
	var cook_story := str(npc_system.get_npc("cook_01").get("background_story", ""))
	if not memory_detail_text.text.contains(cook_story) or memory_detail_text.text.contains(veteran_story):
		push_error("NPC background popup retained stale profile content after switching NPC")
		quit(1)
		return
	memory_detail_close.pressed.emit()
	if not npc_system.debug_select_npc(npc_id):
		push_error("Failed to restore NPC after background popup verification")
		quit(1)
		return
	await process_frame

	daily_plan_system.generate_rule_plan_for_npc(npc_id)
	time_system.set_current_time(1, 8, 0, 0)
	if int(game_state.current_hour) != 8:
		push_error("Failed to set current plan verification time to 08:00")
		quit(1)
		return
	current_plan_button.pressed.emit()
	await process_frame
	await process_frame
	await process_frame
	if not memory_detail_popup.visible or not memory_detail_title.text.contains("当前计划") or not memory_detail_text.text.contains("07:00–11:00"):
		push_error("Current plan popup did not show the active 24-hour plan")
		quit(1)
		return
	var first_visible_plan_line := memory_detail_text.get_first_visible_line()
	if not memory_detail_text.get_line(first_visible_plan_line).contains("00:00–05:00") or not memory_detail_text.text.contains("▶ 07:00–11:00"):
		push_error("Current plan popup should begin with the second prior visible group and mark the 08:00 group third: hour=%d first_line=%d text=%s" % [
			int(game_state.current_hour),
			first_visible_plan_line,
			memory_detail_text.get_line(first_visible_plan_line)
		])
		quit(1)
		return
	var updated_plan: Array = daily_plan_system.get_npc_daily_plan(npc_id)
	updated_plan[8]["reason"] = "计划覆盖刷新测试"
	if not daily_plan_system.set_npc_daily_plan(npc_id, updated_plan, false, "rule_default"):
		push_error("Failed to update the active plan for popup refresh verification")
		quit(1)
		return
	await process_frame
	if not memory_detail_text.text.contains("计划覆盖刷新测试"):
		push_error("Current plan popup should refresh when the active plan is replaced")
		quit(1)
		return

	updated_plan = daily_plan_system.get_npc_daily_plan(npc_id)
	for hour in range(13, 17):
		updated_plan[hour]["action_id"] = "work_tavern"
		updated_plan[hour]["action_name"] = "酿造酒"
		updated_plan[hour]["source"] = "llm_plan_day"
		updated_plan[hour]["target"] = {}
		updated_plan[hour]["priority"] = 60
		updated_plan[hour]["reason"] = "酿造酒"
		updated_plan[hour]["dialogue_goal"] = ""
	time_system.set_current_time(1, 14, 0, 0)
	if not daily_plan_system.set_npc_daily_plan(npc_id, updated_plan, false, "rule_default"):
		push_error("Failed to set grouped LLM plan display fixture")
		quit(1)
		return
	await process_frame
	var grouped_plan_line := "▶ 13:00–16:00  酿造酒｜真实 LLM 日计划"
	if not memory_detail_text.text.contains(grouped_plan_line):
		push_error("Consecutive identical plan hours should merge into one marked range: %s" % memory_detail_text.text)
		quit(1)
		return
	if memory_detail_text.text.contains("\n    酿造酒") or memory_detail_text.text.count("酿造酒") != 1:
		push_error("Plan reason identical to the action name should be hidden: %s" % memory_detail_text.text)
		quit(1)
		return
	updated_plan = daily_plan_system.get_npc_daily_plan(npc_id)
	updated_plan[15]["reason"] = "计划覆盖刷新测试"
	if not daily_plan_system.set_npc_daily_plan(npc_id, updated_plan, false, "rule_default"):
		push_error("Failed to update one grouped plan reason")
		quit(1)
		return
	await process_frame
	if not memory_detail_text.text.contains("计划覆盖刷新测试") or memory_detail_text.text.contains("13:00–16:00"):
		push_error("A distinct visible reason should remain visible and split the merged range")
		quit(1)
		return
	memory_detail_close.pressed.emit()
	await process_frame
	for boundary_hour in [0, 1]:
		time_system.set_current_time(1, boundary_hour, 0, 0)
		current_plan_button.pressed.emit()
		await process_frame
		await process_frame
		await process_frame
		if memory_detail_text.get_first_visible_line() != 0 or not memory_detail_text.get_line(0).contains("00:00–05:00") or not memory_detail_text.text.contains("▶ 00:00–05:00"):
			push_error("Current plan popup boundary positioning failed at %02d:00: first_line=%d" % [
				boundary_hour,
				memory_detail_text.get_first_visible_line()
			])
			quit(1)
			return
		memory_detail_close.pressed.emit()
		await process_frame
	time_system.set_current_time(1, 6, 0, 0)

	var reflection_apply: Dictionary = npc_system.apply_daily_reflection(npc_id, {
		"ok": true,
		"npc_id": npc_id,
		"day": 1,
		"diary_entry": "今天的计划终于能在面板里单独查看了。",
		"knowledge_graph_updates": [
			{
				"subject": "guard_officer",
				"relation": "ui_verification",
				"value": "守备官要求把长期信息拆分为三个入口",
				"confidence": 0.95,
				"subject_label": "守备官",
				"relation_label": "界面验证",
				"value_label": "守备官要求把长期信息拆分为三个入口"
			}
		],
		"source": "verify_ui"
	})
	if not bool(reflection_apply.get("ok", false)):
		push_error("Failed to seed diary and knowledge UI verification")
		quit(1)
		return
	await process_frame
	diary_button.pressed.emit()
	await process_frame
	if not memory_detail_popup.visible or not memory_detail_title.text.contains("日记") or not memory_detail_text.text.contains("今天的计划终于") or memory_detail_text.text.contains("记忆摘要："):
		push_error("Diary button did not open the NPC diary popup")
		quit(1)
		return
	memory_detail_close.pressed.emit()
	await process_frame
	knowledge_button.pressed.emit()
	await process_frame
	if (
		not memory_detail_popup.visible
		or not memory_detail_title.text.contains("认识")
		or not memory_detail_text.text.contains("【守备官】")
		or not memory_detail_text.text.contains("界面验证")
		or not memory_detail_text.text.contains("守备官要求")
		or memory_detail_text.text.contains("ui_verification")
		or memory_detail_text.text.contains("guard_officer")
		or memory_detail_text.text.contains("可信度")
		or memory_detail_text.text.contains("更新于")
	):
		push_error("Knowledge button did not open the NPC knowledge graph popup")
		quit(1)
		return
	memory_detail_close.pressed.emit()
	await process_frame

	var detail_result: Dictionary = npc_panel.debug_open_memory_detail("event_log")
	if not bool(detail_result.get("ok", false)):
		push_error("Failed to open event memory detail popup: %s" % JSON.stringify(detail_result))
		quit(1)
		return
	await process_frame
	if not memory_detail_popup.visible or not memory_detail_title.text.contains("事件") or memory_detail_title.text.contains("事件库") or not memory_detail_text.text.contains("测试事件摘要内容变长"):
		push_error("Event log detail popup did not show expected content")
		quit(1)
		return
	if _contains_internal_event_fields(memory_detail_text.text):
		push_error("Event log detail popup exposed internal structured fields: %s" % memory_detail_text.text)
		quit(1)
		return
	await process_frame
	await process_frame
	if not _is_text_edit_scrolled_near_bottom(memory_detail_text):
		push_error("Event detail popup should open at the latest event. scroll=%d max=%.2f" % [memory_detail_text.scroll_vertical, memory_detail_text.get_v_scroll_bar().max_value])
		quit(1)
		return
	memory_detail_text.scroll_vertical = 12
	await process_frame
	var event_detail_scroll_before := memory_detail_text.scroll_vertical
	memory_system.add_event({
		"type": "work_started",
		"subject_npc_id": npc_id,
		"actor_ids": [npc_id],
		"target_ids": [],
		"location_id": "plaza",
		"visibility": "private",
		"importance": 10,
		"summary": "详情窗滚动保持事件",
		"payload": {
			"action_id": "verify_detail_scroll",
			"building_id": "plaza",
			"workstation_id": "verify_detail_scroll"
		}
	})
	await process_frame
	await process_frame
	await process_frame
	if abs(memory_detail_text.scroll_vertical - event_detail_scroll_before) > 1:
		push_error("Event detail refresh changed the reader scroll position: before=%d after=%d" % [event_detail_scroll_before, memory_detail_text.scroll_vertical])
		quit(1)
		return
	memory_detail_close.pressed.emit()
	await process_frame
	if memory_detail_popup.visible:
		push_error("Memory detail close button did not hide popup")
		quit(1)
		return

	detail_result = npc_panel.debug_open_memory_detail("witness_log")
	if not bool(detail_result.get("ok", false)):
		push_error("Failed to open witness memory detail popup: %s" % JSON.stringify(detail_result))
		quit(1)
		return
	await process_frame
	if not memory_detail_popup.visible or not memory_detail_title.text.contains("见闻") or memory_detail_title.text.contains("见闻库") or not memory_detail_text.text.contains("测试见闻摘要内容变长"):
		push_error("Witness log detail popup did not show expected content")
		quit(1)
		return
	if _contains_internal_event_fields(memory_detail_text.text):
		push_error("Witness log detail popup exposed internal structured fields: %s" % memory_detail_text.text)
		quit(1)
		return
	await process_frame
	await process_frame
	if not _is_text_edit_scrolled_near_bottom(memory_detail_text):
		push_error("Witness detail popup should open at the latest event. scroll=%d max=%.2f" % [memory_detail_text.scroll_vertical, memory_detail_text.get_v_scroll_bar().max_value])
		quit(1)
		return
	memory_detail_text.scroll_vertical = 12
	await process_frame
	var witness_detail_scroll_before := memory_detail_text.scroll_vertical
	var scroll_witness_event: Dictionary = memory_system.add_event({
		"type": "work_started",
		"subject_npc_id": "cook_01",
		"actor_ids": ["cook_01"],
		"target_ids": [npc_id],
		"location_id": "plaza",
		"visibility": "private",
		"importance": 10,
		"summary": "详情窗滚动保持见闻",
		"payload": {
			"action_id": "verify_detail_witness_scroll",
			"building_id": "plaza",
			"workstation_id": "verify_detail_witness_scroll"
		}
	})
	memory_system.add_witness_event(npc_id, str(scroll_witness_event.get("event_id", "")))
	await process_frame
	await process_frame
	await process_frame
	if abs(memory_detail_text.scroll_vertical - witness_detail_scroll_before) > 1:
		push_error("Witness detail refresh changed the reader scroll position: before=%d after=%d" % [witness_detail_scroll_before, memory_detail_text.scroll_vertical])
		quit(1)
		return
	memory_detail_close.pressed.emit()
	await process_frame

	if not npc_system.update_npc_state(npc_id, {"hp": 64, "satiety": 51, "fatigue": 33, "current_action": "guard_placeholder"}):
		push_error("Failed to update NPC state")
		quit(1)
		return
	await process_frame

	var action_label := npc_panel.find_child("NPCActionLabel", true, false) as Label
	if hp_label.text != "HP：64 / 120" or action_label == null or action_label.text != "未知行动" or action_label.get_parent() != header:
		push_error("NPCPanel did not refresh after state update")
		quit(1)
		return

	building_system.debug_select_building("main_hall")
	await process_frame
	if npc_panel.visible or not building_panel.visible:
		push_error("Panel switching from NPC to building failed")
		quit(1)
		return
	await process_frame
	await process_frame
	var building_content := building_panel.find_child("Content", true, false) as VBoxContainer
	var building_scroll := building_panel.find_child("BuildingPanelScroll", true, false) as ScrollContainer
	if building_content == null or building_scroll == null:
		push_error("BuildingPanel responsive-layout nodes not found")
		quit(1)
		return
	var main_hall_height: float = building_panel.size.y
	var main_hall_expected_height: float = minf(616.0, float(building_content.get_combined_minimum_size().y) + 24.0)
	if absf(main_hall_height - main_hall_expected_height) > 3.0 or main_hall_height >= 612.0:
		push_error("BuildingPanel should shrink to its main-hall content instead of filling the viewport: actual=%.2f expected=%.2f" % [main_hall_height, main_hall_expected_height])
		quit(1)
		return
	building_panel.call("_queue_panel_fit")
	await process_frame
	if building_panel.size.y > main_hall_height + 3.0:
		push_error("BuildingPanel fit should not expose a temporary full-height dark block: before=%.2f during=%.2f" % [main_hall_height, building_panel.size.y])
		quit(1)
		return
	await process_frame

	building_panel.show_building("stable")
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	var stable_expected_height: float = minf(616.0, float(building_content.get_combined_minimum_size().y) + 24.0)
	if building_panel.size.y <= main_hall_height + 20.0 or absf(building_panel.size.y - stable_expected_height) > 3.0:
		push_error("BuildingPanel should grow with stable content: main_hall=%.2f stable=%.2f expected=%.2f" % [main_hall_height, building_panel.size.y, stable_expected_height])
		quit(1)
		return

	building_panel.show_building("main_hall")
	root.size = Vector2i(2048, 1109)
	DisplayServer.window_set_size(root.size)
	npc_panel.call("debug_set_layout_viewport_override", Vector2(2048, 1109))
	building_panel.call("debug_set_layout_viewport_override", Vector2(2048, 1109))
	await process_frame
	await process_frame
	await process_frame
	var large_building_expected_height: float = minf(1077.0, float(building_content.get_combined_minimum_size().y) + 24.0)
	if absf(building_panel.size.y - large_building_expected_height) > 3.0:
		push_error("BuildingPanel enlarged-window content fit mismatch: actual=%.2f expected=%.2f" % [building_panel.size.y, large_building_expected_height])
		quit(1)
		return
	if absf((building_panel.position.x + building_panel.size.x) - 2032.0) > 2.0 or building_scroll.get_v_scroll_bar().visible:
		push_error("BuildingPanel should preserve its right margin and avoid unnecessary scrolling after resize")
		quit(1)
		return
	root.size = Vector2i(1152, 648)
	DisplayServer.window_set_size(root.size)
	npc_panel.call("debug_set_layout_viewport_override", Vector2(1152, 648))
	building_panel.call("debug_set_layout_viewport_override", Vector2(1152, 648))
	await process_frame
	await process_frame
	await process_frame
	if not npc_system.update_npc_state(npc_id, {"satiety": 50, "fatigue": 34, "current_action": "work_garden"}):
		push_error("Failed to update hidden NPC state")
		quit(1)
		return
	await process_frame
	if npc_panel.visible or not building_panel.visible:
		push_error("Hidden NPCPanel should not reopen after the current NPC state changes")
		quit(1)
		return

	npc_system.debug_select_npc(npc_id)
	await process_frame
	if not npc_panel.visible or building_panel.visible:
		push_error("Panel switching from building to NPC failed")
		quit(1)
		return

	var dialogue_button := npc_panel.find_child("NPCDialogueButton", true, false) as Button
	var order_button := npc_panel.find_child("NPCAssignButton", true, false) as Button
	if dialogue_button == null or order_button == null:
		push_error("NPCPanel dialogue/order buttons not found")
		quit(1)
		return
	order_button.pressed.emit()
	await process_frame
	if not npc_panel.visible or not order_panel.visible or dialog_panel.visible:
		push_error("Opening order should keep NPCPanel visible and not show DialogPanel")
		quit(1)
		return
	dialogue_button.pressed.emit()
	await process_frame
	if not npc_panel.visible or not dialog_panel.visible or order_panel.visible:
		push_error("Opening dialogue should keep NPCPanel visible and close OrderPanel")
		quit(1)
		return
	order_button.pressed.emit()
	await process_frame
	if not npc_panel.visible or not dialog_panel.visible or order_panel.visible:
		push_error("Opening order must not implicitly complete or replace an active guard dialogue")
		quit(1)
		return
	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	if dialog_system != null and dialog_system.has_method("cancel_displayed_dialogue"):
		dialog_system.cancel_displayed_dialogue()
	await process_frame
	order_panel.visible = false

	building_system.debug_select_building("main_hall")
	await process_frame
	if not building_system.debug_damage_building("main_hall", 30):
		push_error("Failed to damage selected building for repair panel switching check")
		quit(1)
		return
	await process_frame
	if not building_panel.visible:
		push_error("BuildingPanel should remain visible after selected building state changes")
		quit(1)
		return
	if not building_system.repair_building("main_hall"):
		push_error("Failed to start selected building repair")
		quit(1)
		return
	await process_frame

	npc_system.debug_select_npc(npc_id)
	await process_frame
	if not npc_panel.visible or building_panel.visible:
		push_error("NPCPanel should replace BuildingPanel while selected building is repairing")
		quit(1)
		return

	var event_bus := root.get_node_or_null("EventBus")
	if event_bus == null:
		push_error("EventBus not found")
		quit(1)
		return
	event_bus.logical_time_tick.emit(120.0, 1.0)
	await process_frame
	if not npc_panel.visible or building_panel.visible:
		push_error("Building repair progress should not switch the right panel away from NPCPanel")
		quit(1)
		return
	if not await _verify_recruited_name_color(npc_system, npc_panel):
		quit(1)
		return

	var close_button := npc_panel.find_child("NPCPanelCloseButton", true, false) as Button
	if close_button == null:
		push_error("NPCPanel close button not found")
		quit(1)
		return
	close_button.pressed.emit()
	await process_frame
	if npc_panel.visible:
		push_error("NPCPanel close button did not hide panel")
		quit(1)
		return

	print("T0303 NPC panel and state verification passed.")
	quit(0)


func _verify_recruited_name_color(npc_system: Node, npc_panel: Control) -> bool:
	const EXPECTED_FRIENDLY_COLOR := Color(0.64, 0.92, 0.68, 1.0)
	var target_npc_id := "stableman_01"
	if not npc_system.set_npc_recruited(target_npc_id, true):
		push_error("Failed to recruit NPC for friendly name color verification")
		return false
	npc_system.debug_select_npc(target_npc_id)
	await process_frame
	var panel_name := npc_panel.find_child("NPCNameLabel", true, false) as Label
	if panel_name == null or not panel_name.modulate.is_equal_approx(EXPECTED_FRIENDLY_COLOR):
		push_error("Recruited NPC panel name should refresh to light green")
		return false
	var npc_root := root.get_node_or_null("Main/WorldRoot/Station/NPCs")
	var target_node: Node = null
	for child in npc_root.get_children():
		if str(child.get_meta("npc_id", "")) == target_npc_id:
			target_node = child
			break
	if target_node == null:
		push_error("Recruited NPC world node not found")
		return false
	var world_name := target_node.get_node_or_null("NameLabel") as Label3D
	var world_status := target_node.get_node_or_null("StatusLabel") as Label3D
	if world_name == null or not world_name.modulate.is_equal_approx(EXPECTED_FRIENDLY_COLOR):
		push_error("Recruited NPC world name should refresh to light green")
		return false
	if world_status == null or not world_status.modulate.is_equal_approx(Color.WHITE):
		push_error("Only the recruited NPC name should be green; status text should remain neutral")
		return false
	if world_name.text.contains("\n") or not world_status.text.begins_with("HP "):
		push_error("World NPC name and status labels should be visually separable")
		return false
	return true


func _contains_internal_event_fields(text: String) -> bool:
	for marker in ["Payload", "事件ID", "类型：", "地点：", "可见性：", "重要度：", "参与：", "目标："]:
		if text.contains(marker):
			return true
	return false


func _verify_need_progress(progress: ProgressBar, label: Label, expected_danger: bool, phase: String) -> bool:
	var fill := progress.get_theme_stylebox("fill") as StyleBoxFlat
	var fill_color := fill.bg_color.to_html(true) if fill != null else ""
	var expected_fill := DANGER_FILL if expected_danger else NORMAL_FILL
	if bool(progress.get_meta("danger_state", false)) != expected_danger or fill_color != expected_fill:
		push_error("NPCPanel need progress mismatch during %s: danger=%s fill=%s" % [phase, progress.get_meta("danger_state", false), fill_color])
		return false
	var label_color := label.get_theme_color("font_color").to_html(true)
	if expected_danger and label_color != DANGER_LABEL:
		push_error("NPCPanel need label should be red during %s: %s" % [phase, label_color])
		return false
	if not expected_danger and label_color == DANGER_LABEL:
		push_error("NPCPanel need label stayed red during %s" % phase)
		return false
	return true


func _is_text_edit_scrolled_near_bottom(text_edit: TextEdit) -> bool:
	var scroll_bar := text_edit.get_v_scroll_bar()
	if scroll_bar == null or scroll_bar.max_value <= 0.0:
		return false
	var font_size: float = maxf(1.0, float(text_edit.get_theme_font_size("font_size")))
	var visible_line_estimate: int = ceili(text_edit.size.y / font_size) + 2
	var minimum_bottom_scroll: int = maxi(1, text_edit.get_line_count() - visible_line_estimate)
	return text_edit.scroll_vertical >= minimum_bottom_scroll
