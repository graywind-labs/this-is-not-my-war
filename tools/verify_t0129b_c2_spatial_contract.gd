extends SceneTree


const MAIN_PATH := "res://scenes/main/Main.tscn"
const LAYOUT_PATH := "res://data/station_layout.json"
const SPATIAL_PLAN_PATH := "res://data/presentation/station_spatial_plan.json"

var _failed := false


func _init() -> void:
	var layout := _load_json_dictionary(LAYOUT_PATH)
	var plan := _load_json_dictionary(SPATIAL_PLAN_PATH)
	if layout.is_empty() or plan.is_empty():
		_fail("Formal layout or accepted spatial plan is missing")
		return
	if str(layout.get("schema_version", "")) != "station_layout_v2":
		_fail("C2 formal spatial contract must use station_layout_v2")
		return
	var parity_errors := _validate_authoritative_position_parity(layout, plan)
	if not parity_errors.is_empty():
		_fail("C2 authoritative positions drifted from the accepted capacity plan: %s" % parity_errors)
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
	var legacy_npc_root := root.get_node_or_null("Main/WorldRoot/Station/NPCs") as Node3D
	if controller == null or formal_root == null or legacy_npc_root == null:
		_fail("C2 Main integration nodes are missing")
		return
	var snapshot: Dictionary = controller.debug_get_layout_snapshot()
	if int(snapshot.get("configuration_error_count", -1)) != 0:
		_fail("Station layout controller reported config errors: %s" % snapshot)
		return
	if str(snapshot.get("migration_phase", "")) != "a5_p7_default_formal_world":
		_fail("Unexpected C2 migration phase: %s" % snapshot)
		return
	if int(snapshot.get("building_spatial_count", 0)) != 12:
		_fail("All 12 building spatial contracts must be generated: %s" % snapshot)
		return
	if int(snapshot.get("building_workstation_position_count", 0)) != 61:
		_fail("Formal contract must expose 61 building workstations: %s" % snapshot)
		return
	if int(snapshot.get("defense_slot_position_count", 0)) != 4:
		_fail("Formal contract must expose four main-hall defense slots: %s" % snapshot)
		return
	if int(snapshot.get("authoritative_position_count", 0)) != 65:
		_fail("Formal contract must expose exactly 65 authoritative positions: %s" % snapshot)
		return
	if int(snapshot.get("npc_initial_position_count", 0)) != 8:
		_fail("Formal contract must expose all eight NPC initial positions: %s" % snapshot)
		return
	if int(snapshot.get("public_location_count", 0)) != 2:
		_fail("Formal contract must expose plaza and notice-board anchors: %s" % snapshot)
		return
	if int(snapshot.get("navigation_region_count", 0)) != 3:
		_fail("Formal contract must generate the station region plus the staged C3 enemy-approach region: %s" % snapshot)
		return
	if int(snapshot.get("navigation_walkable_cell_count", 0)) < 1200:
		_fail("Formal station navigation coverage is implausibly small: %s" % snapshot)
		return
	if not bool(snapshot.get("navigation_enabled", false)):
		_fail("Default formal navigation must be enabled")
		return
	if not formal_root.visible:
		_fail("A5-P7 formal root must be visible by default")
		return
	var compatibility: Dictionary = controller.debug_set_legacy_compatibility_enabled(true)
	if bool(compatibility.get("navigation_enabled", true)) or bool(compatibility.get("preview_enabled", true)):
		_fail("Explicit legacy compatibility did not suspend formal navigation")
		return
	var legacy_npc_positions := {}
	for npc in legacy_npc_root.get_children():
		if npc is Node3D:
			legacy_npc_positions[str(npc.name)] = (npc as Node3D).global_position

	var spatial_root := formal_root.get_node_or_null("SpatialContract")
	var navigation_region := formal_root.get_node_or_null("SpatialContract/StationNavigation") as NavigationRegion3D
	if spatial_root == null or navigation_region == null:
		_fail("Generated C2 spatial hierarchy is incomplete")
		return
	var marker_count := int(snapshot.get("spatial_anchor_count", 0))
	if marker_count != 135:
		_fail("Unexpected authoritative spatial anchor count: %d" % marker_count)
		return

	var reachability: Dictionary = controller.debug_get_spatial_reachability_snapshot()
	if int(reachability.get("target_count", 0)) != 123:
		_fail("C2 reachability target contract drifted: %s" % reachability)
		return
	if int(reachability.get("unreachable_count", -1)) != 0:
		_fail("Every public, NPC, entry/interior and authoritative target must be reachable: %s" % reachability)
		return

	for raw_building in layout.get("buildings", []):
		var building: Dictionary = raw_building
		var building_id := str(building.get("id", ""))
		var route: Dictionary = controller.get_building_spatial_route(building_id)
		if route.is_empty() or not bool(route.get("live_default", false)) or bool(route.get("staged", true)):
			_fail("Missing live default route for building: %s" % building_id)
			return
		if not route.get("entry_outside_position") is Vector3 or not route.get("door_inside_position") is Vector3:
			_fail("Building route is missing physical door positions: %s" % building_id)
			return
		var positions: Array = (layout.get("building_spatial", {}) as Dictionary)[building_id].get("positions", [])
		for raw_position in positions:
			var position: Dictionary = raw_position
			var position_route: Dictionary = controller.get_building_spatial_route(
				building_id, str(position.get("id", ""))
			)
			if position_route.is_empty() or not position_route.get("interior_target_position") is Vector3:
				_fail("Missing physical target for %s/%s" % [building_id, position.get("id", "")])
				return

	for raw_initial in layout.get("npc_initial_positions", []):
		var initial: Dictionary = raw_initial
		var world_position: Variant = controller.get_npc_initial_world_position(str(initial.get("npc_id", "")))
		if not world_position is Vector3 or absf((world_position as Vector3).x) > 80.0 or absf((world_position as Vector3).z) > 100.0:
			_fail("NPC initial anchor was not generated in the origin-rebased formal world: %s" % initial)
			return

	var preview: Dictionary = controller.debug_set_preview_enabled(true)
	if not bool(preview.get("preview_enabled", false)) or not bool(preview.get("navigation_enabled", false)):
		_fail("Preview must expose and enable the staged navigation island: %s" % preview)
		return
	for _step in 4:
		await process_frame
		await physics_frame
	var navigation_map := navigation_region.get_navigation_map()
	NavigationServer3D.map_force_update(navigation_map)
	var godot_navigation_target_count := 0
	var godot_navigation_source := formal_root.to_global(Vector3(0.0, 0.12, 10.0))
	for raw_building in layout.get("buildings", []):
		var building: Dictionary = raw_building
		var building_id := str(building.get("id", ""))
		var positions: Array = (layout.get("building_spatial", {}) as Dictionary)[building_id].get("positions", [])
		for raw_position in positions:
			var position: Dictionary = raw_position
			var route: Dictionary = controller.get_building_spatial_route(building_id, str(position.get("id", "")))
			var target: Vector3 = route.get("interior_target_position")
			var godot_path := NavigationServer3D.map_get_path(
				navigation_map,
				godot_navigation_source,
				target,
				true
			)
			if godot_path.is_empty():
				_fail("Godot NavigationServer could not reach %s/%s" % [building_id, position.get("id", "")])
				return
			godot_navigation_target_count += 1
	if godot_navigation_target_count != 65:
		_fail("Godot navigation did not validate all 65 authoritative targets")
		return
	var restored: Dictionary = controller.debug_set_preview_enabled(false)
	if bool(restored.get("navigation_enabled", true)) or bool(restored.get("preview_enabled", true)):
		_fail("Returning to legacy gameplay must disable staged navigation: %s" % restored)
		return
	for npc in legacy_npc_root.get_children():
		if npc is Node3D and legacy_npc_positions.has(str(npc.name)):
			if (npc as Node3D).global_position != legacy_npc_positions[str(npc.name)]:
				_fail("C2 staging preview moved a live legacy NPC: %s" % npc.name)
				return
	controller.debug_set_legacy_compatibility_enabled(false)

	print("T0129B C2 spatial contract verification passed: %s" % JSON.stringify({
		"layout": snapshot,
		"reachability": reachability
	}))
	quit(0)


