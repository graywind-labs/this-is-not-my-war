extends SceneTree

const ENVIRONMENT_PATH := "res://data/presentation/environment_art.json"
const CELESTIAL_CONTROLLER_SCRIPT := preload("res://scripts/presentation/environment/CelestialCycleController.gd")


func _init() -> void:
	await process_frame
	var game_state := root.get_node("GameState")
	var original_time := {
		"day": int(game_state.current_day),
		"hour": int(game_state.current_hour),
		"minute": int(game_state.current_minute),
		"second": int(game_state.current_second),
	}
	var environment_config := _load_json(ENVIRONMENT_PATH)
	var controller := CELESTIAL_CONTROLLER_SCRIPT.new() as Node3D
	controller.call("configure", environment_config)
	root.add_child(controller)
	for _frame in range(2):
		await process_frame

	var initial_cycle := controller.call("get_debug_snapshot") as Dictionary
	if not bool(initial_cycle.get("enabled", false)) or not bool(initial_cycle.get("time_signal_connected", false)):
		_fail("Celestial controller is not enabled or connected: %s" % str(initial_cycle))
		return
	if not bool(initial_cycle.get("sun_light_present", false)) or not bool(initial_cycle.get("moon_light_present", false)):
		_fail("Both directional lights must exist")
		return
	if bool(initial_cycle.get("maintains_second_clock", true)) or str(initial_cycle.get("authority_role", "")) != "presentation_only":
		_fail("Celestial presentation crossed the time authority boundary")
		return

	var cases := [
		{"time": [5, 30, 0], "body": "sun", "axis": "east", "altitude": 0.0},
		{"time": [6, 30, 0], "body": "moon", "axis": "west", "altitude": 0.0},
		{"time": [12, 30, 0], "body": "sun", "axis": "south", "altitude": 52.0},
		{"time": [18, 30, 0], "body": "moon", "axis": "east", "altitude": 0.0},
		{"time": [19, 30, 0], "body": "sun", "axis": "west", "altitude": 0.0},
		{"time": [0, 30, 0], "body": "moon", "axis": "south", "altitude": 42.0},
	]
	var case_snapshots: Dictionary = {}
	for test_case in cases:
		var time_parts := test_case.time as Array
		game_state.set_time(2, int(time_parts[0]), int(time_parts[1]), int(time_parts[2]))
		await process_frame
		var cycle := controller.call("get_debug_snapshot") as Dictionary
		if int(cycle.get("active_shadow_count", -1)) > 1:
			_fail("Sun and moon produced two hard shadows at %02d:%02d" % [time_parts[0], time_parts[1]])
			return
		var body := cycle.get(str(test_case.body), {}) as Dictionary
		if absf(float(body.get("altitude_degrees", -999.0)) - float(test_case.altitude)) > 0.08:
			_fail("Celestial altitude is wrong at %02d:%02d: %s" % [time_parts[0], time_parts[1], str(body)])
			return
		if not _matches_axis(body.get("sky_direction", Vector3.ZERO), str(test_case.axis)):
			_fail("Celestial direction is wrong at %02d:%02d: %s" % [time_parts[0], time_parts[1], str(body)])
			return
		case_snapshots["%02d:%02d" % [time_parts[0], time_parts[1]]] = cycle

	var noon_sun := (case_snapshots["12:30"] as Dictionary).get("sun", {}) as Dictionary
	var midnight_moon := (case_snapshots["00:30"] as Dictionary).get("moon", {}) as Dictionary
	if not is_equal_approx(float(noon_sun.get("energy", 0.0)), 1.65) or str((case_snapshots["12:30"] as Dictionary).get("shadow_owner", "")) != "sun":
		_fail("Noon sun energy or shadow ownership is wrong: %s" % str(case_snapshots["12:30"]))
		return
	if not is_equal_approx(float(midnight_moon.get("energy", 0.0)), 0.40) or str((case_snapshots["00:30"] as Dictionary).get("shadow_owner", "")) != "moon":
		_fail("Midnight moon energy or shadow ownership is wrong: %s" % str(case_snapshots["00:30"]))
		return
	if not await _verify_transition_continuity(controller, [5, 30, 0]):
		return
	if not await _verify_transition_continuity(controller, [19, 30, 0]):
		return

	controller.queue_free()
	await process_frame
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _frame in range(8):
		await process_frame
		await physics_frame
	var time_system := root.get_node("Main/Systems/TimeSystem")
	time_system.call("set_paused", true)
	time_system.call("set_current_time", 3, 12, 30, 0)
	await process_frame
	var integrated_view := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/FormalEnvironmentArtView") as Node3D
	var legacy_light := root.get_node_or_null("Main/SunLight") as DirectionalLight3D
	if integrated_view == null or legacy_light == null:
		_fail("Main celestial integration or legacy light is missing")
		return
	var integrated_cycle := (integrated_view.call("get_debug_snapshot") as Dictionary).get("celestial_cycle", {}) as Dictionary
	if int(integrated_cycle.get("legacy_light_retired_count", 0)) != 1 or legacy_light.visible or legacy_light.light_energy > 0.0001 or legacy_light.shadow_enabled:
		_fail("Legacy static sun still contributes light: %s" % str(integrated_cycle))
		return
	var paused_before := integrated_cycle.duplicate(true)
	for _frame in range(8):
		await process_frame
	var paused_after := (integrated_view.call("get_debug_snapshot") as Dictionary).get("celestial_cycle", {}) as Dictionary
	if paused_before.get("time", {}) != paused_after.get("time", {}) or not is_equal_approx(float((paused_before.get("sun", {}) as Dictionary).get("altitude_degrees", -1.0)), float((paused_after.get("sun", {}) as Dictionary).get("altitude_degrees", -2.0))):
		_fail("Celestial cycle advanced while TimeSystem was paused")
		return

	time_system.call("set_paused", false)
	game_state.set_time(original_time.day, original_time.hour, original_time.minute, original_time.second)
	print("T0135-P6 celestial cycle verification passed: %s" % str({
		"sunrise": _compact_body(case_snapshots["05:30"], "sun"),
		"noon": _compact_body(case_snapshots["12:30"], "sun"),
		"sunset": _compact_body(case_snapshots["19:30"], "sun"),
		"moonrise": _compact_body(case_snapshots["18:30"], "moon"),
		"moon_transit": _compact_body(case_snapshots["00:30"], "moon"),
		"single_shadow": true,
		"legacy_light_retired": true,
		"paused_time_frozen": true,
	}))
	quit(0)


