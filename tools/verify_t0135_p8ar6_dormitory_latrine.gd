extends SceneTree


const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const LATRINE_SPECS := [
	{"path": "Main/WorldRoot/FormalStationLayout/PublicProps/DormitoryLatrine", "id": "dormitory_latrine", "position": Vector3(-47.0, 0.0, -10.0)},
	{"path": "Main/WorldRoot/FormalStationLayout/PublicProps/DormitoryLatrine02", "id": "dormitory_latrine_02", "position": Vector3(-47.0, 0.0, -13.6)}
]


func _init() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		_fail("Main.tscn unavailable")
		return
	var main := packed.instantiate()
	var daily_plan_system := main.get_node_or_null("Systems/DailyPlanSystem")
	if daily_plan_system != null:
		daily_plan_system.set_auto_execution_enabled(false)
	root.add_child(main)
	for _frame in range(8):
		await process_frame
		await physics_frame

	var world_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout") as Node3D
	if world_root == null:
		_fail("Formal station root unavailable")
		return
	var dormitory_bounds := AABB(Vector3(-40.5, 0.0, -16.0), Vector3(13.0, 8.0, 14.0))
	var garden_bounds := AABB(Vector3(-48.0, 0.0, 4.0), Vector3(12.0, 5.0, 12.0))
	var world_bounds_list: Array[AABB] = []
	var minimum_wall_clearance := INF
	for spec_value in LATRINE_SPECS:
		var spec := spec_value as Dictionary
		var latrine := root.get_node_or_null(str(spec.get("path", ""))) as Node3D
		if not _verify_latrine(latrine, spec, world_root, dormitory_bounds, garden_bounds):
			return
		world_bounds_list.append(_subtree_bounds_in_space(latrine, world_root, true))
		var expected_position := spec.get("position", Vector3.ZERO) as Vector3
		minimum_wall_clearance = minf(
			minimum_wall_clearance,
			_distance_to_segment(Vector2(expected_position.x, expected_position.z), Vector2(-56.0, -7.0), Vector2(-53.0, -41.0)) - 1.70 - 0.60
		)
	var first_bounds := world_bounds_list[0]
	var second_bounds := world_bounds_list[1]
	var structure_gap := first_bounds.position.z - second_bounds.end.z
	if structure_gap < 0.10 or structure_gap > 0.30 or first_bounds.intersects(second_bounds):
		_fail("Twin latrines are not tightly side-by-side with a clean structure gap: %.3f" % structure_gap)
		return
	if minimum_wall_clearance < 4.0:
		_fail("Twin latrines leave insufficient clearance to the west stockade: %.3f" % minimum_wall_clearance)
		return
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var building_ids := building_system.call("get_building_ids") as Array if building_system != null else []
	if building_system == null or building_ids.has("dormitory_latrine") or building_ids.has("dormitory_latrine_02"):
		_fail("Twin dormitory latrines must not be registered as BuildingSystem buildings")
		return

	print("T0135-P8AR6R twin dormitory latrine verification passed: %s" % JSON.stringify({
		"latrine_count": world_bounds_list.size(),
		"positions": [LATRINE_SPECS[0].get("position"), LATRINE_SPECS[1].get("position")],
		"structure_gap_m": structure_gap,
		"minimum_wall_clearance_m": minimum_wall_clearance,
		"enterable": false,
		"interactive": false,
		"functional": false,
		"navigation_obstacle": true
	}))
	main.queue_free()
	await process_frame
	quit(0)


