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
	var attributes_label := root.get_node_or_null("Main/UI/NPCPanel/PanelContainer/MarginContainer/Content/NPCAttributesLabel") as Label
	var specialties_label := root.get_node_or_null("Main/UI/NPCPanel/PanelContainer/MarginContainer/Content/NPCJobLabel") as Label
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
	var hp_index := hp_label.get_index()
	if attributes_label.get_index() != hp_index + 1 or specialties_label.get_index() != hp_index + 2:
		push_error("NPCPanel order mismatch; expected HP, attributes, specialties")
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

	npc_system.debug_select_npc(npc_id)
	await process_frame
	if not npc_panel.visible or building_panel.visible:
		push_error("Panel switching from building to NPC failed")
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
