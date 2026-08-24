extends SceneTree


const WAGON_SCENE := preload("res://scenes/world/MerchantWagon.tscn")
const REAR_GATE_SCRIPT := preload("res://scripts/presentation/buildings/FormalGateArtView.gd")
const LAYOUT_PATH := "res://data/station_layout.json"
const MOTION_TIMEOUT_MSEC := 35000

var _navigation_map := RID()


func _init() -> void:
	var layout := _load_json_dictionary(LAYOUT_PATH)
	var rear_spatial := layout.get("rear_spatial", {}) as Dictionary
	var route := rear_spatial.get("merchant_route", {}) as Dictionary
	var raw_points := route.get("path_points", []) as Array
	if raw_points.size() != 6:
		_fail("T0132-P7R2 formal merchant route must contain six points")
		return
	var gate_2d := _v2(rear_spatial.get("back_gate", []))
	var dock_2d := _v2(route.get("dock", []))
	var approach_2d := _v2(raw_points[raw_points.size() - 2])
	var configured_clearance := float(route.get("dock_root_clearance_to_back_gate_m", 0.0))
	var root_clearance := dock_2d.distance_to(gate_2d)
	if absf(root_clearance - configured_clearance) > 0.05 or root_clearance < 6.5 or root_clearance > 7.5:
		_fail("T0132-P7R2 dock/root clearance drifted: %.3f" % root_clearance)
		return
	var approach_direction := (gate_2d - approach_2d).normalized()
	var dock_direction := (gate_2d - dock_2d).normalized()
	if approach_direction.dot(dock_direction) < 0.999:
		_fail("T0132-P7R2 dock no longer continues the existing rear approach line")
		return

	var world := Node3D.new()
	world.name = "MerchantRearGateDockTest"
	root.add_child(world)
	await process_frame
	var rear_gate := REAR_GATE_SCRIPT.new() as Node3D
	rear_gate.configure({
		"id": "back_gate",
		"display_name": "后门",
		"clear_width": 5.0,
		"height": 2.8
	})
	rear_gate.position = Vector3(gate_2d.x, 0.0, gate_2d.y)
	world.add_child(rear_gate)

	_navigation_map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(_navigation_map, 0.25)
	NavigationServer3D.map_set_cell_height(_navigation_map, 0.1)
	NavigationServer3D.map_set_active(_navigation_map, true)
	var region := NavigationRegion3D.new()
	region.name = "MerchantRearGateApproachNavigation"
	region.navigation_mesh = _make_route_mesh(approach_2d, dock_2d, float(route.get("corridor_half_width", 2.25)))
	world.add_child(region)
	region.set_navigation_map(_navigation_map)

	var wagon := WAGON_SCENE.instantiate() as MerchantWagon
	wagon.name = "DockRegressionWagon"
	wagon.position = Vector3(approach_2d.x, 0.12, approach_2d.y)
	world.add_child(wagon)
	await process_frame
	wagon.set_navigation_map(_navigation_map)
	if not wagon.configure_profile("merchant_wagon", {"profile": {"base_speed": 12.0, "acceleration": 30.0}}):
		_fail("T0132-P7R2 wagon test profile could not be applied")
		return
	for _i in 8:
		await physics_frame
	var dock := Vector3(dock_2d.x, 0.12, dock_2d.y)
	if not wagon.request_motion(dock, MerchantWagon.ARRIVAL_REQUEST):
		_fail("T0132-P7R2 wagon could not start the rear-gate approach")
		return
	if not await _wait_for_motion_state(wagon, "arrived"):
		_fail("T0132-P7R2 wagon did not physically reach the rear-gate dock: %s" % wagon.debug_get_motion_snapshot())
		return
	if wagon.global_position.distance_to(dock) > 0.35:
		_fail("T0132-P7R2 wagon root stopped outside dock tolerance")
		return

	var horse_collision := wagon.get_node_or_null("HorseBodyCollision") as CollisionShape3D
	var horse_shape := horse_collision.shape as BoxShape3D if horse_collision != null else null
	if horse_collision == null or horse_shape == null:
		_fail("T0132-P7R2 horse collision envelope is missing")
		return
	var gate_world := Vector3(gate_2d.x, horse_collision.global_position.y, gate_2d.y)
	var gate_direction := (gate_world - horse_collision.global_position).normalized()
	var horse_basis := horse_collision.global_transform.basis.orthonormalized()
	var projected_half_extent := (
		absf(gate_direction.dot(horse_basis.x)) * horse_shape.size.x * 0.5
		+ absf(gate_direction.dot(horse_basis.z)) * horse_shape.size.z * 0.5
	)
	var horse_front_clearance := horse_collision.global_position.distance_to(gate_world) - projected_half_extent
	if horse_front_clearance < 0.55 or horse_front_clearance > 1.8:
		_fail("T0132-P7R2 horse front is not just outside the rear gate: %.3f" % horse_front_clearance)
		return
	for _i in 70:
		await physics_frame
	var gate_snapshot := rear_gate.call("debug_get_snapshot") as Dictionary
	if not bool(gate_snapshot.get("friendly_near", false)) or float(gate_snapshot.get("open_fraction", 0.0)) < 0.85:
		_fail("T0132-P7R2 docked wagon did not keep the rear gate open: %s" % gate_snapshot)
		return

	if not wagon.request_motion(Vector3(approach_2d.x, 0.12, approach_2d.y), MerchantWagon.DEPARTURE_REQUEST):
		_fail("T0132-P7R2 wagon could not start departure")
		return
	if not await _wait_for_motion_state(wagon, "arrived"):
		_fail("T0132-P7R2 wagon did not return along the rear route")
		return
	print("T0132-P7R2 merchant rear-gate dock verification passed. root_clearance=%.3f horse_front_clearance=%.3f" % [root_clearance, horse_front_clearance])
	_cleanup_and_quit(0)


func _wait_for_motion_state(wagon: MerchantWagon, expected_state: String) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < MOTION_TIMEOUT_MSEC:
		await physics_frame
		if str(wagon.debug_get_motion_snapshot().get("state", "")) == expected_state:
			return true
	return false


func _make_route_mesh(from_point: Vector2, to_point: Vector2, half_width: float) -> NavigationMesh:
	var direction := (to_point - from_point).normalized()
	var side := Vector2(-direction.y, direction.x) * half_width
	var mesh := NavigationMesh.new()
	mesh.agent_radius = 1.1
	mesh.agent_height = 2.4
	mesh.set_vertices(PackedVector3Array([
		Vector3(from_point.x + side.x, 0.12, from_point.y + side.y),
		Vector3(from_point.x - side.x, 0.12, from_point.y - side.y),
		Vector3(to_point.x + side.x, 0.12, to_point.y + side.y),
		Vector3(to_point.x - side.x, 0.12, to_point.y - side.y)
	]))
	mesh.add_polygon(PackedInt32Array([0, 2, 3, 1]))
	return mesh


func _load_json_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _v2(raw: Variant) -> Vector2:
	if raw is Array and (raw as Array).size() >= 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return Vector2.ZERO


func _fail(message: String) -> void:
	push_error(message)
	_cleanup_and_quit(1)


func _cleanup_and_quit(code: int) -> void:
	if _navigation_map.is_valid():
		NavigationServer3D.free_rid(_navigation_map)
		_navigation_map = RID()
	quit(code)
