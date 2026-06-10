extends SceneTree


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	await process_frame
	await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel")
	var building_panel := root.get_node_or_null("Main/UI/BuildingPanel")
	var dialog_panel := root.get_node_or_null("Main/UI/DialogPanel") as Control
	var order_panel := root.get_node_or_null("Main/UI/OrderPanel") as Control
	if npc_system == null or building_system == null or memory_system == null or npc_panel == null or building_panel == null or dialog_panel == null or order_panel == null:
		push_error("Required systems or panels not found")
		quit(1)
		return

	var npc_id := "veteran_deputy_01"
	if not npc_system.debug_select_npc(npc_id):
		push_error("Failed to select NPC")
		quit(1)
		return
	await process_frame

	if not npc_panel.visible:
		push_error("NPCPanel did not open after NPC selection")
		quit(1)
		return

	var hp_label := npc_panel.find_child("NPCHPLabel", true, false) as Label
	if hp_label == null or hp_label.text != "HP：100 / 100":
		push_error("NPCPanel HP text mismatch: %s" % (hp_label.text if hp_label != null else "<missing>"))
		quit(1)
		return

	var content := root.get_node_or_null("Main/UI/NPCPanel/PanelContainer/MarginContainer/Content")
	var panel_container := root.get_node_or_null("Main/UI/NPCPanel/PanelContainer") as Control
	var hp_experience_row := npc_panel.find_child("NPCHPExperienceRow", true, false) as HBoxContainer
	var experience_label := npc_panel.find_child("NPCExperienceLabel", true, false) as Label
	var attributes_label := npc_panel.find_child("NPCAttributesLabel", true, false) as Label
	var attribute_point_row := npc_panel.find_child("NPCAttributePointRow", true, false) as HBoxContainer
	var strength_point_button := npc_panel.find_child("NPCStrengthPointButton", true, false) as Button
	var intelligence_point_button := npc_panel.find_child("NPCIntelligencePointButton", true, false) as Button
	var strength_value_label := npc_panel.find_child("NPCStrengthValueLabel", true, false) as Label
	var intelligence_value_label := npc_panel.find_child("NPCIntelligenceValueLabel", true, false) as Label
	var specialties_label := root.get_node_or_null("Main/UI/NPCPanel/PanelContainer/MarginContainer/Content/NPCJobLabel") as Label
	var event_log_label := npc_panel.find_child("NPCEventLogLabel", true, false) as Label
	var witness_log_label := npc_panel.find_child("NPCWitnessLogLabel", true, false) as Label
	var event_log_box := npc_panel.find_child("NPCEventLogBox", true, false) as PanelContainer
	var witness_log_box := npc_panel.find_child("NPCWitnessLogBox", true, false) as PanelContainer
	var event_log_text := npc_panel.find_child("NPCEventLogText", true, false) as TextEdit
	var witness_log_text := npc_panel.find_child("NPCWitnessLogText", true, false) as TextEdit
	if hp_experience_row == null or hp_label.get_parent() != hp_experience_row:
		push_error("NPCPanel HP and experience should share one row")
		quit(1)
		return
	if experience_label == null or not experience_label.text.begins_with("经验：") or not experience_label.text.contains(" / "):
		push_error("NPCPanel experience text mismatch: %s" % (experience_label.text if experience_label != null else "<missing>"))
		quit(1)
		return
	if attributes_label == null or attributes_label.text != "属性：":
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
	if specialties_label == null or not specialties_label.text.begins_with("专长："):
		push_error("NPCPanel specialties text mismatch: %s" % (specialties_label.text if specialties_label != null else "<missing>"))
		quit(1)
		return
	if content == null:
		push_error("NPCPanel content node not found")
		quit(1)
		return
	if panel_container == null or event_log_label == null or witness_log_label == null or event_log_box == null or witness_log_box == null or event_log_text == null or witness_log_text == null:
		push_error("NPCPanel memory scroll verification nodes not found")
		quit(1)
		return
	var hp_row_index := hp_experience_row.get_index()
	if attribute_point_row.get_index() != hp_row_index + 1 or specialties_label.get_index() != hp_row_index + 2:
		push_error("NPCPanel order mismatch; expected HP/experience, inline attributes, specialties")
		quit(1)
		return

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

	if not npc_system.update_npc_state(npc_id, {"hp": 64, "satiety": 51, "fatigue": 33, "current_action": "guard_placeholder"}):
		push_error("Failed to update NPC state")
		quit(1)
		return
	await process_frame

	var action_label := root.get_node_or_null("Main/UI/NPCPanel/PanelContainer/MarginContainer/Content/NPCActionLabel") as Label
	if hp_label.text != "HP：64 / 100" or action_label == null or action_label.text != "当前行动：guard_placeholder":
		push_error("NPCPanel did not refresh after state update")
		quit(1)
		return

	building_system.debug_select_building("main_hall")
	await process_frame
	if npc_panel.visible or not building_panel.visible:
		push_error("Panel switching from NPC to building failed")
		quit(1)
		return
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

	var dialogue_button := root.get_node_or_null("Main/UI/NPCPanel/PanelContainer/MarginContainer/Content/NPCDialogueButton") as Button
	var order_button := root.get_node_or_null("Main/UI/NPCPanel/PanelContainer/MarginContainer/Content/NPCAssignButton") as Button
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
	if not npc_panel.visible or dialog_panel.visible or not order_panel.visible:
		push_error("Opening order should close active DialogPanel without hiding NPCPanel")
		quit(1)
		return
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

	var close_button := root.get_node_or_null("Main/UI/NPCPanel/PanelContainer/MarginContainer/Content/Header/NPCPanelCloseButton") as Button
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


func _is_text_edit_scrolled_near_bottom(text_edit: TextEdit) -> bool:
	var scroll_bar := text_edit.get_v_scroll_bar()
	if scroll_bar == null or scroll_bar.max_value <= 0.0:
		return false
	var font_size: float = maxf(1.0, float(text_edit.get_theme_font_size("font_size")))
	var visible_line_estimate: int = ceili(text_edit.size.y / font_size) + 2
	var minimum_bottom_scroll: int = maxi(1, text_edit.get_line_count() - visible_line_estimate)
	return text_edit.scroll_vertical >= minimum_bottom_scroll