func _validate_authoritative_position_parity(layout: Dictionary, plan: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var formal_contracts: Dictionary = layout.get("building_spatial", {})
	var planned_layouts: Dictionary = plan.get("max_level_layouts", {})
	var formal_total := 0
	for building_id in formal_contracts.keys():
		var formal_positions := _index_authoritative_positions(formal_contracts[building_id].get("positions", []))
		var planned: Dictionary = planned_layouts.get(building_id, {})
		var planned_positions := _index_authoritative_positions(planned.get("positions", []))
		formal_total += formal_positions.size()
		if formal_positions.size() != planned_positions.size():
			errors.append("count:%s" % building_id)
			continue
		for position_id in formal_positions.keys():
			var formal: Dictionary = formal_positions[position_id]
			var accepted: Dictionary = planned_positions.get(position_id, {})
			if accepted.is_empty():
				errors.append("missing:%s/%s" % [building_id, position_id])
				continue
			if (
				str(formal.get("type", "")) != str(accepted.get("type", ""))
				or int(formal.get("required_level", 0)) != int(accepted.get("required_level", 0))
				or _v2(formal.get("center", [])) != _v2(accepted.get("center", []))
				or _v2(formal.get("size", [])) != _v2(accepted.get("size", []))
			):
				errors.append("geometry:%s/%s" % [building_id, position_id])
	if formal_total != 65:
		errors.append("formal_total")
	return errors


func _index_authoritative_positions(raw_positions: Variant) -> Dictionary:
	var result: Dictionary = {}
	for raw_position in raw_positions:
		var position: Dictionary = raw_position
		if not ["building_workstation", "defense_device_slot"].has(str(position.get("authority", ""))):
			continue
		result[str(position.get("id", ""))] = position
	return result


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
