extends SceneTree


const MAIN_PATH := "res://scenes/main/Main.tscn"
const LAYOUT_PATH := "res://data/station_layout.json"


func _init() -> void:
	var layout := _load_json_dictionary(LAYOUT_PATH)
	var packed := load(MAIN_PATH) as PackedScene
	if layout.is_empty() or packed == null:
		_fail("T0201 inputs unavailable")
		return
	var main := packed.instantiate()
	root.add_child(main)
	for _step in 6:
		await process_frame
		await physics_frame

	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var hall := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/BuildingRoots/MainHall") as Node3D
	var navigation_region := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/SpatialContract/StationNavigation"
	) as NavigationRegion3D
	if controller == null or hall == null or navigation_region == null:
		_fail("T0201 runtime hierarchy incomplete")
		return

	var hall_definition := _find_building(layout, "main_hall")
	var blocker_config := hall_definition.get("solid_interior_blocker", {}) as Dictionary
	var envelope := _v2(hall_definition.get("envelope_size", []))
	var inset := float(blocker_config.get("inset", -1.0))
	var blocker := hall.get_node_or_null("StaticCollision/InteriorBlocker") as StaticBody3D
	var blocker_shape := (
		blocker.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if blocker != null
		else null
	)
	var blocker_box := blocker_shape.shape as BoxShape3D if blocker_shape != null else null
	if not bool(blocker_config.get("enabled", false)) or blocker == null or blocker_box == null:
		_fail("T0201 main-hall interior blocker is missing")
		return
	var expected_size := Vector3(envelope.x - inset * 2.0, float(hall_definition.get("height", 0.0)), envelope.y - inset * 2.0)
	if not blocker_box.size.is_equal_approx(expected_size):
		_fail("T0201 blocker does not match the configured main-hall interior: %s / %s" % [blocker_box.size, expected_size])
		return
	if (
		blocker.collision_layer != 1
		or blocker.collision_mask != 2
		or str(blocker.get_meta("collision_category", "")) != "building_interior_blocker"
		or str(blocker.get_meta("building_id", "")) != "main_hall"
		or not bool(blocker.get_meta("transparent_entity", false))
		or not bool(blocker.get_meta("blocks_navigation", false))
		or not blocker.is_in_group("formal_navigation_source")
		or not blocker.find_children("*", "MeshInstance3D", true, false).is_empty()
	):
		_fail("T0201 blocker authority or transparency drifted")
		return

	var links_root := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/SpatialContract/BuildingDoorLinks"
	)
	if links_root == null or links_root.get_child_count() != 11:
		_fail("T0201 expected 11 building door links after removing the main-hall link")
		return
	for raw_link in links_root.get_children():
		if str(raw_link.get_meta("building_id", "")) == "main_hall":
			_fail("T0201 main hall still owns a navigation door link")
			return

	var space := hall.get_world_3d().direct_space_state
	var door_hit := _ray_world_static(
		space,
		hall.to_global(Vector3(0.0, 0.8, envelope.y * 0.5 + 1.0)),
		hall.to_global(Vector3(0.0, 0.8, 0.0))
	)
	var door_collider := door_hit.get("collider") as StaticBody3D
	if door_collider != blocker:
		_fail("T0201 transparent blocker does not close the visible main-hall doorway: %s" % door_hit)
		return
	var facade_hit := _ray_world_static(
		space,
		hall.to_global(Vector3(5.0, 0.8, envelope.y * 0.5 + 1.0)),
		hall.to_global(Vector3(5.0, 0.8, 0.0))
	)
	var facade_collider := facade_hit.get("collider") as StaticBody3D
	if (
		facade_collider == null
		or str(facade_collider.get_meta("collision_category", "")) != "building_wall"
		or str(facade_collider.get_meta("building_segment_id", "")) != "front_right"
	):
		_fail("T0201 interior blocker replaced the existing main-hall attack facade: %s" % facade_hit)
		return

	controller.debug_set_preview_enabled(true)
	for _step in 6:
		await physics_frame
	var navigation_map := navigation_region.get_navigation_map()
	NavigationServer3D.map_force_update(navigation_map)
	var start := hall.to_global(Vector3(0.0, 0.0, envelope.y * 0.5 + 2.0))
	var finish := hall.to_global(Vector3(0.0, 0.0, -envelope.y * 0.5 - 2.0))
	var path := NavigationServer3D.map_get_path(navigation_map, start, finish, true)
	if path.size() < 3:
		_fail("T0201 front-to-rear route did not detour around the solid main hall: %s" % path)
		return
	var half_size := Vector2(blocker_box.size.x, blocker_box.size.z) * 0.5
	for index in range(1, path.size()):
		var segment_length := path[index - 1].distance_to(path[index])
		var sample_count := maxi(1, int(ceil(segment_length / 0.2)))
		for sample_index in range(sample_count + 1):
			var sample := path[index - 1].lerp(path[index], float(sample_index) / float(sample_count))
			var local := hall.to_local(sample)
			if absf(local.x) < half_size.x - 0.05 and absf(local.z) < half_size.y - 0.05:
				_fail("T0201 navigation path crosses the main-hall interior at %s: %s" % [local, path])
				return

	var physics_snapshot: Dictionary = controller.debug_get_physics_navigation_snapshot()
	var production_navigation := physics_snapshot.get("production_navigation", {}) as Dictionary
	if (
		int(physics_snapshot.get("building_interior_blocker_count", 0)) != 1
		or int(production_navigation.get("enabled_building_door_link_count", -1)) != 11
	):
		_fail("T0201 physics/navigation snapshot drifted: %s" % physics_snapshot)
		return

	print("T0201 main-hall solid collision verification passed: %s" % JSON.stringify({
		"blocker_size": blocker_box.size,
		"door_links": links_root.get_child_count(),
		"detour_points": path.size(),
		"physics": physics_snapshot,
	}))
	quit(0)


func _ray_world_static(space: PhysicsDirectSpaceState3D, from_position: Vector3, to_position: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from_position, to_position, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space.intersect_ray(query)


func _find_building(layout: Dictionary, building_id: String) -> Dictionary:
	for raw_building in layout.get("buildings", []):
		var building := raw_building as Dictionary
		if str(building.get("id", "")) == building_id:
			return building
	return {}


func _load_json_dictionary(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}


func _v2(value: Variant) -> Vector2:
	if not value is Array or value.size() < 2:
		return Vector2.ZERO
	return Vector2(float(value[0]), float(value[1]))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
