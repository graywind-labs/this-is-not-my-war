extends SceneTree


const MAIN_PATH := "res://scenes/main/Main.tscn"
const FIXTURE_LAYOUTS_PATH := "res://data/building_fixture_layouts.json"

var _failed := false


func _init() -> void:
	var fixture_layouts := _load_json_dictionary(FIXTURE_LAYOUTS_PATH)
	var main_scene := load(MAIN_PATH) as PackedScene
	if fixture_layouts.is_empty() or main_scene == null:
		_fail("T0129C-A3b2 inputs could not be loaded")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	for _step in 4:
		await process_frame
		await physics_frame

	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var formal_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout") as Node3D
	var clinic := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/BuildingRoots/Clinic"
	) as Node3D
	var fixture_root := clinic.get_node_or_null("FixtureLayout") if clinic != null else null
	var clinic_art := clinic.get_node_or_null("ClinicArt") if clinic != null else null
	var navigation_region := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/SpatialContract/StationNavigation"
	) as NavigationRegion3D
	if controller == null or formal_root == null or clinic == null or fixture_root == null or clinic_art == null or navigation_region == null:
		_fail("T0129C-A3b2 hierarchy is incomplete")
		return
	# A3b2 audits the complete maximum-level fixture topology. The formal clinic art
	# level-syncs future bed visuals and collision, so expose Lv.3 for this audit.
	clinic_art.call("debug_force_visual_level", 3)

	var snapshot: Dictionary = controller.debug_get_layout_snapshot()
	var physics_snapshot: Dictionary = controller.debug_get_physics_navigation_snapshot()
	if int(snapshot.get("configuration_error_count", -1)) != 0:
		_fail("Clinic fixture configuration validation failed: %s" % snapshot)
		return
	if (
		int(snapshot.get("building_fixture_count", 0)) != 109
		or int(snapshot.get("fixture_workstation_stand_count", 0)) != 61
		or int(snapshot.get("fixture_occupant_anchor_count", 0)) != 36
		or int(physics_snapshot.get("static_body_count", 0)) != 236
	):
		_fail("Clinic fixture aggregate counts drifted: %s / %s" % [snapshot, physics_snapshot])
		return

	var fixture_collisions := fixture_root.get_node_or_null("StaticCollision")
	var fixture_visuals := fixture_root.get_node_or_null("Visuals")
	var fixture_stands := fixture_root.get_node_or_null("NPCStands")
	var occupant_anchors := fixture_root.get_node_or_null("OccupantAnchors")
	if (
		fixture_collisions == null
		or fixture_visuals == null
		or fixture_stands == null
		or occupant_anchors == null
		or fixture_collisions.get_child_count() != 8
		or fixture_visuals.get_child_count() != 8
		or fixture_stands.get_child_count() != 6
		or occupant_anchors.get_child_count() != 6
	):
		_fail("Clinic visual/collision/stand/occupant-anchor parity failed")
		return

	var clinic_config: Dictionary = (
		(fixture_layouts.get("buildings", {}) as Dictionary).get("clinic", {}) as Dictionary
	)
	var expected_levels := {
		"doctor_desk_01": 1,
		"doctor_desk_02": 1,
		"treatment_bed_01": 1,
		"treatment_bed_02": 1,
		"treatment_bed_03": 2,
		"treatment_bed_04": 3
	}
	var mapped_workstations: Dictionary = {}
	var doctor_count := 0
	var bed_count := 0
	var direct_space_state := formal_root.get_world_3d().direct_space_state
	for raw_fixture in clinic_config.get("fixtures", []):
		var fixture: Dictionary = raw_fixture
		var fixture_id := str(fixture.get("id", ""))
		var workstation_id := str(fixture.get("workstation_id", ""))
		var collision := _find_child_by_meta(fixture_collisions, "fixture_id", fixture_id) as StaticBody3D
		var visual := _find_child_by_meta(fixture_visuals, "fixture_id", fixture_id) as Node3D
		var stand := _find_child_by_meta(fixture_stands, "fixture_id", fixture_id) as Marker3D
		if collision == null or visual == null:
			_fail("Clinic fixture visual/collision is missing: %s" % fixture_id)
			return
		if collision.collision_layer != 1 or collision.collision_mask != 2:
			_fail("Clinic fixture collision layer/mask drifted: %s" % fixture_id)
			return
		var collision_shape := collision.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision_shape == null or not collision_shape.shape is BoxShape3D:
			_fail("Clinic fixture must expose an auditable BoxShape3D: %s" % fixture_id)
			return
		if not (collision_shape.shape as BoxShape3D).size.is_equal_approx(_v3(fixture.get("collision_size", []))):
			_fail("Clinic fixture collision size drifted: %s" % fixture_id)
			return
		if str(fixture.get("kind", "")) == "clinic_exam_table":
			if visual.get_node_or_null("MedicalCloth") == null:
				_fail("Doctor desk is missing its clinic-readable dressing: %s" % fixture_id)
				return
			continue
		if workstation_id.is_empty() or stand == null:
			_fail("Clinic workstation fixture/stand is missing: %s" % fixture_id)
			return
		if int(fixture.get("required_level", 0)) != int(expected_levels.get(workstation_id, 0)):
			_fail("Clinic required-level presentation drifted: %s" % workstation_id)
			return

		mapped_workstations[workstation_id] = fixture_id
		var npc_stand := fixture.get("npc_stand", {}) as Dictionary
		var stand_local := _v2(npc_stand.get("center", []))
		var stand_world := clinic.to_global(Vector3(stand_local.x, 0.0, stand_local.y))
		var fixture_local := _v2(fixture.get("center", []))
		var fixture_world := clinic.to_global(Vector3(fixture_local.x, 0.0, fixture_local.y))
		var route: Dictionary = controller.get_building_spatial_route("clinic", workstation_id)
		if str(route.get("target_fixture_id", "")) != fixture_id:
			_fail("Clinic route did not resolve its fixture: %s" % workstation_id)
			return
		var route_target: Vector3 = route.get("interior_target_position", Vector3.ZERO)
		var logical_target: Vector3 = route.get("logical_position_center_position", Vector3.ZERO)
		if route_target.distance_to(stand_world) > 0.001 or route_target.distance_to(logical_target) < 0.5:
			_fail("Clinic route target was not separated from its logical bay: %s" % workstation_id)
			return

		var stand_shape := SphereShape3D.new()
		stand_shape.radius = 0.35
		var stand_query := PhysicsShapeQueryParameters3D.new()
		stand_query.shape = stand_shape
		stand_query.transform = Transform3D(Basis.IDENTITY, stand_world + Vector3(0.0, 0.52, 0.0))
		stand_query.collision_mask = 1
		for hit in direct_space_state.intersect_shape(stand_query, 32):
			var collider := (hit as Dictionary).get("collider") as StaticBody3D
			if collider != null and str(collider.get_meta("collision_category", "")) == "building_fixture":
				_fail("Clinic NPC stand overlaps a fixture: %s / %s" % [workstation_id, collider.name])
				return
		var ray_height := 0.25 if str(fixture.get("kind", "")) == "clinic_doctor_chair" else 0.52
		var ray_query := PhysicsRayQueryParameters3D.create(
			stand_world + Vector3(0.0, ray_height, 0.0),
			fixture_world + Vector3(0.0, ray_height, 0.0),
			1
		)
		var ray_hit := direct_space_state.intersect_ray(ray_query)
		var ray_collider := ray_hit.get("collider") as StaticBody3D
		if ray_collider == null or str(ray_collider.get_meta("fixture_id", "")) != fixture_id:
			_fail("Clinic fixture does not physically separate its stand: %s" % fixture_id)
			return

		if str(fixture.get("kind", "")) == "clinic_doctor_chair":
			doctor_count += 1
			if str(route.get("arrival_mode", "")) != "mount_after_arrival" or str(route.get("occupant_pose", "")) != "seated_study":
				_fail("Doctor chair must terminate at the seated-study anchor: %s" % workstation_id)
				return
			var occupant_anchor := fixture.get("occupant_anchor", {}) as Dictionary
			var anchor_local := _v2(occupant_anchor.get("center", []))
			if (
				not is_equal_approx(float(fixture.get("rotation_degrees", 0.0)), 180.0)
				or not is_equal_approx(anchor_local.x, fixture_local.x)
				or not is_equal_approx(anchor_local.y, fixture_local.y - 0.12)
			):
				_fail("Doctor chair must face the desk with the seated anchor shifted 0.12m toward it: %s" % workstation_id)
				return
		elif str(fixture.get("kind", "")) == "clinic_bed":
			bed_count += 1
			if str(route.get("arrival_mode", "")) != "mount_after_arrival":
				_fail("Patient bed must use mount-after-arrival: %s" % workstation_id)
				return
			var occupant_anchor := fixture.get("occupant_anchor", {}) as Dictionary
			var anchor_local := _v2(occupant_anchor.get("center", []))
			var expected_anchor_world := clinic.to_global(
				Vector3(anchor_local.x, float(occupant_anchor.get("y", 0.0)), anchor_local.y)
			)
			var route_anchor: Vector3 = route.get("occupant_anchor_position", Vector3.ZERO)
			if route_anchor.distance_to(expected_anchor_world) > 0.001 or str(route.get("occupant_pose", "")) != "lying_supine":
				_fail("Patient bed occupant anchor contract drifted: %s" % workstation_id)
				return
			var anchor_marker := _find_child_by_meta(occupant_anchors, "fixture_id", fixture_id) as Marker3D
			if anchor_marker == null or anchor_marker.global_position.distance_to(expected_anchor_world) > 0.001:
				_fail("Patient anchor marker does not match the route contract: %s" % workstation_id)
				return

	if mapped_workstations.size() != 6 or doctor_count != 2 or bed_count != 4:
		_fail("Clinic must expose exactly two doctor desks and four maximum-level beds")
		return

	controller.debug_set_preview_enabled(true)
	for _preview_step in 4:
		await process_frame
		await physics_frame
	var navigation_map := navigation_region.get_navigation_map()
	NavigationServer3D.map_force_update(navigation_map)
	var route_results: Dictionary = {}
	for workstation_id in mapped_workstations.keys():
		var route: Dictionary = controller.get_building_spatial_route("clinic", str(workstation_id))
		var target: Vector3 = route.get("interior_target_position", Vector3.ZERO)
		var path := NavigationServer3D.map_get_path(
			navigation_map,
			route.get("entry_outside_position", Vector3.ZERO),
			target,
			true
		)
		if path.size() < 3 or path[path.size() - 1].distance_to(target) > 0.3:
			_fail("Production navigation cannot reach clinic stand: %s / %s" % [workstation_id, path])
			return
		route_results[workstation_id] = {
			"fixture_id": mapped_workstations[workstation_id],
			"path_points": path.size(),
			"end_distance": path[path.size() - 1].distance_to(target)
		}
	controller.debug_set_preview_enabled(false)
	clinic_art.call("debug_force_visual_level", 1)

	print("T0129C A3b2 clinic fixture verification passed: %s" % JSON.stringify({
		"fixture_count": fixture_collisions.get_child_count(),
		"doctor_station_count": doctor_count,
		"bed_count": bed_count,
		"stand_count": fixture_stands.get_child_count(),
		"occupant_anchor_count": occupant_anchors.get_child_count(),
		"production_navigation": controller.debug_get_production_navigation_snapshot(),
		"routes": route_results
	}))
	quit(0)


func _find_child_by_meta(parent: Node, key: String, value: String) -> Node:
	for child in parent.get_children():
		if str(child.get_meta(key, "")) == value:
			return child
	return null


func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}


func _v2(value: Variant) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _v3(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
