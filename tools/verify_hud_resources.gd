extends SceneTree

const LEGACY_HIDDEN_RESOURCE_IDS := ["weapons", "armor", "horse_readiness", "defense_devices"]
const EQUIPMENT_DETAIL_RESOURCE_IDS := [
	"item_sword_shield", "item_polearm", "item_bow", "item_crossbow",
	"item_iron_helmet", "item_mail_chest", "item_iron_bracers", "item_iron_greaves"
]
const DEVICE_DETAIL_RESOURCE_IDS := ["item_wall_ballista", "item_wall_arrow_tower"]
const HIDDEN_RESOURCE_IDS := LEGACY_HIDDEN_RESOURCE_IDS + EQUIPMENT_DETAIL_RESOURCE_IDS + DEVICE_DETAIL_RESOURCE_IDS


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)

	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var hud := root.get_node_or_null("Main/UI/HUD")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var device_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	if hud == null or resource_system == null or equipment_system == null or horse_system == null or device_system == null:
		push_error("HUD resource verification nodes not found")
		quit(1)
		return
	if hud._resource_display_name("future_resource_type") != "未知资源":
		push_error("HUD should not expose an unknown internal resource id")
		quit(1)
		return

	var resource_strip := hud.get_node_or_null("ResourceStrip")
	if resource_strip == null:
		push_error("HUD ResourceStrip not found")
		quit(1)
		return

	for raw_resource_id in resource_system.get_resource_ids():
		var resource_id := str(raw_resource_id)
		var definition: Dictionary = resource_system.get_resource_definition(resource_id)
		if not bool(definition.get("show_in_main_hud", true)):
			if _strip_has_resource_label(resource_strip, resource_id):
				push_error("HUD resource strip should hide resource: %s" % resource_id)
				quit(1)
				return
			continue
		var expected_name := str(resource_system.get_resource_name(resource_id))
		if not _strip_contains(resource_strip, expected_name):
			push_error("HUD resource strip is missing resource: %s" % expected_name)
			quit(1)
			return

	resource_system.add_resource("meal", 2)
	resource_system.add_resource("wine", 1)
	resource_system.add_resource("weapons", 3)
	resource_system.add_resource("armor", 2)
	resource_system.add_resource("defense_devices", 4)
	resource_system.add_resource("horse_readiness", 1)
	var detail_amounts := {
		"item_sword_shield": 4,
		"item_polearm": 4,
		"item_bow": 4,
		"item_crossbow": 4,
		"item_iron_helmet": 4,
		"item_mail_chest": 4,
		"item_iron_bracers": 4,
		"item_iron_greaves": 4,
		"item_wall_ballista": 2,
		"item_wall_arrow_tower": 3
	}
	for resource_id in detail_amounts.keys():
		resource_system.add_resource(str(resource_id), int(detail_amounts[resource_id]))
	await process_frame

	for expected_text in ["餐食 2", "酒 1"]:
		if not _strip_contains(resource_strip, expected_text):
			push_error("HUD did not refresh derived resource text: %s" % expected_text)
			quit(1)
			return
	for hidden_resource_id in HIDDEN_RESOURCE_IDS:
		if _strip_has_resource_label(resource_strip, hidden_resource_id):
			push_error("HUD should not show hidden resource in main strip: %s" % hidden_resource_id)
			quit(1)
			return

	var equipment_button := resource_strip.get_node_or_null("EquipmentDetailButton") as Button
	var devices_button := resource_strip.get_node_or_null("DevicesDetailButton") as Button
	if equipment_button == null or devices_button == null:
		push_error("HUD resource detail buttons are missing")
		quit(1)
		return

	equipment_button.pressed.emit()
	await process_frame
	var detail_panel := hud.get_node_or_null("ResourceDetailPanel") as PanelContainer
	var detail_scroll := hud.get_node_or_null("ResourceDetailPanel/ResourceDetailMargin/ResourceDetailContent/ResourceDetailScroll") as ScrollContainer
	var detail_grid := hud.get_node_or_null("ResourceDetailPanel/ResourceDetailMargin/ResourceDetailContent/ResourceDetailScroll/ResourceDetailGrid") as GridContainer
	if detail_panel == null or detail_scroll == null or detail_grid == null or not detail_panel.visible:
		push_error("Equipment detail panel did not open")
		quit(1)
		return
	if not _panel_opens_below_left_of_button(detail_panel, equipment_button):
		push_error("Equipment detail panel should open below-left of its button. panel=%s button=%s viewport=%s" % [
			str(detail_panel.get_global_rect()),
			str(equipment_button.get_global_rect()),
			str(hud.get_viewport().get_visible_rect().size)
		])
		quit(1)
		return
	if not _panel_inside_viewport(detail_panel, hud._get_usable_viewport_size()):
		push_error("Equipment detail panel should stay inside the viewport")
		quit(1)
		return
	var equipment_snapshot: Dictionary = hud.debug_get_resource_detail_snapshot()
	if str(equipment_snapshot.get("mode", "")) != "equipment":
		push_error("Equipment detail snapshot mode drifted: %s" % equipment_snapshot)
		quit(1)
		return
	if Vector2(equipment_snapshot.get("panel_minimum_size", Vector2.ZERO)).x < 490.0:
		push_error("Equipment detail panel was not expanded: %s" % equipment_snapshot)
		quit(1)
		return
	if int(equipment_snapshot.get("grid_columns", 0)) != 6:
		push_error("Equipment detail grid should use six icon columns: %s" % equipment_snapshot)
		quit(1)
		return
	for resource_id in EQUIPMENT_DETAIL_RESOURCE_IDS:
		var actual_unassigned := _count_snapshot_items(
			equipment_snapshot.get("items", []),
			resource_id,
			false
		)
		if actual_unassigned != int(detail_amounts[resource_id]):
			push_error("Equipment icon count drifted for %s: expected=%d actual=%d" % [
				resource_id,
				int(detail_amounts[resource_id]),
				actual_unassigned
			])
			quit(1)
			return
	if _count_snapshot_items(equipment_snapshot.get("items", []), "item_sword_shield", true) != 1:
		push_error("Initial story sword should appear as one assigned physical item: %s" % equipment_snapshot)
		quit(1)
		return
	if not _snapshot_has_tooltip(equipment_snapshot.get("items", []), "已分配给艾达"):
		push_error("Assigned equipment tooltip should resolve the NPC display name: %s" % equipment_snapshot)
		quit(1)
		return
	if _count_snapshot_category(equipment_snapshot.get("items", []), "horse", false) != 2:
		push_error("Every living unassigned horse should have its own icon: %s" % equipment_snapshot)
		quit(1)
		return
	if hud.get_node_or_null("ResourceDetailPanel/ResourceDetailMargin/ResourceDetailContent/ResourceDetailText") != null:
		push_error("Legacy textual inventory summary should be removed")
		quit(1)
		return
	if not _grid_is_icon_only(detail_grid):
		push_error("Equipment inventory grid should contain icon-only buttons with tooltips")
		quit(1)
		return
	var armor_result: Dictionary = equipment_system.equip_npc_armor(
		"veteran_deputy_01",
		"helmet",
		"iron_helmet",
		"private"
	)
	if not bool(armor_result.get("ok", false)):
		push_error("Could not equip armor for live HUD refresh verification: %s" % armor_result)
		quit(1)
		return
	await process_frame
	await process_frame
	equipment_snapshot = hud.debug_get_resource_detail_snapshot()
	if (
		_count_snapshot_items(equipment_snapshot.get("items", []), "item_iron_helmet", false) != int(detail_amounts["item_iron_helmet"]) - 1
		or _count_snapshot_items(equipment_snapshot.get("items", []), "item_iron_helmet", true) != 1
	):
		push_error("Equipping armor should preserve physical count and refresh its assigned icon: %s" % equipment_snapshot)
		quit(1)
		return
	var horse_result: Dictionary = horse_system.assign_horse_to_npc(
		"veteran_deputy_01",
		"horse_chestnut_wind",
		"private"
	)
	if not bool(horse_result.get("ok", false)):
		push_error("Could not assign horse for live HUD refresh verification: %s" % horse_result)
		quit(1)
		return
	await process_frame
	await process_frame
	equipment_snapshot = hud.debug_get_resource_detail_snapshot()
	if (
		_count_snapshot_category(equipment_snapshot.get("items", []), "horse", true) != 1
		or _count_snapshot_category(equipment_snapshot.get("items", []), "horse", false) != 1
		or not _snapshot_has_tooltip(equipment_snapshot.get("items", []), "已分配给艾达")
	):
		push_error("Horse assignment should refresh one dimmed assigned horse icon: %s" % equipment_snapshot)
		quit(1)
		return
	await process_frame
	if detail_scroll.get_v_scroll_bar().max_value <= detail_scroll.get_v_scroll_bar().page:
		push_error("Equipment inventory should scroll vertically when icons exceed the viewport")
		quit(1)
		return

	devices_button.pressed.emit()
	await process_frame
	if not detail_panel.visible:
		push_error("Device detail panel did not open")
		quit(1)
		return
	var device_snapshot: Dictionary = hud.debug_get_resource_detail_snapshot()
	for resource_id in DEVICE_DETAIL_RESOURCE_IDS:
		if _count_snapshot_items(device_snapshot.get("items", []), resource_id, false) != int(detail_amounts[resource_id]):
			push_error("Device inventory should render one icon per concrete item: %s" % device_snapshot)
			quit(1)
			return
	if not _grid_is_icon_only(detail_grid):
		push_error("Device inventory grid should contain icon-only buttons with tooltips")
		quit(1)
		return
	var deployment: Dictionary = device_system.deploy_device("wall_ballista", "main_hall_slot_03")
	if not bool(deployment.get("ok", false)):
		push_error("Could not deploy device for HUD assignment verification: %s" % deployment)
		quit(1)
		return
	await process_frame
	await process_frame
	device_snapshot = hud.debug_get_resource_detail_snapshot()
	var ballista_total := (
		_count_snapshot_items(device_snapshot.get("items", []), "item_wall_ballista", false)
		+ _count_snapshot_category(device_snapshot.get("items", []), "defense_device", true, "deployed_main_hall_slot_03")
	)
	if ballista_total != int(detail_amounts["item_wall_ballista"]):
		push_error("Deploying a device should change its icon state without changing physical item count: %s" % device_snapshot)
		quit(1)
		return
	if not _snapshot_has_tooltip(device_snapshot.get("items", []), "已部署到主厅屋顶西南器械台"):
		push_error("Deployed device tooltip should resolve the formal slot name: %s" % device_snapshot)
		quit(1)
		return
	if not _panel_opens_below_left_of_button(detail_panel, devices_button):
		push_error("Device detail panel should open below-left of its button")
		quit(1)
		return
	if not _panel_inside_viewport(detail_panel, hud._get_usable_viewport_size()):
		push_error("Device detail panel should stay inside the viewport")
		quit(1)
		return

	print("HUD resource inventory verification passed.")
	quit(0)


