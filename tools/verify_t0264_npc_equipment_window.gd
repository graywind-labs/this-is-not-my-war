extends SceneTree

const SLOT_ORDER := ["main_weapon", "helmet", "chest", "bracers", "greaves", "mount"]


func _init() -> void:
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
	for armor_id in equipment_system.get_armor_ids():
		var armor_def: Dictionary = equipment_system.get_armor_def(str(armor_id))
		resource_system.add_resource(str(armor_def.get("source_resource_id", "")), 1)
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
	var window := root.get_node_or_null("Main/UI/NPCEquipmentWindow") as Control
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
	if _tree_contains_text(window, "正式模型截图图标") or _tree_contains_text(window, "点击装配"):
		_fail("Equipment picker still contains the removed explanatory sentence")
		return

	var initial_equipment: Dictionary = npc_system.get_npc(npc_id).get("equipment", {})
	var initial_weapon_id := str((initial_equipment.get("main_weapon", {}) as Dictionary).get("id", ""))
	var initial_weapon_resource := str(equipment_system.get_weapon_def(initial_weapon_id).get("source_resource_id", ""))
	var initial_weapon_stock := int(resource_system.get_resource(initial_weapon_resource))
	var event_count_before: int = memory_system.get_npc_daily_events(npc_id).size()
	var confirm_snapshot: Dictionary = panel.debug_press_equipment_slot("main_weapon")
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


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
