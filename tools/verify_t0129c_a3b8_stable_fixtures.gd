extends SceneTree


const MAIN_PATH := "res://scenes/main/Main.tscn"
const FIXTURE_LAYOUTS_PATH := "res://data/building_fixture_layouts.json"
const STATION_LAYOUT_PATH := "res://data/station_layout.json"
const SPATIAL_PLAN_PATH := "res://data/presentation/station_spatial_plan.json"

var _failed := false


func _init() -> void:
	var fixture_layouts := _load_json_dictionary(FIXTURE_LAYOUTS_PATH)
	var station_layout := _load_json_dictionary(STATION_LAYOUT_PATH)
	var spatial_plan := _load_json_dictionary(SPATIAL_PLAN_PATH)
	var main_scene := load(MAIN_PATH) as PackedScene
	if fixture_layouts.is_empty() or station_layout.is_empty() or spatial_plan.is_empty() or main_scene == null:
		_fail("T0129C-A3b8 inputs could not be loaded")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	for _step in 4:
		await process_frame
		await physics_frame

	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var formal_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout") as Node3D
	var stable := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/BuildingRoots/Stable") as Node3D
	var stable_art := stable.get_node_or_null("StableArt") if stable != null else null
	var fixture_root := stable.get_node_or_null("FixtureLayout") if stable != null else null
	var navigation_region := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/SpatialContract/StationNavigation"
	) as NavigationRegion3D
	if (
		controller == null
		or building_system == null
		or horse_system == null
		or formal_root == null
		or stable == null
		or stable_art == null
		or fixture_root == null
		or navigation_region == null
	):
		_fail("T0129C-A3b8 hierarchy is incomplete")
		return
	# A3b8 is the historical maximum-layout audit. The formal art view correctly
	# disables future fixture collisions at the real Lv.1, so preview Lv.3 before
	# inspecting all nine configured fixture collision sets.
	stable_art.call("debug_force_visual_level", 3)
	await process_frame
	await physics_frame

	var snapshot: Dictionary = controller.debug_get_layout_snapshot()
	var physics_snapshot: Dictionary = controller.debug_get_physics_navigation_snapshot()
	if int(snapshot.get("configuration_error_count", -1)) != 0:
		_fail("Stable fixture configuration validation failed: %s" % snapshot)
		return
	if (
		int(snapshot.get("building_fixture_count", 0)) != 109
		or int(snapshot.get("fixture_workstation_stand_count", 0)) != 61
		or int(snapshot.get("fixture_occupant_anchor_count", 0)) != 36
		or int(snapshot.get("fixture_horse_anchor_count", 0)) != 8
		or int(physics_snapshot.get("static_body_count", 0)) != 236
		or int(physics_snapshot.get("building_fixture_count", 0)) != 133
	):
		_fail("Stable fixture aggregate counts drifted: %s / %s" % [snapshot, physics_snapshot])
		return

	var fixture_collisions := fixture_root.get_node_or_null("StaticCollision")
	var fixture_visuals := fixture_root.get_node_or_null("Visuals")
	var fixture_stands := fixture_root.get_node_or_null("NPCStands")
	var horse_anchors := fixture_root.get_node_or_null("HorseAnchors")
	if (
		fixture_collisions == null
		or fixture_visuals == null
		or fixture_stands == null
		or horse_anchors == null
		or fixture_collisions.get_child_count() != 27
		or fixture_visuals.get_child_count() != 9
		or fixture_stands.get_child_count() != 3
		or horse_anchors.get_child_count() != 8
	):
		_fail("Stable must expose nine fixtures, 27 collision parts, three care stands and eight horse anchors")
		return

	var stable_config: Dictionary = (
		(fixture_layouts.get("buildings", {}) as Dictionary).get("stable", {}) as Dictionary
	)
	var stable_spatial: Dictionary = (
		(station_layout.get("building_spatial", {}) as Dictionary).get("stable", {}) as Dictionary
	)
	var stable_plan: Dictionary = (
		(spatial_plan.get("max_level_layouts", {}) as Dictionary).get("stable", {}) as Dictionary
	)
	var authority_positions: Dictionary = {}
	for raw_position in stable_spatial.get("positions", []):
		var position: Dictionary = raw_position
		authority_positions[str(position.get("id", ""))] = position
	var planned_positions: Dictionary = {}
	for raw_position in stable_plan.get("positions", []):
		var position: Dictionary = raw_position
		planned_positions[str(position.get("id", ""))] = position
	if authority_positions.size() != 3 or planned_positions.size() != 8:
		_fail("Stable authority/presentation position counts must remain 3/8")
		return

	var direct_space_state := formal_root.get_world_3d().direct_space_state
	var mapped_workstations: Dictionary = {}
	var anchor_ids: Dictionary = {}
	var bay_count := 0
	var feed_rack_count := 0
	var route_results: Dictionary = {}
	for raw_fixture in stable_config.get("fixtures", []):
		var fixture: Dictionary = raw_fixture
		var fixture_id := str(fixture.get("id", ""))
		var kind := str(fixture.get("kind", ""))
		var workstation_id := str(fixture.get("workstation_id", ""))
		var visual := _find_child_by_meta(fixture_visuals, "fixture_id", fixture_id) as Node3D
		var collisions := _find_children_by_meta(fixture_collisions, "fixture_id", fixture_id)
		if visual == null or collisions.is_empty():
			_fail("Stable visual/collision set is missing: %s" % fixture_id)
			return
		for collision_node in collisions:
			var collision := collision_node as StaticBody3D
			var collision_shape := collision.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if collision == null or collision.collision_layer != 1 or collision.collision_mask != 2 or collision_shape == null or not collision_shape.shape is BoxShape3D:
				_fail("Stable collision must remain an auditable world-static BoxShape3D: %s" % fixture_id)
				return
			if _collision_overlaps_other_fixture(direct_space_state, collision, collision_shape, fixture_id):
				_fail("Stable fixture overlaps another fixture: %s/%s" % [fixture_id, collision.name])
				return

		match kind:
			"stable_horse_bay":
				bay_count += 1
				if visual.get_node_or_null("TroughBase") == null or visual.get_node_or_null("Feed") == null:
					_fail("Stable bay lacks a readable trough/feed presentation: %s" % fixture_id)
					return
			"stable_feed_storage":
				feed_rack_count += 1
				if not workstation_id.is_empty() or visual.get_node_or_null("QuaterniusFeedBucket") == null:
					_fail("Shared level-two feed rack must use Quaternius dressing without creating capacity")
					return
			_:
				_fail("Unexpected stable fixture kind: %s" % kind)
				return

		var horse_anchor_config := fixture.get("horse_anchor", {}) as Dictionary
		if not horse_anchor_config.is_empty():
			var anchor_id := str(horse_anchor_config.get("id", ""))
			var anchor := _find_child_by_meta(horse_anchors, "horse_anchor_id", anchor_id) as Marker3D
			var anchor_center := _v2(horse_anchor_config.get("center", []))
			var footprint := _v2(horse_anchor_config.get("footprint_size", []))
			if anchor == null or anchor_ids.has(anchor_id) or not planned_positions.has(anchor_id):
				_fail("Stable horse anchor is missing, duplicated or outside the spatial plan: %s" % anchor_id)
				return
			anchor_ids[anchor_id] = fixture_id
			if anchor_center.distance_to(_v2((planned_positions[anchor_id] as Dictionary).get("center", []))) > 0.001:
				_fail("Stable horse anchor drifted from the maximum-level spatial plan: %s" % anchor_id)
				return
			var anchor_world := stable.to_global(Vector3(anchor_center.x, 0.9, anchor_center.y))
			var clearance_hit := _horse_clearance_fixture_hit(direct_space_state, anchor_world, stable.global_basis.orthonormalized(), footprint)
			if footprint.x + 0.001 < 1.4 or footprint.y + 0.001 < 2.2 or not clearance_hit.is_empty():
				_fail("Stable horse CharacterBody clearance is blocked or undersized: %s / %s" % [anchor_id, clearance_hit])
				return

		if workstation_id.is_empty():
			continue
		if mapped_workstations.has(workstation_id) or not authority_positions.has(workstation_id):
			_fail("Stable care workstation mapping is missing or duplicated: %s" % workstation_id)
			return
		mapped_workstations[workstation_id] = fixture_id
		var authority: Dictionary = authority_positions[workstation_id]
		if int(authority.get("required_level", 0)) != int(fixture.get("required_level", 0)):
			_fail("Stable fixture level no longer mirrors BuildingSystem authority: %s" % workstation_id)
			return
		var stand := _find_child_by_meta(fixture_stands, "fixture_id", fixture_id) as Marker3D
		var stand_config := fixture.get("npc_stand", {}) as Dictionary
		var stand_local := _v2(stand_config.get("center", []))
		var anchor_local := _v2(horse_anchor_config.get("center", []))
		var stand_world := stable.to_global(Vector3(stand_local.x, 0.8, stand_local.y))
		var route: Dictionary = controller.get_building_spatial_route("stable", workstation_id)
		if (
			stand == null
			or stand_local.distance_to(anchor_local) < 1.7
			or str(route.get("target_fixture_id", "")) != fixture_id
			or str(route.get("arrival_mode", "")) != "stand"
			or (route.get("interior_target_position", Vector3.ZERO) as Vector3).distance_to(stand_world - Vector3(0.0, 0.8, 0.0)) > 0.001
		):
			_fail("Stable NPC stand/horse clearance route drifted: %s" % workstation_id)
			return

	if bay_count != 8 or feed_rack_count != 1 or mapped_workstations.size() != 3 or anchor_ids.size() != 8:
		_fail("Stable must keep eight bays, one shared feed rack, three care workstations and eight horse anchors")
		return
	if not _verify_building_and_horse_authority(building_system, horse_system):
		return

	controller.debug_set_preview_enabled(true)
	for _preview_step in 4:
		await process_frame
		await physics_frame
	var navigation_map := navigation_region.get_navigation_map()
	NavigationServer3D.map_force_update(navigation_map)
	for workstation_id in mapped_workstations.keys():
		var route: Dictionary = controller.get_building_spatial_route("stable", str(workstation_id))
		var target: Vector3 = route.get("interior_target_position", Vector3.ZERO)
		var path := NavigationServer3D.map_get_path(
			navigation_map,
			route.get("entry_outside_position", Vector3.ZERO),
			target,
			true
		)
		if path.size() < 3 or path[path.size() - 1].distance_to(target) > 0.3:
			_fail("Production navigation cannot reach stable care position: %s / %s" % [workstation_id, path])
			return
		route_results[workstation_id] = path.size()
	controller.debug_set_preview_enabled(false)

	print("T0129C A3b8 stable fixture verification passed: %s" % JSON.stringify({
		"bay_count": bay_count,
		"care_workstation_count": mapped_workstations.size(),
		"horse_anchor_count": anchor_ids.size(),
		"production_navigation": controller.debug_get_production_navigation_snapshot(),
		"routes": route_results
	}))
	quit(0)


