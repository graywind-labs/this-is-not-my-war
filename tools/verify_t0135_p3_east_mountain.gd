extends SceneTree

const LAYOUT_PATH := "res://data/station_layout.json"
const ENVIRONMENT_PATH := "res://data/presentation/environment_art.json"
const ENVIRONMENT_SCENE := preload("res://scenes/environment/FormalEnvironmentArtView.tscn")


func _init() -> void:
	var layout := _load_json(LAYOUT_PATH)
	var environment_config := _load_json(ENVIRONMENT_PATH)
	var view := ENVIRONMENT_SCENE.instantiate() as Node3D
	view.call("configure", environment_config, layout)
	root.add_child(view)
	for _frame in range(5):
		await process_frame
	var snapshot := view.call("get_debug_snapshot") as Dictionary
	if str(snapshot.get("art_revision", "")) != "t0135_p7":
		_fail("P3 environment identity is missing")
		return
	var terrain := snapshot.get("terrain_topology", {}) as Dictionary
	if str(terrain.get("art_revision", "")) != "t0135_p7" or int(terrain.get("mountain_profile_sample_count", 0)) < 17:
		_fail("East mountain profile is incomplete: %s" % str(terrain))
		return
	if float(terrain.get("mountain_start_z", 0.0)) > -360.0 or float(terrain.get("mountain_end_z", 0.0)) < 385.0:
		_fail("East mountain does not continue beyond both camera edges")
		return
	var ranges := terrain.get("mountain_x_ranges", {}) as Dictionary
	if not _range_matches(ranges.get("near", Vector2.ZERO), 120.0, 175.0):
		_fail("Near mountain range drifted: %s" % str(ranges))
		return
	if not _range_matches(ranges.get("mid", Vector2.ZERO), 165.0, 255.0):
		_fail("Mid mountain range drifted: %s" % str(ranges))
		return
	var far_range := ranges.get("far", Vector2.ZERO) as Vector2
	if far_range.x > 235.0 or far_range.y < 350.0:
		_fail("Far mountain does not extend outside the map: %s" % str(ranges))
		return
	var heights := terrain.get("mountain_max_heights", {}) as Dictionary
	if float(heights.get("near", 0.0)) < 4.0 or float(heights.get("near", 99.0)) > 8.0:
		_fail("Near mountain height left the 4-8 m contract: %s" % str(heights))
		return
	if float(heights.get("mid", 0.0)) < 10.0 or float(heights.get("mid", 99.0)) > 18.0:
		_fail("Mid mountain height left the 10-18 m contract: %s" % str(heights))
		return
	if float(heights.get("far", 0.0)) < 18.0 or float(heights.get("far", 99.0)) > 35.0:
		_fail("Far mountain height left the 18-35 m contract: %s" % str(heights))
		return
	var triangles := terrain.get("mountain_triangle_counts", {}) as Dictionary
	for layer_name in ["near", "mid", "far"]:
		if int(triangles.get(layer_name, 0)) < 96:
			_fail("Mountain layer is under-modeled: %s" % str(triangles))
			return
	if int(terrain.get("mountain_boulder_count", 0)) < 40 or not (terrain.get("missing_assets", []) as Array).is_empty():
		_fail("Mountain rock breakup is incomplete: %s" % str(terrain))
		return
	if bool(terrain.get("has_collision", true)) or bool(terrain.get("has_static_body", true)) or bool(terrain.get("has_navigation_region", true)) or bool(terrain.get("has_interaction_area", true)):
		_fail("P3 visible mountain introduced gameplay authority")
		return

	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _frame in range(8):
		await process_frame
		await physics_frame
	var formal_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout") as Node3D
	var natural_root := formal_root.get_node_or_null("NaturalBoundaries") as Node3D if formal_root != null else null
	if natural_root == null:
		_fail("Natural boundary authority is missing")
		return
	if not natural_root.find_children("*RidgeMass", "MeshInstance3D", true, false).is_empty() or not natural_root.find_children("*RidgeCrown", "MeshInstance3D", true, false).is_empty():
		_fail("Legacy east ridge box visuals remain active")
		return
	var ridge_collision_count := 0
	for body in natural_root.find_children("*", "StaticBody3D", true, false):
		if str(body.get_meta("natural_kind", "")) != "rock_ridge":
			continue
		ridge_collision_count += 1
		if not bool(body.get_meta("legacy_rock_ridge_visual_suppressed", false)):
			_fail("Rock-ridge collision lost its visual handover marker")
			return
	if ridge_collision_count != 4:
		_fail("Existing four rock-ridge collision segments changed: %d" % ridge_collision_count)
		return
	var integrated_view := formal_root.get_node_or_null("FormalEnvironmentArtView") as Node3D
	var integrated_terrain := (integrated_view.call("get_debug_snapshot") as Dictionary).get("terrain_topology", {}) as Dictionary if integrated_view != null else {}
	if int(integrated_terrain.get("mountain_profile_sample_count", 0)) < 17:
		_fail("East mountain is not integrated into Main")
		return
	print("T0135-P3 east mountain verification passed: %s" % str({
		"samples": terrain.get("mountain_profile_sample_count"),
		"ranges": ranges,
		"heights": heights,
		"triangles": triangles,
		"boulders": terrain.get("mountain_boulder_count"),
		"ridge_collisions": ridge_collision_count
	}))
	quit(0)


func _range_matches(value: Variant, expected_min: float, expected_max: float) -> bool:
	var actual := value as Vector2
	return is_equal_approx(actual.x, expected_min) and is_equal_approx(actual.y, expected_max)


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
