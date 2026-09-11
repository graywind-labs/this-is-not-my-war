extends SceneTree


const MAIN_PATH := "res://scenes/main/Main.tscn"
const FIXTURE_LAYOUTS_PATH := "res://data/building_fixture_layouts.json"
const STATION_LAYOUT_PATH := "res://data/station_layout.json"

var _failed := false


func _init() -> void:
	var fixture_layouts := _load_json_dictionary(FIXTURE_LAYOUTS_PATH)
	var station_layout := _load_json_dictionary(STATION_LAYOUT_PATH)
	var main_scene := load(MAIN_PATH) as PackedScene
	if fixture_layouts.is_empty() or station_layout.is_empty() or main_scene == null:
		_fail("T0129C-A3b7 inputs could not be loaded")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	for _step in 4:
		await process_frame
		await physics_frame

	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var formal_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout") as Node3D
	var training_ground := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/BuildingRoots/TrainingGround") as Node3D
	var training_art := training_ground.get_node_or_null("TrainingGroundArt") as Node3D if training_ground != null else null
	var fixture_root := training_ground.get_node_or_null("FixtureLayout") if training_ground != null else null
	var navigation_region := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/SpatialContract/StationNavigation"
	) as NavigationRegion3D
	if (
		controller == null
		or building_system == null
		or npc_system == null
		or formal_root == null
		or training_ground == null
		or training_art == null
		or fixture_root == null
		or navigation_region == null
	):
		_fail("T0129C-A3b7 hierarchy is incomplete")
		return

	var snapshot: Dictionary = controller.debug_get_layout_snapshot()
	var physics_snapshot: Dictionary = controller.debug_get_physics_navigation_snapshot()
	if int(snapshot.get("configuration_error_count", -1)) != 0:
		_fail("Training fixture configuration validation failed: %s" % snapshot)
		return
	if (
		int(snapshot.get("building_fixture_count", 0)) != 109
		or int(snapshot.get("fixture_workstation_stand_count", 0)) != 61
		or int(snapshot.get("fixture_occupant_anchor_count", 0)) != 36
		or int(physics_snapshot.get("static_body_count", 0)) != 236
		or int(physics_snapshot.get("building_fixture_count", 0)) != 133
	):
		_fail("Training fixture aggregate counts drifted: %s / %s" % [snapshot, physics_snapshot])
		return
	# The formal art slice projects the authoritative Lv.1 state and therefore disables
	# future fixture collisions. This historical maximum-layout audit explicitly previews
	# Lv.3 before checking all ten configured fixtures.
	training_art.call("debug_force_visual_level", 3)
	for _level_sync in range(2):
		await physics_frame

	var fixture_collisions := fixture_root.get_node_or_null("StaticCollision")
	var fixture_visuals := fixture_root.get_node_or_null("Visuals")
	var fixture_stands := fixture_root.get_node_or_null("NPCStands")
	if (
		fixture_collisions == null
		or fixture_visuals == null
		or fixture_stands == null
		or fixture_collisions.get_child_count() != 10
		or fixture_visuals.get_child_count() != 10
		or fixture_stands.get_child_count() != 6
	):
		_fail("Training ground must expose ten fixtures/colliders and six arrival points")
		return

	var training_config: Dictionary = (
		(fixture_layouts.get("buildings", {}) as Dictionary).get("training_ground", {}) as Dictionary
	)
	var training_spatial: Dictionary = (
		(station_layout.get("building_spatial", {}) as Dictionary).get("training_ground", {}) as Dictionary
	)
	var authority_positions: Dictionary = {}
	for raw_position in training_spatial.get("positions", []):
		var position: Dictionary = raw_position
		authority_positions[str(position.get("id", ""))] = position
	if authority_positions.size() != 6:
		_fail("Training spatial authority must keep exactly six positions")
		return

	var direct_space_state := formal_root.get_world_3d().direct_space_state
	var mapped_workstations: Dictionary = {}
	var instructor_count := 0
	var student_count := 0
	var shared_fixture_count := 0
	var route_results: Dictionary = {}
	for raw_fixture in training_config.get("fixtures", []):
		var fixture: Dictionary = raw_fixture
		var fixture_id := str(fixture.get("id", ""))
		var kind := str(fixture.get("kind", ""))
		var workstation_id := str(fixture.get("workstation_id", ""))
		var visual := _find_child_by_meta(fixture_visuals, "fixture_id", fixture_id) as Node3D
		var collision := _find_child_by_meta(fixture_collisions, "fixture_id", fixture_id) as StaticBody3D
		if visual == null or collision == null or collision.collision_layer != 1 or collision.collision_mask != 2:
			_fail("Training visual/collision pair is missing: %s" % fixture_id)
			return
		var collision_shape := collision.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision_shape == null or not collision_shape.shape is BoxShape3D:
			_fail("Training fixture must expose an auditable BoxShape3D: %s" % fixture_id)
			return
		if _collision_overlaps_other_fixture(direct_space_state, collision, collision_shape, fixture_id):
			_fail("Training fixture overlaps another fixture: %s" % fixture_id)
			return

		match kind:
			"training_command_post":
				instructor_count += 1
				if visual.get_node_or_null("CommandFlag") == null:
					_fail("Instructor position lacks a visible command flag: %s" % fixture_id)
					return
			"training_dummy":
				student_count += 1
			"training_weapon_rack":
				shared_fixture_count += 1
				if visual.get_node_or_null("PracticeShield") == null:
					_fail("Shared weapon rack lacks readable training equipment")
					return
			"training_archery_target":
				shared_fixture_count += 1
				if visual.get_node_or_null("Bullseye") == null:
					_fail("Archery target lacks a visible bullseye")
					return
			"training_sandbag_stack", "training_boundary_fence":
				shared_fixture_count += 1
			_:
				_fail("Unexpected training fixture kind: %s" % kind)
				return

		if workstation_id.is_empty():
			continue
		if mapped_workstations.has(workstation_id) or not authority_positions.has(workstation_id):
			_fail("Training workstation mapping is missing or duplicated: %s" % workstation_id)
			return
		mapped_workstations[workstation_id] = fixture_id
		var authority: Dictionary = authority_positions[workstation_id]
		if int(authority.get("required_level", 0)) != int(fixture.get("required_level", 0)):
			_fail("Training fixture level no longer mirrors spatial authority: %s" % workstation_id)
			return
		var stand := _find_child_by_meta(fixture_stands, "fixture_id", fixture_id) as Marker3D
		var stand_config := fixture.get("npc_stand", {}) as Dictionary
		var stand_local := _v2(stand_config.get("center", []))
		var action_size := _v2(stand_config.get("action_clearance_size", []))
		var stand_world := training_ground.to_global(Vector3(stand_local.x, 0.8, stand_local.y))
		var route: Dictionary = controller.get_building_spatial_route("training_ground", workstation_id)
		if (
			stand == null
			or action_size.distance_to(Vector2(3.0, 3.0)) > 0.001
			or (stand.get_meta("action_clearance_size", Vector2.ZERO) as Vector2).distance_to(action_size) > 0.001
			or str(route.get("target_fixture_id", "")) != fixture_id
			or str(route.get("arrival_mode", "")) != "stand"
			or (route.get("interior_target_position", Vector3.ZERO) as Vector3).distance_to(stand_world - Vector3(0.0, 0.8, 0.0)) > 0.001
		):
			_fail("Training arrival/action-clearance route drifted: %s" % workstation_id)
			return
		if _action_clearance_hits_fixture(direct_space_state, stand_world, action_size):
			_fail("Training 3x3 action area intersects a fixture: %s" % workstation_id)
			return

	if instructor_count != 2 or student_count != 4 or shared_fixture_count != 4 or mapped_workstations.size() != 6:
		_fail("Training ground must keep two instructors, four students and four shared fixtures")
		return

	if not _verify_building_system_capacity(building_system, npc_system):
		return

	controller.debug_set_preview_enabled(true)
	for _preview_step in 4:
		await process_frame
		await physics_frame
	var navigation_map := navigation_region.get_navigation_map()
	NavigationServer3D.map_force_update(navigation_map)
	for workstation_id in mapped_workstations.keys():
		var route: Dictionary = controller.get_building_spatial_route("training_ground", str(workstation_id))
		var target: Vector3 = route.get("interior_target_position", Vector3.ZERO)
		var path := NavigationServer3D.map_get_path(
			navigation_map,
			route.get("entry_outside_position", Vector3.ZERO),
			target,
			true
		)
		if path.size() < 3 or path[path.size() - 1].distance_to(target) > 0.3:
			_fail("Production navigation cannot reach training position: %s / %s" % [workstation_id, path])
			return
		route_results[workstation_id] = path.size()
	controller.debug_set_preview_enabled(false)

	print("T0129C A3b7 training ground fixture verification passed: %s" % JSON.stringify({
		"instructor_count": instructor_count,
		"student_count": student_count,
		"shared_fixture_count": shared_fixture_count,
		"production_navigation": controller.debug_get_production_navigation_snapshot(),
		"routes": route_results
	}))
	quit(0)


