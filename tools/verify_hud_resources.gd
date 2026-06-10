extends SceneTree

const DETAIL_PANEL_RESOURCE_IDS := ["weapons", "armor", "horse_readiness", "defense_devices"]


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
		if DETAIL_PANEL_RESOURCE_IDS.has(resource_id):
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
	await process_frame

	for expected_text in ["餐食 2", "酒 1"]:
		if not _strip_contains(resource_strip, expected_text):
			push_error("HUD did not refresh derived resource text: %s" % expected_text)
			quit(1)
			return
	for redundant_text in ["武器 3", "盔甲 2", "工程器械 4", "马匹整备 1"]:
		if _strip_contains(resource_strip, redundant_text):
			push_error("HUD should not duplicate detail-panel resource in main strip: %s" % redundant_text)
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
	if not detail_text.text.contains("库存：武器 3 / 盔甲 2 / 马匹整备 1"):
		push_error("Equipment detail panel did not show aggregate inventory: %s" % detail_text.text)
		quit(1)
		return
	if not detail_text.text.contains("剑盾") or not detail_text.text.contains("锁子甲") or not detail_text.text.contains("整备马匹"):
		push_error("Equipment detail panel did not show equipment definitions: %s" % detail_text.text)
		quit(1)
		return
	if detail_text.text.contains("短剑"):
		push_error("Equipment detail panel should not show removed short sword definition: %s" % detail_text.text)
		quit(1)
		return

	devices_button.pressed.emit()
	await process_frame
	if not detail_panel.visible or not detail_text.text.contains("工程器械库存：4"):
		push_error("Device detail panel did not show defense device inventory: %s" % detail_text.text)
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
