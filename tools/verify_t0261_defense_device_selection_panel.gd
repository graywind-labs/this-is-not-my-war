extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")

var _failures: Array[String] = []
var _clicked_ids: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in 6:
		await physics_frame
		await process_frame

	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var device_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var presenter := root.get_node_or_null("Main/WorldRoot/Station/DefenseDevices")
	var panel := root.get_node_or_null("Main/UI/DefenseDevicePanel") as Control
	var building_panel := root.get_node_or_null("Main/UI/BuildingPanel") as Control
	var indicator := root.get_node_or_null("Main/WorldRoot/Station/Effects/AttackRangeIndicator")
	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	var event_bus := root.get_node_or_null("EventBus")
	_check(
		building_system != null and device_system != null and resource_system != null
		and presenter != null and panel != null and building_panel != null
		and indicator != null and camera != null and event_bus != null,
		"T0261 runtime dependencies are missing"
	)
	if not _failures.is_empty():
		_finish()
		return
	event_bus.defense_device_clicked.connect(_on_defense_device_clicked)

	_set_building_level(building_system, "wall", 1)
	_set_building_level(building_system, "main_hall", 1)
	resource_system.add_resource("item_wall_ballista", 2)
	var wall_result: Dictionary = device_system.deploy_device("wall_ballista", "wall_slot_01")
	var hall_result: Dictionary = device_system.deploy_device("wall_ballista", "main_hall_slot_03")
	_check(bool(wall_result.get("ok", false)), "T0261 wall ballista deployment failed")
	_check(bool(hall_result.get("ok", false)), "T0261 main-hall ballista deployment failed")
	for _frame in 4:
		await physics_frame
		await process_frame

	for result in [wall_result, hall_result]:
		var deployment_id := str((result as Dictionary).get("deployment_id", ""))
		var view := presenter.get_view_for_deployment(deployment_id) as Node3D
		_check(view != null, "T0261 deployed view is missing: %s" % deployment_id)
		if view == null:
			continue
		var area := view.get_node_or_null("InteractionArea") as Area3D
		var shape := view.get_node_or_null("InteractionArea/CollisionShape3D") as CollisionShape3D
		_check(area != null and shape != null, "T0261 interaction area is missing: %s" % deployment_id)
		if area == null or shape == null:
			continue
		var screen_position := camera.unproject_position(shape.global_position)
		var interaction: Dictionary = presenter.get_world_click_interaction(screen_position)
		_check(
			str(interaction.get("deployment_id", "")) == deployment_id,
			"T0261 area-only ray selected the wrong deployment: %s" % JSON.stringify(interaction)
		)
		_send_world_click(screen_position)
		await process_frame
		await process_frame
		var panel_snapshot: Dictionary = panel.debug_get_snapshot()
		var authority: Dictionary = device_system.get_deployment(deployment_id)
		var effect: Dictionary = authority.get("effect", {}) as Dictionary
		var range_snapshot: Dictionary = indicator.get_debug_snapshot()
		_check(_clicked_ids.has(deployment_id), "T0261 click signal was not emitted: %s" % deployment_id)
		_check(panel.visible, "T0261 defense-device panel did not open: %s" % deployment_id)
		_check(not building_panel.visible, "T0261 host BuildingPanel stole the device click: %s" % deployment_id)
		_check(str(panel_snapshot.get("deployment_id", "")) == deployment_id, "T0261 panel identity drifted")
		_check(str(panel_snapshot.get("name", "")) == "弩床", "T0261 panel name is not the selected ballista")
		var values: Dictionary = panel_snapshot.get("values", {}) as Dictionary
		_check(values.size() == 6, "T0261 panel exposes fields beyond the six required properties")
		_check(str(values.get("hp", "")).contains("%d / %d" % [int(authority.get("hp", 0)), int(authority.get("max_hp", 0))]), "T0261 panel HP mismatch")
		_check(is_equal_approx(float(panel_snapshot.get("hp_progress_value", -1.0)), float(authority.get("hp", 0))), "T0277 device HP progress value mismatch")
		_check(is_equal_approx(float(panel_snapshot.get("hp_progress_max", -1.0)), float(authority.get("max_hp", 0))), "T0277 device HP progress maximum mismatch")
		_check(not bool(panel_snapshot.get("hp_progress_danger", true)), "T0277 full-health device HP progress is incorrectly red")
		_check(str(values.get("attack", "")).contains(str(int(effect.get("damage", 0)))), "T0261 panel attack mismatch")
		_check(str(values.get("defense", "")).contains(str(int(authority.get("defense", 0)))), "T0261 panel defense mismatch")
		_check(str(values.get("penetration", "")).contains(str(int(effect.get("penetration", 0)))), "T0261 panel penetration mismatch")
		_check(str(values.get("range", "")).contains(_trim_decimal(float(effect.get("range", 0.0)))), "T0261 panel range mismatch")
		_check(str(values.get("attack_speed", "")).contains(_trim_decimal(float(effect.get("attack_speed", 0.0)), 2)), "T0261 panel attack speed mismatch")
		_check(not bool(panel_snapshot.get("has_description", true)), "T0261 panel contains a redundant description")
		_check(not bool(panel_snapshot.get("has_authority_note", true)), "T0261 panel contains a redundant authority note")
		_check(bool(panel_snapshot.get("has_undeploy_button", false)), "T0274 panel is missing the undeploy button")
		_check(str(panel_snapshot.get("undeploy_button_text", "")) == "卸下", "T0274 undeploy button label drifted")
		_check(bool(range_snapshot.get("visible", false)), "T0261 click did not show the attack range ring")
		_check(str(range_snapshot.get("selection_id", "")) == deployment_id, "T0261 range ring selected the wrong deployment")
		_check(is_equal_approx(float(range_snapshot.get("displayed_range", -1.0)), float(effect.get("range", 0.0))), "T0261 range ring ignored effective device range")

	panel.call("_update_hp_progress", {"hp": 29, "max_hp": 100})
	var critical_snapshot: Dictionary = panel.debug_get_snapshot()
	var critical_progress := panel.find_child("DefenseDeviceHPProgress", true, false) as ProgressBar
	var critical_fill := critical_progress.get_theme_stylebox("fill") as StyleBoxFlat if critical_progress != null else null
	_check(bool(critical_snapshot.get("hp_progress_danger", false)), "T0277 device HP progress did not enter the critical state")
	_check(critical_fill != null and critical_fill.bg_color.to_html(true) == "a7433bff", "T0277 critical device HP progress is not red")

	var undeploy_button := panel.find_child("DefenseDeviceUndeployButton", true, false) as Button
	var damage_confirm := panel.find_child("DefenseDeviceDamagedUndeployConfirm", true, false) as ConfirmationDialog
	_check(undeploy_button != null and damage_confirm != null, "T0274 undeploy controls are missing")
	if undeploy_button != null and damage_confirm != null:
		var wall_id := str(wall_result.get("deployment_id", ""))
		var hall_id := str(hall_result.get("deployment_id", ""))
		_check(int(resource_system.get_resource("item_wall_ballista")) == 0, "T0274 deployed fixture inventory is not zero")

		event_bus.defense_device_clicked.emit(wall_id)
		await process_frame
		undeploy_button.pressed.emit()
		await process_frame
		_check(device_system.get_deployment(wall_id).is_empty(), "T0274 full-health device remained deployed")
		_check(not bool(device_system.get_slot("wall_slot_01").get("occupied", true)), "T0274 full-health undeploy did not clear the slot")
		_check(int(resource_system.get_resource("item_wall_ballista")) == 1, "T0274 full-health device did not return to inventory")
		_check(not panel.visible, "T0274 full-health undeploy did not close the panel")
		_check(not bool(indicator.get_debug_snapshot().get("visible", true)), "T0274 full-health undeploy did not clear the range ring")

		var hall_before_damage: Dictionary = device_system.get_deployment(hall_id)
		device_system.apply_damage_to_device(hall_id, 1, {"attacker_id": "verify_t0274"})
		var damaged_hall: Dictionary = device_system.get_deployment(hall_id)
		_check(int(damaged_hall.get("hp", 0)) == int(hall_before_damage.get("hp", 0)) - 1, "T0274 damaged fixture was not damaged")
		var guarded_result: Dictionary = device_system.undeploy_device(hall_id, false)
		_check(bool(guarded_result.get("requires_confirmation", false)), "T0274 authority did not guard damaged removal")
		_check(not device_system.get_deployment(hall_id).is_empty(), "T0274 guarded damaged removal changed deployment")
		event_bus.defense_device_clicked.emit(hall_id)
		await process_frame
		undeploy_button.pressed.emit()
		await process_frame
		var confirm_snapshot: Dictionary = panel.debug_get_snapshot()
		_check(bool(confirm_snapshot.get("damage_confirm_visible", false)), "T0274 damaged device did not ask for confirmation")
		_check(str(confirm_snapshot.get("damage_confirm_text", "")).contains("受损") and str(confirm_snapshot.get("damage_confirm_text", "")).contains("直接销毁"), "T0274 damaged confirmation copy is incomplete")
		_check(not device_system.get_deployment(hall_id).is_empty(), "T0274 opening the damaged confirmation changed deployment")
		_check(int(resource_system.get_resource("item_wall_ballista")) == 1, "T0274 opening the damaged confirmation changed inventory")

		damage_confirm.canceled.emit()
		damage_confirm.hide()
		await process_frame
		_check(not device_system.get_deployment(hall_id).is_empty(), "T0274 choosing no removed the damaged device")
		_check(bool(device_system.get_slot("main_hall_slot_03").get("occupied", false)), "T0274 choosing no cleared the damaged slot")
		_check(int(resource_system.get_resource("item_wall_ballista")) == 1, "T0274 choosing no changed inventory")

		undeploy_button.pressed.emit()
		await process_frame
		damage_confirm.confirmed.emit()
		await process_frame
		_check(device_system.get_deployment(hall_id).is_empty(), "T0274 confirmed damaged device remained deployed")
		_check(not bool(device_system.get_slot("main_hall_slot_03").get("occupied", true)), "T0274 confirmed damaged undeploy did not clear the slot")
		_check(int(resource_system.get_resource("item_wall_ballista")) == 1, "T0274 damaged device was incorrectly returned to inventory")
		_check(device_system.get_device_ruins().is_empty(), "T0274 manual damaged removal left a blocking ruin")
		_check(bool(device_system.get_deploy_eligibility("wall_ballista", "wall_slot_01").get("ok", false)), "T0274 cleared wall slot cannot accept another device")
		_check(bool(device_system.get_deploy_eligibility("wall_ballista", "main_hall_slot_03").get("ok", false)), "T0274 cleared hall slot cannot accept another device")

	event_bus.building_clicked.emit("main_hall")
	await process_frame
	_check(not panel.visible, "T0261 building selection did not close the defense-device panel")
	_check(not bool(indicator.get_debug_snapshot().get("visible", true)), "T0261 building selection did not hide the range ring")
	_finish()


func _send_world_click(screen_position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = screen_position
	event.global_position = screen_position
	event.pressed = true
	root.push_input(event)


func _set_building_level(building_system: Node, building_id: String, level: int) -> void:
	var buildings: Dictionary = building_system.get("_buildings")
	var building: Dictionary = buildings.get(building_id, {})
	building["level"] = level
	buildings[building_id] = building
	building_system.set("_buildings", buildings)


func _on_defense_device_clicked(deployment_id: String) -> void:
	_clicked_ids.append(deployment_id)


func _trim_decimal(value: float, decimals: int = 1) -> String:
	var text := ("%%.%df" % decimals) % value
	while text.contains(".") and text.ends_with("0"):
		text = text.left(-1)
	if text.ends_with("."):
		text = text.left(-1)
	return text


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0261_DEFENSE_DEVICE_SELECTION_PANEL_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
