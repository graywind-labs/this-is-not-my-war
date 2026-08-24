extends SceneTree


const MAIN_PATH := "res://scenes/main/Main.tscn"
const LAYOUT_PATH := "res://data/station_layout.json"

var _failed := false


func _init() -> void:
	var layout := _load_json_dictionary(LAYOUT_PATH)
	var main_scene := load(MAIN_PATH) as PackedScene
	if layout.is_empty() or main_scene == null:
		_fail("T0129C-A3a inputs could not be loaded")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	await physics_frame

	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var formal_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout") as Node3D
	var navigation_region := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/SpatialContract/StationNavigation"
	) as NavigationRegion3D
	if controller == null or formal_root == null or navigation_region == null:
		_fail("T0129C-A3a formal navigation hierarchy is incomplete")
		return

	var production: Dictionary = controller.debug_get_production_navigation_snapshot()
	if not bool(production.get("available", false)):
		_fail("Production navigation mesh was not generated: %s" % production)
		return
	if str(production.get("navigation_kind", "")) != "production_static_collider_bake":
		_fail("Production navigation is not a static-collider bake: %s" % production)
		return
	if str(production.get("source_geometry_mode", "")) != "static_colliders":
		_fail("Production navigation source contract drifted: %s" % production)
		return
	if int(production.get("geometry_parsed_geometry_type", -1)) != NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS:
		_fail("NavigationMesh is not parsing StaticBody3D colliders: %s" % production)
		return
	if int(production.get("geometry_source_geometry_mode", -1)) != NavigationMesh.SOURCE_GEOMETRY_GROUPS_EXPLICIT:
		_fail("NavigationMesh source group mode drifted: %s" % production)
		return
	if not is_equal_approx(float(production.get("cell_size", 0.0)), 0.25):
		_fail("Production cell size must remain 0.25 m: %s" % production)
		return
	if not is_equal_approx(float(production.get("cell_height", 0.0)), 0.1):
		_fail("Production cell height must remain 0.1 m: %s" % production)
		return
	if not is_equal_approx(float(production.get("requested_agent_radius", 0.0)), 0.35):
		_fail("NPC physical radius contract drifted: %s" % production)
		return
	if not is_equal_approx(float(production.get("agent_radius", 0.0)), 0.5):
		_fail("Recast radius must stay conservatively aligned to two 0.25 m voxels: %s" % production)
		return
	if int(production.get("polygon_count", 0)) < 100 or int(production.get("vertex_count", 0)) < 100:
		_fail("Production bake produced implausibly little navigation geometry: %s" % production)
		return
	if int(production.get("bake_msec", -1)) < 0:
		_fail("Production bake timing was not recorded: %s" % production)
		return
	if int(production.get("building_door_link_count", 0)) != 12:
		_fail("Production map must expose one explicit transition per building door: %s" % production)
		return
	if int(production.get("enabled_building_door_link_count", -1)) != 0:
		_fail("Staged building links must remain disabled outside preview: %s" % production)
		return
	if not is_equal_approx(float(production.get("contract_grid_cell_size", 0.0)), 0.5):
		_fail("The deterministic 0.5 m contract grid must remain available as a separate oracle: %s" % production)
		return

	var source_group_name := str(production.get("source_group_name", ""))
	var source_bodies := get_nodes_in_group(source_group_name)
	if source_bodies.size() != 234:
		_fail("Expected 78 structural blockers, 131 fixture collision parts, 24 natural blockers, and one floor in the production source group: %d" % source_bodies.size())
		return
	var category_counts: Dictionary = {}
	for raw_body in source_bodies:
		var body := raw_body as StaticBody3D
		if body == null or body.collision_layer != 1:
			_fail("Production source contains a non-static or wrong-layer node")
			return
		var category := str(body.get_meta("collision_category", "unknown"))
		category_counts[category] = int(category_counts.get(category, 0)) + 1
	if int(category_counts.get("navigation_floor", 0)) != 1:
		_fail("Production bake floor count drifted: %s" % category_counts)
		return
	if int(category_counts.get("building_fixture", 0)) != 131:
		_fail("Building fixture bake-source count drifted: %s" % category_counts)
		return
	if int(category_counts.get("natural_river_cliff", 0)) != 8 or int(category_counts.get("natural_rock_ridge", 0)) != 4 or int(category_counts.get("natural_dense_forest", 0)) != 12:
		_fail("Natural collision bake-source counts drifted: %s" % category_counts)
		return

	controller.debug_set_preview_enabled(true)
	for _step in 4:
		await process_frame
		await physics_frame
	var navigation_map := navigation_region.get_navigation_map()
	NavigationServer3D.map_force_update(navigation_map)
	production = controller.debug_get_production_navigation_snapshot()
	if int(production.get("enabled_building_door_link_count", 0)) != 12:
		_fail("Preview did not enable every production door link: %s" % production)
		return
	var verified_doors := 0
	for raw_building in layout.get("buildings", []):
		var building: Dictionary = raw_building
		var building_id := str(building.get("id", ""))
		var building_root := formal_root.get_node(
			"BuildingRoots/%s" % str(building.get("node_name", ""))
		) as Node3D
		var envelope := _v2(building.get("envelope_size", [1.0, 1.0]))
		var route: Dictionary = controller.get_building_spatial_route(building_id)
		var side_source := building_root.to_global(Vector3(-envelope.x * 0.5 - 2.0, 0.12, 0.0))
		var target: Vector3 = route.get("interior_target_position", Vector3.ZERO)
		var path := NavigationServer3D.map_get_path(navigation_map, side_source, target, true)
		if path.size() < 3:
			_fail("Production navigation did not route around the side wall: %s / %s" % [building_id, path])
			return
		if not _path_crosses_front_door(building_root, path, envelope, 1.8):
			_fail("Production path did not enter through the real front door: %s / %s" % [building_id, path])
			return
		verified_doors += 1
	controller.debug_set_preview_enabled(false)
	if verified_doors != 12:
		_fail("Expected all 12 real doors to be verified")
		return

	print("T0129C A3a production navigation verification passed: %s" % JSON.stringify({
		"production": production,
		"source_categories": category_counts,
		"verified_doors": verified_doors
	}))
	quit(0)


func _path_crosses_front_door(
	building_root: Node3D,
	path: PackedVector3Array,
	envelope: Vector2,
	door_width: float
) -> bool:
	var front_z := envelope.y * 0.5
	for index in range(path.size() - 1):
		var from_local := building_root.to_local(path[index])
		var to_local := building_root.to_local(path[index + 1])
		var from_delta := from_local.z - front_z
		var to_delta := to_local.z - front_z
		if from_delta * to_delta > 0.0 or is_equal_approx(from_local.z, to_local.z):
			continue
		var weight := (front_z - from_local.z) / (to_local.z - from_local.z)
		if weight < 0.0 or weight > 1.0:
			continue
		var crossing_x := lerpf(from_local.x, to_local.x, weight)
		if absf(crossing_x) <= door_width * 0.5 + 0.2:
			return true
	return false


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
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