func _verify_building_system_capacity(building_system: Node, npc_system: Node) -> bool:
	for index in range(8):
		var npc_id := "training_test_%02d" % (index + 1)
		npc_system._profiles[npc_id] = {"id": npc_id, "name": npc_id, "states": {"current_action": "idle", "current_location": "plaza"}}
	var instructor_1: Dictionary = building_system.claim_workstation("training_ground", "training_test_01", "training_instructor_station")
	var instructor_full: Dictionary = building_system.claim_workstation("training_ground", "training_test_02", "training_instructor_station")
	var student_1: Dictionary = building_system.claim_workstation("training_ground", "training_test_03", "training_practice_slot")
	var student_2: Dictionary = building_system.claim_workstation("training_ground", "training_test_04", "training_practice_slot")
	var student_full: Dictionary = building_system.claim_workstation("training_ground", "training_test_05", "training_practice_slot")
	if (
		not bool(instructor_1.get("ok", false))
		or bool(instructor_full.get("ok", false))
		or str(instructor_full.get("reason", "")) != "no_free_workstation"
		or not bool(student_1.get("ok", false))
		or not bool(student_2.get("ok", false))
		or bool(student_full.get("ok", false))
		or str(student_full.get("reason", "")) != "no_free_workstation"
	):
		_fail("BuildingSystem level-one training capacity drifted")
		return false
	for npc_id in ["training_test_01", "training_test_03", "training_test_04"]:
		building_system.release_workstation("training_ground", npc_id)
	var building: Dictionary = building_system.get_building("training_ground")
	building_system._apply_workstation_upgrade(building, building_system.get_upgrade_level_effect("training_ground", 2))
	var level_two_instructors := _count_station_type(building, "training_instructor_station")
	var level_two_students := _count_station_type(building, "training_practice_slot")
	building_system._apply_workstation_upgrade(building, building_system.get_upgrade_level_effect("training_ground", 3))
	var level_three_instructors := _count_station_type(building, "training_instructor_station")
	var level_three_students := _count_station_type(building, "training_practice_slot")
	for index in range(8):
		npc_system._profiles.erase("training_test_%02d" % (index + 1))
	if level_two_instructors != 1 or level_two_students != 3 or level_three_instructors != 2 or level_three_students != 4:
		_fail("BuildingSystem training level deltas must be 1+2 -> 1+3 -> 2+4")
		return false
	return true


func _count_station_type(building: Dictionary, station_type: String) -> int:
	var result := 0
	for raw_station in building.get("workstations", []):
		var station: Dictionary = raw_station
		if str(station.get("type", "")) == station_type:
			result += 1
	return result


func _collision_overlaps_other_fixture(space_state: PhysicsDirectSpaceState3D, body: StaticBody3D, collision_shape: CollisionShape3D, fixture_id: String) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision_shape.shape
	query.transform = collision_shape.global_transform
	query.collision_mask = 1
	query.exclude = [body.get_rid()]
	for hit in space_state.intersect_shape(query, 64):
		var collider := (hit as Dictionary).get("collider") as StaticBody3D
		if collider != null and str(collider.get_meta("collision_category", "")) == "building_fixture" and str(collider.get_meta("fixture_id", "")) != fixture_id:
			return true
	return false


func _action_clearance_hits_fixture(space_state: PhysicsDirectSpaceState3D, center: Vector3, size: Vector2) -> bool:
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, 1.4, size.y)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = 1
	for hit in space_state.intersect_shape(query, 64):
		var collider := (hit as Dictionary).get("collider") as StaticBody3D
		if collider != null and str(collider.get_meta("collision_category", "")) == "building_fixture":
			return true
	return false


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


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
