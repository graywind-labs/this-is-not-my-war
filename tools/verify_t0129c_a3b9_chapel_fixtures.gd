extends SceneTree

const MAIN_PATH := "res://scenes/main/Main.tscn"
const FIXTURE_PATH := "res://data/building_fixture_layouts.json"

func _init() -> void:
	var config := _load_json(FIXTURE_PATH)
	var packed := load(MAIN_PATH) as PackedScene
	if config.is_empty() or packed == null:
		_fail("A3b9 inputs unavailable")
		return
	var main := packed.instantiate()
	root.add_child(main)
	for _i in 4:
		await process_frame
		await physics_frame
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var chapel := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/BuildingRoots/Chapel") as Node3D
	var region := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/SpatialContract/StationNavigation") as NavigationRegion3D
	var fixture_root := chapel.get_node_or_null("FixtureLayout") if chapel != null else null
	var chapel_art := chapel.get_node_or_null("ChapelArt") if chapel != null else null
	if controller == null or building_system == null or fixture_root == null or region == null or chapel_art == null:
		_fail("A3b9 hierarchy incomplete")
		return
	var snapshot: Dictionary = controller.debug_get_layout_snapshot()
	var physics: Dictionary = controller.debug_get_physics_navigation_snapshot()
	if int(snapshot.get("configuration_error_count", -1)) != 0 or not _final_counts_match(snapshot, physics):
		_fail("A3b9 final aggregate/config drift: %s / %s" % [snapshot, physics])
		return
	var visuals := fixture_root.get_node_or_null("Visuals")
	var collisions := fixture_root.get_node_or_null("StaticCollision")
	var stands := fixture_root.get_node_or_null("NPCStands")
	var anchors := fixture_root.get_node_or_null("OccupantAnchors")
	if visuals == null or collisions == null or stands == null or anchors == null or visuals.get_child_count() != 16 or collisions.get_child_count() != 16 or stands.get_child_count() != 11 or anchors.get_child_count() != 10:
		_fail("Chapel must expose 16 fixtures/colliders, 11 stands and 10 prayer anchors")
		return
	chapel_art.call("debug_force_visual_level", 1)
	if _active_visual_count(visuals) != 11 or _active_collision_count(collisions) != 11:
		_fail("Chapel Lv.1 must expose only altar + ten prayer seats")
		return
	chapel_art.call("debug_force_visual_level", 2)
	if _active_visual_count(visuals) != 16 or _active_collision_count(collisions) != 16:
		_fail("Chapel Lv.2 must expose all five non-capacity presentation fixtures")
		return
	var chapel_config := ((config.get("buildings", {}) as Dictionary).get("chapel", {}) as Dictionary)
	var mapped := 0
	var prayer_count := 0
	var left_pews := 0
	var right_pews := 0
	var level_two_shared := 0
	var route_sizes: Dictionary = {}
	controller.debug_set_preview_enabled(true)
	for _i in 3:
		await physics_frame
	var map := region.get_navigation_map()
	NavigationServer3D.map_force_update(map)
	for raw_fixture in chapel_config.get("fixtures", []):
		var fixture := raw_fixture as Dictionary
		var fixture_id := str(fixture.get("id", ""))
		var visual := _find_by_meta(visuals, "fixture_id", fixture_id) as Node3D
		var body := _find_by_meta(collisions, "fixture_id", fixture_id) as StaticBody3D
		if visual == null or body == null or body.collision_layer != 1 or body.collision_mask != 2:
			_fail("Chapel visual/collision missing: %s" % fixture_id)
			return
		var workstation_id := str(fixture.get("workstation_id", ""))
		if workstation_id.is_empty():
			if int(fixture.get("required_level", 0)) != 2:
				_fail("Chapel shared upgrade must be level two: %s" % fixture_id)
				return
			if str(fixture.get("kind", "")) == "chapel_stained_window" and (visual.get_node_or_null("LeftWindowFrame") == null or visual.get_node_or_null("WindowMullion") == null or visual.get_node_or_null("WindowFrame") != null):
				_fail("Chapel stained window must use an open framed assembly")
				return
			if str(fixture.get("kind", "")) == "chapel_roof_truss" and float(fixture.get("visual_y", 0.0)) < 3.0:
				_fail("Chapel roof truss must remain above the interior sightline")
				return
			level_two_shared += 1
			continue
		mapped += 1
		if workstation_id.begins_with("chapel_prayer_seat_"):
			prayer_count += 1
			var pew_side := str(fixture.get("pew_side", ""))
			left_pews += 1 if pew_side == "left" else 0
			right_pews += 1 if pew_side == "right" else 0
			var anchor := fixture.get("occupant_anchor", {}) as Dictionary
			if (
				str(fixture.get("kind", "")) != "chapel_prayer_pew"
				or str(fixture.get("asset_path", "")) != "res://assets/3d/quaternius/props/chapel_bench.glb"
				or str(fixture.get("arrival_mode", "")) != "mount_after_arrival"
				or str(anchor.get("pose", "")) != "seated_prayer"
				or visual.get_node_or_null("BackRail") == null
				or visual.get_node_or_null("SeatMarkerCushion") == null
				or visual.get_node_or_null("PrayerBook") == null
			):
				_fail("Prayer seat lacks Quaternius pew presentation: %s" % workstation_id)
				return
		elif workstation_id == "chapel_altar_01":
			for required_prop in ["AisleRunner", "CrossStem", "LeftCandlestick", "RightCandlestick", "Chalice", "Lectern", "LecternBook"]:
				if visual.get_node_or_null(required_prop) == null:
					_fail("Chapel altar lacks professional prop: %s" % required_prop)
					return
		var route: Dictionary = controller.get_building_spatial_route("chapel", workstation_id)
		var target: Vector3 = route.get("interior_target_position", Vector3.ZERO)
		var path := NavigationServer3D.map_get_path(map, route.get("entry_outside_position", Vector3.ZERO), target, true)
		if str(route.get("target_fixture_id", "")) != fixture_id or path.size() < 3 or path[-1].distance_to(target) > 0.31:
			_fail("Chapel production route failed: %s / %s" % [workstation_id, path])
			return
		route_sizes[workstation_id] = path.size()
	controller.debug_set_preview_enabled(false)
	var building: Dictionary = building_system.get_building("chapel")
	if mapped != 11 or prayer_count != 10 or left_pews != 5 or right_pews != 5 or level_two_shared != 5 or _count_type(building, "chapel_altar") != 1 or _count_type(building, "chapel_prayer_seat") != 10:
		_fail("Chapel fixed 1+10 authority contract drifted")
		return
	chapel_art.call("debug_force_visual_level", 1)
	print("T0129C A3b9R chapel verification passed: %s" % JSON.stringify({"fixtures":16,"pew_rows":5,"routes":route_sizes}))
	quit(0)

func _final_counts_match(snapshot: Dictionary, physics: Dictionary) -> bool:
	return int(snapshot.get("building_fixture_count", 0)) == 109 and int(snapshot.get("fixture_workstation_stand_count", 0)) == 61 and int(snapshot.get("fixture_occupant_anchor_count", 0)) == 36 and int(physics.get("building_fixture_count", 0)) == 133 and int(physics.get("static_body_count", 0)) == 236

func _active_visual_count(visuals: Node) -> int:
	var total := 0
	for child in visuals.get_children():
		if child is Node3D and (child as Node3D).visible:
			total += 1
	return total

func _active_collision_count(collisions: Node) -> int:
	var total := 0
	for child in collisions.get_children():
		if child is StaticBody3D and (child as StaticBody3D).collision_layer != 0:
			total += 1
	return total

func _count_type(building: Dictionary, type_id: String) -> int:
	var total := 0
	for raw in building.get("workstations", []):
		if str((raw as Dictionary).get("type", "")) == type_id: total += 1
	return total

func _find_by_meta(parent: Node, key: String, value: String) -> Node:
	for child in parent.get_children():
		if str(child.get_meta(key, "")) == value: return child
	return null

func _load_json(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
