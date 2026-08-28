extends SceneTree


const MAIN_PATH := "res://scenes/main/Main.tscn"
const LAYOUT_PATH := "res://data/station_layout.json"
const SPATIAL_PLAN_PATH := "res://data/presentation/station_spatial_plan.json"

var _failed := false


func _init() -> void:
	var layout := _load_json_dictionary(LAYOUT_PATH)
	var plan := _load_json_dictionary(SPATIAL_PLAN_PATH)
	if layout.is_empty() or plan.is_empty():
		_fail("Station layout or presentation spatial plan is missing")
		return
	if str(layout.get("schema_version", "")) != "station_layout_v2":
		_fail("Unexpected formal station layout schema")
		return
	if not bool((layout.get("migration", {}) as Dictionary).get("formal_layout_active", false)):
		_fail("A5-P7 must activate the accepted formal layout by default")
		return
	var parity_errors := _validate_plan_parity(layout, plan)
	if not parity_errors.is_empty():
		_fail("Formal layout drifted from the accepted spatial plan: %s" % parity_errors)
		return

	var main_scene := load(MAIN_PATH) as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var formal_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout") as Node3D
	var legacy_station := root.get_node_or_null("Main/WorldRoot/Station") as Node3D
	var camera_rig := root.get_node_or_null("Main/CameraRig") as Node3D
	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	if (
		controller == null
		or formal_root == null
		or legacy_station == null
		or camera_rig == null
		or camera == null
	):
		_fail("C1 Main integration nodes are missing")
		return

	var snapshot: Dictionary = controller.debug_get_layout_snapshot()
	if int(snapshot.get("configuration_error_count", -1)) != 0:
		_fail("Station layout controller reported config errors: %s" % snapshot)
		return
	if str(snapshot.get("migration_phase", "")) != "a5_p7_default_formal_world":
		_fail("Unexpected station layout migration phase: %s" % snapshot)
		return
	if not bool(snapshot.get("preview_enabled", false)):
		_fail("Main must start on the accepted formal gameplay camera")
		return
	if not bool(snapshot.get("formal_root_visible", false)):
		_fail("Default formal geometry must be visible")
		return
	if int(snapshot.get("building_count", 0)) != 12:
		_fail("Formal layout must generate all 12 building roots: %s" % snapshot)
		return
	if int(snapshot.get("road_count", 0)) != 42:
		_fail("Formal layout must generate the collision-safe 42-road network: %s" % snapshot)
		return
	if int(snapshot.get("wall_segment_count", 0)) != 14:
		_fail("Formal layout must generate 14 irregular wall segments: %s" % snapshot)
		return
	if int(snapshot.get("gate_count", 0)) != 2 or int(snapshot.get("plaza_patch_count", 0)) != 3:
		_fail("Formal layout gates or plaza patches are incomplete: %s" % snapshot)
		return
	_assert_vector2(snapshot.get("terrain_size"), Vector2(700.0, 720.0), "formal terrain")
	if _failed:
		return
	if float(snapshot.get("terrain_surface_y", -99.0)) <= float(snapshot.get("river_surface_y", 99.0)):
		_fail("Formal river must remain lower than station ground")
		return
	_assert_vector3(formal_root.position, Vector3.ZERO, "formal world origin")
	if _failed:
		return
	var formal_static_body_count := formal_root.find_children("*", "StaticBody3D", true, false).size()
	if formal_static_body_count != 240:
		_fail("Formal layout static-body count changed unexpectedly: %d" % formal_static_body_count)
		return
	var staged_navigation := formal_root.find_children("*", "NavigationRegion3D", true, false)
	if staged_navigation.size() != 3:
		_fail("The station, enemy-approach, and rear-route navigation regions must exist")
		return
	for raw_region in staged_navigation:
		if not (raw_region as NavigationRegion3D).enabled:
			_fail("Default formal navigation must be enabled")
			return

	var compatibility_snapshot: Dictionary = controller.debug_set_legacy_compatibility_enabled(true)
	if (
		not bool(compatibility_snapshot.get("legacy_compatibility_override", false))
		or bool(compatibility_snapshot.get("preview_enabled", true))
		or bool(compatibility_snapshot.get("formal_root_visible", true))
	):
		_fail("Explicit compatibility mode did not restore the legacy map")
		return

	var building_roots := formal_root.get_node_or_null("BuildingRoots")
	if building_roots == null or building_roots.get_child_count() != 12:
		_fail("Formal BuildingRoots hierarchy is incomplete")
		return
	for raw_building in layout.get("buildings", []):
		var building: Dictionary = raw_building
		var node := building_roots.get_node_or_null(str(building.get("node_name", ""))) as Node3D
		if node == null:
			_fail("Missing formal building root: %s" % building)
			return
		var center := _v2(building.get("center", [0.0, 0.0]))
		_assert_vector3(node.position, Vector3(center.x, 0.0, center.y), str(building.get("id", "")))
		if _failed:
			return
		if not is_equal_approx(node.rotation_degrees.y, float(building.get("rotation_degrees", 0.0))):
			_fail("Formal building orientation drifted: %s" % building.get("id", ""))
			return
		if str(node.get_meta("building_id", "")) != str(building.get("id", "")):
			_fail("Formal building metadata is missing: %s" % building.get("id", ""))
			return

	var legacy_hall := legacy_station.get_node("Buildings/MainHall") as Node3D
	var legacy_hall_transform := legacy_hall.transform
	var legacy_ground := legacy_station.get_node("Ground") as MeshInstance3D
	var legacy_ground_size := (legacy_ground.mesh as PlaneMesh).size
	var old_rig_position := camera_rig.global_position
	var old_camera_position := camera.position
	var old_camera_rotation := camera.rotation_degrees
	var old_x_limits: Vector2 = camera_rig.get("x_limits")
	var old_z_limits: Vector2 = camera_rig.get("z_limits")

	var preview_snapshot: Dictionary = controller.debug_set_preview_enabled(true)
	if not bool(preview_snapshot.get("preview_enabled", false)):
		_fail("Formal layout preview did not activate")
		return
	if not bool(preview_snapshot.get("formal_root_visible", false)):
		_fail("Formal staging root must become visible during preview")
		return
	_assert_vector3(camera_rig.global_position, Vector3(-2.0, 0.0, 18.0), "formal camera focus")
	_assert_vector2(camera_rig.get("x_limits"), Vector2(-150.0, 150.0), "formal camera x limits")
	_assert_vector2(camera_rig.get("z_limits"), Vector2(-215.0, 240.0), "preview camera z limits")
	if _failed:
		return
	if not is_equal_approx(camera.position.length(), 70.0):
		_fail("Preview camera did not use the 70 m overview distance")
		return

	var restore_snapshot: Dictionary = controller.debug_set_preview_enabled(false)
	if bool(restore_snapshot.get("preview_enabled", true)):
		_fail("Formal layout preview did not return to the gameplay map")
		return
	if bool(restore_snapshot.get("formal_root_visible", true)):
		_fail("Formal staging root must hide after returning to the gameplay map")
		return
	_assert_vector3(camera_rig.global_position, old_rig_position, "restored rig position")
	_assert_vector3(camera.position, old_camera_position, "restored camera position")
	_assert_vector3(camera.rotation_degrees, old_camera_rotation, "restored camera rotation")
	_assert_vector2(camera_rig.get("x_limits"), old_x_limits, "restored x limits")
	_assert_vector2(camera_rig.get("z_limits"), old_z_limits, "restored z limits")
	if _failed:
		return
	if legacy_hall.transform != legacy_hall_transform:
		_fail("C1 preview mutated the legacy MainHall transform")
		return
	if (legacy_ground.mesh as PlaneMesh).size != legacy_ground_size:
		_fail("C1 preview mutated the legacy gameplay ground")
		return
	if not legacy_station.visible:
		_fail("C1 preview must not hide or replace the legacy gameplay root")
		return
	controller.debug_set_legacy_compatibility_enabled(false)

	print("T0129B C1 station layout verification passed: %s" % JSON.stringify(snapshot))
	quit(0)


