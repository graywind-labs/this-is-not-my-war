extends SceneTree


const MAIN_PATH := "res://scenes/main/Main.tscn"
const FIXTURE_LAYOUTS_PATH := "res://data/building_fixture_layouts.json"

var _failed := false


func _init() -> void:
	var fixture_layouts := _load_json_dictionary(FIXTURE_LAYOUTS_PATH)
	var main_scene := load(MAIN_PATH) as PackedScene
	if fixture_layouts.is_empty() or main_scene == null:
		_fail("T0129C-A3b1 inputs could not be loaded")
		return
	if str(fixture_layouts.get("schema_version", "")) != "building_fixture_layout_v1":
		_fail("Unexpected fixture layout schema")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	for _step in 4:
		await process_frame
		await physics_frame

	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var formal_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout") as Node3D
	var blacksmith := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/BuildingRoots/Blacksmith"
	) as Node3D
	var fixture_root := blacksmith.get_node_or_null("FixtureLayout") if blacksmith != null else null
	var navigation_region := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/SpatialContract/StationNavigation"
	) as NavigationRegion3D
	if controller == null or formal_root == null or blacksmith == null or fixture_root == null or navigation_region == null:
		_fail("T0129C-A3b1 hierarchy is incomplete")
		return

	var snapshot: Dictionary = controller.debug_get_layout_snapshot()
	var physics_snapshot: Dictionary = controller.debug_get_physics_navigation_snapshot()
	if int(snapshot.get("configuration_error_count", -1)) != 0:
		_fail("Fixture configuration validation failed: %s" % snapshot)
		return
	if str(snapshot.get("fixture_layouts_schema", "")) != "building_fixture_layout_v1":
		_fail("Fixture schema is absent from the formal snapshot: %s" % snapshot)
		return
	if (
		int(snapshot.get("building_fixture_count", 0)) != 109
		or int(snapshot.get("fixture_workstation_stand_count", 0)) != 61
		or int(snapshot.get("fixture_occupant_anchor_count", 0)) != 36
	):
		_fail("Blacksmith fixture/stand counts drifted: %s" % snapshot)
		return
	if int(physics_snapshot.get("static_body_count", 0)) != 243 or int(physics_snapshot.get("building_fixture_count", 0)) != 133:
		_fail("Fixture aggregate was not added to the production collision source: %s" % physics_snapshot)
		return

	var fixture_collisions := fixture_root.get_node_or_null("StaticCollision")
	var fixture_visuals := fixture_root.get_node_or_null("Visuals")
	var fixture_stands := fixture_root.get_node_or_null("NPCStands")
	if (
		fixture_collisions == null
		or fixture_visuals == null
		or fixture_stands == null
		or fixture_collisions.get_child_count() != 5
		or fixture_visuals.get_child_count() != 5
		or fixture_stands.get_child_count() != 3
	):
		_fail("Blacksmith fixture visual/collision/stand parity failed")
		return

	var blacksmith_config: Dictionary = (
		(fixture_layouts.get("buildings", {}) as Dictionary).get("blacksmith", {}) as Dictionary
	)
	var mapped_workstations: Dictionary = {}
	var direct_space_state := formal_root.get_world_3d().direct_space_state
	for raw_fixture in blacksmith_config.get("fixtures", []):
		var fixture: Dictionary = raw_fixture
		var fixture_id := str(fixture.get("id", ""))
		var collision := _find_child_by_meta(fixture_collisions, "fixture_id", fixture_id) as StaticBody3D
		var visual := _find_child_by_meta(fixture_visuals, "fixture_id", fixture_id) as Node3D
		if collision == null or visual == null:
			_fail("Fixture visual/collision pair is missing: %s" % fixture_id)
			return
		if collision.collision_layer != 1 or collision.collision_mask != 2:
			_fail("Fixture collision layer/mask drifted: %s" % fixture_id)
			return
		var collision_shape := collision.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision_shape == null or not collision_shape.shape is BoxShape3D:
			_fail("Fixture must expose an auditable BoxShape3D: %s" % fixture_id)
			return
		var expected_collision_size := _v3(fixture.get("collision_size", []))
		if not (collision_shape.shape as BoxShape3D).size.is_equal_approx(expected_collision_size):
			_fail("Fixture collision size drifted: %s" % fixture_id)
			return
		var workstation_id := str(fixture.get("workstation_id", ""))
		if workstation_id.is_empty():
			continue
		mapped_workstations[workstation_id] = fixture_id
		var npc_stand := fixture.get("npc_stand", {}) as Dictionary
		var stand_local := _v2(npc_stand.get("center", []))
		var stand_world := blacksmith.to_global(Vector3(stand_local.x, 0.0, stand_local.y))
		var fixture_local := _v2(fixture.get("center", []))
		var fixture_world := blacksmith.to_global(Vector3(fixture_local.x, 0.0, fixture_local.y))
		var route: Dictionary = controller.get_building_spatial_route("blacksmith", workstation_id)
		if str(route.get("target_fixture_id", "")) != fixture_id:
			_fail("Workstation route did not resolve its fixture contract: %s" % workstation_id)
			return
		var route_target: Vector3 = route.get("interior_target_position", Vector3.ZERO)
		var logical_target: Vector3 = route.get("logical_position_center_position", Vector3.ZERO)
		if route_target.distance_to(stand_world) > 0.001 or route_target.distance_to(logical_target) < 0.2:
			_fail("Route target was not separated from the logical bay center: %s route=%s stand=%s logical=%s distances=%.3f/%.3f" % [
				workstation_id,
				route_target,
				stand_world,
				logical_target,
				route_target.distance_to(stand_world),
				route_target.distance_to(logical_target)
			])
			return
		var expected_facing := (blacksmith.global_basis * Vector3(0.0, 0.0, -1.0)).normalized()
		var route_facing: Vector3 = route.get("interior_target_facing_direction", Vector3.ZERO)
		if route_facing.distance_to(expected_facing) > 0.001:
			_fail("Workstation facing direction drifted: %s" % workstation_id)
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
				_fail("NPC stand overlaps a fixture collider: %s / %s" % [workstation_id, collider.name])
				return
		var ray_query := PhysicsRayQueryParameters3D.create(
			stand_world + Vector3(0.0, 0.52, 0.0),
			fixture_world + Vector3(0.0, 0.52, 0.0),
			1
		)
		var ray_hit := direct_space_state.intersect_ray(ray_query)
		var ray_collider := ray_hit.get("collider") as StaticBody3D
		if ray_collider == null or str(ray_collider.get_meta("fixture_id", "")) != fixture_id:
			_fail("Fixture collider does not physically separate the stand from the prop: %s" % fixture_id)
			return

	if mapped_workstations.size() != 3:
		_fail("Blacksmith workstation-to-fixture parity must be exactly three")
		return

	controller.debug_set_preview_enabled(true)
	for _preview_step in 4:
		await process_frame
		await physics_frame
	var navigation_map := navigation_region.get_navigation_map()
	NavigationServer3D.map_force_update(navigation_map)
	var route_results: Dictionary = {}
	for workstation_id in mapped_workstations.keys():
		var route: Dictionary = controller.get_building_spatial_route("blacksmith", str(workstation_id))
		var target: Vector3 = route.get("interior_target_position", Vector3.ZERO)
		var path := NavigationServer3D.map_get_path(
			navigation_map,
			route.get("entry_outside_position", Vector3.ZERO),
			target,
			true
		)
		if path.size() < 3 or path[path.size() - 1].distance_to(target) > 0.3:
			_fail("Production navigation cannot reach the fixture-safe stand: %s / %s" % [workstation_id, path])
			return
		route_results[workstation_id] = {
			"fixture_id": mapped_workstations[workstation_id],
			"path_points": path.size(),
			"end_distance": path[path.size() - 1].distance_to(target)
		}
	controller.debug_set_preview_enabled(false)

	print("T0129C A3b1 blacksmith fixture verification passed: %s" % JSON.stringify({
		"fixture_count": fixture_collisions.get_child_count(),
		"stand_count": fixture_stands.get_child_count(),
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
