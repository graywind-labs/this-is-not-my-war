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
		_fail("P2 environment identity is missing")
		return
	var terrain := snapshot.get("terrain_topology", {}) as Dictionary
	if str(terrain.get("art_revision", "")) != "t0135_p7" or int(terrain.get("profile_sample_count", 0)) < 10:
		_fail("River profile is incomplete: %s" % str(terrain))
		return
	if float(terrain.get("minimum_valley_width", 0.0)) < 24.0 or float(terrain.get("maximum_valley_width", 99.0)) > 34.0:
		_fail("River-valley width left the 24-34 m contract: %s" % str(terrain))
		return
	if float(terrain.get("minimum_water_width", 0.0)) < 7.0 or float(terrain.get("maximum_water_width", 99.0)) > 11.0:
		_fail("Water width left the 7-11 m contract: %s" % str(terrain))
		return
	if not is_equal_approx(float(terrain.get("river_start_z", 0.0)), -335.0) or not is_equal_approx(float(terrain.get("river_end_z", 0.0)), 385.0):
		_fail("River does not continue through the full terrain edge envelope")
		return
	if not is_equal_approx(float(terrain.get("ground_surface_y", 99.0)), 0.0) or not is_equal_approx(float(terrain.get("water_surface_y", 99.0)), -1.2):
		_fail("River elevation contract drifted: %s" % str(terrain))
		return
	if int(terrain.get("plateau_triangle_count", 0)) < 80 or int(terrain.get("bank_triangle_count", 0)) < 300:
		_fail("Disconnected banks or terraced slopes are incomplete: %s" % str(terrain))
		return
	if int(terrain.get("water_triangle_count", 0)) < 20 or int(terrain.get("foam_triangle_count", 0)) < 40:
		_fail("Animated water or bank foam is incomplete: %s" % str(terrain))
		return
	if int(terrain.get("riverbank_rock_count", 0)) < 30 or not (terrain.get("missing_assets", []) as Array).is_empty():
		_fail("Riverbank rock breakup is incomplete: %s" % str(terrain))
		return
	if int(terrain.get("cross_water_ground_surface_count", -1)) != 0:
		_fail("A ground surface still crosses the river")
		return
	if bool(terrain.get("has_collision", true)) or bool(terrain.get("has_static_body", true)) or bool(terrain.get("has_navigation_region", true)) or bool(terrain.get("has_interaction_area", true)):
		_fail("P2 visible terrain introduced gameplay authority")
		return

	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _frame in range(8):
		await process_frame
		await physics_frame
	var formal_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout") as Node3D
	if formal_root == null:
		_fail("Formal station root is missing")
		return
	var terrain_root := formal_root.get_node_or_null("Terrain") as Node3D
	if terrain_root == null or not bool(terrain_root.get_meta("formal_terrain_topology_active", false)):
		_fail("Legacy terrain was not handed over to the formal topology")
		return
	for node_name in ["WestGround", "EastGround", "RiverSurface"]:
		var legacy := terrain_root.get_node_or_null(node_name) as MeshInstance3D
		if legacy == null or legacy.visible or not bool(legacy.get_meta("legacy_terrain_visual_suppressed", false)):
			_fail("Legacy terrain visual remains active: %s" % node_name)
			return
	var natural_root := formal_root.get_node_or_null("NaturalBoundaries") as Node3D
	if natural_root == null:
		_fail("Natural boundary authority is missing")
		return
	if not natural_root.find_children("*CliffFace", "MeshInstance3D", true, false).is_empty() or not natural_root.find_children("*RockLip", "MeshInstance3D", true, false).is_empty():
		_fail("Legacy river-cliff box visuals remain active")
		return
	if not natural_root.find_children("*Understory", "MeshInstance3D", true, false).is_empty():
		_fail("Legacy forest floor boxes still cross the river valley")
		return
	var river_collision_count := 0
	for body in natural_root.find_children("*", "StaticBody3D", true, false):
		if str(body.get_meta("natural_kind", "")) != "river_cliff":
			continue
		river_collision_count += 1
		if not bool(body.get_meta("legacy_river_cliff_visual_suppressed", false)):
			_fail("River collision lost its visual handover marker")
			return
	if river_collision_count != 8:
		_fail("Existing eight river-cliff collision segments changed: %d" % river_collision_count)
		return
	var integrated_view := formal_root.get_node_or_null("FormalEnvironmentArtView") as Node3D
	if integrated_view == null:
		_fail("Formal terrain is not integrated into Main")
		return
	var integrated_terrain := (integrated_view.call("get_debug_snapshot") as Dictionary).get("terrain_topology", {}) as Dictionary
	if int(integrated_terrain.get("cross_water_ground_surface_count", -1)) != 0:
		_fail("Main integration restored cross-water ground")
		return
	print("T0135-P2 formal river-valley verification passed: %s" % str({
		"samples": terrain.get("profile_sample_count"),
		"valley_width": [terrain.get("minimum_valley_width"), terrain.get("maximum_valley_width")],
		"water_width": [terrain.get("minimum_water_width"), terrain.get("maximum_water_width")],
		"plateau_triangles": terrain.get("plateau_triangle_count"),
		"bank_triangles": terrain.get("bank_triangle_count"),
		"river_collisions": river_collision_count
	}))
	quit(0)


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
