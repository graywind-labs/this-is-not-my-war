extends SceneTree


const PANEL_SETTLE_FRAME_LIMIT := 10
const SAMPLE_OFFSETS: Array[Vector3] = [
	Vector3(0.0, 0.0, 0.0),
	Vector3(0.0, 0.35, 0.0),
	Vector3(-0.35, 0.25, 0.0),
	Vector3(0.35, 0.25, 0.0),
	Vector3(0.0, -0.25, 0.0),
	Vector3(-0.35, 0.0, -0.35),
	Vector3(0.35, 0.0, -0.35),
	Vector3(-0.35, 0.0, 0.35),
	Vector3(0.35, 0.0, 0.35)
]


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main scene failed to load")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await physics_frame

	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var panel := root.get_node_or_null("Main/UI/BuildingPanel") as Control
	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	if building_system == null or resource_system == null or panel == null or camera == null:
		_fail("Required building click verification nodes are missing")
		return

	# Defense in depth: even a direct stale button signal during transparent
	# measurement must not enter the authoritative upgrade path.
	var guarded_state_before := _get_building_action_snapshot(building_system)
	var guarded_resources_before: Dictionary = resource_system.get_resource_snapshot()
	panel.show_building("main_hall")
	if panel.modulate.a >= 0.99 or not bool(panel._reveal_after_fit):
		_fail("Transparent action-guard verification did not enter measurement state")
		return
	panel._on_upgrade_pressed()
	if guarded_state_before != _get_building_action_snapshot(building_system):
		_fail("Transparent panel accepted a direct upgrade signal")
		return
	if guarded_resources_before != resource_system.get_resource_snapshot():
		_fail("Transparent panel upgrade guard changed resources")
		return
	panel.show_building("")
	await process_frame

	var checked_count := 0
	for building_id in building_system.get_building_ids():
		panel.show_building("")
		await process_frame
		var click_position_variant: Variant = _find_click_position(building_system, camera, building_id)
		if click_position_variant == null:
			_fail("No camera-visible click point resolves to building: %s" % building_id)
			return
		var click_position: Vector2 = click_position_variant
		var building_state_before := _get_building_action_snapshot(building_system)
		var resources_before: Dictionary = resource_system.get_resource_snapshot()

		var motion := InputEventMouseMotion.new()
		motion.position = click_position
		motion.global_position = click_position
		root.push_input(motion)
		await process_frame

		var press := InputEventMouseButton.new()
		press.position = click_position
		press.global_position = click_position
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		root.push_input(press)
		if not panel.visible or str(panel._current_building_id) != building_id:
			_fail("Real mouse press did not select building: %s" % building_id)
			return
		if panel.modulate.a < 0.99 and panel.mouse_behavior_recursive != Control.MOUSE_BEHAVIOR_DISABLED:
			_fail("Transparent panel still accepts recursive mouse input: %s" % building_id)
			return

		await process_frame
		var release := InputEventMouseButton.new()
		release.position = click_position
		release.global_position = click_position
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		root.push_input(release)

		var settled := false
		for _frame in range(PANEL_SETTLE_FRAME_LIMIT):
			await process_frame
			if (
				panel.visible
				and panel.modulate.a >= 0.99
				and not bool(panel._panel_fit_queued)
				and not bool(panel._reveal_after_fit)
				and panel.size.y > 1.0
			):
				settled = true
				break
		if not settled:
			_fail("Building panel did not become visible and fitted in time: %s" % building_id)
			return
		if panel.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_DISABLED:
			_fail("Fitted building panel did not restore mouse input: %s" % building_id)
			return
		if building_state_before != _get_building_action_snapshot(building_system):
			_fail("Selecting a building changed HP, level, repair, or upgrade state: %s" % building_id)
			return
		if resources_before != resource_system.get_resource_snapshot():
			_fail("Selecting a building spent or added resources: %s" % building_id)
			return
		checked_count += 1

	# A second world click can arrive before the first transparent measurement
	# finishes. It must replace the pending fit instead of hitting hidden buttons.
	panel.show_building("")
	await process_frame
	var first_id := "main_hall"
	var second_id := "warehouse"
	var first_position_variant: Variant = _find_click_position(building_system, camera, first_id)
	var second_position_variant: Variant = _find_click_position(building_system, camera, second_id)
	if first_position_variant == null or second_position_variant == null:
		_fail("Rapid-switch verification could not find both building click points")
		return
	var rapid_state_before := _get_building_action_snapshot(building_system)
	var rapid_resources_before: Dictionary = resource_system.get_resource_snapshot()
	_push_click(first_position_variant)
	if str(panel._current_building_id) != first_id:
		_fail("Rapid-switch first building was not selected")
		return
	_push_click(second_position_variant)
	if str(panel._current_building_id) != second_id:
		_fail("Transparent pending panel blocked the rapid second building click")
		return
	var rapid_settled := false
	for _frame in range(PANEL_SETTLE_FRAME_LIMIT):
		await process_frame
		if (
			panel.visible
			and panel.modulate.a >= 0.99
			and not bool(panel._panel_fit_queued)
			and not bool(panel._reveal_after_fit)
			and panel.size.y > 1.0
		):
			rapid_settled = true
			break
	if not rapid_settled:
		_fail("Rapid-switch panel did not settle on the second building")
		return
	if rapid_state_before != _get_building_action_snapshot(building_system):
		_fail("Rapid building switching changed a building action state")
		return
	if rapid_resources_before != resource_system.get_resource_snapshot():
		_fail("Rapid building switching changed resources")
		return

	print("T0047 real building mouse click verification passed: %d buildings." % checked_count)
	quit(0)


func _find_click_position(building_system: Node, camera: Camera3D, building_id: String) -> Variant:
	var viewport_rect := root.get_viewport().get_visible_rect()
	var node_paths: Array = building_system._building_scene_nodes.get(building_id, [])
	for raw_path in node_paths:
		var building_node := building_system.get_node_or_null(NodePath(str(raw_path)))
		if building_node == null:
			continue
		var collision_shape := building_node.get_node_or_null("ClickArea/CollisionShape3D") as CollisionShape3D
		if collision_shape == null or not collision_shape.shape is BoxShape3D:
			continue
		var shape_size: Vector3 = (collision_shape.shape as BoxShape3D).size
		for sample_offset in SAMPLE_OFFSETS:
			var local_point := Vector3(
				shape_size.x * sample_offset.x,
				shape_size.y * sample_offset.y,
				shape_size.z * sample_offset.z
			)
			var world_point := collision_shape.to_global(local_point)
			if camera.is_position_behind(world_point):
				continue
			var screen_point := camera.unproject_position(world_point)
			if not viewport_rect.has_point(screen_point):
				continue
			if building_system._pick_building_at_screen_position(screen_point) == building_id:
				return screen_point
	return null


func _get_building_action_snapshot(building_system: Node) -> Dictionary:
	var snapshot := {}
	for building_id in building_system.get_building_ids():
		var building: Dictionary = building_system.get_building(building_id)
		snapshot[building_id] = {
			"hp": int(building.get("hp", 0)),
			"max_hp": int(building.get("max_hp", 0)),
			"level": int(building.get("level", 0)),
			"repairing": building_system.is_repair_in_progress(building_id),
			"upgrading": building_system.is_upgrade_in_progress(building_id)
		}
	return snapshot


func _push_click(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion)
	var press := InputEventMouseButton.new()
	press.position = position
	press.global_position = position
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press)
	var release := InputEventMouseButton.new()
	release.position = position
	release.global_position = position
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	root.push_input(release)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
