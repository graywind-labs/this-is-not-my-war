extends SceneTree

const EXPECTED_MAX_DISTANCE := 120.0
const EXPECTED_SPLITS := [0.12, 0.30, 0.60]


func _init() -> void:
	await process_frame
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _frame in range(12):
		await process_frame
		await physics_frame

	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var environment_view := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/FormalEnvironmentArtView") as Node3D
	var legacy_light := root.get_node_or_null("Main/SunLight") as DirectionalLight3D
	if time_system == null or environment_view == null or legacy_light == null:
		_fail("Main shadow-stability integration nodes are missing")
		return

	time_system.call("set_paused", true)
	time_system.call("set_current_time", 3, 12, 30, 0)
	await process_frame
	var cycle := (environment_view.call("get_debug_snapshot") as Dictionary).get("celestial_cycle", {}) as Dictionary
	var shadow := cycle.get("directional_shadow", {}) as Dictionary
	if shadow.is_empty():
		_fail("Directional shadow debug snapshot is missing")
		return
	if int(shadow.get("mode", -1)) != DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS:
		_fail("Celestial lights must use the measured two-split CSM budget: %s" % str(shadow))
		return
	if not is_equal_approx(float(shadow.get("max_distance", 0.0)), EXPECTED_MAX_DISTANCE):
		_fail("Directional shadow range is not stabilized at 120 m: %s" % str(shadow))
		return
	if not bool(shadow.get("blend_splits", false)) or not bool(shadow.get("sun_moon_match", false)):
		_fail("Sun/moon cascades are not blended or do not match: %s" % str(shadow))
		return
	for index in range(EXPECTED_SPLITS.size()):
		var key := "split_%d" % (index + 1)
		if not is_equal_approx(float(shadow.get(key, -1.0)), float(EXPECTED_SPLITS[index])):
			_fail("Unexpected cascade allocation for %s: %s" % [key, str(shadow)])
			return
	if int(cycle.get("active_shadow_count", -1)) != 1 or str(cycle.get("shadow_owner", "")) != "sun":
		_fail("Noon must retain one sun-owned shadow: %s" % str(cycle))
		return
	if legacy_light.visible or legacy_light.shadow_enabled or legacy_light.light_energy > 0.0001:
		_fail("Legacy static sun contributes after P6R")
		return

	var paused_before := cycle.duplicate(true)
	for _frame in range(8):
		await process_frame
	var paused_after := (environment_view.call("get_debug_snapshot") as Dictionary).get("celestial_cycle", {}) as Dictionary
	if paused_before.get("time", {}) != paused_after.get("time", {}):
		_fail("Paused celestial time advanced during stability verification")
		return
	if (paused_before.get("sun", {}) as Dictionary).get("sky_direction", Vector3.ZERO) != (paused_after.get("sun", {}) as Dictionary).get("sky_direction", Vector3.ZERO):
		_fail("Paused sun direction changed during stability verification")
		return

	time_system.call("set_current_time", 3, 0, 30, 0)
	await process_frame
	var night_cycle := (environment_view.call("get_debug_snapshot") as Dictionary).get("celestial_cycle", {}) as Dictionary
	if int(night_cycle.get("active_shadow_count", -1)) != 1 or str(night_cycle.get("shadow_owner", "")) != "moon":
		_fail("Midnight must transfer the same stabilized cascades to the moon: %s" % str(night_cycle))
		return
	if not bool((night_cycle.get("directional_shadow", {}) as Dictionary).get("sun_moon_match", false)):
		_fail("Sun/moon cascade settings diverged after shadow handoff")
		return

	print("T0135-P6R directional shadow stability verification passed: %s" % str({
		"max_distance": shadow.get("max_distance"),
		"blend_splits": shadow.get("blend_splits"),
		"splits": EXPECTED_SPLITS,
		"day_owner": "sun",
		"night_owner": "moon",
		"paused_time_frozen": true,
		"taa_enabled": false,
	}))
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