func _validate_plan_parity(layout: Dictionary, plan: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var terrain: Dictionary = layout.get("terrain", {})
	var plan_terrain: Dictionary = plan.get("terrain", {})
	if _v2(terrain.get("center", [])) != _v2(plan_terrain.get("underlay_center", [])):
		errors.append("terrain_center")
	if _v2(terrain.get("size", [])) != _v2(plan_terrain.get("underlay_size", [])):
		errors.append("terrain_size")
	if str(terrain.get("ground_color", "")) != str(plan_terrain.get("continuous_ground_color", "")):
		errors.append("ground_color")
	if not is_equal_approx(
		float(terrain.get("river_center_x", 0.0)),
		float(plan_terrain.get("river_channel_center_x", 0.0))
	):
		errors.append("river_center")
	var station: Dictionary = layout.get("station", {})
	var plan_station: Dictionary = plan.get("station", {})
	if (station.get("wall_segments", []) as Array) != (plan_station.get("wall_segments", []) as Array):
		errors.append("wall_segments")
	if _v2((station.get("front_gate", {}) as Dictionary).get("center", [])) != _v2(
		(plan_station.get("front_gate", {}) as Dictionary).get("center", [])
	):
		errors.append("front_gate")
	if _v2((station.get("back_gate", {}) as Dictionary).get("center", [])) != _v2(
		(plan_station.get("back_gate", {}) as Dictionary).get("center", [])
	):
		errors.append("back_gate")
	if (layout.get("roads", []) as Array) != (plan.get("roads", []) as Array):
		errors.append("roads")
	var layout_buildings := _index_by_id(layout.get("buildings", []))
	var plan_buildings := _index_by_id(plan.get("building_lots", []))
	if layout_buildings.size() != plan_buildings.size():
		errors.append("building_count")
	for building_id in layout_buildings.keys():
		var building: Dictionary = layout_buildings[building_id]
		var planned: Dictionary = plan_buildings.get(building_id, {})
		if planned.is_empty():
			errors.append("building_missing:%s" % building_id)
			continue
		if (
			_v2(building.get("center", [])) != _v2(planned.get("center", []))
			or _v2(building.get("lot_size", [])) != _v2(planned.get("lot_size", []))
			or _v2(building.get("envelope_size", [])) != _v2(planned.get("envelope_size", []))
			or not is_equal_approx(
				float(building.get("rotation_degrees", 0.0)),
				float(planned.get("rotation_degrees", 0.0))
			)
		):
			errors.append("building_geometry:%s" % building_id)
	var camera: Dictionary = layout.get("camera", {})
	var plan_camera: Dictionary = plan.get("camera", {})
	for key in ["min_distance", "max_distance", "initial_distance", "pitch_degrees"]:
		if not is_equal_approx(float(camera.get(key, 0.0)), float(plan_camera.get(key, 0.0))):
			errors.append("camera:%s" % key)
	if _v2(camera.get("initial_focus", [])) != _v2(plan_camera.get("initial_focus", [])):
		errors.append("camera_focus")
	if _v2(camera.get("x_limits", [])) != _v2(plan_camera.get("x_limits", [])):
		errors.append("camera_x_limits")
	if _v2(camera.get("z_limits", [])) != _v2(plan_camera.get("z_limits", [])):
		errors.append("camera_z_limits")
	return errors


func _index_by_id(raw_items: Variant) -> Dictionary:
	var result: Dictionary = {}
	for raw_item in raw_items:
		var item: Dictionary = raw_item
		result[str(item.get("id", ""))] = item
	return result


func _assert_vector2(value: Variant, expected: Vector2, label: String) -> void:
	var actual: Vector2 = value
	if actual.distance_to(expected) > 0.001:
		_fail("Unexpected %s: %s != %s" % [label, actual, expected])


func _assert_vector3(value: Variant, expected: Vector3, label: String) -> void:
	var actual: Vector3 = value
	if actual.distance_to(expected) > 0.001:
		_fail("Unexpected %s: %s != %s" % [label, actual, expected])


func _v2(value: Variant) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _load_json_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
