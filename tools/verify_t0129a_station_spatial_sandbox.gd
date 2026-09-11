extends SceneTree


const SANDBOX_PATH := "res://scenes/art/StationSpatialSandbox.tscn"
const PLAN_PATH := "res://data/presentation/station_spatial_plan.json"
const BUILDING_DEFS_PATH := "res://data/building_defs.json"
const DEFENSE_DEVICE_DEFS_PATH := "res://data/defense_device_defs.json"


func _init() -> void:
	var plan := _load_json_dictionary(PLAN_PATH)
	if plan.is_empty():
		_fail("Station spatial plan JSON is missing or invalid")
		return
	if str(plan.get("schema_version", "")) != "station_spatial_plan_v7":
		_fail("Unexpected station spatial plan schema")
		return
	if not is_equal_approx(float(plan.world_units.godot_units_per_meter), 1.0):
		_fail("Spatial plan must keep one Godot unit per meter")
		return

	var sandbox_scene := load(SANDBOX_PATH) as PackedScene
	if sandbox_scene == null:
		_fail("Failed to load StationSpatialSandbox.tscn")
		return
	var sandbox := sandbox_scene.instantiate()
	root.add_child(sandbox)
	await process_frame
	await process_frame

	var snapshot: Dictionary = sandbox.get_validation_snapshot()
	if not bool(snapshot.get("config_loaded", false)):
		_fail("Spatial sandbox did not load its plan")
		return
	if int(snapshot.get("lot_count", 0)) != 12:
		_fail("Expected 12 reserved building lots: %s" % [snapshot])
		return
	if int(snapshot.get("road_count", 0)) != 42:
		_fail("Expected the collision-safe 42-road network: %s" % [snapshot])
		return
	if int(snapshot.get("lot_overlap_count", -1)) != 0:
		_fail("Reserved building lots overlap: %s" % [snapshot.get("lot_overlaps", [])])
		return
	if int(snapshot.get("lots_outside_count", -1)) != 0:
		_fail("Reserved building lots extend outside the interior: %s" % [snapshot.get("lots_outside", [])])
		return
	if int(snapshot.get("road_lot_overlap_count", -1)) != 0:
		_fail("Roads consume reserved building lots: %s" % [snapshot.get("road_lot_overlaps", [])])
		return

	_assert_vector2(snapshot.get("interior_size"), Vector2(103.0, 95.0), "station interior bounding box")
	_assert_vector2(snapshot.get("detail_size"), Vector2(280.0, 360.0), "detailed terrain")
	_assert_vector2(snapshot.get("underlay_size"), Vector2(700.0, 720.0), "low-detail underlay")
	_assert_vector2(snapshot.get("blacksmith_lot_size"), Vector2(16.0, 16.0), "blacksmith lot")
	_assert_vector2(snapshot.get("main_hall_lot_size"), Vector2(24.0, 20.0), "central main hall lot")
	_assert_vector2(snapshot.get("main_hall_envelope_size"), Vector2(22.0, 18.0), "central main hall envelope")
	if _failed:
		return
	if str(snapshot.get("layout_reference", "")) != "Main.tscn relative building composition / v1":
		_fail("Spatial plan must declare the current Main composition as its relative-layout reference")
		return
	if int(snapshot.get("main_reference_layout_error_count", -1)) != 0:
		_fail("Main-relative building composition drifted: %s" % [snapshot.get("main_reference_layout_errors", [])])
		return
	if float(snapshot.get("main_hall_graybox_height", 0.0)) < 3.0:
		_fail("Main hall must remain the dominant central graybox volume")
		return
	if str(snapshot.get("ground_color", "")) != "#405842" or int(snapshot.get("terrain_layer_count", 0)) != 1:
		_fail("Sandbox must render one continuous deep-green ground layer without a pale station patch")
		return
	if int(snapshot.get("terrain_tile_count", 0)) != 2:
		_fail("Expanded ground must use two efficient same-material banks around a real lowered river trench")
		return
	if float(snapshot.get("station_above_river_m", 0.0)) < 1.0:
		_fail("River surface must be physically lower than the station ground")
		return
	if not is_equal_approx(float(snapshot.get("target_interior_area_m2", 0.0)), 9785.0):
		_fail("Target station interior area changed: %s" % snapshot)
		return
	if not is_equal_approx(float(snapshot.get("current_area_m2", 0.0)), 728.0):
		_fail("Current station comparison area changed: %s" % snapshot)
		return
	if absf(float(snapshot.get("area_multiplier", 0.0)) - (9785.0 / 728.0)) > 0.001:
		_fail("Area multiplier is inconsistent: %s" % snapshot)
		return
	if float(snapshot.get("enemy_spawn_to_front_gate_m", 0.0)) < 240.0:
		_fail("Enemy forest staging must sit at the far map-edge forest, not near the gate")
		return
	var enemy_edge_inset := float(snapshot.get("enemy_spawn_edge_inset_m", 999.0))
	if enemy_edge_inset < 25.0 or enemy_edge_inset > 65.0:
		_fail("Enemy spawn must remain embedded just inside the map-edge forest")
		return
	if float(snapshot.get("back_gate_to_escape_completion_m", 0.0)) < 200.0:
		_fail("Rear escape route must leave enough time for player intervention")
		return
	if float(snapshot.get("escape_completion_edge_inset_m", 999.0)) > 35.0:
		_fail("Escape completion must occur at the map edge")
		return
	if int(snapshot.get("route_stage_count", 0)) != 6:
		_fail("Enemy route must expose six visible stages")
		return
	if not is_equal_approx(float(snapshot.get("camera_min_distance", 0.0)), 20.0) or not is_equal_approx(float(snapshot.get("camera_max_distance", 0.0)), 70.0):
		_fail("Sandbox camera must cover the planned 20-70 meter range")
		return
	if str(snapshot.get("workshop_orientation_direction", "")) != "东北":
		_fail("Workshop frontage must face inward using the northeast member of the eight-direction set")
		return
	if int(snapshot.get("eight_direction_lot_count", 0)) != 12 or not (snapshot.get("eight_direction_errors", []) as Array).is_empty():
		_fail("Every building must use a declared cardinal/intercardinal frontage: %s" % snapshot.get("eight_direction_errors", []))
		return
	if int(snapshot.get("building_name_label_count", 0)) != 12:
		_fail("Every building must expose a persistent name label")
		return
	if int(snapshot.get("entrance_access_error_count", -1)) != 0:
		_fail("Every building entrance must meet a road endpoint: %s" % [snapshot.get("entrance_access_errors", [])])
		return
	if float(snapshot.get("plaza_patch_area_m2", 999.0)) > 120.0:
		_fail("Public junction patches must stay compact instead of recreating a ceremonial plaza")
		return
	if int(snapshot.get("forest_instance_count", 0)) < 650:
		_fail("Natural cover must extend densely toward the underlay edges")
		return
	_assert_vector2((snapshot.get("forest_scatter_bounds") as Rect2).size, Vector2(688.0, 708.0), "forest scatter")
	if _failed:
		return
	if float(snapshot.get("camera_to_terrain_min_margin_m", 0.0)) < 85.0:
		_fail("Camera pan limits can expose the expanded terrain edge")
		return
	_assert_vector2(snapshot.get("camera_21_9_ground_footprint_size"), Vector2(338.84055, 124.77954), "21:9 maximum-zoom ground footprint")
	if _failed:
		return
	if float(snapshot.get("camera_21_9_to_terrain_min_margin_m", 0.0)) < 24.0:
		_fail("A 21:9 viewport can expose the terrain edge at a camera pan corner: %s" % snapshot)
		return
	if int(snapshot.get("blacksmith_max_positions", 0)) != 3:
		_fail("Blacksmith lot must reserve three visible max-level forge positions")
		return
	if int(snapshot.get("max_level_layout_count", 0)) != 12:
		_fail("Every building must have a max-level physical packing layout: %s" % snapshot)
		return
	if int(snapshot.get("max_level_position_rect_count", 0)) != 80:
		_fail("Expected 80 concrete fixture/work/upgrade footprints across the 12 buildings: %s" % snapshot)
		return
	if int(snapshot.get("authoritative_position_rect_count", 0)) != 65:
		_fail("Expected 61 building workstations plus four main-hall defense slots: %s" % snapshot)
		return
	if int(snapshot.get("stable_horse_anchor_count", 0)) != 8:
		_fail("Stable must physically expose all eight horse anchors at once: %s" % snapshot)
		return
	if float(snapshot.get("minimum_primary_aisle_width_m", 0.0)) < 2.4:
		_fail("Every max-level layout must preserve a 2.4 m primary aisle")
		return
	if int(snapshot.get("capacity_layout_error_count", -1)) != 0:
		_fail("Max-level physical footprints overflow, overlap, or block circulation: %s" % [snapshot.get("capacity_layout_errors", [])])
		return
	if int(snapshot.get("enemy_stress_count", 0)) != 48:
		_fail("Fifth-wave stress roster must instantiate all 48 configured enemies: %s" % snapshot)
		return
	if int(snapshot.get("enemy_stress_configuration_error_count", -1)) != 0:
		_fail("Enemy stress simulation configuration is invalid: %s" % snapshot.get("enemy_stress", {}))
		return
	if int(snapshot.get("enemy_stress_stage_corridor_error_count", -1)) != 0:
		_fail("Enemy formation exceeds a configured route or gate corridor: %s" % snapshot.get("enemy_stress", {}))
		return
	if not bool(snapshot.get("enemy_stress_spawn_inside_zone", false)):
		_fail("All 48 enemies must fit inside the protected forest spawn zone")
		return
	if not bool(snapshot.get("enemy_spawn_outside_initial_view", false)):
		_fail("The forest spawn formation must remain outside the initial maximum-zoom view")
		return
	if int(snapshot.get("enemy_route_lot_clearance_error_count", -1)) != 0:
		_fail("Enemy march corridor intersects an unrelated building lot: %s" % snapshot.get("enemy_route_lot_clearance_errors", []))
		return
	if int(snapshot.get("generated_mesh_count", 0)) < 180:
		_fail("Spatial sandbox did not generate enough graybox/environment geometry: %s" % snapshot)
		return

	var capacity_errors := _validate_max_position_counts(plan)
	if not capacity_errors.is_empty():
		_fail("Max-level visible position counts diverge from building_defs: %s" % capacity_errors)
		return
	var authoritative_layout_errors := _validate_authoritative_position_layouts(plan)
	if not authoritative_layout_errors.is_empty():
		_fail("Physical workstation/defense-slot IDs diverge from authority data: %s" % authoritative_layout_errors)
		return

	var enemy_stress := sandbox.get_node("Runtime/EnemyStress")
	var stress_result: Dictionary = enemy_stress.debug_run_full_simulation(0.12)
	if int(stress_result.get("character_body_count", 0)) != 48 or int(stress_result.get("collision_shape_count", 0)) != 48:
		_fail("Stress run must use 48 physical CharacterBody3D envelopes: %s" % stress_result)
		return
	var expected_type_counts := {
		"melee_infantry": 28,
		"polearm_infantry": 4,
		"crossbowman": 10,
		"mounted_ranged": 6
	}
	if stress_result.get("unit_type_counts", {}) != expected_type_counts:
		_fail("Stress roster diverges from wave_05 composition: %s" % stress_result)
		return
	if not bool(stress_result.get("completed", false)) or int(stress_result.get("overlap_sample_count", -1)) != 0:
		_fail("All 48 enemies must complete the forest-to-main-hall route without body-envelope overlap: %s" % stress_result)
		return
	if float(stress_result.get("minimum_clearance_m", -1.0)) < 0.12:
		_fail("Enemy formation minimum body clearance is below 0.12 m: %s" % stress_result)
		return

	var escape_stress := sandbox.get_node("Runtime/EscapeStress")
	var escape_result: Dictionary = escape_stress.debug_run_all_scenarios()
	if int(escape_result.get("configuration_error_count", -1)) != 0:
		_fail("Escape stress configuration is invalid: %s" % escape_result)
		return
	if int(escape_result.get("path_point_count", 0)) != 6 or int(escape_result.get("segment_count", 0)) != 5:
		_fail("Escape stress route must retain six physical path points: %s" % escape_result)
		return
	if float(escape_result.get("route_distance_m", 0.0)) < 260.0:
		_fail("Rear escape path is too short for player intervention: %s" % escape_result)
		return
	if not bool(escape_result.get("five_round_window_available", false)):
		_fail("Even the attacked/accelerated escape must allow five intervention rounds: %s" % escape_result)
		return
	if not bool(escape_result.get("completion_requires_final_point", false)) or int(escape_result.get("completion_error_count", -1)) != 0:
		_fail("Escape completion must occur only at the final map-edge point: %s" % escape_result)
		return
	var scenarios: Dictionary = escape_result.get("scenarios", {})
	if float(scenarios.get("default_seconds", 0.0)) < 50.0 or float(scenarios.get("attacked_seconds", 0.0)) < 40.0:
		_fail("Escape pacing is too short under default or attacked conditions: %s" % escape_result)
		return

	var focus_result: Dictionary = sandbox.debug_focus_area("blacksmith")
	if not bool(focus_result.get("ok", false)):
		_fail("Blacksmith focus shortcut is unavailable")
		return
	var focused_position: Vector3 = focus_result.get("camera_rig_position", Vector3.ZERO)
	if Vector2(focused_position.x, focused_position.z).distance_to(Vector2(15.0, 36.0)) > 0.01:
		_fail("Blacksmith focus did not target its planned lot")
		return

	print("T0129A station spatial sandbox verification passed: %s" % JSON.stringify(snapshot))
	quit(0)


