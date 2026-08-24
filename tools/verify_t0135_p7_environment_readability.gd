extends SceneTree

const EXPECTED_BUILDINGS := [
	"blacksmith", "workshop", "chapel", "clinic", "dining_hall", "dormitory", "tavern",
]


func _init() -> void:
	await process_frame
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _frame in range(12):
		await process_frame
		await physics_frame

	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var environment_view := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/FormalEnvironmentArtView") as Node3D
	var controller := environment_view.get_node_or_null("CelestialCycleController") as Node3D if environment_view != null else null
	var roof_controller := root.get_node_or_null("Main/Presentation/RoofVisibilityController")
	if time_system == null or environment_view == null or controller == null or roof_controller == null:
		_fail("P7 integration nodes are missing")
		return
	time_system.call("set_paused", true)

	var time_samples: Dictionary = {}
	for sample in [
		{"name": "night", "time": [0, 30, 0]},
		{"name": "predawn", "time": [5, 15, 0]},
		{"name": "sunrise", "time": [5, 30, 0]},
		{"name": "day", "time": [12, 30, 0]},
		{"name": "sunset", "time": [19, 30, 0]},
		{"name": "evening", "time": [20, 30, 0]},
	]:
		var parts := sample.time as Array
		time_system.call("set_current_time", 3, int(parts[0]), int(parts[1]), int(parts[2]))
		await process_frame
		var snapshot := controller.call("get_debug_snapshot") as Dictionary
		time_samples[str(sample.name)] = snapshot.get("environment", {}) as Dictionary

	var day := time_samples.get("day", {}) as Dictionary
	var night := time_samples.get("night", {}) as Dictionary
	if str(day.get("phase", "")) != "day" or float(day.get("ambient_energy", 0.0)) < 0.84 or float(day.get("exposure", 0.0)) < 1.08:
		_fail("Day presentation is not bright/readable enough: %s" % str(day))
		return
	if str(night.get("phase", "")) != "night" or float(night.get("ambient_energy", 0.0)) < 0.44 or float(night.get("background_energy", 0.0)) < 0.34:
		_fail("Night presentation falls below the readable cool-light floor: %s" % str(night))
		return
	if float(day.get("ambient_energy", 0.0)) <= float(night.get("ambient_energy", 0.0)):
		_fail("Day must remain brighter than night")
		return
	if str((time_samples.get("predawn", {}) as Dictionary).get("phase", "")) != "twilight":
		_fail("Predawn did not blend through twilight: %s" % str(time_samples.get("predawn")))
		return
	if str((time_samples.get("sunrise", {}) as Dictionary).get("phase", "")) != "golden" or str((time_samples.get("sunset", {}) as Dictionary).get("phase", "")) != "golden":
		_fail("Sunrise/sunset are not coordinated with the golden environment state")
		return

	var controller_snapshot := controller.call("get_debug_snapshot") as Dictionary
	if not bool(controller_snapshot.get("world_environment_present", false)) or not bool(controller_snapshot.get("procedural_sky_present", false)):
		_fail("The unique dynamic WorldEnvironment or procedural sky is missing")
		return
	if controller.find_children("*", "WorldEnvironment", true, false).size() != 1:
		_fail("Celestial controller must own exactly one WorldEnvironment")
		return

	time_system.call("set_current_time", 3, 0, 30, 0)
	roof_controller.call("debug_apply_distance", 80.0)
	var closed_snapshot := controller.call("get_debug_snapshot") as Dictionary
	var closed_fill := closed_snapshot.get("interior_fill", {}) as Dictionary
	var closed_environment := closed_snapshot.get("environment", {}) as Dictionary
	if int(closed_fill.get("active_light_count", -1)) != 0 or int(closed_fill.get("revealed_building_count", -1)) != 0:
		_fail("Interior fill leaked through opaque roofs: %s" % str(closed_fill))
		return

	roof_controller.call("debug_apply_distance", 50.0)
	var revealed_snapshot := controller.call("get_debug_snapshot") as Dictionary
	var revealed_fill := revealed_snapshot.get("interior_fill", {}) as Dictionary
	var revealed_environment := revealed_snapshot.get("environment", {}) as Dictionary
	if int(revealed_fill.get("configured_building_count", 0)) != EXPECTED_BUILDINGS.size():
		_fail("Closed enterable building fill configuration is incomplete: %s" % str(revealed_fill))
		return
	if int(revealed_fill.get("light_count", 0)) != EXPECTED_BUILDINGS.size():
		_fail("Each closed enterable building must have one contained downward fill light: %s" % str(revealed_fill))
		return
	if int(revealed_fill.get("revealed_building_count", 0)) != EXPECTED_BUILDINGS.size() or int(revealed_fill.get("active_light_count", 0)) != EXPECTED_BUILDINGS.size():
		_fail("Roof reveal did not activate all intended interior fills: %s" % str(revealed_fill))
		return
	for building_id in EXPECTED_BUILDINGS:
		if float((revealed_fill.get("reveal_by_building", {}) as Dictionary).get(building_id, 0.0)) < 0.98:
			_fail("Interior reveal did not reach full readability for %s" % building_id)
			return
		if float((revealed_fill.get("energy_by_building", {}) as Dictionary).get(building_id, 0.0)) < 0.80:
			_fail("Night interior fill is too dim for %s: %s" % [building_id, str(revealed_fill)])
			return
	if float(revealed_environment.get("fog_density", 1.0)) >= float(closed_environment.get("fog_density", 0.0)) * 0.4:
		_fail("Near-interior fog was not reduced enough: closed=%s revealed=%s" % [str(closed_environment), str(revealed_environment)])
		return

	var fill_light_count := 0
	for node in _all_descendants(main):
		if not bool(node.get_meta("interior_fill", false)):
			continue
		fill_light_count += 1
		if not node is SpotLight3D or not bool(node.get_meta("presentation_only", false)):
			_fail("Interior fill introduced a non-presentation node: %s" % node.get_path())
			return
		var fill_light := node as SpotLight3D
		if not fill_light.shadow_enabled or fill_light.light_volumetric_fog_energy > 0.0001:
			_fail("Interior fill must use shell-blocked shadows and must not light global fog: %s" % node.get_path())
			return
	if fill_light_count != EXPECTED_BUILDINGS.size():
		_fail("Unexpected interior fill node count: %d" % fill_light_count)
		return

	time_system.call("set_current_time", 3, 12, 30, 0)
	var day_revealed_fill := (controller.call("get_debug_snapshot") as Dictionary).get("interior_fill", {}) as Dictionary
	if float((day_revealed_fill.get("energy_by_building", {}) as Dictionary).get("clinic", 0.0)) <= float((revealed_fill.get("energy_by_building", {}) as Dictionary).get("clinic", 0.0)):
		_fail("Revealed interiors should be brighter around noon than at night")
		return

	print("T0135-P7 environment readability verification passed: %s" % str({
		"phases": {
			"night": night.get("phase"),
			"predawn": (time_samples.get("predawn", {}) as Dictionary).get("phase"),
			"sunrise": (time_samples.get("sunrise", {}) as Dictionary).get("phase"),
			"day": day.get("phase"),
			"sunset": (time_samples.get("sunset", {}) as Dictionary).get("phase"),
			"evening": (time_samples.get("evening", {}) as Dictionary).get("phase"),
		},
		"day_ambient": day.get("ambient_energy"),
		"night_ambient": night.get("ambient_energy"),
		"interior_lights": fill_light_count,
		"night_revealed_buildings": revealed_fill.get("revealed_building_count"),
		"fog_reduction": revealed_environment.get("fog_density"),
	}))
	quit(0)


func _all_descendants(parent: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in parent.get_children():
		result.append(child)
		result.append_array(_all_descendants(child))
	return result


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
