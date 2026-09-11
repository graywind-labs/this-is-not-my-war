extends Node3D


const PLAN_PATH := "res://data/presentation/station_spatial_plan.json"
const ENEMY_WAVES_PATH := "res://data/enemy_waves.json"

var _plan: Dictionary = {}
var _stress_config: Dictionary = {}
var _units: Array[Dictionary] = []
var _unit_nodes: Array[CharacterBody3D] = []
var _stage_defs: Array[Dictionary] = []
var _stage_positions: Array[Array] = []
var _segment_durations: Array[float] = []
var _total_duration := 0.0
var _elapsed := 0.0
var _running := false
var _completed := false
var _configuration_errors: Array[String] = []
var _last_stress_snapshot: Dictionary = {}


func _ready() -> void:
	_plan = _load_json_dictionary(PLAN_PATH)
	_stress_config = _plan.get("enemy_stress_test", {})
	_build_wave_units()
	_build_stage_trajectories()
	reset_simulation()


func _process(delta: float) -> void:
	if not _running or _completed:
		return
	_elapsed = minf(_total_duration, _elapsed + delta * float(_stress_config.get("visual_speed_multiplier", 8.0)))
	_apply_simulation_time(_elapsed)
	if _elapsed >= _total_duration:
		_running = false
		_completed = true


func toggle_simulation() -> Dictionary:
	if _completed:
		reset_simulation()
	_running = not _running
	return get_validation_snapshot()


func reset_simulation() -> Dictionary:
	_elapsed = 0.0
	_running = false
	_completed = false
	_apply_simulation_time(0.0)
	return get_validation_snapshot()


func debug_run_full_simulation(sample_step_seconds: float = 0.05) -> Dictionary:
	var minimum_clearance := INF
	var overlap_sample_count := 0
	var sampled_frames := 0
	var sample_time := 0.0
	var step := maxf(sample_step_seconds, 0.01)
	while sample_time <= _total_duration + 0.001:
		_apply_simulation_time(minf(sample_time, _total_duration))
		var clearance_snapshot := _measure_current_clearance()
		minimum_clearance = minf(minimum_clearance, float(clearance_snapshot.get("minimum_clearance_m", INF)))
		if int(clearance_snapshot.get("overlap_pair_count", 0)) > 0:
			overlap_sample_count += 1
		sampled_frames += 1
		sample_time += step
	_apply_simulation_time(_total_duration)
	_elapsed = _total_duration
	_running = false
	_completed = true
	if minimum_clearance == INF:
		minimum_clearance = 0.0
	_last_stress_snapshot = {
		"sampled_frames": sampled_frames,
		"minimum_clearance_m": minimum_clearance,
		"overlap_sample_count": overlap_sample_count,
		"completed": true
	}
	return get_validation_snapshot()


func get_validation_snapshot() -> Dictionary:
	var type_counts: Dictionary = {}
	for unit in _units:
		var type_id := str(unit.get("unit_type", "unknown"))
		type_counts[type_id] = int(type_counts.get(type_id, 0)) + 1
	var clearance_snapshot := _measure_current_clearance()
	var result := {
		"config_loaded": not _stress_config.is_empty(),
		"source_wave_number": int(_stress_config.get("source_wave_number", 0)),
		"enemy_count": _units.size(),
		"character_body_count": _unit_nodes.size(),
		"collision_shape_count": find_children("*", "CollisionShape3D", true, false).size(),
		"unit_type_counts": type_counts,
		"stage_count": _stage_defs.size(),
		"segment_count": _segment_durations.size(),
		"total_route_duration_seconds": _total_duration,
		"elapsed_seconds": _elapsed,
		"running": _running,
		"completed": _completed,
		"configuration_error_count": _configuration_errors.size(),
		"configuration_errors": _configuration_errors.duplicate(),
		"current_minimum_clearance_m": float(clearance_snapshot.get("minimum_clearance_m", 0.0)),
		"current_overlap_pair_count": int(clearance_snapshot.get("overlap_pair_count", 0)),
		"spawn_formation_inside_zone": _spawn_formation_inside_zone(),
		"stage_corridor_error_count": _validate_stage_corridors().size(),
		"stage_corridor_errors": _validate_stage_corridors()
	}
	for key in _last_stress_snapshot.keys():
		result[key] = _last_stress_snapshot[key]
	return result