var _failed := false


func _validate_max_position_counts(plan: Dictionary) -> Array[String]:
	var raw_defs = _load_json_variant(BUILDING_DEFS_PATH)
	if not raw_defs is Array:
		return ["building_defs_not_array"]
	var authoritative_max: Dictionary = {}
	for raw_building in raw_defs:
		var building: Dictionary = raw_building
		var building_id := str(building.get("id", ""))
		var counts: Dictionary = {}
		for raw_station in building.get("workstations", []):
			var station: Dictionary = raw_station
			var type_id := str(station.get("type", ""))
			counts[type_id] = int(counts.get(type_id, 0)) + 1
		var upgrade: Dictionary = building.get("upgrade", {})
		var effects: Dictionary = upgrade.get("level_effects", {})
		for raw_level in effects.keys():
			var effect: Dictionary = effects.get(raw_level, {})
			for raw_delta in effect.get("workstation_deltas", []):
				var delta: Dictionary = raw_delta
				var type_id := str(delta.get("type", ""))
				counts[type_id] = int(counts.get(type_id, 0)) + int(delta.get("count", 0))
		var total := 0
		for count in counts.values():
			total += int(count)
		authoritative_max[building_id] = total

	var errors: Array[String] = []
	for raw_lot in plan.get("building_lots", []):
		var lot: Dictionary = raw_lot
		var building_id := str(lot.get("id", ""))
		if building_id == "main_hall":
			if int(lot.get("max_visual_positions", -1)) != 4:
				errors.append("main_hall defense slots != 4")
			continue
		var expected := int(authoritative_max.get(building_id, -1))
		var actual := int(lot.get("max_visual_positions", -1))
		if actual != expected:
			errors.append("%s expected %d got %d" % [building_id, expected, actual])
	return errors


