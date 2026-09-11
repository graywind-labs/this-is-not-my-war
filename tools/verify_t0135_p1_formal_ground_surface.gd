extends SceneTree

const LAYOUT_PATH := "res://data/station_layout.json"
const ENVIRONMENT_PATH := "res://data/presentation/environment_art.json"
const ENVIRONMENT_SCENE := preload("res://scenes/environment/FormalEnvironmentArtView.tscn")


func _init() -> void:
	var layout := _load_json(LAYOUT_PATH)
	var environment_config := _load_json(ENVIRONMENT_PATH)
	if str(environment_config.get("schema_version", "")) != "environment_art_v1":
		_fail("Environment art config is missing or has the wrong schema")
		return
	var view := ENVIRONMENT_SCENE.instantiate() as Node3D
	view.call("configure", environment_config, layout)
	root.add_child(view)
	for _frame in range(4):
		await process_frame
	var snapshot: Dictionary = view.call("get_debug_snapshot")
	if str(snapshot.get("art_revision", "")) != "t0135_p7":
		_fail("Formal ground art identity is missing")
		return
	if int(snapshot.get("ground_polygon_vertex_count", 0)) != 15 or int(snapshot.get("ground_triangle_count", 0)) != 13:
		_fail("Station interior grass surface does not match the accepted polygon: %s" % str(snapshot))
		return
	if int(snapshot.get("plaza_triangle_count", -1)) != 0 or str(snapshot.get("plaza_topology", "")) != "road_network_junction_no_separate_marker":
		_fail("Plaza must read only as a widened road junction without a separate marker: %s" % str(snapshot))
		return
	if snapshot.get("plaza_visual_size", Vector2.ZERO) != Vector2(14.0, 12.0):
		_fail("Plaza visual envelope drifted")
		return
	if snapshot.get("plaza_center_clear_size", Vector2.ZERO) != Vector2(8.0, 6.0):
		_fail("Plaza center clear area drifted")
		return
	if snapshot.get("plaza_authority_center", Vector2.ZERO) != Vector2(0.0, 10.0) or not is_equal_approx(float(snapshot.get("plaza_authority_radius", 0.0)), 4.0):
		_fail("Presentation changed the plaza authority contract")
		return
	if int(snapshot.get("legacy_plaza_box_count", -1)) != 0:
		_fail("Legacy rectangular plaza patches are still visible")
		return
	if int(snapshot.get("door_wear_count", -1)) != 0 or int(snapshot.get("drainage_strip_count", 0)) != 3:
		_fail("Door wear or drainage projection is incomplete: %s" % str(snapshot))
		return
	if str(snapshot.get("door_wear_topology", "")) != "road_shoulders_only_no_independent_patches":
		_fail("Independent door patches returned: %s" % str(snapshot))
		return
	if int(snapshot.get("debris_cluster_count", 0)) < 10 or int(snapshot.get("pebble_count", 0)) < 40:
		_fail("Quaternius debris density is incomplete: %s" % str(snapshot))
		return
	if int(snapshot.get("vegetation_cluster_count", 0)) < 50 or int(snapshot.get("vegetation_count", 0)) < 240:
		_fail("Quaternius ground-detail density is incomplete: %s" % str(snapshot))
		return
	if str(snapshot.get("debris_distribution", "")) != "scattered_non_enclosing_clusters":
		_fail("Pebbles must remain in scattered non-enclosing debris clusters")
		return
	if int(snapshot.get("station_detail_cluster_count", 0)) < 10 or int(snapshot.get("station_detail_prop_count", 0)) < 35:
		_fail("Functional station-life prop density is incomplete: %s" % str(snapshot))
		return
	if not (snapshot.get("missing_assets", []) as Array).is_empty() or (snapshot.get("asset_sources", []) as Array).size() != 5:
		_fail("Ground-detail source assets are incomplete: %s" % str(snapshot))
		return
	if bool(snapshot.get("has_collision", true)) or bool(snapshot.get("has_static_body", true)) or bool(snapshot.get("has_navigation_region", true)) or bool(snapshot.get("has_interaction_area", true)):
		_fail("Ground presentation introduced gameplay authority")
		return
	if bool(snapshot.get("roads_affect_navigation", true)) or str(snapshot.get("authority_role", "")) != "presentation_only":
		_fail("Ground presentation authority boundary is missing")
		return
	if not _verify_plaza_center_clear(view):
		return

	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	var main := main_scene.instantiate()
	root.add_child(main)
	for _frame in range(6):
		await process_frame
		await physics_frame
	var integrated := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/FormalEnvironmentArtView")
	if integrated == null or not integrated.has_method("get_debug_snapshot"):
		_fail("Formal ground art is not installed in Main")
		return
	var integrated_snapshot: Dictionary = integrated.call("get_debug_snapshot")
	if int(integrated_snapshot.get("door_wear_count", -1)) != 0 or int(integrated_snapshot.get("legacy_plaza_box_count", -1)) != 0:
		_fail("Main integration lost the P1 ground contract")
		return
	if not integrated.find_children("*DoorWear*", "MeshInstance3D", true, false).is_empty() or not integrated.find_children("PlazaPebble*", "Node3D", true, false).is_empty():
		_fail("Rejected oval door wear or plaza pebble ring returned")
		return
	var plaza_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/Plaza") as Node3D
	if plaza_root == null or not bool(plaza_root.get_meta("legacy_patch_visuals_suppressed", false)):
		_fail("Legacy plaza suppression metadata is missing")
		return
	if not plaza_root.find_children("Patch*", "MeshInstance3D", true, false).is_empty():
		_fail("Main still renders old Plaza Box nodes")
		return
	for reserved_lot in root.get_node("Main/WorldRoot/FormalStationLayout/BuildingRoots").find_children("ReservedLot", "Node3D", true, false):
		if reserved_lot is MeshInstance3D or not bool(reserved_lot.get_meta("planning_metadata_only", false)):
			_fail("ReservedLot planning rectangles are still rendered")
			return
	var road_view := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/Roads/FormalRoadNetworkArt")
	if road_view == null or int((road_view.call("get_debug_snapshot") as Dictionary).get("road_count", 0)) != 42:
		_fail("P1 changed the accepted road network")
		return
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	if controller == null:
		_fail("StationLayoutController is missing")
		return
	var controller_snapshot: Dictionary = controller.call("get_validation_snapshot")
	if str(controller_snapshot.get("environment_art_schema", "")) != "environment_art_v1" or int(controller_snapshot.get("configuration_error_count", -1)) != 0:
		_fail("Station controller did not validate environment_art_v1: %s" % str(controller_snapshot))
		return
	print("T0135-P1R2 formal ground and station-life density verification passed: %s" % str({
		"ground_triangles": snapshot.get("ground_triangle_count"),
		"plaza_triangles": snapshot.get("plaza_triangle_count"),
		"door_wear": snapshot.get("door_wear_count"),
		"drainage": snapshot.get("drainage_strip_count"),
		"pebbles": snapshot.get("pebble_count"),
		"vegetation": snapshot.get("vegetation_count"),
		"detail_clusters": snapshot.get("station_detail_cluster_count"),
		"detail_props": snapshot.get("station_detail_prop_count")
	}))
	quit(0)


func _verify_plaza_center_clear(view: Node3D) -> bool:
	for node in view.find_children("*", "Node3D", true, false):
		if not bool(node.get_meta("embedded_ground_debris", false)) and not bool(node.get_meta("ground_edge_vegetation", false)):
			continue
		var point := Vector2((node as Node3D).position.x, (node as Node3D).position.z)
		if absf(point.x) < 4.0 and absf(point.y - 10.0) < 3.0:
			_fail("Physical ground detail entered the plaza 8x6 m clear center: %s" % str(point))
			return false
	return true


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
