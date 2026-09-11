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
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel")
	if npc_system == null or resource_system == null or memory_system == null or llm_bridge == null or npc_panel == null:
		push_error("Required systems or NPCPanel not found")
		quit(1)
		return

	var target_id := "cook_01"
	var witness_id := "doctor_01"
	npc_system.debug_select_npc(target_id)
	await process_frame
	if not npc_panel.visible:
		push_error("NPCPanel did not open for interaction verification")
		quit(1)
		return

	# NPCPanel is wrapped in a runtime ScrollContainer, so interaction tests locate
	# stable named controls instead of depending on the pre-wrap absolute path.
	var public_visibility_radio := npc_panel.find_child("NPCInteractionPublicRadio", true, false) as CheckBox
	var private_visibility_radio := npc_panel.find_child("NPCInteractionPrivateRadio", true, false) as CheckBox
	var money_spin := npc_panel.find_child("NPCGiftMoneySpin", true, false) as SpinBox
	var gift_button := npc_panel.find_child("NPCGiftMoneyButton", true, false) as Button
	var wine_spin := npc_panel.find_child("NPCGiftWineSpin", true, false) as SpinBox
	var gift_wine_button := npc_panel.find_child("NPCGiftWineButton", true, false) as Button
	var wine_label := npc_panel.find_child("NPCWineLabel", true, false) as Label
	var weapon_button := npc_panel.find_child("NPCGiveWeaponButton", true, false) as Button
	var order_button := npc_panel.find_child("NPCAssignButton", true, false) as Button
	var dialogue_button := npc_panel.find_child("NPCDialogueButton", true, false) as Button
	var management_row := npc_panel.find_child("NPCManagementButtonRow", true, false) as HBoxContainer
	var strategy_value := npc_panel.find_child("NPCCombatStrategyValue", true, false) as Label
	var equipment_label := npc_panel.find_child("NPCEquipmentLabel", true, false) as Label
	var result_label := npc_panel.find_child("NPCInteractionResultLabel", true, false) as Label
	if [public_visibility_radio, private_visibility_radio, money_spin, gift_button, wine_spin, gift_wine_button, wine_label, weapon_button, order_button, dialogue_button, management_row, strategy_value, equipment_label, result_label].has(null):
		push_error("NPC interaction controls are missing")
		quit(1)
		return
	if npc_panel.find_child("NPCCombatStrategySelect", true, false) != null:
		push_error("NPCPanel must not expose a manual combat strategy selector")
		quit(1)
		return
	if npc_panel.find_child("NPCInteractionVisibilitySelect", true, false) != null:
		push_error("Legacy interaction visibility dropdown should be removed")
		quit(1)
		return
	if npc_panel.find_child("NPCDialogueHistoryButton", true, false) != null:
		push_error("NPCPanel should no longer contain the dialogue history button")
		quit(1)
		return
	if weapon_button.get_parent() != management_row or order_button.get_parent() != management_row:
		push_error("Equipment and order should share the management row")
		quit(1)
		return
	if dialogue_button.get_parent() != management_row.get_parent() or dialogue_button.get_index() <= management_row.get_index():
		push_error("Dialogue should be a full-width control below the management row")
		quit(1)
		return
	for radio in [public_visibility_radio, private_visibility_radio]:
		for style_name in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			if not radio.get_theme_stylebox(style_name) is StyleBoxEmpty:
				push_error("NPC visibility radio should not draw %s highlight frames" % style_name)
				quit(1)
				return
	if (
		public_visibility_radio.text != "公开"
		or private_visibility_radio.text != "私下"
		or public_visibility_radio.button_group == null
		or public_visibility_radio.button_group != private_visibility_radio.button_group
	):
		push_error("Interaction visibility should use one public/private radio group")
		quit(1)
		return
	private_visibility_radio.button_pressed = true
	await process_frame
	if public_visibility_radio.button_pressed or not private_visibility_radio.button_pressed or str(npc_panel.call("_get_selected_visibility")) != "private":
		push_error("Selecting private should unselect public and submit private visibility")
		quit(1)
		return
	public_visibility_radio.button_pressed = true
	await process_frame
	if not public_visibility_radio.button_pressed or private_visibility_radio.button_pressed or str(npc_panel.call("_get_selected_visibility")) != "local_public":
		push_error("Selecting public should unselect private and submit local_public visibility")
		quit(1)
		return
	for removed_control in ["NPCWeaponSelect", "NPCUnequipWeaponButton", "NPCArmorSelect", "NPCEquipArmorButton", "NPCUnequipArmorButton", "NPCHorseSelect", "NPCAssignHorseButton", "NPCUnassignHorseButton"]:
		if npc_panel.find_child(removed_control, true, false) != null:
			push_error("Legacy equipment control should be removed: %s" % removed_control)
			quit(1)
			return
	if root.get_node_or_null("Main/UI/NPCPanel/PanelContainer/MarginContainer/Content/NPCInteractionButtonRow/NPCAttackButton") != null:
		push_error("Attack button should no longer exist in NPCPanel")
		quit(1)
		return
	if root.get_node_or_null("Main/UI/NPCPanel/PanelContainer/MarginContainer/Content/NPCInteractionButtonRow/NPCRestOrHealButton") != null:
		push_error("Rest/heal button should not exist in NPCPanel")
		quit(1)
		return
	var money_line_edit := money_spin.get_line_edit()
	if money_line_edit == null:
		push_error("Gift money spin line edit is missing")
		quit(1)
		return
	money_line_edit.text = "5wasd7"
	money_line_edit.text_changed.emit(money_line_edit.text)
	await process_frame
	if money_line_edit.text != "57":
		push_error("Gift money input should keep only digits, got: %s" % money_line_edit.text)
		quit(1)
		return
	money_line_edit.grab_focus()
	var letter_event := InputEventKey.new()
	letter_event.pressed = true
	letter_event.keycode = KEY_W
	money_line_edit.gui_input.emit(letter_event)
	await process_frame
	if money_line_edit.has_focus():
		push_error("Gift money input should release focus when a letter key is pressed")
		quit(1)
		return
	money_line_edit.grab_focus()
	_push_left_click(Vector2(5, 5))
	await process_frame
	if money_line_edit.has_focus():
		push_error("Gift money input should release focus after clicking outside it")
		quit(1)
		return

	var dialog_panel := root.get_node_or_null("Main/UI/DialogPanel") as Control
	var dialog_input := root.get_node_or_null("Main/UI/DialogPanel/PanelContainer/MarginContainer/Content/InputRow/DialogInputEdit") as LineEdit
	if dialog_panel == null or dialog_input == null:
		push_error("Dialog input controls are missing")
		quit(1)
		return
	dialog_panel.visible = true
	dialog_input.grab_focus()
	_push_left_click(Vector2(5, 5))
	await process_frame
	if dialog_input.has_focus():
		push_error("Dialog input should release focus after clicking outside it")
		quit(1)
		return
	dialog_panel.visible = false

	var order_panel := root.get_node_or_null("Main/UI/OrderPanel") as Control
	var order_text := root.get_node_or_null("Main/UI/OrderPanel/PanelContainer/MarginContainer/Content/OrderTextEdit") as TextEdit
	if order_panel == null or order_text == null:
		push_error("Order input controls are missing")
		quit(1)
		return
	order_panel.visible = true
	order_text.grab_focus()
	_push_left_click(Vector2(5, 5))
	await process_frame
	if order_text.has_focus():
		push_error("Order text input should release focus after clicking outside it")
		quit(1)
		return
	order_panel.visible = false

	public_visibility_radio.button_pressed = true
	money_spin.value = 5.0
	var money_before: int = int(resource_system.get_resource("money"))
	var npc_money_before: int = int(npc_system.get_npc_state(target_id).get("money", 0))
	gift_button.pressed.emit()
	await process_frame
	if resource_system.get_resource("money") != money_before - 5:
		push_error("Gift money button did not spend global money")
		quit(1)
		return
	if int(npc_system.get_npc_state(target_id).get("money", 0)) != npc_money_before + 5:
		push_error("Gift money button did not update NPC money")
		quit(1)
		return
	if result_label.text.find("已赠予 5 枚第纳尔") < 0:
		push_error("Gift money should show a success result before switching NPC, got: %s" % result_label.text)
		quit(1)
		return
	resource_system.add_resource("wine", 2)
	await process_frame
	wine_spin.value = 1.0
	var global_wine_before: int = int(resource_system.get_resource("wine"))
	var npc_wine_before: int = int(npc_system.get_npc_state(target_id).get("wine", 0))
	gift_wine_button.pressed.emit()
	await process_frame
	if int(resource_system.get_resource("wine")) != global_wine_before - 1:
		push_error("Gift wine button did not spend global wine")
		quit(1)
		return
	if int(npc_system.get_npc_state(target_id).get("wine", 0)) != npc_wine_before + 1:
		push_error("Gift wine button did not update NPC-owned wine")
		quit(1)
		return
	if result_label.text.find("已赠予 1 份酒") < 0 or not wine_label.text.contains("酒：%d" % (npc_wine_before + 1)):
		push_error("Gift wine UI did not refresh result and NPC-owned wine label")
		quit(1)
		return
	npc_system.debug_select_npc(witness_id)
	await process_frame
	if result_label.text != "":
		push_error("NPC interaction result should be cleared when switching NPC, got: %s" % result_label.text)
		quit(1)
		return
	if not _has_event(memory_system.get_npc_daily_events(target_id), "money_given"):
		push_error("Gift money did not enter target NPC event log")
		quit(1)
		return
	if not _has_event(memory_system.get_npc_witness_events(witness_id), "money_given"):
		push_error("Public gift money did not reach same-location witness log")
		quit(1)
		return
	if not _has_event(memory_system.get_npc_daily_events(target_id), "wine_given"):
		push_error("Gift wine did not enter target NPC event log")
		quit(1)
		return
	if not _has_event(memory_system.get_npc_witness_events(witness_id), "wine_given"):
		push_error("Public gift wine did not reach same-location witness log")
		quit(1)
		return

	resource_system.add_resource("item_bow", 1)
	await process_frame
	if not weapon_button.disabled or weapon_button.text != "装备" or weapon_button.tooltip_text != "还未征召，无法配装。":
		push_error("Unrecruited equipment entry should remain visible, disabled, and explain recruitment")
		quit(1)
		return
	if not order_button.disabled or order_button.tooltip_text != "还未征召，无法命令。":
		push_error("Unrecruited order entry should remain visible, disabled, and explain recruitment")
		quit(1)
		return
	var recruitment_hint := "需先说服该人物应征入伍，才能进行这项操作。"
	if strategy_value.tooltip_text != recruitment_hint or strategy_value.modulate.a > 0.5:
		push_error("Unrecruited read-only combat strategy should remain visibly recruitment-gated")
		quit(1)
		return
	var locked_snapshot: Dictionary = npc_panel.debug_get_equipment_window_snapshot()
	if bool(locked_snapshot.get("visible", false)):
		push_error("Disabled unrecruited equipment entry should not open the equipment window")
		quit(1)
		return

	var recruited_target_id := "veteran_deputy_01"
	npc_system.debug_select_npc(recruited_target_id)
	await process_frame
	if weapon_button.disabled:
		push_error("Equipment window entry stayed disabled for recruited NPC")
		quit(1)
		return
	weapon_button.pressed.emit()
	if bool(npc_panel.debug_get_equipment_window_snapshot().get("locked", true)):
		push_error("Recruited work-mode equipment window should be interactive")
		quit(1)
		return
	npc_panel.debug_press_equipment_slot("main_weapon")
	npc_panel.debug_confirm_equipment_unequip()
	npc_panel.debug_press_equipment_slot("main_weapon")
	npc_panel.debug_select_equipment_item("main_weapon", "bow")
	await process_frame
	var target_profile: Dictionary = npc_system.get_npc(recruited_target_id)
	var equipment: Dictionary = target_profile.get("equipment", {})
	var main_weapon: Dictionary = equipment.get("main_weapon", {})
	if str(main_weapon.get("id", "")) != "bow":
		push_error("Weapon button did not assign selected formal weapon")
		quit(1)
		return
	if equipment_label.visible:
		push_error("Legacy equipment summary should remain hidden")
		quit(1)
		return
	if not _has_event(memory_system.get_npc_daily_events(recruited_target_id), "equipment_changed"):
		push_error("Replacing Ada's story sword with the selected bow did not write equipment_changed")
		quit(1)
		return

	npc_system.debug_select_npc(target_id)
	await process_frame

	var dialogue_context: Dictionary = llm_bridge.debug_build_npc_context(target_id)
	var short_memory: Dictionary = dialogue_context.get("short_term_memory", {})
	var experienced: Array = short_memory.get("experienced_events", [])
	if not _summaries_contain(experienced, "守备官给了"):
		push_error("Dialogue NPC context did not include non-dialogue interaction memories: %s" % JSON.stringify(experienced))
		quit(1)
		return

	print("T0704 NPC panel non-dialogue interaction verification passed; attack entry moved to DialogPanel.")
	quit(0)


func _has_event(events: Array, event_type: String) -> bool:
	for raw_event in events:
		var event: Dictionary = raw_event if raw_event is Dictionary else {}
		if str(event.get("type", "")) == event_type:
			return true
	return false


func _summaries_contain(events: Array, text: String) -> bool:
	for raw_event in events:
		var event: Dictionary = raw_event if raw_event is Dictionary else {}
		if str(event.get("summary", "")).contains(text):
			return true
	return false


func _push_left_click(position: Vector2) -> void:
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = position
	root.push_input(click_event)