func _verify_transition_continuity(view: Node3D, center_time: Array) -> bool:
	var game_state := root.get_node("GameState")
	var center_seconds := int(center_time[0]) * 3600 + int(center_time[1]) * 60 + int(center_time[2])
	var snapshots: Array[Dictionary] = []
	for offset in [-1, 0, 1]:
		var sample_seconds := posmod(center_seconds + offset, 86400)
		game_state.set_time(2, int(sample_seconds / 3600), int((sample_seconds % 3600) / 60), sample_seconds % 60)
		await process_frame
		snapshots.append((view.call("get_debug_snapshot") as Dictionary).get("celestial_cycle", {}) as Dictionary)
	for body_name in ["sun", "moon"]:
		for index in range(1, snapshots.size()):
			var previous := snapshots[index - 1].get(body_name, {}) as Dictionary
			var current := snapshots[index].get(body_name, {}) as Dictionary
			var previous_direction: Vector3 = previous.get("sky_direction", Vector3.ZERO)
			var current_direction: Vector3 = current.get("sky_direction", Vector3.ZERO)
			if previous_direction.distance_to(current_direction) > 0.002 or absf(float(previous.get("energy", 0.0)) - float(current.get("energy", 0.0))) > 0.01:
				_fail("Celestial transition jumped near %02d:%02d for %s" % [center_time[0], center_time[1], body_name])
				return false
	return true


func _matches_axis(direction_value: Variant, axis: String) -> bool:
	var direction: Vector3 = direction_value
	match axis:
		"east":
			return direction.x > 0.995 and absf(direction.z) < 0.02
		"west":
			return direction.x < -0.995 and absf(direction.z) < 0.02
		"south":
			return direction.z < -0.60 and absf(direction.x) < 0.02
	return false


func _compact_body(cycle_value: Variant, body_name: String) -> Dictionary:
	var cycle := cycle_value as Dictionary
	var body := cycle.get(body_name, {}) as Dictionary
	return {
		"altitude_degrees": snappedf(float(body.get("altitude_degrees", 0.0)), 0.001),
		"azimuth_degrees": snappedf(float(body.get("azimuth_degrees", 0.0)), 0.001),
		"energy": snappedf(float(body.get("energy", 0.0)), 0.001),
		"shadow_owner": cycle.get("shadow_owner", "none"),
	}


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
