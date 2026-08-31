extends SceneTree


const COMPACT_VIEWPORT := Vector2i(1152, 648)
const LARGE_VIEWPORT := Vector2i(2400, 1350)
const MAX_POPUP_WIDTH := 460.0
const MAX_POPUP_HEIGHT := 560.0


func _init() -> void:
	root.size = COMPACT_VIEWPORT
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main.tscn failed to load.")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame

	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var device_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var presenter := root.get_node_or_null("Main/UI/DefenseSlotPresenter")
	var device_presenter := root.get_node_or_null(
		"Main/WorldRoot/Station/DefenseDevices"
	)
	if [
		building_system,
		device_system,
		resource_system,
		presenter,
		device_presenter
	].has(null):
		_fail("T0112 required runtime nodes are missing.")
		return

	_set_building_level(building_system, "wall", 1)
	_set_building_level(building_system, "main_hall", 1)
	presenter._refresh_all()
	await process_frame
	if not _verify_unlocked_marker_visibility(presenter):
		return
	if not await _verify_compact_popup(presenter):
		return
	if not await _verify_wall_bonus_presentation(building_system, device_system, presenter):
		return
	if not await _verify_main_hall_no_bonus(building_system, presenter):
		return
	if not _verify_range_curves(building_system, device_system):
		return
	if not await _verify_deployed_range_refresh(
		building_system,
		device_system,
		resource_system,
		device_presenter
	):
		return

	print("T0112 defense deployment UI verification passed.")
	quit(0)


func _verify_unlocked_marker_visibility(presenter: Node) -> bool:
	var visible_plus_slots := ["wall_slot_01", "main_hall_slot_03"]
	var hidden_locked_slots := [
		"wall_slot_02",
		"wall_slot_03",
		"wall_slot_04",
		"main_hall_slot_01",
		"main_hall_slot_02",
		"main_hall_slot_04"
	]
	for slot_id in visible_plus_slots:
		var snapshot: Dictionary = presenter.debug_get_marker_snapshot(slot_id)
		if (
			str(snapshot.get("text", "")) != "+"
			or not bool(snapshot.get("unlocked", false))
		):
			return _fail("Unlocked slot must expose one configured + marker: %s / %s" % [slot_id, snapshot])
	for slot_id in hidden_locked_slots:
		var snapshot: Dictionary = presenter.debug_get_marker_snapshot(slot_id)
		if (
			bool(snapshot.get("visible", true))
			or not str(snapshot.get("text", "")).is_empty()
			or bool(snapshot.get("unlocked", true))
		):
			return _fail("Locked slot marker leaked into the world UI: %s" % slot_id)
	return true


func _verify_compact_popup(presenter: Node) -> bool:
	if not presenter.debug_open_slot("wall_slot_01"):
		return _fail("Could not open the first wall deployment slot.")
	await process_frame
	await process_frame
	var compact_snapshot: Dictionary = presenter.debug_get_popup_snapshot()
	if not _is_popup_compact(compact_snapshot, COMPACT_VIEWPORT):
		return _fail(
			"Compact viewport popup is outside its bounds: %s"
			% JSON.stringify(compact_snapshot)
		)
	if (
		bool(compact_snapshot.get("bonus_visible", true))
		or bool(compact_snapshot.get("status_visible", true))
	):
		return _fail("Wall Lv.1 must not show a fake bonus or default status note.")

	var popup := presenter.get_node_or_null("DefenseDeploymentPanel")
	if popup == null:
		return _fail("Deployment popup node is missing.")
	var forbidden_fragments := [
		"每次部署消耗",
		"同级横向选择",
		"库存与槽位由系统实时校验"
	]
	for label_node in popup.find_children("*", "Label", true, false):
		var text := str((label_node as Label).text)
		for fragment in forbidden_fragments:
			if text.contains(fragment):
				return _fail("Deployment popup still contains redundant text: %s" % fragment)

	var compact_size: Vector2 = compact_snapshot.get("size", Vector2.ZERO)
	root.size = LARGE_VIEWPORT
	await process_frame
	await process_frame
	await process_frame
	var large_snapshot: Dictionary = presenter.debug_get_popup_snapshot()
	if not _is_popup_compact(large_snapshot, LARGE_VIEWPORT):
		return _fail(
			"Large viewport popup is outside its bounds: %s"
			% JSON.stringify(large_snapshot)
		)
	var large_size: Vector2 = large_snapshot.get("size", Vector2.ZERO)
	if large_size.y > compact_size.y + 2.0:
		return _fail("Maximizing the window must not stretch the popup vertically.")
	return true


func _verify_wall_bonus_presentation(
	building_system: Node,
	device_system: Node,
	presenter: Node
) -> bool:
	presenter._close_popup()
	_set_building_level(building_system, "wall", 3)
	presenter._refresh_all()
	await process_frame
	if not presenter.debug_open_slot("wall_slot_01"):
		return _fail("Could not reopen the wall slot at Lv.3.")
	await process_frame
	await process_frame
	var popup_snapshot: Dictionary = presenter.debug_get_popup_snapshot()
	if (
		not bool(popup_snapshot.get("bonus_visible", false))
		or not str(popup_snapshot.get("bonus_text", "")).contains("射程×1.05")
	):
		return _fail("Wall Lv.3 range reward is missing from the deployment popup.")
	var slot: Dictionary = device_system.get_slot("wall_slot_01")
	if not is_equal_approx(
		float((slot.get("effect_modifiers", {}) as Dictionary).get(
			"range_multiplier",
			0.0
		)),
		1.05
	):
		return _fail("Wall Lv.3 slot did not resolve to a 1.05x range multiplier.")
	return true