func _strip_contains(resource_strip: Node, expected_text: String) -> bool:
	for child in resource_strip.get_children():
		if child is Label and str(child.text).contains(expected_text):
			return true
	return false


func _strip_has_resource_label(resource_strip: Node, resource_id: String) -> bool:
	var expected_node_name := "%sResourceLabel" % resource_id.to_pascal_case()
	for child in resource_strip.get_children():
		if child is Label and str(child.name) == expected_node_name:
			return true
	return false


func _count_snapshot_items(items: Variant, item_id: String, assigned: bool) -> int:
	var count := 0
	if not items is Array:
		return count
	for raw_item in items:
		var item: Dictionary = raw_item if raw_item is Dictionary else {}
		if str(item.get("item_id", "")) == item_id and bool(item.get("assigned", false)) == assigned:
			count += 1
	return count


func _count_snapshot_category(
	items: Variant,
	category: String,
	assigned: bool,
	item_id: String = ""
) -> int:
	var count := 0
	if not items is Array:
		return count
	for raw_item in items:
		var item: Dictionary = raw_item if raw_item is Dictionary else {}
		if str(item.get("category", "")) != category or bool(item.get("assigned", false)) != assigned:
			continue
		if not item_id.is_empty() and str(item.get("item_id", "")) != item_id:
			continue
		count += 1
	return count