func _build_wave_units() -> void:
	var waves = _load_json_variant(ENEMY_WAVES_PATH)
	if not waves is Array:
		_configuration_errors.append("enemy_waves_not_array")
		return
	var source_wave_number := int(_stress_config.get("source_wave_number", 5))
	var source_wave: Dictionary = {}
	for raw_wave in waves:
		var wave: Dictionary = raw_wave
		if int(wave.get("wave_number", 0)) == source_wave_number:
			source_wave = wave
			break
	if source_wave.is_empty():
		_configuration_errors.append("source_wave_missing")
		return
	var body_profiles: Dictionary = _stress_config.get("body_profiles", {})
	var unit_index := 0
	for raw_group in source_wave.get("enemies", []):
		var group: Dictionary = raw_group
		var unit_type := str(group.get("unit_type", "melee_infantry"))
		var profile: Dictionary = body_profiles.get(unit_type, {})
		for _group_index in maxi(0, int(group.get("count", 0))):
			unit_index += 1
			var unit := {
				"id": "stress_enemy_%02d" % unit_index,
				"enemy_type_id": str(group.get("enemy_type_id", "enemy")),
				"unit_type": unit_type,
				"weapon_type": str(group.get("weapon_type", "")),
				"radius": maxf(float(profile.get("radius", 0.42)), 0.2),
				"height": maxf(float(profile.get("height", 1.8)), 0.8),
				"color": str(profile.get("color", "#a24f46")),
				"source_move_speed": float(group.get("move_speed", 3.0))
			}
			_units.append(unit)
			var unit_node := _create_unit_node(unit)
			add_child(unit_node)
			_unit_nodes.append(unit_node)
	var expected_count := int(_stress_config.get("expected_enemy_count", 48))
	if _units.size() != expected_count:
		_configuration_errors.append("enemy_count_%d_expected_%d" % [_units.size(), expected_count])


func _create_unit_node(unit: Dictionary) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = str(unit.get("id", "StressEnemy"))
	body.collision_layer = 0
	body.collision_mask = 0
	body.set_meta("enemy_type_id", unit.get("enemy_type_id", ""))
	body.set_meta("unit_type", unit.get("unit_type", ""))
	var radius := float(unit.get("radius", 0.42))
	var height := float(unit.get("height", 1.8))
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = maxf(height, radius * 2.0)
	var collision := CollisionShape3D.new()
	collision.name = "PhysicalEnvelope"
	collision.shape = shape
	body.add_child(collision)
	var color := Color.from_string(str(unit.get("color", "#a24f46")), Color("#a24f46"))
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh.radial_segments = 8
	mesh.rings = 4
	var visible_body := MeshInstance3D.new()
	visible_body.name = "Body"
	visible_body.mesh = mesh
	visible_body.material_override = _make_material(color)
	body.add_child(visible_body)
	if str(unit.get("unit_type", "")) == "mounted_ranged":
		var horse_mesh := BoxMesh.new()
		horse_mesh.size = Vector3(1.1, 0.8, 1.8)
		var horse := MeshInstance3D.new()
		horse.name = "HorseEnvelope"
		horse.position = Vector3(0.0, -0.65, 0.0)
		horse.mesh = horse_mesh
		horse.material_override = _make_material(color.darkened(0.22))
		body.add_child(horse)
	return body


func _build_stage_trajectories() -> void:
	var raw_formations: Array = _stress_config.get("stage_formations", [])
	for formation_index in raw_formations.size():
		var formation: Dictionary = raw_formations[formation_index]
		var stage_id := str(formation.get("stage_id", ""))
		if not formation.has("point"):
			_configuration_errors.append("stress_stage_point_missing_%s" % stage_id)
			continue
		var stage := formation.duplicate(true)
		_stage_defs.append(stage)
	for stage_index in _stage_defs.size():
		var raw_positions := _build_formation_positions(stage_index)
		if stage_index > 0:
			raw_positions = _assign_slots_by_nearest(_stage_positions[stage_index - 1], raw_positions)
		_stage_positions.append(raw_positions)
	var march_speed := maxf(float(_stress_config.get("march_speed_mps", 3.0)), 0.1)
	for stage_index in maxi(_stage_defs.size() - 1, 0):
		var from_point := _v2((_stage_defs[stage_index] as Dictionary).get("point", [0.0, 0.0]))
		var to_point := _v2((_stage_defs[stage_index + 1] as Dictionary).get("point", [0.0, 0.0]))
		var duration := from_point.distance_to(to_point) / march_speed
		_segment_durations.append(duration)
		_total_duration += duration


