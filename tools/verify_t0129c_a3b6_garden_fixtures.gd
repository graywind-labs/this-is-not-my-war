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
		_fail("T0129C-A3b6 inputs could not be loaded")
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
	var garden := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/BuildingRoots/Garden") as Node3D
	var fixture_root := garden.get_node_or_null("FixtureLayout") if garden != null else null
	var navigation_region := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/SpatialContract/StationNavigation"
	) as NavigationRegion3D
	if (
		controller == null
		or building_system == null
		or npc_system == null
		or formal_root == null
		or garden == null
		or fixture_root == null
		or navigation_region == null
	):
		_fail("T0129C-A3b6 hierarchy is incomplete")
		return

	var snapshot: Dictionary = controller.debug_get_layout_snapshot()
	var physics_snapshot: Dictionary = controller.debug_get_physics_navigation_snapshot()
	if int(snapshot.get("configuration_error_count", -1)) != 0:
		_fail("Garden fixture configuration validation failed: %s" % snapshot)
		return
	if (
		int(snapshot.get("building_fixture_count", 0)) != 109
		or int(snapshot.get("fixture_workstation_stand_count", 0)) != 61
		or int(snapshot.get("fixture_occupant_anchor_count", 0)) != 36
		or int(physics_snapshot.get("static_body_count", 0)) != 236
	):
		_fail("Garden fixture aggregate counts drifted: %s / %s" % [snapshot, physics_snapshot])
		return

	var fixture_collisions := fixture_root.get_node_or_null("StaticCollision")
	var fixture_visuals := fixture_root.get_node_or_null("Visuals")
	var fixture_stands := fixture_root.get_node_or_null("NPCStands")
	if (
		fixture_collisions == null
		or fixture_visuals == null
		or fixture_stands == null
		or fixture_collisions.get_child_count() != 15
		or fixture_visuals.get_child_count() != 9
		or fixture_stands.get_child_count() != 3
	):
		_fail("Garden must expose nine fixtures, fifteen collision parts and three farm arrival points")
		return

	var garden_config: Dictionary = (
		(fixture_layouts.get("buildings", {}) as Dictionary).get("garden", {}) as Dictionary
	)
	var authority_positions: Dictionary = {}
	var garden_spatial: Dictionary = (
		(station_layout.get("building_spatial", {}) as Dictionary).get("garden", {}) as Dictionary
	)
	for raw_position in garden_spatial.get("positions", []):
		var position: Dictionary = raw_position
		authority_positions[str(position.get("id", ""))] = position
	if authority_positions.size() != 3:
		_fail("Garden spatial authority must keep exactly three farm plots")
		return

	var direct_space_state := formal_root.get_world_3d().direct_space_state
	var garden_art := garden.get_node_or_null("GardenArt")
	if garden_art != null and garden_art.has_method("debug_force_visual_level"):
		garden_art.call("debug_force_visual_level", 3)
		await physics_frame
	var mapped_workstations: Dictionary = {}
	var bed_count := 0
	var level_three_bed_count := 0
	var level_two_quality_count := 0
	var shared_fixture_count := 0
	var route_results: Dictionary = {}
	for raw_fixture in garden_config.get("fixtures", []):
		var fixture: Dictionary = raw_fixture
		var fixture_id := str(fixture.get("id", ""))
		var kind := str(fixture.get("kind", ""))
		var workstation_id := str(fixture.get("workstation_id", ""))
		var visual := _find_child_by_meta(fixture_visuals, "fixture_id", fixture_id) as Node3D
		var collision_parts := _find_children_by_meta(fixture_collisions, "fixture_id", fixture_id)
		if visual == null or collision_parts.is_empty():
			_fail("Garden visual/collision pair is missing: %s" % fixture_id)
			return
		var expected_part_count := 3 if kind == "garden_raised_bed" else 1
		if collision_parts.size() != expected_part_count:
			_fail("Garden fixture collision part count drifted: %s / %s" % [fixture_id, collision_parts.size()])
			return
		for collision_node in collision_parts:
			var collision := collision_node as StaticBody3D
			if collision == null or collision.collision_layer != 1 or collision.collision_mask != 2:
				_fail("Garden collision layer/mask drifted: %s" % fixture_id)
				return
			var collision_shape := collision.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if collision_shape == null or not collision_shape.shape is BoxShape3D:
				_fail("Garden collision component must expose an auditable BoxShape3D: %s" % fixture_id)
				return
			if _collision_overlaps_other_fixture(direct_space_state, collision, collision_shape, fixture_id):
				_fail("Garden furniture overlaps another fixture: %s / %s" % [fixture_id, collision.name])
				return

		match kind:
			"garden_raised_bed":
				bed_count += 1
				if str(fixture.get("collision_mode", "")) != "garden_u_border":
					_fail("Garden bed cannot use a solid work-surface collider: %s" % fixture_id)
					return
				if int(fixture.get("required_level", 0)) == 3:
					level_three_bed_count += 1
				var crop_count := 0
				for child in visual.get_children():
					if str(child.name).begins_with("Crop"):
						crop_count += 1
				if crop_count != 9:
					_fail("Each garden plot must visibly contain three crop rows: %s / %s" % [fixture_id, crop_count])
					return
				var bed_center := _v2(fixture.get("center", []))
				var bed_world := garden.to_global(Vector3(bed_center.x, 0.45, bed_center.y))
				if _point_hits_fixture(direct_space_state, bed_world, fixture_id):
					_fail("Garden work surface was incorrectly made solid: %s" % fixture_id)
					return
			"garden_irrigation_channel", "garden_compost_bin":
				if int(fixture.get("required_level", 0)) != 2:
					_fail("Garden quality fixture must belong to level two: %s" % fixture_id)
					return
				level_two_quality_count += 1
				shared_fixture_count += 1
			"garden_wheelbarrow", "garden_tool_rack", "garden_fence", "garden_harvest_crate":
				shared_fixture_count += 1
			_:
				_fail("Unexpected garden fixture kind: %s" % kind)
				return

		if workstation_id.is_empty():
			continue
		if kind != "garden_raised_bed" or mapped_workstations.has(workstation_id) or not authority_positions.has(workstation_id):
			_fail("Garden workstation mapping is missing or duplicated: %s" % workstation_id)
			return
		mapped_workstations[workstation_id] = fixture_id
		var authority: Dictionary = authority_positions[workstation_id]
		if int(authority.get("required_level", 0)) != int(fixture.get("required_level", 0)):
			_fail("Garden fixture level no longer mirrors spatial authority: %s" % workstation_id)
			return

		var stand := _find_child_by_meta(fixture_stands, "fixture_id", fixture_id) as Marker3D
		var stand_config := fixture.get("npc_stand", {}) as Dictionary
		var stand_local := _v2(stand_config.get("center", []))
		var stand_world := garden.to_global(Vector3(stand_local.x, 0.52, stand_local.y))
		var fixture_local := _v2(fixture.get("center", []))
		var route: Dictionary = controller.get_building_spatial_route("garden", workstation_id)
		if (
			stand == null
			or not is_equal_approx(float(stand_config.get("facing_degrees", 99.0)), 0.0)
			or str(route.get("target_fixture_id", "")) != fixture_id
			or str(route.get("arrival_mode", "")) != "stand"
			or (route.get("interior_target_position", Vector3.ZERO) as Vector3).distance_to(stand_world - Vector3(0.0, 0.52, 0.0)) > 0.001
			or stand_local.distance_to(fixture_local) < 1.45
		):
			_fail("Garden arrival/facing route drifted: %s" % workstation_id)
			return
		if _point_hits_any_fixture(direct_space_state, stand_world):
			_fail("Garden arrival point overlaps a fixture: %s" % workstation_id)
			return

	if (
		bed_count != 3
		or level_three_bed_count != 1
		or level_two_quality_count != 2
		or shared_fixture_count != 6
		or mapped_workstations.size() != 3
	):
		_fail("Garden must keep 2 -> 2 -> 3 plots and six non-authority fixtures")
		return

	for index in range(3):
		var npc_id := "farm_test_%02d" % (index + 1)
		npc_system._profiles[npc_id] = {
			"id": npc_id,
			"name": npc_id,
			"states": {"current_action": "idle", "current_location": "plaza"}
		}
		var claim: Dictionary = building_system.claim_workstation("garden", npc_id, "farm")
		if index < 2:
			var expected_id := "garden_plot_%02d" % (index + 1)
			if not bool(claim.get("ok", false)) or str(claim.get("workstation_id", "")) != expected_id:
				_fail("BuildingSystem level-one farming capacity drifted: %s / %s" % [expected_id, claim])
				return
		elif bool(claim.get("ok", false)) or str(claim.get("reason", "")) != "no_free_workstation":
			_fail("Level-one garden exposed the level-three plot")
			return
	for index in range(2):
		var npc_id := "farm_test_%02d" % (index + 1)
		building_system.release_workstation("garden", npc_id, "garden_plot_%02d" % (index + 1))
		npc_system._profiles.erase(npc_id)
	npc_system._profiles.erase("farm_test_03")

	var level_three_building: Dictionary = building_system.get_building("garden")
	var level_three_effect: Dictionary = building_system.get_upgrade_level_effect("garden", 3)
	building_system._apply_workstation_upgrade(level_three_building, level_three_effect)
	var level_three_farm_count := 0
	for raw_station in level_three_building.get("workstations", []):
		var station: Dictionary = raw_station
		if str(station.get("type", "")) == "farm":
			level_three_farm_count += 1
	if level_three_farm_count != 3:
		_fail("BuildingSystem level-three garden must expose exactly three farm plots")
		return
	var level_two_effect: Dictionary = building_system.get_upgrade_level_effect("garden", 2)
	if not (level_two_effect.get("workstation_deltas", []) as Array).is_empty():
		_fail("Level-two garden must improve yield without adding a workstation")
		return

	controller.debug_set_preview_enabled(true)
	for _preview_step in 4:
		await process_frame
		await physics_frame
	var navigation_map := navigation_region.get_navigation_map()
	NavigationServer3D.map_force_update(navigation_map)
	for workstation_id in mapped_workstations.keys():
		var route: Dictionary = controller.get_building_spatial_route("garden", str(workstation_id))
		var target: Vector3 = route.get("interior_target_position", Vector3.ZERO)
		var path := NavigationServer3D.map_get_path(
			navigation_map,
			route.get("entry_outside_position", Vector3.ZERO),
			target,
			true
		)
		if path.size() < 3 or path[path.size() - 1].distance_to(target) > 0.3:
			_fail("Production navigation cannot reach garden arrival point: %s / %s" % [workstation_id, path])
			return
		route_results[workstation_id] = path.size()
	controller.debug_set_preview_enabled(false)

	print("T0129C A3b6 garden fixture verification passed: %s" % JSON.stringify({
		"farm_plot_count": bed_count,
		"shared_fixture_count": shared_fixture_count,
		"production_navigation": controller.debug_get_production_navigation_snapshot(),
		"routes": route_results
	}))
	quit(0)


