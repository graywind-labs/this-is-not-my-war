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
		_fail("T0129C-A3b5 inputs could not be loaded")
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
	var tavern := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/BuildingRoots/Tavern"
	) as Node3D
	var fixture_root := tavern.get_node_or_null("FixtureLayout") if tavern != null else null
	var tavern_art := tavern.get_node_or_null("TavernArt") if tavern != null else null
	var navigation_region := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/SpatialContract/StationNavigation"
	) as NavigationRegion3D
	if (
		controller == null
		or building_system == null
		or npc_system == null
		or formal_root == null
		or tavern == null
		or fixture_root == null
		or tavern_art == null
		or navigation_region == null
	):
		_fail("T0129C-A3b5 hierarchy is incomplete")
		return
	# T0131-P6 projects future fixture collision by the current visual level. Exercise the
	# complete highest-level furniture contract without mutating BuildingSystem authority.
	tavern_art.call("debug_force_visual_level", 3)

	var snapshot: Dictionary = controller.debug_get_layout_snapshot()
	var physics_snapshot: Dictionary = controller.debug_get_physics_navigation_snapshot()
	if int(snapshot.get("configuration_error_count", -1)) != 0:
		_fail("Tavern fixture configuration validation failed: %s" % snapshot)
		return
	if (
		int(snapshot.get("building_fixture_count", 0)) != 109
		or int(snapshot.get("fixture_workstation_stand_count", 0)) != 61
		or int(snapshot.get("fixture_occupant_anchor_count", 0)) != 36
		or int(physics_snapshot.get("static_body_count", 0)) != 236
	):
		_fail("Tavern fixture aggregate counts drifted: %s / %s" % [snapshot, physics_snapshot])
		return

	var fixture_collisions := fixture_root.get_node_or_null("StaticCollision")
	var fixture_visuals := fixture_root.get_node_or_null("Visuals")
	var fixture_stands := fixture_root.get_node_or_null("NPCStands")
	if (
		fixture_collisions == null
		or fixture_visuals == null
		or fixture_stands == null
		or fixture_collisions.get_child_count() != 6
		or fixture_visuals.get_child_count() != 6
		or fixture_stands.get_child_count() != 3
	):
		_fail("Tavern must expose six furniture bodies and three brewing arrival points")
		return

	var tavern_config: Dictionary = (
		(fixture_layouts.get("buildings", {}) as Dictionary).get("tavern", {}) as Dictionary
	)
	var authority_positions: Dictionary = {}
	var tavern_spatial: Dictionary = (
		(station_layout.get("building_spatial", {}) as Dictionary).get("tavern", {}) as Dictionary
	)
	for raw_position in tavern_spatial.get("positions", []):
		var position: Dictionary = raw_position
		authority_positions[str(position.get("id", ""))] = position
	if authority_positions.size() != 3:
		_fail("Tavern spatial authority must keep exactly three brewing bays")
		return

	var direct_space_state := formal_root.get_world_3d().direct_space_state
	var mapped_workstations: Dictionary = {}
	var stand_positions: Array[Vector2] = []
	var brewing_device_count := 0
	var level_three_device_count := 0
	var level_two_quality_fixture_count := 0
	var shared_fixture_count := 0
	for raw_fixture in tavern_config.get("fixtures", []):
		var fixture: Dictionary = raw_fixture
		var fixture_id := str(fixture.get("id", ""))
		var kind := str(fixture.get("kind", ""))
		var workstation_id := str(fixture.get("workstation_id", ""))
		var collision := _find_child_by_meta(fixture_collisions, "fixture_id", fixture_id) as StaticBody3D
		var visual := _find_child_by_meta(fixture_visuals, "fixture_id", fixture_id) as Node3D
		if collision == null or visual == null:
			_fail("Tavern visual/collision pair is missing: %s" % fixture_id)
			return
		if collision.collision_layer != 1 or collision.collision_mask != 2:
			_fail("Tavern collision layer/mask drifted: %s" % fixture_id)
			return
		var collision_shape := collision.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision_shape == null or not collision_shape.shape is BoxShape3D:
			_fail("Tavern fixture must expose an auditable BoxShape3D: %s" % fixture_id)
			return
		if not (collision_shape.shape as BoxShape3D).size.is_equal_approx(_v3(fixture.get("collision_size", []))):
			_fail("Tavern fixture collision size drifted: %s" % fixture_id)
			return
		if _fixture_overlaps_other_fixture(direct_space_state, collision, collision_shape):
			_fail("Tavern physical furniture overlaps another fixture: %s" % fixture_id)
			return

		match kind:
			"tavern_fermentation_cask":
				brewing_device_count += 1
				if int(fixture.get("required_level", 0)) == 3:
					level_three_device_count += 1
			"tavern_wine_shelf":
				if int(fixture.get("required_level", 0)) == 2:
					level_two_quality_fixture_count += 1
				shared_fixture_count += 1
			"tavern_empty_barrel_rack", "tavern_mug_table":
				shared_fixture_count += 1
			_:
				_fail("Unexpected tavern fixture kind: %s" % kind)
				return

		if workstation_id.is_empty():
			continue
		if kind != "tavern_fermentation_cask" or mapped_workstations.has(workstation_id) or not authority_positions.has(workstation_id):
			_fail("Tavern workstation mapping is missing or duplicated: %s" % workstation_id)
			return
		mapped_workstations[workstation_id] = fixture_id
		var authority: Dictionary = authority_positions[workstation_id]
		if int(authority.get("required_level", 0)) != int(fixture.get("required_level", 0)):
			_fail("Tavern fixture level no longer mirrors spatial authority: %s" % workstation_id)
			return

		var stand := _find_child_by_meta(fixture_stands, "fixture_id", fixture_id) as Marker3D
		var stand_config := fixture.get("npc_stand", {}) as Dictionary
		var stand_local := _v2(stand_config.get("center", []))
		var stand_world := tavern.to_global(Vector3(stand_local.x, 0.0, stand_local.y))
		var fixture_local := _v2(fixture.get("center", []))
		var fixture_world := tavern.to_global(Vector3(fixture_local.x, 0.0, fixture_local.y))
		var route: Dictionary = controller.get_building_spatial_route("tavern", workstation_id)
		if (
			stand == null
			or not is_equal_approx(float(stand_config.get("facing_degrees", 99.0)), 0.0)
			or str(route.get("target_fixture_id", "")) != fixture_id
			or str(route.get("arrival_mode", "")) != "stand"
			or (route.get("interior_target_position", Vector3.ZERO) as Vector3).distance_to(stand_world) > 0.001
		):
			_fail("Tavern arrival/facing route drifted: %s" % workstation_id)
			return
		stand_positions.append(stand_local)

		var stand_shape := SphereShape3D.new()
		stand_shape.radius = 0.35
		var stand_query := PhysicsShapeQueryParameters3D.new()
		stand_query.shape = stand_shape
		stand_query.transform = Transform3D(Basis.IDENTITY, stand_world + Vector3(0.0, 0.52, 0.0))
		stand_query.collision_mask = 1
		for hit in direct_space_state.intersect_shape(stand_query, 32):
			var collider := (hit as Dictionary).get("collider") as StaticBody3D
			if collider != null and str(collider.get_meta("collision_category", "")) == "building_fixture":
				_fail("Tavern arrival point overlaps furniture: %s / %s" % [workstation_id, collider.name])
				return
		var ray_query := PhysicsRayQueryParameters3D.create(
			stand_world + Vector3(0.0, 0.52, 0.0),
			fixture_world + Vector3(0.0, 0.52, 0.0),
			1
		)
		var ray_hit := direct_space_state.intersect_ray(ray_query)
		var ray_collider := ray_hit.get("collider") as StaticBody3D
		if ray_collider == null or str(ray_collider.get_meta("fixture_id", "")) != fixture_id:
			_fail("Tavern arrival point does not face its own fermenter: %s" % workstation_id)
			return

	if (
		brewing_device_count != 3
		or level_three_device_count != 1
		or level_two_quality_fixture_count != 1
		or shared_fixture_count != 3
		or mapped_workstations.size() != 3
	):
		_fail("Tavern must keep 2 -> 2 -> 3 brewing devices and three non-authority fixtures")
		return
	for index in range(stand_positions.size()):
		for other_index in range(index + 1, stand_positions.size()):
			if stand_positions[index].distance_to(stand_positions[other_index]) < 0.7:
				_fail("Tavern brewing arrival pair cannot hold two NPC bodies")
				return

	for index in range(3):
		var npc_id := "brew_test_%02d" % (index + 1)
		npc_system._profiles[npc_id] = {
			"id": npc_id,
			"name": npc_id,
			"states": {"current_action": "idle", "current_location": "plaza"}
		}
		var claim: Dictionary = building_system.claim_workstation("tavern", npc_id, "brew")
		if index < 2:
			var expected_id := "cellar_%02d" % (index + 1)
			if not bool(claim.get("ok", false)) or str(claim.get("workstation_id", "")) != expected_id:
				_fail("BuildingSystem level-one brewing capacity drifted: %s / %s" % [expected_id, claim])
				return
		elif bool(claim.get("ok", false)) or str(claim.get("reason", "")) != "no_free_workstation":
			_fail("Level-one tavern exposed the level-three fermenter")
			return
	for index in range(2):
		var npc_id := "brew_test_%02d" % (index + 1)
		building_system.release_workstation("tavern", npc_id, "cellar_%02d" % (index + 1))
		npc_system._profiles.erase(npc_id)
	npc_system._profiles.erase("brew_test_03")

	var level_three_building: Dictionary = building_system.get_building("tavern")
	var level_three_effect: Dictionary = building_system.get_upgrade_level_effect("tavern", 3)
	building_system._apply_workstation_upgrade(level_three_building, level_three_effect)
	var level_three_brew_count := 0
	for raw_station in level_three_building.get("workstations", []):
		var station: Dictionary = raw_station
		if str(station.get("type", "")) == "brew":
			level_three_brew_count += 1
	if level_three_brew_count != 3:
		_fail("BuildingSystem level-three tavern must expose exactly three brewing positions")
		return
	var level_two_effect: Dictionary = building_system.get_upgrade_level_effect("tavern", 2)
	if not (level_two_effect.get("workstation_deltas", []) as Array).is_empty():
		_fail("Level-two tavern must improve quality/efficiency without adding a workstation")
		return

	controller.debug_set_preview_enabled(true)
	for _preview_step in 4:
		await process_frame
		await physics_frame
	var navigation_map := navigation_region.get_navigation_map()
	NavigationServer3D.map_force_update(navigation_map)
	var route_results: Dictionary = {}
	for workstation_id in mapped_workstations.keys():
		var route: Dictionary = controller.get_building_spatial_route("tavern", str(workstation_id))
		var target: Vector3 = route.get("interior_target_position", Vector3.ZERO)
		var path := NavigationServer3D.map_get_path(
			navigation_map,
			route.get("entry_outside_position", Vector3.ZERO),
			target,
			true
		)
		if path.size() < 3 or path[path.size() - 1].distance_to(target) > 0.3:
			_fail("Production navigation cannot reach tavern arrival point: %s / %s" % [workstation_id, path])
			return
		route_results[workstation_id] = path.size()
	controller.debug_set_preview_enabled(false)
	tavern_art.call("debug_force_visual_level", 1)

	print("T0129C A3b5 tavern fixture verification passed: %s" % JSON.stringify({
		"brewing_device_count": brewing_device_count,
		"shared_fixture_count": shared_fixture_count,
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