func _build_formation_positions(stage_index: int) -> Array:
	var stage: Dictionary = _stage_defs[stage_index]
	var center := _v2(stage.get("point", [0.0, 0.0]))
	var direction := _stage_direction(stage_index)
	var lateral := Vector2(direction.y, -direction.x)
	var columns := maxi(1, int(stage.get("columns", 4)))
	var rows := ceili(float(_units.size()) / float(columns))
	var spacing_x := float(stage.get("spacing_x", 1.4))
	var spacing_z := float(stage.get("spacing_z", 1.8))
	var positions: Array = []
	for unit_index in _units.size():
		var row := unit_index / columns
		var column := unit_index % columns
		var row_count := mini(columns, _units.size() - row * columns)
		var lateral_offset := (float(column) - float(row_count - 1) * 0.5) * spacing_x
		var longitudinal_offset := (float(row) - float(rows - 1) * 0.5) * spacing_z
		var point := center + lateral * lateral_offset + direction * longitudinal_offset
		positions.append(Vector3(point.x, float((_units[unit_index] as Dictionary).get("height", 1.8)) * 0.5, point.y))
	return positions


func _assign_slots_by_nearest(previous_positions: Array, raw_targets: Array) -> Array:
	var assigned: Array = []
	assigned.resize(_units.size())
	var remaining_units: Array[int] = []
	var remaining_targets: Array[int] = []
	for index in _units.size():
		remaining_units.append(index)
		remaining_targets.append(index)
	while not remaining_units.is_empty():
		var best_unit_list_index := 0
		var best_target_list_index := 0
		var best_distance := INF
		for unit_list_index in remaining_units.size():
			var unit_index := remaining_units[unit_list_index]
			var previous: Vector3 = previous_positions[unit_index]
			for target_list_index in remaining_targets.size():
				var target_index := remaining_targets[target_list_index]
				var target: Vector3 = raw_targets[target_index]
				var distance := Vector2(previous.x, previous.z).distance_squared_to(Vector2(target.x, target.z))
				if distance < best_distance:
					best_distance = distance
					best_unit_list_index = unit_list_index
					best_target_list_index = target_list_index
		var selected_unit := remaining_units[best_unit_list_index]
		var selected_target := remaining_targets[best_target_list_index]
		assigned[selected_unit] = raw_targets[selected_target]
		remaining_units.remove_at(best_unit_list_index)
		remaining_targets.remove_at(best_target_list_index)
	return assigned


func _stage_direction(stage_index: int) -> Vector2:
	if _stage_defs.size() <= 1:
		return Vector2(0.0, -1.0)
	var current := _v2((_stage_defs[stage_index] as Dictionary).get("point", [0.0, 0.0]))
	if stage_index + 1 < _stage_defs.size():
		return (_v2((_stage_defs[stage_index + 1] as Dictionary).get("point", [0.0, 0.0])) - current).normalized()
	return (current - _v2((_stage_defs[stage_index - 1] as Dictionary).get("point", [0.0, 0.0]))).normalized()


func _apply_simulation_time(simulation_time: float) -> void:
	if _stage_positions.is_empty() or _unit_nodes.is_empty():
		return
	var remaining := clampf(simulation_time, 0.0, _total_duration)
	var segment_index := 0
	while segment_index < _segment_durations.size() and remaining > _segment_durations[segment_index]:
		remaining -= _segment_durations[segment_index]
		segment_index += 1
	if segment_index >= _segment_durations.size():
		_set_unit_positions(_stage_positions[_stage_positions.size() - 1])
		return
	var duration := maxf(_segment_durations[segment_index], 0.001)
	var amount := clampf(remaining / duration, 0.0, 1.0)
	var from_positions: Array = _stage_positions[segment_index]
	var to_positions: Array = _stage_positions[segment_index + 1]
	var resolved_positions: Array = []
	for unit_index in _unit_nodes.size():
		var from_position: Vector3 = from_positions[unit_index]
		var to_position: Vector3 = to_positions[unit_index]
		var current := from_position.lerp(to_position, amount)
		resolved_positions.append(current)
	resolved_positions = _resolve_body_envelopes(resolved_positions)
	for unit_index in _unit_nodes.size():
		var from_position: Vector3 = from_positions[unit_index]
		var to_position: Vector3 = to_positions[unit_index]
		var current: Vector3 = resolved_positions[unit_index]
		var body := _unit_nodes[unit_index]
		body.position = current
		var direction := to_position - from_position
		direction.y = 0.0
		if direction.length_squared() > 0.001:
			body.rotation.y = atan2(direction.x, direction.z)