func _collision_overlaps_other_fixture(
	space_state: PhysicsDirectSpaceState3D,
	body: StaticBody3D,
	collision_shape: CollisionShape3D,
	fixture_id: String
) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision_shape.shape
	query.transform = collision_shape.global_transform
	query.collision_mask = 1
	query.exclude = [body.get_rid()]
	for hit in space_state.intersect_shape(query, 64):
		var collider := (hit as Dictionary).get("collider") as StaticBody3D
		if (
			collider != null
			and str(collider.get_meta("collision_category", "")) == "building_fixture"
			and str(collider.get_meta("fixture_id", "")) != fixture_id
		):
			return true
	return false


func _point_hits_fixture(space_state: PhysicsDirectSpaceState3D, point: Vector3, fixture_id: String) -> bool:
	var shape := SphereShape3D.new()
	shape.radius = 0.22
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, point)
	query.collision_mask = 1
	for hit in space_state.intersect_shape(query, 32):
		var collider := (hit as Dictionary).get("collider") as StaticBody3D
		if collider != null and str(collider.get_meta("fixture_id", "")) == fixture_id:
			return true
	return false


func _point_hits_any_fixture(space_state: PhysicsDirectSpaceState3D, point: Vector3) -> bool:
	var shape := SphereShape3D.new()
	shape.radius = 0.35
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, point)
	query.collision_mask = 1
	for hit in space_state.intersect_shape(query, 32):
		var collider := (hit as Dictionary).get("collider") as StaticBody3D
		if collider != null and str(collider.get_meta("collision_category", "")) == "building_fixture":
			return true
	return false


func _find_children_by_meta(parent: Node, key: String, value: String) -> Array[Node]:
	var result: Array[Node] = []
	for child in parent.get_children():
		if str(child.get_meta(key, "")) == value:
			result.append(child)
	return result


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
