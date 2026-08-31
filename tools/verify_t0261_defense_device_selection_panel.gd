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
		_check(str(values.get("attack", "")).contains(str(int(effect.get("damage", 0)))), "T0261 panel attack mismatch")
		_check(str(values.get("defense", "")).contains(str(int(authority.get("defense", 0)))), "T0261 panel defense mismatch")
		_check(str(values.get("penetration", "")).contains(str(int(effect.get("penetration", 0)))), "T0261 panel penetration mismatch")
		_check(str(values.get("range", "")).contains(_trim_decimal(float(effect.get("range", 0.0)))), "T0261 panel range mismatch")
		_check(str(values.get("attack_speed", "")).contains(_trim_decimal(float(effect.get("attack_speed", 0.0)), 2)), "T0261 panel attack speed mismatch")
		_check(not bool(panel_snapshot.get("has_description", true)), "T0261 panel contains a redundant description")
		_check(not bool(panel_snapshot.get("has_authority_note", true)), "T0261 panel contains a redundant authority note")
		_check(bool(range_snapshot.get("visible", false)), "T0261 click did not show the attack range ring")
		_check(str(range_snapshot.get("selection_id", "")) == deployment_id, "T0261 range ring selected the wrong deployment")
		_check(is_equal_approx(float(range_snapshot.get("displayed_range", -1.0)), float(effect.get("range", 0.0))), "T0261 range ring ignored effective device range")

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
