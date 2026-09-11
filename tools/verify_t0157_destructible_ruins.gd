extends SceneTree


const MAIN_PATH := "res://scenes/main/Main.tscn"


func _init() -> void:
	var packed := load(MAIN_PATH) as PackedScene
	if packed == null:
		_fail("T0157 Main scene unavailable")
		return
	var main := packed.instantiate()
	root.add_child(main)
	for _index in 6:
		await process_frame
		await physics_frame

	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var device_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var presenter := root.get_node_or_null("Main/WorldRoot/Station/DefenseDevices")
	var fortification := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/WallsAndGates/FortificationArt")
	var warehouse_art := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/BuildingRoots/Warehouse/WarehouseArt")
	var main_hall_art := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/BuildingRoots/MainHall/MainHallArt")
	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	if building_system == null or device_system == null or resource_system == null or presenter == null or fortification == null or warehouse_art == null or main_hall_art == null or gm_panel == null:
		_fail("T0157 runtime hierarchy incomplete")
		return
	if gm_panel.find_child("DestroyFirstDefenseDeviceButton", true, false) == null or gm_panel.find_child("DefenseDeviceRuinSnapshotButton", true, false) == null:
		_fail("T0157 GM ruin verification controls are missing")
		return

	if not await _verify_device_ruins(building_system, device_system, resource_system, presenter):
		return
	if not await _verify_front_gate_breach(building_system, fortification):
		return
	if not await _verify_warehouse_threshold(building_system, warehouse_art):
		return
	if not await _verify_main_hall_ruin(building_system, main_hall_art):
		return

	print("T0157 destructible ruins verification passed: device replacement/expiry, gate 1%, warehouse 30%, main hall terminal ruin")
	main.queue_free()
	await process_frame
	quit(0)


func _verify_device_ruins(building_system: Node, device_system: Node, resource_system: Node, presenter: Node) -> bool:
	var buildings: Dictionary = building_system.get("_buildings")
	var wall: Dictionary = buildings.get("wall", {})
	wall["level"] = maxi(2, int(wall.get("level", 1)))
	buildings["wall"] = wall
	building_system.set("_buildings", buildings)
	resource_system.add_resource("item_wall_ballista", 2)
	resource_system.add_resource("item_wall_arrow_tower", 1)
	var ballista_result: Dictionary = device_system.deploy_device("wall_ballista", "wall_slot_01")
	var arrow_result: Dictionary = device_system.deploy_device("wall_arrow_tower", "wall_slot_02")
	if not bool(ballista_result.get("ok", false)) or not bool(arrow_result.get("ok", false)):
		_fail("T0157 could not deploy both device types")
		return false
	await process_frame
	var ballista_id := str(ballista_result.get("deployment_id", ""))
	var arrow_id := str(arrow_result.get("deployment_id", ""))
	var ballista_hp := int(device_system.get_deployment(ballista_id).get("hp", 0))
	if not bool(device_system.apply_damage_to_device(ballista_id, ballista_hp).get("destroyed", false)):
		_fail("T0157 ballista did not enter destroyed state")
		return false
	if not bool(device_system.debug_destroy_device(arrow_id).get("destroyed", false)):
		_fail("T0157 arrow tower did not enter destroyed state")
		return false
	await process_frame
	if device_system.get_deployments().size() != 0 or device_system.get_device_ruins().size() != 2 or presenter.get_ruin_view_count() != 2:
		_fail("T0157 destroyed devices did not release slots and retain two ruins")
		return false
	for slot_id in ["wall_slot_01", "wall_slot_02"]:
		var ruin_view: Node3D = presenter.get_ruin_view_for_slot(slot_id)
		var snapshot: Dictionary = ruin_view.get_debug_snapshot() if ruin_view != null else {}
		var model: Dictionary = snapshot.get("model", {}) if snapshot.get("model", {}) is Dictionary else {}
		if ruin_view == null or not bool(snapshot.get("is_ruin", false)) or not bool(model.get("destroyed_visual", false)):
			_fail("T0157 %s did not use its collapsed normal model" % slot_id)
			return false
	var replacement: Dictionary = device_system.deploy_device("wall_ballista", "wall_slot_01")
	if not bool(replacement.get("ok", false)):
		_fail("T0157 replacement deployment failed")
		return false
	await process_frame
	if presenter.get_ruin_view_for_slot("wall_slot_01") != null or device_system.get_device_ruins().size() != 1:
		_fail("T0157 replacement did not clear the old slot ruin")
		return false
	device_system._process(16.0)
	await process_frame
	if not device_system.get_device_ruins().is_empty() or presenter.get_ruin_view_count() != 0:
		_fail("T0157 device ruin did not expire after its configured lifetime")
		return false
	return true


