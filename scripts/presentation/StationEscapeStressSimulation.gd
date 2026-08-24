extends Node3D


const PLAN_PATH := "res://data/presentation/station_spatial_plan.json"

var _config: Dictionary = {}
var _path_points: Array[Vector2] = []
var _segment_lengths: Array[float] = []
var _total_distance := 0.0
var _distance_travelled := 0.0
var _running := false
var _completed := false
var _speed_multiplier := 1.0
var _body: CharacterBody3D
var _configuration_errors: Array[String] = []


func _ready() -> void:
	var plan := _load_json_dictionary(PLAN_PATH)
	var rear_route: Dictionary = plan.get("rear_route", {})
	_config = rear_route.get("escape_stress_test", {})
	_speed_multiplier = float(_config.get("default_speed_multiplier", 1.0))
	for raw_point in _config.get("path_points", []):
		_path_points.append(_v2(raw_point))
	if _path_points.size() < 2:
		_configuration_errors.append("path_requires_two_points")
	for index in maxi(_path_points.size() - 1, 0):
		var length := _path_points[index].distance_to(_path_points[index + 1])
		_segment_lengths.append(length)
		_total_distance += length
	_body = _create_body()
	add_child(_body)
	reset_simulation()


func _process(delta: float) -> void:
	if not _running or _completed:
		return
	var base_speed := float(_config.get("base_move_speed_mps", 5.0))
	var visual_multiplier := float(_config.get("visual_speed_multiplier", 12.0))
	_distance_travelled = minf(_total_distance, _distance_travelled + base_speed * _speed_multiplier * visual_multiplier * delta)
	_apply_distance(_distance_travelled)
	if _distance_travelled >= _total_distance - 0.001:
		_running = false
		_completed = true


func toggle_simulation() -> Dictionary:
	if _completed:
		reset_simulation()
	_running = not _running
	return get_validation_snapshot()


func reset_simulation() -> Dictionary:
	_distance_travelled = 0.0
	_running = false
	_completed = false
	_speed_multiplier = float(_config.get("default_speed_multiplier", 1.0))
	_apply_distance(0.0)
	return get_validation_snapshot()


func set_scenario(scenario: String) -> Dictionary:
	match scenario:
		"money_slow":
			_speed_multiplier = float(_config.get("money_slow_multiplier", 0.65))
		"attacked":
			_speed_multiplier = float(_config.get("attack_speed_multiplier", 1.25))
		_:
			_speed_multiplier = float(_config.get("default_speed_multiplier", 1.0))
	return get_validation_snapshot()


func debug_run_all_scenarios() -> Dictionary:
	var base_speed := maxf(float(_config.get("base_move_speed_mps", 5.0)), 0.01)
	var scenarios := {
		"default_seconds": _total_distance / (base_speed * float(_config.get("default_speed_multiplier", 1.0))),
		"money_slow_seconds": _total_distance / (base_speed * float(_config.get("money_slow_multiplier", 0.65))),
		"attacked_seconds": _total_distance / (base_speed * float(_config.get("attack_speed_multiplier", 1.25))),
		"minimum_speed_seconds": _total_distance / (base_speed * float(_config.get("minimum_speed_multiplier", 0.35))),
		"maximum_speed_seconds": _total_distance / (base_speed * float(_config.get("maximum_speed_multiplier", 2.5)))
	}
	var completion_errors: Array[String] = []
	for sample_index in 100:
		var distance := _total_distance * float(sample_index) / 100.0
		_apply_distance(distance)
		if _is_at_completion(distance):
			completion_errors.append("premature_completion_%d" % sample_index)
	_apply_distance(_total_distance)
	if not _is_at_completion(_total_distance):
		completion_errors.append("final_completion_missing")
	reset_simulation()
	var result := get_validation_snapshot()
	result["scenarios"] = scenarios
	result["completion_error_count"] = completion_errors.size()
	result["completion_errors"] = completion_errors
	return result


func get_validation_snapshot() -> Dictionary:
	var base_speed := maxf(float(_config.get("base_move_speed_mps", 5.0)), 0.01)
	var rounds := int(_config.get("intervention_rounds", 5))
	var round_spacing := float(_config.get("minimum_intervention_spacing_seconds", 6.0))
	var attack_multiplier := maxf(float(_config.get("attack_speed_multiplier", 1.25)), 0.01)
	return {
		"config_loaded": not _config.is_empty(),
		"path_point_count": _path_points.size(),
		"segment_count": _segment_lengths.size(),
		"route_distance_m": _total_distance,
		"base_move_speed_mps": base_speed,
		"speed_multiplier": _speed_multiplier,
		"distance_travelled_m": _distance_travelled,
		"progress": _distance_travelled / maxf(_total_distance, 0.001),
		"running": _running,
		"completed": _completed,
		"configuration_error_count": _configuration_errors.size(),
		"configuration_errors": _configuration_errors.duplicate(),
		"default_duration_seconds": _total_distance / (base_speed * float(_config.get("default_speed_multiplier", 1.0))),
		"fast_duration_seconds": _total_distance / (base_speed * attack_multiplier),
		"five_round_window_required_seconds": rounds * round_spacing,
		"five_round_window_available": _total_distance / (base_speed * attack_multiplier) >= rounds * round_spacing,
		"completion_requires_final_point": not _is_at_completion(maxf(_total_distance - 0.5, 0.0)) and _is_at_completion(_total_distance)
	}


func _apply_distance(distance: float) -> void:
	if _body == null or _path_points.is_empty():
		return
	var remaining := clampf(distance, 0.0, _total_distance)
	for segment_index in _segment_lengths.size():
		var segment_length := _segment_lengths[segment_index]
		if remaining <= segment_length or segment_index == _segment_lengths.size() - 1:
			var amount := remaining / maxf(segment_length, 0.001)
			var position := _path_points[segment_index].lerp(_path_points[segment_index + 1], amount)
			_body.position = Vector3(position.x, 0.9, position.y)
			var direction := _path_points[segment_index + 1] - _path_points[segment_index]
			_body.rotation.y = atan2(direction.x, direction.y)
			return
		remaining -= segment_length


func _is_at_completion(distance: float) -> bool:
	return distance >= _total_distance - 0.01


func _create_body() -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = "EscapingNpcStressBody"
	body.collision_layer = 0
	body.collision_mask = 0
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	var collision := CollisionShape3D.new()
	collision.name = "PhysicalEnvelope"
	collision.shape = shape
	body.add_child(collision)
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.35
	mesh.height = 1.8
	mesh.radial_segments = 8
	mesh.rings = 4
	var visible_body := MeshInstance3D.new()
	visible_body.name = "Body"
	visible_body.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#d3a85c")
	material.roughness = 0.9
	visible_body.material_override = material
	body.add_child(visible_body)
	return body


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
