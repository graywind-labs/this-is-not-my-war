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
	await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel")
	var building_panel := root.get_node_or_null("Main/UI/BuildingPanel")
	if npc_system == null or building_system == null or npc_panel == null or building_panel == null:
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

	var hp_label := root.get_node_or_null("Main/UI/NPCPanel/PanelContainer/MarginContainer/Content/NPCHPLabel") as Label
	if hp_label == null or hp_label.text != "HP：100 / 100":
		push_error("NPCPanel HP text mismatch: %s" % (hp_label.text if hp_label != null else "<missing>"))
		quit(1)
		return

	var content := root.get_node_or_null("Main/UI/NPCPanel/PanelContainer/MarginContainer/Content")
	var panel_container := root.get_node_or_null("Main/UI/NPCPanel/PanelContainer") as Control
	var attributes_label := root.get_node_or_null("Main/UI/NPCPanel/PanelContainer/MarginContainer/Content/NPCAttributesLabel") as Label
	var specialties_label := root.get_node_or_null("Main/UI/NPCPanel/PanelContainer/MarginContainer/Content/NPCJobLabel") as Label
	var event_log_label := root.get_node_or_null("Main/UI/NPCPanel/PanelContainer/MarginContainer/Content/NPCEventLogLabel") as Label
	var witness_log_label := root.get_node_or_null("Main/UI/NPCPanel/PanelContainer/MarginContainer/Content/NPCWitnessLogLabel") as Label
	if attributes_label == null or attributes_label.text != "属性：力量 7，智力 6":
		push_error("NPCPanel attributes text mismatch: %s" % (attributes_label.text if attributes_label != null else "<missing>"))
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
	if panel_container == null or event_log_label == null or witness_log_label == null:
		push_error("NPCPanel growth verification nodes not found")
		quit(1)
		return
	var hp_index := hp_label.get_index()
	if attributes_label.get_index() != hp_index + 1 or specialties_label.get_index() != hp_index + 2:
		push_error("NPCPanel order mismatch; expected HP, attributes, specialties")
		quit(1)
		return

	var long_memory_lines: Array[String] = ["事件库：内容膨胀测试"]
	for index in range(40):
		long_memory_lines.append("- 08:%02d:00 测试事件摘要内容变长" % index)
	event_log_label.text = "\n".join(long_memory_lines)
	witness_log_label.text = "\n".join(long_memory_lines)
	await process_frame
	if npc_panel.global_position.y < -0.5:
		push_error("NPCPanel grew upward outside the viewport: %.2f" % npc_panel.global_position.y)
		quit(1)
		return
	if panel_container.global_position.y < npc_panel.global_position.y - 0.5:
		push_error("NPCPanel content grew upward past the panel top: %.2f < %.2f" % [panel_container.global_position.y, npc_panel.global_position.y])
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
