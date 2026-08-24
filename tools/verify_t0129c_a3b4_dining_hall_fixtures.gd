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
		_fail("T0129C-A3b4 inputs could not be loaded")
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
	var dining_hall := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/BuildingRoots/DiningHall"
	) as Node3D
	var fixture_root := dining_hall.get_node_or_null("FixtureLayout") if dining_hall != null else null
	var dining_hall_art := dining_hall.get_node_or_null("DiningHallArt") if dining_hall != null else null
	var navigation_region := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/SpatialContract/StationNavigation"
	) as NavigationRegion3D
	if (
		controller == null
		or building_system == null
		or npc_system == null
		or formal_root == null
		or dining_hall == null
		or fixture_root == null
		or dining_hall_art == null
		or navigation_region == null
	):
		_fail("T0129C-A3b4 hierarchy is incomplete")
		return
	dining_hall_art.call("debug_force_visual_level", 3)

	var snapshot: Dictionary = controller.debug_get_layout_snapshot()
	var physics_snapshot: Dictionary = controller.debug_get_physics_navigation_snapshot()
	if int(snapshot.get("configuration_error_count", -1)) != 0:
		_fail("Dining hall fixture configuration validation failed: %s" % snapshot)
		return
	if (
		int(snapshot.get("building_fixture_count", 0)) != 109
		or int(snapshot.get("fixture_workstation_stand_count", 0)) != 61
		or int(snapshot.get("fixture_occupant_anchor_count", 0)) != 36
		or int(physics_snapshot.get("static_body_count", 0)) != 236
	):
		_fail("Dining hall fixture aggregate counts drifted: %s / %s" % [snapshot, physics_snapshot])
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
		or fixture_collisions.get_child_count() != 15
		or fixture_visuals.get_child_count() != 15
		or fixture_stands.get_child_count() != 13
		or occupant_anchors.get_child_count() != 10
	):
		_fail("Dining hall must expose 15 furniture bodies, 13 arrival points and 10 sitting anchors")
		return

	var dining_config: Dictionary = (
		(fixture_layouts.get("buildings", {}) as Dictionary).get("dining_hall", {}) as Dictionary
	)
	var authority_positions: Dictionary = {}
	var building_spatial := station_layout.get("building_spatial", {}) as Dictionary
	var dining_spatial := building_spatial.get("dining_hall", {}) as Dictionary
	for raw_position in dining_spatial.get("positions", []):
		var position: Dictionary = raw_position
		authority_positions[str(position.get("id", ""))] = position
	if authority_positions.size() != 13:
		_fail("Dining hall spatial authority must keep three kitchens and ten seats")
		return

	var direct_space_state := formal_root.get_world_3d().direct_space_state
	var mapped_workstations: Dictionary = {}
	var stand_positions: Array[Vector2] = []
	var kitchen_count := 0
	var chair_count := 0
	var table_count := 0
	var level_three_kitchens := 0
	for raw_fixture in dining_config.get("fixtures", []):
		var fixture: Dictionary = raw_fixture
		var fixture_id := str(fixture.get("id", ""))
		var kind := str(fixture.get("kind", ""))
		var workstation_id := str(fixture.get("workstation_id", ""))
		var collision := _find_child_by_meta(fixture_collisions, "fixture_id", fixture_id) as StaticBody3D
		var visual := _find_child_by_meta(fixture_visuals, "fixture_id", fixture_id) as Node3D
		if collision == null or visual == null:
			_fail("Dining hall visual/collision pair is missing: %s" % fixture_id)
			return
		if collision.collision_layer != 1 or collision.collision_mask != 2:
			_fail("Dining hall collision layer/mask drifted: %s" % fixture_id)
			return
		var collision_shape := collision.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision_shape == null or not collision_shape.shape is BoxShape3D:
			_fail("Dining hall fixture must expose an auditable BoxShape3D: %s" % fixture_id)
			return
		if not (collision_shape.shape as BoxShape3D).size.is_equal_approx(_v3(fixture.get("collision_size", []))):
			_fail("Dining hall fixture collision size drifted: %s" % fixture_id)
			return
		if _fixture_overlaps_other_fixture(direct_space_state, collision, collision_shape):
			_fail("Dining hall physical furniture overlaps another fixture: %s" % fixture_id)
			return

		match kind:
			"dining_cauldron_hearth":
				kitchen_count += 1
				if int(fixture.get("required_level", 0)) == 3:
					level_three_kitchens += 1
			"dining_chair":
				chair_count += 1
			"dining_table":
				table_count += 1
				if not workstation_id.is_empty():
					_fail("Shared dining tables must not create authority capacity")
					return
			_:
				_fail("Unexpected dining hall fixture kind: %s" % kind)
				return

		if workstation_id.is_empty():
			continue
		if mapped_workstations.has(workstation_id) or not authority_positions.has(workstation_id):
			_fail("Dining hall workstation mapping is missing or duplicated: %s" % workstation_id)
			return
		mapped_workstations[workstation_id] = fixture_id
		var authority: Dictionary = authority_positions[workstation_id]
		if (
			_v2(authority.get("center", [])).distance_to(_v2(fixture.get("center", []))) > 0.001
			or int(authority.get("required_level", 0)) != int(fixture.get("required_level", 0))
		):
			_fail("Dining hall fixture no longer mirrors spatial authority: %s" % workstation_id)
			return

		var stand := _find_child_by_meta(fixture_stands, "fixture_id", fixture_id) as Marker3D
		if stand == null:
			_fail("Dining hall arrival marker is missing: %s" % workstation_id)
			return
		var stand_config := fixture.get("npc_stand", {}) as Dictionary
		var stand_local := _v2(stand_config.get("center", []))
		stand_positions.append(stand_local)
		var stand_world := dining_hall.to_global(Vector3(stand_local.x, 0.0, stand_local.y))
		var fixture_local := _v2(fixture.get("center", []))
		var fixture_world := dining_hall.to_global(Vector3(fixture_local.x, 0.0, fixture_local.y))
		var route: Dictionary = controller.get_building_spatial_route("dining_hall", workstation_id)
		if (
			str(route.get("target_fixture_id", "")) != fixture_id
			or (route.get("interior_target_position", Vector3.ZERO) as Vector3).distance_to(stand_world) > 0.001
		):
			_fail("Dining hall route no longer terminates at its physical arrival point: %s" % workstation_id)
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
				_fail("Dining hall arrival point overlaps furniture: %s / %s" % [workstation_id, collider.name])
				return
		var ray_height := 0.32 if kind == "dining_chair" else 0.52
		var ray_query := PhysicsRayQueryParameters3D.create(
			stand_world + Vector3(0.0, ray_height, 0.0),
			fixture_world + Vector3(0.0, ray_height, 0.0),
			1
		)
		var ray_hit := direct_space_state.intersect_ray(ray_query)
		var ray_collider := ray_hit.get("collider") as StaticBody3D
		if ray_collider == null or str(ray_collider.get_meta("fixture_id", "")) != fixture_id:
			_fail("Dining hall arrival point does not lead to its own fixture: %s" % workstation_id)
			return

		if kind == "dining_chair":
			var anchor := _find_child_by_meta(occupant_anchors, "fixture_id", fixture_id) as Marker3D
			var anchor_config := fixture.get("occupant_anchor", {}) as Dictionary
			var anchor_local := _v2(anchor_config.get("center", []))
			var expected_anchor_world := dining_hall.to_global(
				Vector3(anchor_local.x, float(anchor_config.get("y", 0.0)), anchor_local.y)
			)
			if (
				anchor == null
				or str(route.get("arrival_mode", "")) != "mount_after_arrival"
				or str(route.get("occupant_pose", "")) != "sitting"
				or (route.get("occupant_anchor_position", Vector3.ZERO) as Vector3).distance_to(expected_anchor_world) > 0.001
				or anchor.global_position.distance_to(expected_anchor_world) > 0.001
			):
				_fail("Dining chair arrival/occupation/sitting contract drifted: %s" % workstation_id)
				return
		else:
			if str(route.get("arrival_mode", "")) != "stand" or route.has("occupant_anchor_position"):
				_fail("Kitchen station must remain a standing workstation: %s" % workstation_id)
				return

	if (
		kitchen_count != 3
		or chair_count != 10
		or table_count != 2
		or level_three_kitchens != 1
		or mapped_workstations.size() != 13
	):
		_fail("Dining hall must keep 2 -> 2 -> 3 kitchens, 10 seats and two non-authority tables")
		return
	for index in range(stand_positions.size()):
		for other_index in range(index + 1, stand_positions.size()):
			if stand_positions[index].distance_to(stand_positions[other_index]) < 0.7:
				_fail("Dining hall arrival pair cannot hold two NPC bodies")
				return

	for index in range(11):
		var npc_id := "dining_test_%02d" % (index + 1)
		npc_system._profiles[npc_id] = {
			"id": npc_id,
			"name": npc_id,
			"states": {"current_action": "idle", "current_location": "plaza"}
		}
		var claim: Dictionary = building_system.claim_workstation("dining_hall", npc_id, "dining_seat")
		if index < 10:
			var expected_id := "dining_seat_%02d" % (index + 1)
			if not bool(claim.get("ok", false)) or str(claim.get("workstation_id", "")) != expected_id:
				_fail("BuildingSystem dining seat occupancy order drifted: %s / %s" % [expected_id, claim])
				return
		elif bool(claim.get("ok", false)) or str(claim.get("reason", "")) != "no_free_workstation":
			_fail("Dining hall accepted an eleventh diner")
			return
	for index in range(10):
		var npc_id := "dining_test_%02d" % (index + 1)
		building_system.release_workstation("dining_hall", npc_id, "dining_seat_%02d" % (index + 1))
		npc_system._profiles.erase(npc_id)
	npc_system._profiles.erase("dining_test_11")

	for index in range(3):
		var npc_id := "kitchen_test_%02d" % (index + 1)
		npc_system._profiles[npc_id] = {
			"id": npc_id,
			"name": npc_id,
			"states": {"current_action": "idle", "current_location": "plaza"}
		}
		var claim: Dictionary = building_system.claim_workstation(
			"dining_hall", npc_id, "dining_kitchen_station"
		)
		if index < 2:
			var expected_id := "dining_kitchen_station_%02d" % (index + 1)
			if not bool(claim.get("ok", false)) or str(claim.get("workstation_id", "")) != expected_id:
				_fail("BuildingSystem level-one kitchen capacity drifted: %s / %s" % [expected_id, claim])
				return
		elif bool(claim.get("ok", false)) or str(claim.get("reason", "")) != "no_free_workstation":
			_fail("Level-one dining hall exposed the level-three kitchen")
			return
	for index in range(2):
		var npc_id := "kitchen_test_%02d" % (index + 1)
		building_system.release_workstation(
			"dining_hall", npc_id, "dining_kitchen_station_%02d" % (index + 1)
		)
		npc_system._profiles.erase(npc_id)
	npc_system._profiles.erase("kitchen_test_03")

	controller.debug_set_preview_enabled(true)
	for _preview_step in 4:
		await process_frame
		await physics_frame
	var navigation_map := navigation_region.get_navigation_map()
	NavigationServer3D.map_force_update(navigation_map)
	var route_results: Dictionary = {}
	for workstation_id in mapped_workstations.keys():
		var route: Dictionary = controller.get_building_spatial_route("dining_hall", str(workstation_id))
		var target: Vector3 = route.get("interior_target_position", Vector3.ZERO)
		var path := NavigationServer3D.map_get_path(
			navigation_map,
			route.get("entry_outside_position", Vector3.ZERO),
			target,
			true
		)
		if path.size() < 3 or path[path.size() - 1].distance_to(target) > 0.3:
			_fail("Production navigation cannot reach dining arrival point: %s / %s" % [workstation_id, path])
			return
		route_results[workstation_id] = path.size()
	controller.debug_set_preview_enabled(false)

	print("T0129C A3b4 dining hall fixture verification passed: %s" % JSON.stringify({
		"kitchen_count": kitchen_count,
		"chair_count": chair_count,
		"shared_table_count": table_count,
		"production_navigation": controller.debug_get_production_navigation_snapshot(),
		"routes": route_results
	}))
	quit(0)


func _fixture_overlaps_other_fixture(
	space_state: PhysicsDirectSpaceState3D,
	body: StaticBody3D,
	collision_shape: CollisionShape3D
) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision_shape.shape
	query.transform = collision_shape.global_transform
	query.collision_mask = 1
	query.exclude = [body.get_rid()]
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