func _verify_building_and_horse_authority(building_system: Node, horse_system: Node) -> bool:
	var building: Dictionary = building_system.get_building("stable")
	var level_one_count := _count_station_type(building, "horse_care")
	building_system._apply_workstation_upgrade(building, building_system.get_upgrade_level_effect("stable", 2))
	var level_two_count := _count_station_type(building, "horse_care")
	building_system._apply_workstation_upgrade(building, building_system.get_upgrade_level_effect("stable", 3))
	var level_three_count := _count_station_type(building, "horse_care")
	if [level_one_count, level_two_count, level_three_count] != [2, 2, 3]:
		_fail("BuildingSystem stable care capacity must remain 2 -> 2 -> 3")
		return false
	var horse_ids: Array = horse_system.get_horse_ids()
	if horse_ids.size() != 2:
		_fail("Stable staging must not create or remove HorseSystem entities")
		return false
	for horse_id in horse_ids:
		var horse: Dictionary = horse_system.get_horse_snapshot(str(horse_id))
		if str(horse.get("location", "")) != "stable" or not bool(horse.get("is_adult", false)):
			_fail("Both initial adult horses must remain physically in the stable")
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
	for hit in space_state.intersect_shape(query, 128):
		var collider := (hit as Dictionary).get("collider") as StaticBody3D
		if collider != null and str(collider.get_meta("collision_category", "")) == "building_fixture" and str(collider.get_meta("fixture_id", "")) != fixture_id:
			return true
	return false


func _horse_clearance_fixture_hit(space_state: PhysicsDirectSpaceState3D, center: Vector3, basis: Basis, size: Vector2) -> String:
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, 1.8, size.y)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(basis, center)
	query.collision_mask = 1
	for hit in space_state.intersect_shape(query, 64):
		var collider := (hit as Dictionary).get("collider") as StaticBody3D
		if collider != null and str(collider.get_meta("collision_category", "")) == "building_fixture":
			return "%s/%s" % [str(collider.get_meta("fixture_id", "")), collider.name]
	return ""


func _find_child_by_meta(parent: Node, key: String, value: String) -> Node:
	for child in parent.get_children():
		if str(child.get_meta(key, "")) == value:
			return child
	return null


func _find_children_by_meta(parent: Node, key: String, value: String) -> Array[Node]:
	var result: Array[Node] = []
	for child in parent.get_children():
		if str(child.get_meta(key, "")) == value:
			result.append(child)
	return result


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
