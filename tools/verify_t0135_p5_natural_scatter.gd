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
		_fail("P5 environment identity is missing")
		return
	var scatter := snapshot.get("natural_scatter", {}) as Dictionary
	if str(scatter.get("art_revision", "")) != "t0135_p7":
		_fail("P5 natural scatter view is not active: %s" % str(scatter))
		return
	var zones := scatter.get("zone_counts", {}) as Dictionary
	for zone in ["riverbank", "mountain_foot", "forest_understory", "road_edge", "station_open"]:
		if not zones.has(zone):
			_fail("Missing natural scatter zone: %s" % zone)
			return
		var zone_total := 0
		for count in (zones[zone] as Dictionary).values():
			zone_total += int(count)
		if zone_total < _minimum_zone_count(zone):
			_fail("Natural scatter zone is too sparse: %s=%d" % [zone, zone_total])
			return
	if int(scatter.get("total_instance_count", 0)) < 3500:
		_fail("Full-map natural scatter density is below contract: %s" % str(scatter))
		return
	var patches := scatter.get("patch_counts", {}) as Dictionary
	if int(patches.get("riverbank", 0)) < 30 or int(patches.get("mountain_foot", 0)) < 20 or int(patches.get("road_edge", 0)) < 8:
		_fail("Ground transitions are incomplete: %s" % str(patches))
		return
	if int(scatter.get("river_channel_intrusions", -1)) != 0:
		_fail("Natural detail entered the river channel: %s" % str(scatter))
		return
	if int(scatter.get("road_core_intrusions", -1)) != 0:
		_fail("Natural detail entered a formal road core: %s" % str(scatter))
		return
	if int(scatter.get("building_lot_intrusions", -1)) != 0 or int(scatter.get("plaza_intrusions", -1)) != 0:
		_fail("Natural detail entered a building lot or plaza gathering clearance: %s" % str(scatter))
		return
	if float(scatter.get("minimum_formal_route_clearance", 0.0)) < 4.79:
		_fail("Full-map scatter entered an enemy, merchant, or escape corridor: %s" % str(scatter))
		return
	if bool(scatter.get("has_collision", true)) or bool(scatter.get("has_static_body", true)) or bool(scatter.get("has_navigation_region", true)) or bool(scatter.get("has_interaction_area", true)):
		_fail("P5 scatter introduced gameplay authority")
		return

	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _frame in range(8):
		await process_frame
		await physics_frame
	var formal_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout") as Node3D
	var integrated_view := formal_root.get_node_or_null("FormalEnvironmentArtView") as Node3D if formal_root != null else null
	var integrated_scatter := (integrated_view.call("get_debug_snapshot") as Dictionary).get("natural_scatter", {}) as Dictionary if integrated_view != null else {}
	if int(integrated_scatter.get("total_instance_count", 0)) < 3500:
		_fail("P5 natural scatter is not integrated into Main")
		return
	print("T0135-P5 natural scatter verification passed: %s" % str({
		"zones": zones,
		"patches": patches,
		"instances": scatter.get("total_instance_count"),
		"minimum_route_clearance": scatter.get("minimum_formal_route_clearance")
	}))
	quit(0)


func _minimum_zone_count(zone: String) -> int:
	return {
		"riverbank": 500,
		"mountain_foot": 650,
		"forest_understory": 2200,
		"road_edge": 100,
		"station_open": 150
	}.get(zone, 1)


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
