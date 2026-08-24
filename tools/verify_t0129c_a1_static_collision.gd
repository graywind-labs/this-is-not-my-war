extends SceneTree


const MAIN_PATH := "res://scenes/main/Main.tscn"
const LAYOUT_PATH := "res://data/station_layout.json"

var _failed := false


func _init() -> void:
	var layout := _load_json_dictionary(LAYOUT_PATH)
	var main_scene := load(MAIN_PATH) as PackedScene
	if layout.is_empty() or main_scene == null:
		_fail("T0129C-A1 inputs could not be loaded")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	for _step in 4:
		await process_frame
		await physics_frame

	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var formal_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout") as Node3D
	var building_roots := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/BuildingRoots")
	if controller == null or formal_root == null or building_roots == null:
		_fail("T0129C-A1 staging hierarchy is incomplete")
		return

	var snapshot: Dictionary = controller.debug_get_physics_navigation_snapshot()
	if str(snapshot.get("schema_version", "")) != "physics_navigation_v1":
		_fail("Unexpected physics/navigation schema: %s" % snapshot)
		return
	if int(snapshot.get("configuration_error_count", -1)) != 0:
		_fail("Physics/navigation configuration is invalid: %s" % snapshot)
		return
	if int(snapshot.get("world_static_layer", 0)) != 1 or int(snapshot.get("actor_body_layer", 0)) != 2:
		_fail("Collision layer contract drifted: %s" % snapshot)
		return
	if int(snapshot.get("interaction_layer", 0)) != 4:
		_fail("Interaction layer contract drifted: %s" % snapshot)
		return
	var npc_profile: Dictionary = snapshot.get("npc_profile", {})
	var foot_profile: Dictionary = snapshot.get("enemy_foot_profile", {})
	var mounted_profile: Dictionary = snapshot.get("enemy_mounted_profile", {})
	if not is_equal_approx(float(npc_profile.get("radius", 0.0)), 0.35):
		_fail("NPC capsule profile drifted: %s" % npc_profile)
		return
	if not is_equal_approx(float(foot_profile.get("radius", 0.0)), 0.42):
		_fail("Foot enemy capsule profile drifted: %s" % foot_profile)
		return
	if not is_equal_approx(float(mounted_profile.get("radius", 0.0)), 0.65):
		_fail("Mounted enemy capsule profile drifted: %s" % mounted_profile)
		return
	if not bool(snapshot.get("avoidance_enabled", false)) or int(snapshot.get("avoidance_max_neighbors", 0)) != 10:
		_fail("Local avoidance contract is missing: %s" % snapshot)
		return
	if not is_equal_approx(float(snapshot.get("production_cell_size", 0.0)), 0.25):
		_fail("Production navigation resolution drifted: %s" % snapshot)
		return
	if int(snapshot.get("static_body_count", 0)) != 234 or int(snapshot.get("collision_shape_count", 0)) != 234:
		_fail("Expected 78 structural blockers, 131 fixture collision parts, 24 natural blockers, and one production navigation floor: %s" % snapshot)
		return
	if int(snapshot.get("building_shell_count", 0)) != 60:
		_fail("Expected five wall bodies for each of 12 buildings: %s" % snapshot)
		return
	if int(snapshot.get("station_wall_count", 0)) != 14 or int(snapshot.get("gate_post_count", 0)) != 4:
		_fail("Station wall or gate-post collision count drifted: %s" % snapshot)
		return
	if int(snapshot.get("building_fixture_count", 0)) != 131 or int(snapshot.get("natural_boundary_count", 0)) != 24:
		_fail("Building fixture collision count drifted: %s" % snapshot)
		return
	if bool(snapshot.get("live_actor_bodies_migrated", true)):
		_fail("A1 must not claim that live NPC/enemy bodies are already migrated")
		return

	for raw_building in layout.get("buildings", []):
		var building: Dictionary = raw_building
		var building_id := str(building.get("id", ""))
		var building_root := building_roots.get_node_or_null(str(building.get("node_name", ""))) as Node3D
		var collision_root := building_root.get_node_or_null("StaticCollision") if building_root != null else null
		if building_root == null or collision_root == null or collision_root.get_child_count() != 5:
			_fail("Building shell is incomplete: %s" % building_id)
			return
		if not is_equal_approx(float(collision_root.get_meta("door_clear_width", 0.0)), 1.8):
			_fail("Building door width drifted: %s" % building_id)
			return
		for raw_body in collision_root.get_children():
			var body := raw_body as StaticBody3D
			if body == null or body.collision_layer != 1 or body.collision_mask != 2:
				_fail("Invalid static shell layer/mask: %s" % building_id)
				return
			var shape := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if shape == null or not shape.shape is BoxShape3D:
				_fail("Building shell must use auditable BoxShape3D: %s" % building_id)
				return

		var envelope := _v2(building.get("envelope_size", [1.0, 1.0]))
		var side_hit := _ray_world_static(
			building_root.to_global(Vector3(-envelope.x * 0.5 - 1.0, 0.8, 0.0)),
			building_root.to_global(Vector3(0.0, 0.8, 0.0))
		)
		if side_hit.is_empty() or str((side_hit.get("collider") as StaticBody3D).get_meta("collision_category", "")) != "building_wall":
			_fail("Side wall failed to block direct entry: %s" % building_id)
			return
		var door_hit := _ray_world_static(
			building_root.to_global(Vector3(0.0, 0.8, envelope.y * 0.5 + 1.0)),
			building_root.to_global(Vector3(0.0, 0.8, 0.0))
		)
		if not door_hit.is_empty():
			_fail("Formal door opening is physically blocked: %s / %s" % [building_id, door_hit])
			return

	var preview: Dictionary = controller.debug_set_preview_enabled(true)
	if not bool(preview.get("navigation_enabled", false)):
		_fail("Staged navigation did not enable for A1 verification")
		return
	for _preview_step in 4:
		await process_frame
		await physics_frame
	var navigation_region := formal_root.get_node("SpatialContract/StationNavigation") as NavigationRegion3D
	var navigation_map := navigation_region.get_navigation_map()
	NavigationServer3D.map_force_update(navigation_map)
	var building_path_count := 0
	for raw_building in layout.get("buildings", []):
		var building_id := str((raw_building as Dictionary).get("id", ""))
		var route: Dictionary = controller.get_building_spatial_route(building_id)
		var path := NavigationServer3D.map_get_path(
			navigation_map,
			route.get("entry_outside_position", Vector3.ZERO),
			route.get("interior_target_position", Vector3.ZERO),
			true
		)
		if path.is_empty():
			_fail("Godot navigation cannot pass the formal door: %s" % building_id)
			return
		building_path_count += 1
	if building_path_count != 12:
		_fail("Expected 12 verified building door paths")
		return
	controller.debug_set_preview_enabled(false)

	print("T0129C A1 static collision verification passed: %s" % JSON.stringify(snapshot))
	quit(0)


func _ray_world_static(from_position: Vector3, to_position: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from_position, to_position, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return root.world_3d.direct_space_state.intersect_ray(query)


func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}


func _v2(value: Variant) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