func _resolve_body_envelopes(raw_positions: Array) -> Array:
	var resolved := raw_positions.duplicate()
	var minimum_gap := float(_stress_config.get("minimum_body_gap_m", 0.12)) + 0.002
	# Position-based separation models the local avoidance needed while five/seven columns
	# reform into the four-column gate queue. It never changes combat state or route targets.
	for iteration in 96:
		var correction_count := 0
		for first_index in resolved.size():
			for second_index in range(first_index + 1, resolved.size()):
				var first: Vector3 = resolved[first_index]
				var second: Vector3 = resolved[second_index]
				var delta := Vector2(second.x - first.x, second.z - first.z)
				var required := (
					float((_units[first_index] as Dictionary).get("radius", 0.42))
					+ float((_units[second_index] as Dictionary).get("radius", 0.42))
					+ minimum_gap
				)
				var distance := delta.length()
				if distance >= required - 0.0001:
					continue
				if distance <= 0.0001:
					var deterministic_angle := float((first_index * 37 + second_index * 71) % 360) * PI / 180.0
					delta = Vector2(cos(deterministic_angle), sin(deterministic_angle))
					distance = 0.0
				else:
					delta /= distance
				var correction := delta * (required - distance + 0.0002) * 0.5
				first.x -= correction.x
				first.z -= correction.y
				second.x += correction.x
				second.z += correction.y
				resolved[first_index] = first
				resolved[second_index] = second
				correction_count += 1
		if correction_count == 0:
			break
	return resolved


func _set_unit_positions(positions: Array) -> void:
	for unit_index in mini(_unit_nodes.size(), positions.size()):
		_unit_nodes[unit_index].position = positions[unit_index]


func _measure_current_clearance() -> Dictionary:
	var minimum_clearance := INF
	var overlap_pair_count := 0
	var minimum_gap := float(_stress_config.get("minimum_body_gap_m", 0.12))
	for first_index in _unit_nodes.size():
		var first := _unit_nodes[first_index]
		var first_radius := float((_units[first_index] as Dictionary).get("radius", 0.42))
		for second_index in range(first_index + 1, _unit_nodes.size()):
			var second := _unit_nodes[second_index]
			var second_radius := float((_units[second_index] as Dictionary).get("radius", 0.42))
			var planar_distance := Vector2(first.position.x, first.position.z).distance_to(Vector2(second.position.x, second.position.z))
			var clearance := planar_distance - first_radius - second_radius
			minimum_clearance = minf(minimum_clearance, clearance)
			if clearance < minimum_gap - 0.001:
				overlap_pair_count += 1
	if minimum_clearance == INF:
		minimum_clearance = 0.0
	return {"minimum_clearance_m": minimum_clearance, "overlap_pair_count": overlap_pair_count}


func _spawn_formation_inside_zone() -> bool:
	if _stage_positions.is_empty():
		return false
	var route: Dictionary = _plan.get("enemy_route", {})
	var center := _v2(route.get("spawn_zone_center", [0.0, 0.0]))
	var half := _v2(route.get("spawn_zone_size", [0.0, 0.0])) * 0.5
	for unit_index in _stage_positions[0].size():
		var position: Vector3 = _stage_positions[0][unit_index]
		var radius := float((_units[unit_index] as Dictionary).get("radius", 0.42))
		if absf(position.x - center.x) + radius > half.x + 0.01 or absf(position.z - center.y) + radius > half.y + 0.01:
			return false
	return true


func _validate_stage_corridors() -> Array[String]:
	var errors: Array[String] = []
	for stage_index in _stage_defs.size():
		var stage: Dictionary = _stage_defs[stage_index]
		var center := _v2(stage.get("point", [0.0, 0.0]))
		var lateral := Vector2(_stage_direction(stage_index).y, -_stage_direction(stage_index).x)
		var maximum_lateral := 0.0
		for unit_index in _stage_positions[stage_index].size():
			var position: Vector3 = _stage_positions[stage_index][unit_index]
			var offset := Vector2(position.x, position.z) - center
			var radius := float((_units[unit_index] as Dictionary).get("radius", 0.42))
			maximum_lateral = maxf(maximum_lateral, absf(offset.dot(lateral)) + radius)
		if maximum_lateral * 2.0 > float(stage.get("corridor_width", 0.0)) + 0.01:
			errors.append("%s_width_%.2f" % [stage.get("stage_id", "stage"), maximum_lateral * 2.0])
	return errors


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	return material


func _v2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _load_json_dictionary(path: String) -> Dictionary:
	var value = _load_json_variant(path)
	return value if value is Dictionary else {}


func _load_json_variant(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())
