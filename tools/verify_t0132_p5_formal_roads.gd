extends SceneTree

const LAYOUT_PATH := "res://data/station_layout.json"
const ROAD_SCRIPT := preload("res://scripts/presentation/environment/FormalRoadNetworkArtView.gd")


func _init() -> void:
	var layout := _load_json(LAYOUT_PATH)
	var roads: Array = layout.get("roads", [])
	if roads.size() != 42:
		_fail("Accepted station road count drifted before visual projection")
		return
	var road_view := ROAD_SCRIPT.new() as Node3D
	road_view.configure(roads)
	root.add_child(road_view)
	await process_frame
	await process_frame
	var snapshot: Dictionary = road_view.get_debug_snapshot()
	if str(snapshot.get("art_revision", "")) != "t0132_p5":
		_fail("Formal road art identity is missing")
		return
	if int(snapshot.get("road_count", 0)) != 42 or int(snapshot.get("road_root_count", 0)) != 42:
		_fail("Formal road scene did not project all accepted segments")
		return
	var kinds: Dictionary = snapshot.get("kind_counts", {})
	if kinds != {"main": 10, "service": 23, "enemy": 4, "trade": 5}:
		_fail("Road-purpose counts drifted: %s" % str(kinds))
		return
	if int(snapshot.get("ribbon_count", 0)) != 84:
		_fail("Every road must have a feathered shoulder and compacted core")
		return
	if int(snapshot.get("junction_patch_count", 0)) != 31:
		_fail("Shared road endpoints are missing rounded junction patches")
		return
	if int(snapshot.get("rut_strip_count", 0)) < 150 or int(snapshot.get("embedded_stone_count", 0)) < 55:
		_fail("Formal road wear detail density is too low: %s" % str(snapshot))
		return
	if int(snapshot.get("triangle_count", 0)) < 600:
		_fail("Irregular low-poly road geometry was not generated")
		return
	if bool(snapshot.get("has_collision", true)) or bool(snapshot.get("roads_affect_navigation", true)):
		_fail("Road visuals must not create collision or navigation authority")
		return
	if not bool(snapshot.get("has_irregular_edges", false)) or not bool(snapshot.get("has_compacted_core", false)) or not bool(snapshot.get("has_cart_ruts", false)):
		_fail("Road surface layers are incomplete")
		return
	var widths: Dictionary = snapshot.get("widths", {})
	var endpoints: Dictionary = snapshot.get("endpoints", {})
	for raw_road in roads:
		var road: Dictionary = raw_road
		var road_id := str(road.get("id", ""))
		if not widths.has(road_id) or not is_equal_approx(float(widths[road_id]), float(road.get("width", 0.0))):
			_fail("Road width changed in presentation: %s" % road_id)
			return
		var projected: Dictionary = endpoints.get(road_id, {})
		if projected.get("from", []) != road.get("from", []) or projected.get("to", []) != road.get("to", []):
			_fail("Road endpoints changed in presentation: %s" % road_id)
			return

	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	var main := main_scene.instantiate()
	root.add_child(main)
	for _frame in range(4):
		await process_frame
	var integrated := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/Roads/FormalRoadNetworkArt")
	if integrated == null or not integrated.has_method("get_debug_snapshot"):
		_fail("Formal road network is not installed in Main")
		return
	var integrated_snapshot: Dictionary = integrated.get_debug_snapshot()
	if int(integrated_snapshot.get("road_count", 0)) != 42:
		_fail("Main integration lost formal road segments")
		return
	var integrated_roads := root.get_node("Main/WorldRoot/FormalStationLayout/Roads") as Node3D
	if not integrated_roads.find_children("*", "StaticBody3D", true, false).is_empty() or not integrated_roads.find_children("*", "CollisionShape3D", true, false).is_empty():
		_fail("Integrated road presentation introduced physical blockers")
		return
	print("T0132-P5 formal road network verification passed: %s" % str({
		"roads": snapshot.get("road_count"),
		"ribbons": snapshot.get("ribbon_count"),
		"ruts": snapshot.get("rut_strip_count"),
		"stones": snapshot.get("embedded_stone_count"),
		"junctions": snapshot.get("junction_patch_count"),
		"triangles": snapshot.get("triangle_count")
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
