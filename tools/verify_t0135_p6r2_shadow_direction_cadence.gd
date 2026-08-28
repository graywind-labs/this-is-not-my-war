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
	var controller := CELESTIAL_CONTROLLER_SCRIPT.new() as Node3D
	var environment_config := _load_json(ENVIRONMENT_PATH)
	var cadence_config := environment_config.get("celestial_cycle", {}) as Dictionary
	# P6R3 supersedes the production cadence with continuous transforms, while
	# retaining this test as coverage for the optional low-frequency fallback.
	cadence_config["directional_transform_update_interval_game_seconds"] = 60.0
	environment_config["celestial_cycle"] = cadence_config
	controller.call("configure", environment_config)
	root.add_child(controller)
	for _frame in range(2):
		await process_frame

	game_state.set_time(2, 6, 0, 0)
	await process_frame
	var sun_light := controller.get_node_or_null("SunDirectionalLight") as DirectionalLight3D
	if sun_light == null:
		_fail("Runtime sun DirectionalLight is missing")
		return
	var start := controller.call("get_debug_snapshot") as Dictionary
	var start_shadow := start.get("directional_shadow", {}) as Dictionary
	var start_sun := start.get("sun", {}) as Dictionary
	var start_count := int(start_shadow.get("transform_update_count", -1))
	var start_applied: Vector3 = start_shadow.get("sun_applied_light_ray_direction", Vector3.ZERO)
	var start_basis := sun_light.basis
	if not is_equal_approx(float(start_shadow.get("transform_update_interval_game_seconds", 0.0)), 60.0):
		_fail("Directional transform cadence is not configured to 60 game seconds: %s" % str(start_shadow))
		return
	if start_applied.length_squared() < 0.99:
		_fail("Initial applied sun direction is missing: %s" % str(start_shadow))
		return

	for second in range(1, 60):
		game_state.set_time(2, 6, 0, second)
		await process_frame
	var within_bucket := controller.call("get_debug_snapshot") as Dictionary
	var within_shadow := within_bucket.get("directional_shadow", {}) as Dictionary
	var within_sun := within_bucket.get("sun", {}) as Dictionary
	var exact_start_direction: Vector3 = start_sun.get("light_ray_direction", Vector3.ZERO)
	var exact_end_direction: Vector3 = within_sun.get("light_ray_direction", Vector3.ZERO)
	var applied_end: Vector3 = within_shadow.get("sun_applied_light_ray_direction", Vector3.ZERO)
	if int(within_shadow.get("transform_update_count", -1)) != start_count:
		_fail("Directional transform updated inside one 60-second bucket: %s" % str(within_shadow))
		return
	if not applied_end.is_equal_approx(start_applied):
		_fail("Applied sun direction drifted inside one cadence bucket")
		return
	if not sun_light.basis.is_equal_approx(start_basis):
		_fail("Runtime DirectionalLight basis changed inside one cadence bucket")
		return
	if exact_end_direction.distance_to(exact_start_direction) <= 0.0001:
		_fail("Continuous celestial state stopped advancing inside the cadence bucket")
		return
	if is_equal_approx(float(within_sun.get("energy", 0.0)), float(start_sun.get("energy", 0.0))):
		_fail("Sun energy no longer updates continuously inside the cadence bucket")
		return

	game_state.set_time(2, 6, 1, 0)
	await process_frame
	var next_bucket := controller.call("get_debug_snapshot") as Dictionary
	var next_shadow := next_bucket.get("directional_shadow", {}) as Dictionary
	var next_sun := next_bucket.get("sun", {}) as Dictionary
	var next_applied: Vector3 = next_shadow.get("sun_applied_light_ray_direction", Vector3.ZERO)
	if int(next_shadow.get("transform_update_count", -1)) != start_count + 1:
		_fail("Directional transform did not update exactly once at the next minute: %s" % str(next_shadow))
		return
	if not next_applied.is_equal_approx(next_sun.get("light_ray_direction", Vector3.ZERO)):
		_fail("Minute-boundary transform did not catch up to the current absolute sun direction")
		return
	if sun_light.basis.is_equal_approx(start_basis):
		_fail("Runtime DirectionalLight basis did not change at the minute boundary")
		return

	var simulated_signal_count := 0
	var cadence_count_before := int(next_shadow.get("transform_update_count", 0))
	for offset in range(1, 241):
		var total_seconds := 6 * 3600 + 60 + offset
		game_state.set_time(2, int(total_seconds / 3600), int((total_seconds % 3600) / 60), total_seconds % 60)
		simulated_signal_count += 1
		await process_frame
	var cadence_end := controller.call("get_debug_snapshot") as Dictionary
	var cadence_shadow := cadence_end.get("directional_shadow", {}) as Dictionary
	var cadence_updates := int(cadence_shadow.get("transform_update_count", 0)) - cadence_count_before
	if cadence_updates != 4 or simulated_signal_count != 240:
		_fail("240 second-level signals must produce exactly four transform updates: %s" % str({
			"signals": simulated_signal_count,
			"updates": cadence_updates,
			"shadow": cadence_shadow,
		}))
		return

	game_state.set_time(2, 0, 30, 0)
	await process_frame
	var night := controller.call("get_debug_snapshot") as Dictionary
	if str(night.get("shadow_owner", "")) != "moon" or int(night.get("active_shadow_count", -1)) != 1:
		_fail("Cadence changed sun/moon shadow ownership: %s" % str(night))
		return
	var night_shadow := night.get("directional_shadow", {}) as Dictionary
	if not bool(night_shadow.get("sun_moon_match", false)):
		_fail("Cadence diverged sun/moon cascade settings")
		return

	game_state.set_time(original_time.day, original_time.hour, original_time.minute, original_time.second)
	controller.queue_free()
	print("T0135-P6R2 shadow direction cadence verification passed: %s" % str({
		"interval_game_seconds": 60,
		"second_level_signals": simulated_signal_count,
		"transform_updates": cadence_updates,
		"continuous_energy": true,
		"continuous_celestial_state": true,
		"single_shadow_owner": true,
	}))
	quit(0)


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