func _verify_main_hall_no_bonus(building_system: Node, presenter: Node) -> bool:
	presenter._close_popup()
	_set_building_level(building_system, "main_hall", 1)
	presenter._refresh_all()
	await process_frame
	if not presenter.debug_open_slot("main_hall_slot_03"):
		return _fail("Could not open the first main-hall deployment slot.")
	await process_frame
	await process_frame
	var popup_snapshot: Dictionary = presenter.debug_get_popup_snapshot()
	if (
		bool(popup_snapshot.get("bonus_visible", true))
		or str(popup_snapshot.get("bonus_text", "")).contains("高台加成")
	):
		return _fail("Main hall must not display a defense-device range bonus.")
	return true


func _verify_range_curves(building_system: Node, device_system: Node) -> bool:
	var expected_wall := [1.0, 1.0, 1.05, 1.05, 1.10, 1.10]
	for level in range(1, 7):
		_set_building_level(building_system, "wall", level)
		var wall_slot: Dictionary = device_system.get_slot("wall_slot_01")
		var wall_multiplier := float(
			(wall_slot.get("effect_modifiers", {}) as Dictionary).get(
				"range_multiplier",
				0.0
			)
		)
		if not is_equal_approx(wall_multiplier, expected_wall[level - 1]):
			return _fail("Wall Lv.%d range multiplier mismatch." % level)

		_set_building_level(building_system, "main_hall", level)
		var hall_slot: Dictionary = device_system.get_slot("main_hall_slot_03")
		var hall_multiplier := float(
			(hall_slot.get("effect_modifiers", {}) as Dictionary).get(
				"range_multiplier",
				0.0
			)
		)
		if not is_equal_approx(hall_multiplier, 1.0):
			return _fail("Main hall Lv.%d must retain the base 1.0x range." % level)
	return true


func _verify_deployed_range_refresh(
	building_system: Node,
	device_system: Node,
	resource_system: Node,
	device_presenter: Node
) -> bool:
	_set_building_level(building_system, "wall", 1)
	resource_system.add_resource("item_wall_ballista", 1)
	var deploy_result: Dictionary = device_system.deploy_device(
		"wall_ballista",
		"wall_slot_01"
	)
	if not bool(deploy_result.get("ok", false)):
		return _fail("Could not deploy a ballista for range refresh verification.")
	var deployment_id := str(deploy_result.get("deployment_id", ""))
	await process_frame
	var base_deployment: Dictionary = device_system.get_deployment(deployment_id)
	var base_range := float(
		(base_deployment.get("effect", {}) as Dictionary).get("range", 0.0)
	)
	var device_view: Node3D = device_presenter.get_view_for_deployment(deployment_id)
	if device_view == null:
		return _fail("Deployed ballista view is missing.")

	_set_building_level(building_system, "wall", 5)
	var event_bus := root.get_node_or_null("EventBus")
	if event_bus != null:
		event_bus.building_state_changed.emit("wall")
	await process_frame
	var upgraded_deployment: Dictionary = device_system.get_deployment(deployment_id)
	var upgraded_range := float(
		(upgraded_deployment.get("effect", {}) as Dictionary).get("range", 0.0)
	)
	if (
		base_range <= 0.0
		or not is_equal_approx(upgraded_range, base_range * 1.10)
	):
		return _fail("Existing wall deployments did not inherit later range rewards.")
	var status_label := device_view.get_node_or_null("StatusLabel") as Label3D
	if status_label == null or not status_label.text.contains("射程 37.4"):
		return _fail("World device view did not refresh its upgraded effective range.")
	return true


func _is_popup_compact(snapshot: Dictionary, viewport_size: Vector2i) -> bool:
	if not bool(snapshot.get("visible", false)):
		return false
	var size: Vector2 = snapshot.get("size", Vector2.ZERO)
	var position: Vector2 = snapshot.get("position", Vector2.ZERO)
	return (
		size.x > 0.0
		and size.y > 0.0
		and size.x <= MAX_POPUP_WIDTH + 1.0
		and size.y <= MAX_POPUP_HEIGHT + 1.0
		and position.x >= 0.0
		and position.y >= 0.0
		and position.x + size.x <= float(viewport_size.x)
		and position.y + size.y <= float(viewport_size.y)
	)


func _set_building_level(building_system: Node, building_id: String, level: int) -> void:
	var buildings: Dictionary = building_system.get("_buildings")
	var building: Dictionary = buildings.get(building_id, {})
	building["level"] = level
	building["hp"] = maxi(1, int(building.get("max_hp", 1)))
	buildings[building_id] = building
	building_system.set("_buildings", buildings)


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