func _verify_latrine(latrine: Node3D, spec: Dictionary, world_root: Node3D, dormitory_bounds: AABB, garden_bounds: AABB) -> bool:
	if latrine == null:
		_fail("Dormitory latrine is missing: %s" % str(spec.get("path", "")))
		return false
	var expected_position := spec.get("position", Vector3.ZERO) as Vector3
	if latrine.position.distance_to(expected_position) > 0.01 or absf(latrine.rotation_degrees.y - 90.0) > 0.01:
		_fail("Dormitory latrine placement drifted: %s / %s" % [latrine.position, latrine.rotation_degrees])
		return false
	if (
		str(latrine.get_meta("layout_id", "")) != str(spec.get("id", ""))
		or str(latrine.get_meta("outbuilding_type", "")) != "latrine"
		or str(latrine.get_meta("authority_role", "")) != "presentation_only_noninteractive_outbuilding"
		or bool(latrine.get_meta("has_interior", true))
		or bool(latrine.get_meta("enterable", true))
		or bool(latrine.get_meta("interactive", true))
		or bool(latrine.get_meta("functional", true))
		or bool(latrine.get_meta("roof_fade_member", true))
	):
		_fail("Dormitory latrine gained interior, interaction or gameplay authority")
		return false
	for path in [
		"StoneFoundation/FoundationCore",
		"ClosedExteriorShell/RearPlasterWall",
		"OakTimberFrame/CornerPost",
		"ClosedPlankDoor/DoorPlank01",
		"ClosedPlankDoor/CrescentVentDark",
		"PermanentOpaqueRoof/WestRoofPlane",
		"PermanentOpaqueRoof/EastRoofPlane",
		"RoofVentilation/VentPipe",
		"RoofVentilation/RearLouverDark"
	]:
		if latrine.get_node_or_null(path) == null:
			_fail("Dormitory latrine lacks required exterior element: %s" % path)
			return false
	if (
		not latrine.find_children("*", "Area3D", true, false).is_empty()
		or not latrine.find_children("*", "Light3D", true, false).is_empty()
		or not latrine.find_children("*", "AnimationPlayer", true, false).is_empty()
	):
		_fail("Dormitory latrine unexpectedly gained Area3D, light or animation")
		return false
	var collision := latrine.get_node_or_null("StaticCollision") as StaticBody3D
	var collision_shape := collision.get_node_or_null("CollisionShape3D") as CollisionShape3D if collision != null else null
	var box := collision_shape.shape as BoxShape3D if collision_shape != null else null
	if (
		collision == null
		or box == null
		or box.size.distance_to(Vector3(2.8, 3.2, 2.4)) > 0.01
		or str(collision.get_meta("collision_category", "")) != "service_outbuilding_latrine"
		or str(collision.get_meta("navigation_role", "")) != "solid_non_enterable_outbuilding"
		or not collision.is_in_group("formal_navigation_source")
	):
		_fail("Dormitory latrine static collision/navigation contract is invalid")
		return false
	var local_bounds := _subtree_bounds_in_space(latrine, latrine, true)
	var world_bounds := _subtree_bounds_in_space(latrine, world_root, true)
	if (
		not local_bounds.has_volume()
		or local_bounds.position.x < -1.80
		or local_bounds.end.x > 1.80
		or local_bounds.position.z < -1.70
		or local_bounds.end.z > 1.70
		or local_bounds.position.y < -0.01
		or local_bounds.end.y > 4.10
		or world_bounds.intersects(dormitory_bounds)
		or world_bounds.intersects(garden_bounds)
	):
		_fail("Dormitory latrine bounds escaped or overlap a building envelope: %s / %s" % [local_bounds, world_bounds])
		return false
	return true


func _subtree_bounds_in_space(root_node: Node, space: Node3D, visible_only: bool) -> AABB:
	var points: Array[Vector3] = []
	var nodes: Array[Node] = [root_node]
	while not nodes.is_empty():
		var current: Node = nodes.pop_back()
		for child in current.get_children():
			nodes.append(child)
		if current is MeshInstance3D:
			var mesh_node := current as MeshInstance3D
			if mesh_node.mesh == null or (visible_only and not mesh_node.is_visible_in_tree()):
				continue
			var mesh_bounds := mesh_node.mesh.get_aabb()
			for x_index in range(2):
				for y_index in range(2):
					for z_index in range(2):
						var corner := mesh_bounds.position + Vector3(
							mesh_bounds.size.x * float(x_index),
							mesh_bounds.size.y * float(y_index),
							mesh_bounds.size.z * float(z_index)
						)
						points.append(space.to_local(mesh_node.to_global(corner)))
	if points.is_empty():
		return AABB()
	var min_point := points[0]
	var max_point := points[0]
	for point in points:
		min_point = min_point.min(point)
		max_point = max_point.max(point)
	return AABB(min_point, max_point - min_point)


func _distance_to_segment(point: Vector2, first: Vector2, second: Vector2) -> float:
	var delta := second - first
	if delta.length_squared() <= 0.000001:
		return point.distance_to(first)
	var t := clampf((point - first).dot(delta) / delta.length_squared(), 0.0, 1.0)
	return point.distance_to(first + delta * t)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