func _verify_front_gate_breach(building_system: Node, fortification: Node) -> bool:
	var gate_view := fortification.get_node_or_null("GateArt/FrontGateArt")
	if gate_view == null:
		_fail("T0157 formal front gate view missing")
		return false
	var gate: Dictionary = building_system.get_building("front_gate")
	building_system.apply_damage_to_building("front_gate", int(gate.get("hp", 0)), "t0157_test")
	for _index in 50:
		await physics_frame
	var destroyed: Dictionary = gate_view.debug_get_snapshot()
	if not bool(destroyed.get("destroyed", false)) or float(destroyed.get("collapse_fraction", 0.0)) < 0.95 or bool(destroyed.get("blocking_collision", true)):
		_fail("T0157 front gate did not collapse and release its blocking state")
		return false
	if not _all_gate_leaf_shapes_disabled(gate_view, true):
		_fail("T0157 destroyed front gate retained door-leaf collision")
		return false
	building_system.restore_building_hp("front_gate", 1)
	await physics_frame
	if not bool(building_system.get_building("front_gate").get("destruction_latched", false)):
		_fail("T0157 front gate recovered below the configured 1% threshold")
		return false
	building_system.restore_building_hp("front_gate", 1)
	for _index in 50:
		await physics_frame
	var restored: Dictionary = gate_view.debug_get_snapshot()
	if bool(restored.get("destroyed", true)) or float(restored.get("collapse_fraction", 1.0)) > 0.05 or not bool(restored.get("blocking_collision", false)):
		_fail("T0157 front gate did not restore at 1% HP")
		return false
	if not _all_gate_leaf_shapes_disabled(gate_view, false):
		_fail("T0157 restored front gate did not restore door-leaf collision")
		return false
	return true


func _verify_warehouse_threshold(building_system: Node, warehouse_art: Node) -> bool:
	var warehouse: Dictionary = building_system.get_building("warehouse")
	building_system.apply_damage_to_building("warehouse", int(warehouse.get("hp", 0)), "t0157_test")
	await process_frame
	if not bool(warehouse_art.get_art_slice_snapshot().get("ruin_visible", false)):
		_fail("T0157 warehouse ruin did not appear at 0 HP")
		return false
	building_system.restore_building_hp("warehouse", 44)
	await process_frame
	if not bool(warehouse_art.get_art_slice_snapshot().get("ruin_visible", false)):
		_fail("T0157 warehouse recovered before 30% HP")
		return false
	building_system.restore_building_hp("warehouse", 1)
	await process_frame
	var restored: Dictionary = warehouse_art.get_art_slice_snapshot()
	if bool(restored.get("ruin_visible", true)) or bool(restored.get("destruction_latched", true)):
		_fail("T0157 warehouse did not restore its normal model at 30% HP")
		return false
	return true


func _verify_main_hall_ruin(building_system: Node, main_hall_art: Node) -> bool:
	var main_hall: Dictionary = building_system.get_building("main_hall")
	building_system.apply_damage_to_building("main_hall", int(main_hall.get("hp", 0)), "t0157_test")
	await process_frame
	var snapshot: Dictionary = main_hall_art.get_art_slice_snapshot()
	if not bool(snapshot.get("ruin_visible", false)) or not bool(snapshot.get("destruction_latched", false)):
		_fail("T0157 main hall terminal ruin did not appear")
		return false
	building_system.restore_building_hp("main_hall", int(main_hall.get("max_hp", 1)))
	await process_frame
	if not bool(main_hall_art.get_art_slice_snapshot().get("ruin_visible", false)):
		_fail("T0157 non-recoverable main hall ruin was incorrectly cleared")
		return false
	return true


func _all_gate_leaf_shapes_disabled(gate_view: Node, expected_disabled: bool) -> bool:
	var found := 0
	for hinge_path in ["LeftDoorHinge", "RightDoorHinge"]:
		var hinge := gate_view.get_node_or_null(hinge_path)
		if hinge == null:
			return false
		for raw_shape in hinge.find_children("*", "CollisionShape3D", true, false):
			found += 1
			if (raw_shape as CollisionShape3D).disabled != expected_disabled:
				return false
	return found == 2


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
