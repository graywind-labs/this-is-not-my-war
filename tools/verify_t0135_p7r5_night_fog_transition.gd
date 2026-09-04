extends SceneTree

const EXPECTED_FOG_REGIONS := ["east_mountain_foot", "front_forest", "rear_forest", "river_valley"]


func _init() -> void:
	await process_frame
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _frame in range(12):
		await process_frame
		await physics_frame

	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var controller := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/FormalEnvironmentArtView/CelestialCycleController")
	var roof_controller := root.get_node_or_null("Main/Presentation/RoofVisibilityController")
	if time_system == null or controller == null or roof_controller == null:
		_fail("Night fog integration nodes are missing")
		return
	time_system.call("set_paused", true)
	roof_controller.call("debug_apply_distance", 80.0)

	var samples: Dictionary = {}
	for sample in [
		{"name": "day", "time": [12, 30]},
		{"name": "evening_start", "time": [17, 30]},
		{"name": "evening_mid", "time": [19, 15]},
		{"name": "night", "time": [0, 30]},
		{"name": "morning_start", "time": [4, 30]},
		{"name": "morning_mid", "time": [6, 0]},
		{"name": "morning_clear", "time": [7, 30]},
	]:
		var parts := sample.time as Array
		time_system.call("set_current_time", 3, int(parts[0]), int(parts[1]), 0)
		await process_frame
		samples[str(sample.name)] = controller.call("get_debug_snapshot") as Dictionary

	var day_environment := _environment(samples, "day")
	var evening_mid_environment := _environment(samples, "evening_mid")
	var night_environment := _environment(samples, "night")
	var morning_mid_environment := _environment(samples, "morning_mid")
	if float(day_environment.get("night_fog_weight", -1.0)) > 0.001:
		_fail("Day fog did not fully clear: %s" % str(day_environment))
		return
	if float(_environment(samples, "evening_start").get("night_fog_weight", -1.0)) > 0.001:
		_fail("Evening fog starts before the configured transition")
		return
	if not _is_partial_weight(float(evening_mid_environment.get("night_fog_weight", -1.0))):
		_fail("Evening fog is not spreading gradually: %s" % str(evening_mid_environment))
		return
	if float(night_environment.get("night_fog_weight", 0.0)) < 0.999 or float(night_environment.get("fog_density_base", 0.0)) < 0.0055:
		_fail("Deep-night fog is not visibly dense enough: %s" % str(night_environment))
		return
	if float(_environment(samples, "morning_start").get("night_fog_weight", 0.0)) < 0.999:
		_fail("Morning fog starts clearing before the configured transition")
		return
	if not _is_partial_weight(float(morning_mid_environment.get("night_fog_weight", -1.0))):
		_fail("Morning fog is not clearing gradually: %s" % str(morning_mid_environment))
		return
	if float(_environment(samples, "morning_clear").get("night_fog_weight", -1.0)) > 0.001:
		_fail("Morning fog did not fully clear")
		return
	if float(evening_mid_environment.get("fog_density", 0.0)) <= float(day_environment.get("fog_density", 1.0)):
		_fail("Evening global fog density did not rise continuously")
		return
	if float(morning_mid_environment.get("fog_density", 0.0)) >= float(night_environment.get("fog_density", 0.0)):
		_fail("Morning global fog density did not fall continuously")
		return

	var night_fog := _fog(samples, "night")
	if int(night_fog.get("volume_count", 0)) < EXPECTED_FOG_REGIONS.size() or not bool(night_fog.get("volumetric_enabled", false)):
		_fail("Peripheral volumetric fog ring is incomplete: %s" % str(night_fog))
		return
	var found_regions: Array[String] = []
	for raw_volume in night_fog.get("volumes", []):
		var volume := raw_volume as Dictionary
		var region := str(volume.get("region", ""))
		if not found_regions.has(region):
			found_regions.append(region)
		if not bool(volume.get("presentation_only", false)):
			_fail("Peripheral fog volume is not presentation-only: %s" % str(volume))
			return
		if float(volume.get("density", 0.0)) < float(volume.get("base_density", 0.0)) * 0.99:
			_fail("Peripheral fog did not reach its night density: %s" % str(volume))
			return
	found_regions.sort()
	if found_regions != EXPECTED_FOG_REGIONS:
		_fail("Unexpected peripheral fog regions: %s" % str(found_regions))
		return
	for raw_volume in _fog(samples, "day").get("volumes", []):
		if float((raw_volume as Dictionary).get("density", 1.0)) > 0.00001:
			_fail("Peripheral fog remains visible during the day: %s" % str(raw_volume))
			return

	for node in _all_descendants(controller):
		if node.has_meta("fog_zone_id") and (node is CollisionObject3D or node is NavigationRegion3D):
			_fail("Fog volume changed gameplay geometry: %s" % node.get_path())
			return

	print("T0135-P7R5 night fog transition verification passed: %s" % str({
		"weights": {
			"day": day_environment.get("night_fog_weight"),
			"evening_mid": evening_mid_environment.get("night_fog_weight"),
			"night": night_environment.get("night_fog_weight"),
			"morning_mid": morning_mid_environment.get("night_fog_weight"),
		},
		"night_density": night_environment.get("fog_density"),
		"fog_regions": found_regions,
	}))
	quit(0)


func _environment(samples: Dictionary, sample_name: String) -> Dictionary:
	return (samples.get(sample_name, {}) as Dictionary).get("environment", {}) as Dictionary


func _fog(samples: Dictionary, sample_name: String) -> Dictionary:
	return (samples.get(sample_name, {}) as Dictionary).get("peripheral_fog", {}) as Dictionary


func _is_partial_weight(weight: float) -> bool:
	return weight > 0.10 and weight < 0.90


func _all_descendants(parent: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in parent.get_children():
		result.append(child)
		result.append_array(_all_descendants(child))
	return result


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
