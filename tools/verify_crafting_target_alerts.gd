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
		if not bool(snapshot.get("needs_alert", false)):
			_fail("Empty crafting target should require its alert: %s" % JSON.stringify(snapshot))
			return
		if not str(snapshot.get("label_path", "")).contains("/FormalStationLayout/BuildingRoots/"):
			_fail("Crafting alert is not anchored to the formal building label: %s" % JSON.stringify(snapshot))
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
		var label_on_screen := Rect2(Vector2.ZERO, Vector2(1152.0, 648.0)).has_point(label_screen_position)
		if alert.visible != label_on_screen:
			_fail("Crafting alert visibility does not follow its formal label: %s" % JSON.stringify(snapshot))
			return
		if label_on_screen and alert.position.y + alert.size.y * alert.scale.y * 0.5 >= label_screen_position.y:
			_fail("Crafting alert is not positioned above the %s name label: alert=%s size=%s label=%s" % [
				building_id, alert.position, alert.size, label_screen_position
			])
			return

	var blacksmith_alert := presenter.get_node_or_null("BlacksmithCraftingTargetAlert") as Button
	if blacksmith_alert == null:
		_fail("Blacksmith alert button is missing")
		return
	# Headless viewport mouse hit-testing is platform-dependent. The geometry and
	# visibility contract is asserted above; emit the same Button signal here to
	# verify the stable semantic click path into BuildingSystem and BuildingPanel.
	blacksmith_alert.pressed.emit()
	for _frame in range(8):
		await process_frame
	var panel_snapshot: Dictionary = building_panel.debug_get_crafting_panel_snapshot()
	if not building_panel.visible or str(panel_snapshot.get("building_id", "")) != "blacksmith":
		_fail("Clicking the blacksmith alert did not open the matching building panel")
		return
	if str(building_system.get_selected_building_id()) != "blacksmith":
		_fail("Crafting alert click did not use BuildingSystem selection state")
		return
	if not bool(panel_snapshot.get("target_popup_visible", false)):
		_fail("Clicking the blacksmith alert did not expand the crafting target popup: %s" % JSON.stringify(panel_snapshot))
		return
	if not bool(panel_snapshot.get("missing_target_alert_visible", false)):
		_fail("Empty crafting target does not show the matching panel alert: %s" % JSON.stringify(panel_snapshot))
		return
	var target_select := building_panel.get_node_or_null("%CraftingTargetSelect") as OptionButton
	if target_select == null:
		target_select = building_panel.find_child("CraftingTargetSelect", true, false) as OptionButton
	var panel_alert := building_panel.find_child("CraftingTargetMissingAlert", true, false) as Button
	if target_select == null or panel_alert == null:
		_fail("Crafting target selector or its missing-target alert is absent")
		return
	if panel_alert.text != "!" or panel_alert.tooltip_text != ALERT_TOOLTIP:
		_fail("Panel crafting alert text or tooltip does not match the world alert")
		return
	var panel_alert_color := panel_alert.get_theme_color("font_color")
	if panel_alert_color.r <= panel_alert_color.g or panel_alert_color.r <= panel_alert_color.b:
		_fail("Panel crafting alert is not visually red: %s" % panel_alert_color)
		return
	target_select.get_popup().hide()

	var selected: Dictionary = crafting_system.set_target("blacksmith", "craft_iron_helmet", false)
	if not bool(selected.get("ok", false)):
		_fail("Could not select blacksmith fixture target: %s" % JSON.stringify(selected))
		return
	await process_frame
	panel_snapshot = building_panel.debug_get_crafting_panel_snapshot()
	var hidden_snapshot: Dictionary = presenter.debug_get_alert_snapshot("blacksmith")
	var workshop_snapshot: Dictionary = presenter.debug_get_alert_snapshot("workshop")
	if bool(hidden_snapshot.get("needs_alert", true)) or bool(hidden_snapshot.get("visible", true)):
		_fail("Selecting a target did not hide the matching alert: %s" % JSON.stringify(hidden_snapshot))
		return
	if not bool(workshop_snapshot.get("needs_alert", false)):
		_fail("Selecting the blacksmith target incorrectly changed the workshop alert")
		return
	if bool(panel_snapshot.get("missing_target_alert_visible", true)):
		_fail("Selecting a target did not hide the panel alert: %s" % JSON.stringify(panel_snapshot))
		return

	var cleared: Dictionary = crafting_system.set_target("blacksmith", "", false)
	if not bool(cleared.get("ok", false)):
		_fail("Could not clear blacksmith fixture target: %s" % JSON.stringify(cleared))
		return
	await process_frame
	var restored_snapshot: Dictionary = presenter.debug_get_alert_snapshot("blacksmith")
	if not bool(restored_snapshot.get("needs_alert", false)):
		_fail("Clearing the target did not restore the alert: %s" % JSON.stringify(restored_snapshot))
		return
	panel_snapshot = building_panel.debug_get_crafting_panel_snapshot()
	if not bool(panel_snapshot.get("missing_target_alert_visible", false)):
		_fail("Clearing the target did not restore the panel alert: %s" % JSON.stringify(panel_snapshot))
		return

	var workshop_alert := presenter.get_node_or_null("WorkshopCraftingTargetAlert") as Button
	if workshop_alert == null:
		_fail("Workshop alert button is missing")
		return
	workshop_alert.pressed.emit()
	for _frame in range(8):
		await process_frame
	panel_snapshot = building_panel.debug_get_crafting_panel_snapshot()
	if (
		str(building_system.get_selected_building_id()) != "workshop"
		or str(panel_snapshot.get("building_id", "")) != "workshop"
		or not bool(panel_snapshot.get("target_popup_visible", false))
	):
		_fail("Clicking the workshop alert did not select it and expand its target popup: %s" % JSON.stringify(panel_snapshot))
		return

	print("Crafting target alert verification passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