func _snapshot_has_tooltip(items: Variant, tooltip: String) -> bool:
	if not items is Array:
		return false
	for raw_item in items:
		if raw_item is Dictionary and str((raw_item as Dictionary).get("tooltip", "")) == tooltip:
			return true
	return false


func _grid_is_icon_only(grid: GridContainer) -> bool:
	for child in grid.get_children():
		if not child is Button:
			return false
		var button := child as Button
		if not button.text.is_empty() or button.icon == null or button.tooltip_text.is_empty():
			return false
		var item: Dictionary = button.get_meta("inventory_item", {})
		if bool(item.get("assigned", false)) and button.self_modulate == Color.WHITE:
			return false
		if not bool(item.get("assigned", false)) and button.self_modulate != Color.WHITE:
			return false
	return true


func _panel_opens_below_left_of_button(panel: Control, button: Control) -> bool:
	var panel_rect := panel.get_global_rect()
	var button_rect := button.get_global_rect()
	var expected_y := button_rect.position.y + button_rect.size.y
	return (
		absf(panel_rect.position.x - button_rect.position.x) <= 2.0
		and panel_rect.position.y >= expected_y
		and panel_rect.position.y <= expected_y + 12.0
	)


func _panel_inside_viewport(panel: Control, viewport_size: Vector2) -> bool:
	var panel_rect := panel.get_global_rect()
	return (
		panel_rect.position.x >= 0.0
		and panel_rect.position.y >= 0.0
		and panel_rect.position.x + panel_rect.size.x <= viewport_size.x + 1.0
		and panel_rect.position.y + panel_rect.size.y <= viewport_size.y + 1.0
	)
