extends SceneTree

const ALERT_TOOLTIP := "未选择制造物品"
const BUILDING_IDS := ["blacksmith", "workshop"]


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	root.add_child(main_scene.instantiate())
	await process_frame
	await process_frame

	var presenter := root.get_node_or_null("Main/UI/CraftingTargetAlerts") as Control
	var crafting_system := root.get_node_or_null("Main/Systems/CraftingSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var building_panel := root.get_node_or_null("Main/UI/BuildingPanel") as Control
	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	if presenter == null or crafting_system == null or building_system == null or building_panel == null or camera == null:
		_fail("Required crafting alert integration nodes are missing")
		return
	presenter.debug_set_viewport_size_override(Vector2(1152.0, 648.0))
	await process_frame

	if presenter.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_fail("Full-screen alert presenter must not block unrelated world input")
		return

	for building_id in BUILDING_IDS:
		var snapshot: Dictionary = presenter.debug_get_alert_snapshot(building_id)
		if snapshot.is_empty():
			_fail("Missing crafting alert snapshot for %s" % building_id)
			return
		if not bool(snapshot.get("needs_alert", false)) or not bool(snapshot.get("visible", false)):
			_fail("Empty crafting target should show its alert: %s" % JSON.stringify(snapshot))
			return
		if str(snapshot.get("text", "")) != "!" or str(snapshot.get("tooltip", "")) != ALERT_TOOLTIP:
			_fail("Crafting alert text or tooltip contract mismatch: %s" % JSON.stringify(snapshot))
			return
		var alert := presenter.get_node_or_null("%sCraftingTargetAlert" % building_id.to_pascal_case()) as Button
		var label := root.get_node_or_null(str(snapshot.get("label_path", ""))) as Label3D
		if alert == null or label == null:
			_fail("Crafting alert or building label is missing for %s" % building_id)
			return
		var font_color := alert.get_theme_color("font_color")
		if font_color.r <= font_color.g or font_color.r <= font_color.b:
			_fail("Crafting alert is not visually red for %s: %s" % [building_id, font_color])
			return
		var label_screen_position := camera.unproject_position(label.global_position)
		if alert.position.y + alert.size.y * alert.scale.y * 0.5 >= label_screen_position.y:
			_fail("Crafting alert is not positioned above the %s name label: alert=%s size=%s label=%s" % [
				building_id, alert.position, alert.size, label_screen_position
			])
			return

	var blacksmith_alert := presenter.get_node_or_null("BlacksmithCraftingTargetAlert") as Button
	if blacksmith_alert == null:
		_fail("Blacksmith alert button is missing")
		return
	var alert_click_position := blacksmith_alert.position + blacksmith_alert.size * blacksmith_alert.scale * 0.5
	var motion := InputEventMouseMotion.new()
	motion.position = alert_click_position
	motion.global_position = alert_click_position
	root.push_input(motion)
	await process_frame
	if root.gui_get_hovered_control() != blacksmith_alert:
		_fail("Mouse hover did not resolve to the blacksmith crafting alert button")
		return
	var press := InputEventMouseButton.new()
	press.position = alert_click_position
	press.global_position = alert_click_position
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press)
	var release := InputEventMouseButton.new()
	release.position = alert_click_position
	release.global_position = alert_click_position
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	root.push_input(release)
	await process_frame
	var panel_snapshot: Dictionary = building_panel.debug_get_crafting_panel_snapshot()
	if not building_panel.visible or str(panel_snapshot.get("building_id", "")) != "blacksmith":
		_fail("Clicking the blacksmith alert did not open the matching building panel")
		return
	if str(building_system.get_selected_building_id()) != "blacksmith":
		_fail("Crafting alert click did not use BuildingSystem selection state")
		return

	var selected: Dictionary = crafting_system.set_target("blacksmith", "craft_iron_helmet", false)
	if not bool(selected.get("ok", false)):
		_fail("Could not select blacksmith fixture target: %s" % JSON.stringify(selected))
		return
	await process_frame
	var hidden_snapshot: Dictionary = presenter.debug_get_alert_snapshot("blacksmith")
	var workshop_snapshot: Dictionary = presenter.debug_get_alert_snapshot("workshop")
	if bool(hidden_snapshot.get("needs_alert", true)) or bool(hidden_snapshot.get("visible", true)):
		_fail("Selecting a target did not hide the matching alert: %s" % JSON.stringify(hidden_snapshot))
		return
	if not bool(workshop_snapshot.get("needs_alert", false)) or not bool(workshop_snapshot.get("visible", false)):
		_fail("Selecting the blacksmith target incorrectly changed the workshop alert")
		return

	var cleared: Dictionary = crafting_system.set_target("blacksmith", "", false)
	if not bool(cleared.get("ok", false)):
		_fail("Could not clear blacksmith fixture target: %s" % JSON.stringify(cleared))
		return
	await process_frame
	var restored_snapshot: Dictionary = presenter.debug_get_alert_snapshot("blacksmith")
	if not bool(restored_snapshot.get("needs_alert", false)) or not bool(restored_snapshot.get("visible", false)):
		_fail("Clearing the target did not restore the alert: %s" % JSON.stringify(restored_snapshot))
		return

	print("Crafting target alert verification passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
