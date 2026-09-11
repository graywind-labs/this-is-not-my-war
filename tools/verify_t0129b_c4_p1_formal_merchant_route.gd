extends SceneTree


const FORMAL_ROUTE_MODE := "formal_rear_trade_debug"
const ARRIVAL_TIMEOUT_MSEC := 60000


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	var merchant_system := root.get_node_or_null("Main/Systems/MerchantSystem")
	var layout_controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if merchant_system == null or layout_controller == null or time_system == null:
		_fail("C4-P1 required systems are missing")
		return
	var route: Dictionary = layout_controller.get_formal_merchant_route_world()
	var points := route.get("path_points", []) as Array
	if points.size() != 6:
		_fail("Formal merchant route must contain six audited points")
		return
	var spawn: Vector3 = route.get("spawn", Vector3.ZERO)
	var dock: Vector3 = route.get("dock", Vector3.ZERO)
	var back_gate: Vector3 = route.get("back_gate", Vector3.ZERO)
	if not spawn.is_equal_approx(Vector3(945.0, 0.0, -315.0)) or not dock.is_equal_approx(Vector3(971.8, 0.0, -52.4)):
		_fail("Formal merchant route did not apply the staging offset")
		return
	if spawn.distance_to(dock) < 250.0:
		_fail("Formal merchant route is not a genuine map-edge journey")
		return
	var dock_gate_distance := Vector2(dock.x, dock.z).distance_to(Vector2(back_gate.x, back_gate.z))
	if absf(dock_gate_distance - float(route.get("dock_root_clearance_to_back_gate_m", 0.0))) > 0.05 or dock_gate_distance > 7.1:
		_fail("Formal merchant dock is not the audited rear-gate stop: %.3f" % dock_gate_distance)
		return

	Engine.time_scale = 3.0
	time_system.set_current_time(1, 10, 0, 0)
	var start_result: Dictionary = merchant_system.debug_force_formal_wagon_arrival()
	if not bool(start_result.get("ok", false)):
		_fail("Formal merchant wagon could not start")
		return
	var wagon := root.get_node_or_null("Main/WorldRoot/DailyMerchantWagon")
	if wagon == null or not wagon.configure_profile("merchant_wagon", {"profile": {"base_speed": 20.0, "acceleration": 60.0}}):
		_fail("Formal merchant wagon test acceleration could not be applied")
		return
	var arrival_snapshot: Dictionary = merchant_system.get_market_snapshot()
	if str(arrival_snapshot.get("route_mode", "")) != FORMAL_ROUTE_MODE or int(arrival_snapshot.get("route_point_count", 0)) != 6:
		_fail("MerchantSystem did not build the formal polyline route")
		return
	if bool(arrival_snapshot.get("active", false)):
		_fail("Trade became active before the wagon reached the formal dock")
		return
	if not await _wait_for_wagon_state(merchant_system, "parked"):
		_fail("Formal wagon did not reach its remote dock: %s" % str(merchant_system.get_market_snapshot().get("wagon", {})))
		return
	arrival_snapshot = merchant_system.get_market_snapshot()
	var wagon_snapshot := arrival_snapshot.get("wagon", {}) as Dictionary
	if not bool(arrival_snapshot.get("active", false)) or not bool(wagon_snapshot.get("trade_bubble_visible", false)):
		_fail("Formal dock arrival did not atomically enable trade")
		return
	if (wagon_snapshot.get("world_position", Vector3.ZERO) as Vector3).distance_to(dock) > 0.35:
		_fail("Formal wagon stopped outside the dock tolerance")
		return
	var horse_collision := wagon.get_node_or_null("HorseBodyCollision") as CollisionShape3D
	var horse_shape := horse_collision.shape as BoxShape3D if horse_collision != null else null
	if horse_collision == null or horse_shape == null:
		_fail("Formal wagon horse collision envelope is missing")
		return
	var gate_direction := back_gate - horse_collision.global_position
	gate_direction.y = 0.0
	var horse_to_gate_distance := gate_direction.length()
	gate_direction = gate_direction.normalized()
	var horse_basis := horse_collision.global_transform.basis.orthonormalized()
	var projected_half_extent := (
		absf(gate_direction.dot(horse_basis.x)) * horse_shape.size.x * 0.5
		+ absf(gate_direction.dot(horse_basis.z)) * horse_shape.size.z * 0.5
	)
	var horse_front_clearance := horse_to_gate_distance - projected_half_extent
	if horse_front_clearance < 0.55 or horse_front_clearance > 1.8:
		_fail("Formal wagon horse front is not parked just outside the rear gate: %.3f" % horse_front_clearance)
		return
	var fortification_art := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/WallsAndGates/FortificationArt")
	if fortification_art == null or not fortification_art.has_method("get_gate_snapshot"):
		_fail("Formal rear gate art is unavailable")
		return
	for _i in 70:
		await physics_frame
	var rear_gate_snapshot := fortification_art.call("get_gate_snapshot", "back_gate") as Dictionary
	if not bool(rear_gate_snapshot.get("friendly_near", false)) or float(rear_gate_snapshot.get("open_fraction", 0.0)) < 0.85:
		_fail("Docked merchant wagon did not keep the rear gate open: %s" % rear_gate_snapshot)
		return

	merchant_system.debug_force_wagon_departure()
	var departure_snapshot: Dictionary = merchant_system.get_market_snapshot()
	if bool(departure_snapshot.get("active", true)) or str(departure_snapshot.get("wagon_state", "")) != "departing":
		_fail("Formal departure did not close trade immediately")
		return
	if not await _wait_for_wagon_state(merchant_system, "absent"):
		_fail("Formal wagon did not return to the map edge")
		return
	var restored_snapshot: Dictionary = merchant_system.get_market_snapshot()
	if str(restored_snapshot.get("route_mode", "")) != "formal_rear_trade_default" or int(restored_snapshot.get("route_point_count", 0)) != 6:
		_fail("Formal debug visit did not restore the default formal route")
		return
	if not bool(layout_controller.is_runtime_formal_world_enabled()):
		_fail("Formal route debug visit disabled the default formal world")
		return
	Engine.time_scale = 1.0
	print("T0129B C4-P1 formal merchant route verification passed.")
	quit(0)


func _wait_for_wagon_state(merchant_system: Node, expected_state: String) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < ARRIVAL_TIMEOUT_MSEC:
		await physics_frame
		if str(merchant_system.get_market_snapshot().get("wagon_state", "")) == expected_state:
			return true
	return false


func _fail(message: String) -> void:
	Engine.time_scale = 1.0
	push_error(message)
	quit(1)
