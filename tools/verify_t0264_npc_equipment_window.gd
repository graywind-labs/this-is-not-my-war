extends SceneTree

const SLOT_ORDER := ["main_weapon", "helmet", "chest", "bracers", "greaves", "mount"]


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn could not be loaded")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var panel := root.get_node_or_null("Main/UI/NPCPanel")
	if [npc_system, equipment_system, resource_system, memory_system, horse_system, panel].has(null):
		_fail("T0264 required systems are missing")
		return

	var npc_id := "veteran_deputy_01"
	resource_system.add_resource("item_polearm", 1)
	npc_system.debug_select_npc(npc_id)
	await process_frame
	await process_frame

	var equipment_button := panel.find_child("NPCGiveWeaponButton", true, false) as Button
	var summary := panel.find_child("NPCEquipmentLabel", true, false) as Label
	if equipment_button == null or equipment_button.text != "装备" or equipment_button.disabled:
		_fail("NPCPanel must expose one enabled equipment button")
		return
	if summary == null or summary.visible:
		_fail("Legacy equipment summary must be hidden")
		return
	for removed_name in [
		"NPCWeaponRow", "NPCWeaponSelect", "NPCUnequipWeaponButton",
		"NPCArmorRow", "NPCArmorSelect", "NPCEquipArmorButton", "NPCUnequipArmorButton",
		"NPCHorseAssignmentRow", "NPCHorseSelect", "NPCAssignHorseButton", "NPCUnassignHorseButton",
	]:
		if panel.find_child(removed_name, true, false) != null:
			_fail("Legacy equipment control still exists: %s" % removed_name)
			return

	var opened: Dictionary = panel.debug_toggle_equipment_window()
	if not bool(opened.get("visible", false)) or bool(opened.get("summary_visible", true)):
		_fail("Equipment window did not open: %s" % JSON.stringify(opened))
		return
	var slots: Dictionary = opened.get("slots", {})
	for slot in SLOT_ORDER:
		if not slots.has(slot) or not bool((slots[slot] as Dictionary).get("clickable", false)):
			_fail("Equipment slot is missing or cannot receive clicks: %s" % slot)
			return
	var window := root.get_node_or_null("Main/UI/NPCPanel/NPCEquipmentWindow") as Control
	var portrait := panel.find_child("NPCPortraitView", true, false) as Control
	if window == null or portrait == null or window.global_position.y + 1.0 < portrait.get_global_rect().end.y:
		_fail("Equipment window is not placed below the portrait: window=%s portrait=%s panel=%s" % [
			window.get_global_rect() if window != null else Rect2(),
			portrait.get_global_rect() if portrait != null else Rect2(),
			panel.get_global_rect(),
		])
		return
	var info_panel := panel.get_node_or_null("PanelContainer") as Control
	if info_panel == null or (root.size.x >= 900 and window.get_global_rect().end.x > info_panel.get_global_rect().position.x + 1.0):
		_fail("Equipment window overlaps the NPC information panel: equipment=%s info=%s portrait=%s" % [window.get_global_rect(), info_panel.get_global_rect() if info_panel != null else Rect2(), portrait.get_global_rect()])
		return
	if window.find_child("TwoHeadSilhouette", true, false) == null:
		_fail("The shared two-head silhouette is missing")
		return
	for slot in SLOT_ORDER:
		var slot_button := window.get_slot_button(slot) as Button
		if slot_button == null or not is_equal_approx(slot_button.size.x, slot_button.size.y):
			_fail("Equipment slot must use a square 1:1 frame: %s size=%s" % [slot, slot_button.size if slot_button != null else Vector2.ZERO])
			return
		if slot_button.get_theme_constant("icon_max_width") < int(slot_button.size.x):
			_fail("Equipment icon cannot fill its square slot: %s" % slot)
			return
		if not _button_has_compact_frame(slot_button, 0.0, 0):
			_fail("Equipment slot still has content padding or border: %s" % slot)
			return
	if _tree_contains_text(window, "正式模型截图图标") or _tree_contains_text(window, "点击装配"):
		_fail("Equipment picker still contains the removed explanatory sentence")
		return
	if int(resource_system.get_resource("item_iron_helmet")) != 0:
		_fail("Zero-stock click fixture unexpectedly has a helmet")
		return
	window.global_position = Vector2(8.0, window.global_position.y)
	var helmet_button := window.get_slot_button("helmet") as Button
	await _activate_control(helmet_button)
	var zero_stock_snapshot: Dictionary = panel.debug_get_equipment_window_snapshot()
	if (
		not bool(zero_stock_snapshot.get("picker_visible", false))
		or str(zero_stock_snapshot.get("picker_slot", "")) != "helmet"
		or not _tree_contains_text(window, "暂无可用装备。")
	):
		_fail("A recruited NPC zero-stock slot did not open the empty picker: %s" % JSON.stringify(zero_stock_snapshot))
		return
	var picker_rect: Rect2 = zero_stock_snapshot.get("picker_global_rect", Rect2())
	if picker_rect.position.x < window.get_global_rect().end.x or picker_rect.position.y < 0.0:
		_fail("Equipment picker did not flip right when the equipment window touched the left edge: picker=%s window=%s" % [picker_rect, window.get_global_rect()])
		return
	window.close_picker()
	panel._layout_equipment_window()
	for armor_id in equipment_system.get_armor_ids():
		var armor_def: Dictionary = equipment_system.get_armor_def(str(armor_id))
		resource_system.add_resource(str(armor_def.get("source_resource_id", "")), 1)

	var initial_equipment: Dictionary = npc_system.get_npc(npc_id).get("equipment", {})
	var initial_weapon_id := str((initial_equipment.get("main_weapon", {}) as Dictionary).get("id", ""))
	var initial_weapon_resource := str(equipment_system.get_weapon_def(initial_weapon_id).get("source_resource_id", ""))
	var initial_weapon_stock := int(resource_system.get_resource(initial_weapon_resource))
	var event_count_before: int = memory_system.get_npc_daily_events(npc_id).size()
	var main_weapon_button := window.get_slot_button("main_weapon") as Button
	await _activate_control(main_weapon_button)
	var confirm_snapshot: Dictionary = panel.debug_get_equipment_window_snapshot()
	confirm_snapshot["confirm_visible"] = (root.find_child("NPCEquipmentUnequipConfirm", true, false) as ConfirmationDialog).visible
	if not bool(confirm_snapshot.get("confirm_visible", false)) or str(confirm_snapshot.get("pending_unequip_slot", "")) != "main_weapon":
		_fail("Occupied slot did not ask for confirmation")
		return
	var confirm := root.find_child("NPCEquipmentUnequipConfirm", true, false) as ConfirmationDialog
	confirm.canceled.emit()
	confirm.hide()
	await process_frame
	if str(npc_system.get_npc(npc_id).get("equipment", {}).get("main_weapon", {}).get("id", "")) != initial_weapon_id:
		_fail("Choosing No changed the equipped weapon")
		return
	if int(resource_system.get_resource(initial_weapon_resource)) != initial_weapon_stock or memory_system.get_npc_daily_events(npc_id).size() != event_count_before:
		_fail("Choosing No changed inventory or events")
		return

	panel.debug_press_equipment_slot("main_weapon")
	panel.debug_confirm_equipment_unequip()
	await process_frame
	if not (npc_system.get_npc(npc_id).get("equipment", {}).get("main_weapon", {}) as Dictionary).is_empty():
		_fail("Choosing Yes did not clear the occupied weapon slot")
		return
	if int(resource_system.get_resource(initial_weapon_resource)) != initial_weapon_stock + 1:
		_fail("Choosing Yes did not return the exact weapon inventory")
		return
	if memory_system.get_npc_daily_events(npc_id).size() != event_count_before + 1:
		_fail("Choosing Yes did not preserve the original unequip event path")
		return

	var empty_snapshot: Dictionary = panel.debug_press_equipment_slot("main_weapon")
	if not bool(empty_snapshot.get("picker_visible", false)) or str(empty_snapshot.get("picker_slot", "")) != "main_weapon":
		_fail("Empty weapon slot did not open its picker")
		return
	var picker_grid := window.find_child("EquipmentPickerGrid", true, false) as GridContainer
	if picker_grid == null or picker_grid.columns != 3:
		_fail("Equipment picker must use a three-column HUD-style icon grid")
		return
	var picker_buttons: Array[Button] = []
	for child in picker_grid.get_children():
		if child is Button:
			picker_buttons.append(child as Button)
	if picker_buttons.is_empty() or picker_buttons.size() != int(empty_snapshot.get("picker_item_count", -1)):
		_fail("Equipment picker icon count does not match available items: %s" % JSON.stringify(empty_snapshot))
		return
	for picker_button in picker_buttons:
		var item: Dictionary = picker_button.get_meta("equipment_picker_item", {})
		var expected_name := str(item.get("name", item.get("horse_name", "装备")))
		if (
			not picker_button.text.is_empty()
			or picker_button.icon == null
			or picker_button.tooltip_text != expected_name
			or picker_button.tooltip_text.contains("已分配")
			or picker_button.tooltip_text.contains("未分配")
		):
			_fail("Picker candidate must be one icon with a name-only tooltip: %s" % picker_button.name)
			return
		if not _button_has_compact_frame(picker_button, 1.0, 1):
			_fail("Picker candidate does not match HUD compact icon framing: %s" % picker_button.name)
			return
	var polearm_before := int(resource_system.get_resource("item_polearm"))
	panel.debug_select_equipment_item("main_weapon", "polearm")
	await process_frame
	if str(npc_system.get_npc(npc_id).get("equipment", {}).get("main_weapon", {}).get("id", "")) != "polearm":
		_fail("Picker did not equip the selected concrete weapon")
		return
	if int(resource_system.get_resource("item_polearm")) != polearm_before - 1:
		_fail("Picker did not consume concrete weapon inventory")
		return

	for slot in ["helmet", "chest", "bracers", "greaves"]:
		var ids: Array = equipment_system.get_armor_ids(slot)
		if ids.is_empty():
			_fail("No configured armor for %s" % slot)
			return
		var armor_id := str(ids[0])
		panel.debug_press_equipment_slot(slot)
		panel.debug_select_equipment_item(slot, armor_id)
		await process_frame
		if str(npc_system.get_npc(npc_id).get("equipment", {}).get(slot, {}).get("id", "")) != armor_id:
			_fail("Picker did not equip %s" % slot)
			return
		for raw_candidate in (panel._build_equipment_options(npc_system.get_npc(npc_id)).get(slot, []) as Array):
			if raw_candidate is Dictionary and str((raw_candidate as Dictionary).get("id", "")) == armor_id:
				_fail("Assigned armor still appears in the available-only picker: %s" % armor_id)
				return

	var available_horses: Array = horse_system.get_available_horses_for_npc(npc_id)
	if available_horses.is_empty():
		_fail("No available adult horse for mount slot")
		return
	var horse_id := str((available_horses[0] as Dictionary).get("horse_id", ""))
	panel.debug_press_equipment_slot("mount")
	panel.debug_select_equipment_item("mount", horse_id)
	await process_frame
	if str(npc_system.get_npc(npc_id).get("equipment", {}).get("mount", {}).get("horse_id", "")) != horse_id:
		_fail("Mount picker did not use the formal horse assignment path")
		return
	for raw_candidate in (panel._build_equipment_options(npc_system.get_npc(npc_id)).get("mount", []) as Array):
		if raw_candidate is Dictionary and str((raw_candidate as Dictionary).get("horse_id", "")) == horse_id:
			_fail("Assigned horse still appears in the available-only picker: %s" % horse_id)
			return

	var mode_result: Dictionary = npc_system.set_npc_behavior_mode(npc_id, "combat", "t0264_lock_test")
	if not bool(mode_result.get("ok", false)):
		_fail("Could not enter combat lock state: %s" % JSON.stringify(mode_result))
		return
	await process_frame
	panel.show_npc(npc_id)
	await process_frame
	var locked_snapshot: Dictionary = panel.debug_get_equipment_window_snapshot()
	if not bool(locked_snapshot.get("visible", false)) or not bool(locked_snapshot.get("locked", false)):
		_fail("Equipment window should remain open and lock during combat")
		return
	var locked_equipment := (npc_system.get_npc(npc_id).get("equipment", {}) as Dictionary).duplicate(true)
	var locked_stock := int(resource_system.get_resource("item_polearm"))
	var locked_events: int = memory_system.get_npc_daily_events(npc_id).size()
	var locked_press: Dictionary = panel.debug_press_equipment_slot("main_weapon")
	if not bool(locked_press.get("notice_visible", false)):
		_fail("Locked slot click did not show the unavailable notice")
		return
	if npc_system.get_npc(npc_id).get("equipment", {}) != locked_equipment:
		_fail("Locked slot click changed equipment")
		return
	if int(resource_system.get_resource("item_polearm")) != locked_stock or memory_system.get_npc_daily_events(npc_id).size() != locked_events:
		_fail("Locked slot click changed inventory or events")
		return

	var unrecruited_id := "cook_01"
	npc_system.debug_select_npc(unrecruited_id)
	await process_frame
	await process_frame
	var unrecruited_window_snapshot: Dictionary = panel.debug_get_equipment_window_snapshot()
	if not bool(unrecruited_window_snapshot.get("visible", false)) or not bool(unrecruited_window_snapshot.get("locked", false)):
		_fail("Equipment window should remain visible and locked for an unrecruited NPC")
		return
	await _activate_control(window.get_slot_button("helmet") as Button)
	var unrecruited_press: Dictionary = panel.debug_get_equipment_window_snapshot()
	var notice := root.find_child("NPCEquipmentNotice", true, false) as AcceptDialog
	if (
		not notice.visible
		or notice.dialog_text != "尚未入伍，不能装备。"
		or bool(unrecruited_press.get("picker_visible", false))
		or (root.find_child("NPCEquipmentUnequipConfirm", true, false) as ConfirmationDialog).visible
	):
		_fail("Unrecruited slot click should only show the recruitment notice: %s" % JSON.stringify(unrecruited_press))
		return

	print("T0264 NPC equipment window verification passed.")
	quit(0)


func _tree_contains_text(node: Node, needle: String) -> bool:
	if node is Label and (node as Label).text.contains(needle):
		return true
	if node is Button and (node as Button).text.contains(needle):
		return true
	for child in node.get_children():
		if _tree_contains_text(child, needle):
			return true
	return false


func _activate_control(control: Control) -> void:
	if control == null:
		return
	if control is Button:
		(control as Button).pressed.emit()
	await process_frame


func _button_has_compact_frame(button: Button, expected_margin: float, expected_border: int) -> bool:
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style := button.get_theme_stylebox(state)
		if style == null:
			continue
		if (
			not is_equal_approx(style.content_margin_left, expected_margin)
			or not is_equal_approx(style.content_margin_top, expected_margin)
			or not is_equal_approx(style.content_margin_right, expected_margin)
			or not is_equal_approx(style.content_margin_bottom, expected_margin)
		):
			return false
		if style is StyleBoxFlat:
			var flat := style as StyleBoxFlat
			if (
				flat.border_width_left != expected_border
				or flat.border_width_top != expected_border
				or flat.border_width_right != expected_border
				or flat.border_width_bottom != expected_border
			):
				return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
