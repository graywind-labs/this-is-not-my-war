extends SceneTree

const LEGACY_HIDDEN_RESOURCE_IDS := ["weapons", "armor", "horse_readiness", "defense_devices"]
const EQUIPMENT_DETAIL_RESOURCE_IDS := [
	"item_sword_shield", "item_polearm", "item_bow", "item_crossbow",
	"item_iron_helmet", "item_mail_chest", "item_iron_bracers", "item_iron_greaves",
	"item_arrow_bundle"
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
	if hud == null or resource_system == null:
		push_error("HUD resource verification nodes not found")
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
		"item_sword_shield": 1,
		"item_polearm": 2,
		"item_bow": 3,
		"item_crossbow": 4,
		"item_iron_helmet": 1,
		"item_mail_chest": 2,
		"item_iron_bracers": 3,
		"item_iron_greaves": 4,
		"item_arrow_bundle": 5,
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
	var detail_text := hud.get_node_or_null("ResourceDetailPanel/ResourceDetailMargin/ResourceDetailContent/ResourceDetailText") as RichTextLabel
	if detail_panel == null or detail_text == null or not detail_panel.visible:
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
	for resource_id in EQUIPMENT_DETAIL_RESOURCE_IDS:
		var expected_detail := "%s %d" % [
			str(resource_system.get_resource_name(resource_id)),
			int(detail_amounts[resource_id])
		]
		if not detail_text.text.contains(expected_detail):
			push_error("Equipment detail panel is missing exact inventory %s: %s" % [expected_detail, detail_text.text])
			quit(1)
			return
	if not detail_text.text.contains("马厩：2 匹（成年 2 / 小马 0）"):
		push_error("Equipment detail panel did not show real stable horse counts: %s" % detail_text.text)
		quit(1)
		return
	for legacy_text in ["武器 3", "盔甲 2", "马匹整备 1"]:
		if detail_text.text.contains(legacy_text):
			push_error("Equipment detail panel still shows deprecated aggregate inventory: %s" % legacy_text)
			quit(1)
			return
	if detail_text.text.contains("短剑"):
		push_error("Equipment detail panel should not show removed short sword definition: %s" % detail_text.text)
		quit(1)
		return

	devices_button.pressed.emit()
	await process_frame
	if not detail_panel.visible:
		push_error("Device detail panel did not open")
		quit(1)
		return
	for resource_id in DEVICE_DETAIL_RESOURCE_IDS:
		var expected_device_detail := "%s %d" % [
			str(resource_system.get_resource_name(resource_id)),
			int(detail_amounts[resource_id])
		]
		if not detail_text.text.contains(expected_device_detail):
			push_error("Device detail panel is missing exact inventory %s: %s" % [expected_device_detail, detail_text.text])
			quit(1)
			return
	if detail_text.text.contains("工程器械 4"):
		push_error("Device detail panel still shows deprecated defense_devices inventory: %s" % detail_text.text)
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