func _validate_authoritative_position_layouts(plan: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var expected: Dictionary = {}
	var raw_defs = _load_json_variant(BUILDING_DEFS_PATH)
	if not raw_defs is Array:
		return ["building_defs_not_array"]
	for raw_building in raw_defs:
		var building: Dictionary = raw_building
		var building_id := str(building.get("id", ""))
		var type_counts: Dictionary = {}
		for raw_station in building.get("workstations", []):
			var station: Dictionary = raw_station
			var type_id := str(station.get("type", ""))
			type_counts[type_id] = int(type_counts.get(type_id, 0)) + 1
			expected[building_id + "/" + str(station.get("id", ""))] = "%s|1" % type_id
		var effects: Dictionary = ((building.get("upgrade", {}) as Dictionary).get("level_effects", {}) as Dictionary)
		var levels: Array[int] = []
		for raw_level in effects.keys():
			levels.append(int(raw_level))
		levels.sort()
		for level in levels:
			var effect: Dictionary = effects.get(str(level), effects.get(level, {}))
			for raw_delta in effect.get("workstation_deltas", []):
				var delta: Dictionary = raw_delta
				var type_id := str(delta.get("type", ""))
				var start_index := int(type_counts.get(type_id, 0)) + 1
				var count := int(delta.get("count", 0))
				for offset in count:
					var station_id := "%s_%02d" % [str(delta.get("id_prefix", "station")), start_index + offset]
					expected[building_id + "/" + station_id] = "%s|%d" % [type_id, level]
				type_counts[type_id] = start_index + count - 1
	var defense_defs = _load_json_variant(DEFENSE_DEVICE_DEFS_PATH)
	if not defense_defs is Dictionary:
		return ["defense_device_defs_not_dictionary"]
	for raw_slot in defense_defs.get("slots", []):
		var slot: Dictionary = raw_slot
		if str(slot.get("building_id", "")) == "main_hall":
			expected["main_hall/" + str(slot.get("id", ""))] = "defense_device_slot|%d" % int(slot.get("required_building_level", 1))

	var actual: Dictionary = {}
	var layouts: Dictionary = plan.get("max_level_layouts", {})
	for raw_building_id in layouts.keys():
		var building_id := str(raw_building_id)
		var layout: Dictionary = layouts.get(building_id, {})
		for raw_position in layout.get("positions", []):
			var position: Dictionary = raw_position
			var authority := str(position.get("authority", ""))
			if authority != "building_workstation" and authority != "defense_device_slot":
				continue
			var key := building_id + "/" + str(position.get("id", ""))
			actual[key] = "%s|%d" % [str(position.get("type", "")), int(position.get("required_level", 1))]
	for key in expected.keys():
		if not actual.has(key):
			errors.append("missing_%s" % key)
		elif str(actual.get(key)) != str(expected.get(key)):
			errors.append("metadata_%s_expected_%s_got_%s" % [key, expected.get(key), actual.get(key)])
	for key in actual.keys():
		if not expected.has(key):
			errors.append("unexpected_%s" % key)
	return errors


func _assert_vector2(raw_value: Variant, expected: Vector2, label: String) -> void:
	var actual := raw_value as Vector2
	if not actual.is_equal_approx(expected):
		_fail("Unexpected %s size: %s, expected %s" % [label, actual, expected])


func _load_json_dictionary(path: String) -> Dictionary:
	var parsed = _load_json_variant(path)
	return parsed if parsed is Dictionary else {}


func _load_json_variant(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


func _fail(message: String) -> bool:
	_failed = true
	push_error(message)
	quit(1)
	return false
