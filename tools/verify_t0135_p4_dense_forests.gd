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
	for _frame in range(8):
		await process_frame
	var snapshot := view.call("get_debug_snapshot") as Dictionary
	if str(snapshot.get("art_revision", "")) != "t0135_p7":
		_fail("P4 environment identity is missing")
		return
	var forest := snapshot.get("forest", {}) as Dictionary
	if str(forest.get("art_revision", "")) != "t0135_p7":
		_fail("P4 forest view is not active: %s" % str(forest))
		return
	var trees := forest.get("tree_counts", {}) as Dictionary
	if int(forest.get("total_tree_count", 0)) < 5000 or int(trees.get("front", 0)) < 2000 or int(trees.get("rear", 0)) < 2200 or int(trees.get("side", 0)) < 250:
		_fail("Forest density is below the hard contract: %s" % str(forest))
		return
	var variants := forest.get("tree_variant_counts", {}) as Dictionary
	if variants.has("common") or variants.has("pine") or int(variants.get("slender_pine", 0)) < 1000 or int(variants.get("layered_pine", 0)) < 1000 or int(variants.get("broad_fir", 0)) < 1000:
		_fail("Unified conifer silhouettes are incomplete or legacy leafy trees remain: %s" % str(variants))
		return
	var bushes := forest.get("bush_counts", {}) as Dictionary
	if int(forest.get("total_bush_count", 0)) < 2500 or int(bushes.get("side", 0)) < 150:
		_fail("Forest undergrowth is too sparse: %s" % str(forest))
		return
	var chunks := forest.get("chunk_counts", {}) as Dictionary
	if not is_equal_approx(float(forest.get("chunk_size", 0.0)), 40.0) or int(chunks.get("front", 0)) < 80 or int(chunks.get("rear", 0)) < 80 or int(chunks.get("side", 0)) < 20:
		_fail("Forest is not split into independently cullable chunks: %s" % str(forest))
		return
	var front_bounds := forest.get("front_bounds", Rect2()) as Rect2
	var rear_bounds := forest.get("rear_bounds", Rect2()) as Rect2
	var side_bounds := forest.get("side_bounds", Rect2()) as Rect2
	if front_bounds.position.x > -350.0 or front_bounds.end.x < 350.0 or front_bounds.end.y < 385.0 or rear_bounds.position.y > -385.0 or rear_bounds.end.x < 350.0 or side_bounds.position.y > -60.0 or side_bounds.end.y < 70.0:
		_fail("Forest does not continue to the map and mountain edges: %s / %s" % [front_bounds, rear_bounds])
		return
	if int(forest.get("spawn_clear_tree_count", -1)) != 0 or int(forest.get("spawn_screen_tree_count", 0)) < 70:
		_fail("Enemy spawn clearing or visual screen is invalid: %s" % str(forest))
		return
	if float(forest.get("minimum_corridor_clearance", 0.0)) < 5.19:
		_fail("A forest trunk entered a formal travel corridor: %s" % str(forest))
		return
	if float(forest.get("minimum_station_clearance", 0.0)) < 7.99:
		_fail("A tree entered the station wall clearance: %s" % str(forest))
		return
	if float(forest.get("mountain_tree_density_factor", 1.0)) > 0.20 or int(forest.get("mountain_tree_count", 0)) <= 0 or int(forest.get("riverbank_tree_count", 0)) <= 0:
		_fail("Terrain-specific sparse forest rules are missing: %s" % str(forest))
		return
	var density_counts := forest.get("station_density_counts", {}) as Dictionary
	if int(density_counts.get("near", 0)) <= 0 or int(density_counts.get("transition", 0)) <= int(density_counts.get("near", 0)) or int(density_counts.get("far", 0)) <= int(density_counts.get("transition", 0)):
		_fail("Station-to-wilderness density gradient is not readable: %s" % str(density_counts))
		return
	if not (forest.get("missing_assets", []) as Array).is_empty():
		_fail("Forest assets are missing: %s" % str(forest))
		return
	if bool(forest.get("has_collision", true)) or bool(forest.get("has_static_body", true)) or bool(forest.get("has_navigation_region", true)) or bool(forest.get("has_interaction_area", true)):
		_fail("P4 forest presentation introduced gameplay authority")
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
	if not natural_root.find_children("*Trunk*", "MeshInstance3D", true, false).is_empty() or not natural_root.find_children("*Crown*", "MeshInstance3D", true, false).is_empty():
		_fail("Legacy sparse forest visuals remain active")
		return
	var forest_collision_count := 0
	for body in natural_root.find_children("*", "StaticBody3D", true, false):
		if str(body.get_meta("natural_kind", "")) != "dense_forest":
			continue
		forest_collision_count += 1
		if not bool(body.get_meta("legacy_dense_forest_tree_visuals_suppressed", false)):
			_fail("Dense-forest collision lost its visual handover marker")
			return
	if forest_collision_count != 12:
		_fail("Existing twelve dense-forest collision segments changed: %d" % forest_collision_count)
		return
	var integrated_view := formal_root.get_node_or_null("FormalEnvironmentArtView") as Node3D
	var integrated_forest := (integrated_view.call("get_debug_snapshot") as Dictionary).get("forest", {}) as Dictionary if integrated_view != null else {}
	if int(integrated_forest.get("total_tree_count", 0)) < 5000:
		_fail("Dense forest is not integrated into Main")
		return
	print("T0135-P4 dense forest verification passed: %s" % str({
		"trees": trees,
		"variants": variants,
		"bushes": bushes,
		"chunks": chunks,
		"spawn_screen": forest.get("spawn_screen_tree_count"),
		"mountain_trees": forest.get("mountain_tree_count"),
		"riverbank_trees": forest.get("riverbank_tree_count"),
		"station_density": density_counts,
		"minimum_clearance": forest.get("minimum_corridor_clearance"),
		"forest_collisions": forest_collision_count
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
