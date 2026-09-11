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
	if time_system == null or controller == null or roof_controller == null:
		_fail("P7R3 integration nodes are missing")
		return
	time_system.call("set_paused", true)
	roof_controller.call("debug_apply_distance", 50.0)

	var samples: Dictionary = {}
	for hour in [0, 6, 9, 12, 15, 18, 20]:
		time_system.call("set_current_time", 3, hour, 0, 0)
		samples[hour] = controller.call("get_debug_snapshot") as Dictionary

	var night_fill := (samples[0] as Dictionary).get("interior_fill", {}) as Dictionary
	var morning_fill := (samples[9] as Dictionary).get("interior_fill", {}) as Dictionary
	var noon_fill := (samples[12] as Dictionary).get("interior_fill", {}) as Dictionary
	var afternoon_fill := (samples[15] as Dictionary).get("interior_fill", {}) as Dictionary
	var evening_fill := (samples[18] as Dictionary).get("interior_fill", {}) as Dictionary
	var night_clinic := _building_color(night_fill, "clinic")
	var morning_clinic := _building_color(morning_fill, "clinic")
	var noon_clinic := _building_color(noon_fill, "clinic")
	var afternoon_clinic := _building_color(afternoon_fill, "clinic")
	var evening_clinic := _building_color(evening_fill, "clinic")
	var daylight_target: Color = noon_fill.get("daylight_color", Color.WHITE)

	if _color_distance(night_clinic, Color("#ffd18f")) > 0.01 or _color_distance(evening_clinic, night_clinic) > 0.01:
		_fail("Night practical warmth was not preserved at 00:00/18:00: night=%s evening=%s" % [night_clinic, evening_clinic])
		return
	if _color_distance(noon_clinic, daylight_target) > 0.01:
		_fail("Noon interior color does not match the derived exterior daylight: interior=%s target=%s" % [noon_clinic, daylight_target])
		return
	if _color_distance(noon_clinic, night_clinic) < 0.20:
		_fail("Noon interior remains too close to the orange night-light tint: night=%s noon=%s" % [night_clinic, noon_clinic])
		return
	if _color_distance(morning_clinic, afternoon_clinic) > 0.001:
		_fail("Morning and afternoon daylight tint weights lost symmetry: morning=%s afternoon=%s" % [morning_clinic, afternoon_clinic])
		return
	if _color_distance(morning_clinic, night_clinic) <= 0.05 or _color_distance(morning_clinic, noon_clinic) <= 0.02:
		_fail("09:00 tint is not a genuine transition between night warmth and noon daylight")
		return

	var fill_lights: Array[SpotLight3D] = []
	for node in _all_descendants(main):
		if bool(node.get_meta("interior_fill", false)) and node is SpotLight3D:
			fill_lights.append(node as SpotLight3D)
	if fill_lights.size() != EXPECTED_BUILDINGS.size():
		_fail("Soft area-fill light count changed unexpectedly: %d" % fill_lights.size())
		return
	var counts_by_building: Dictionary = {}
	for fill_light in fill_lights:
		var building_id := str(fill_light.get_meta("building_id", ""))
		counts_by_building[building_id] = int(counts_by_building.get(building_id, 0)) + 1
		if fill_light.position.y < 2.2 or fill_light.position.y > 2.4:
			_fail("Area fill height escaped the room: %s position=%s" % [fill_light.get_path(), fill_light.position])
			return
		if building_id == "blacksmith":
			if absf(fill_light.position.x) > 0.1 or absf(fill_light.position.z + 4.0) > 0.1 or fill_light.spot_range > 8.01 or fill_light.spot_angle < 71.5:
				_fail("Blacksmith hybrid fill is not shaped around the rear forge bay: %s" % fill_light.get_path())
				return
		elif Vector2(fill_light.position.x, fill_light.position.z).length() > 0.1 or fill_light.spot_range < 13.0 or fill_light.spot_angle < 83.5:
			_fail("Area fill is not broad and centered below the roof: %s position=%s" % [fill_light.get_path(), fill_light.position])
			return
		if building_id != "blacksmith" and (fill_light.spot_attenuation > 0.05 or fill_light.spot_angle_attenuation > 0.05):
			_fail("Area fill falloff is too point-like: %s distance=%.3f edge=%.3f" % [fill_light.get_path(), fill_light.spot_attenuation, fill_light.spot_angle_attenuation])
			return
		if not fill_light.shadow_enabled or fill_light.light_volumetric_fog_energy > 0.0001:
			_fail("Area fill must be shell-shadowed and fog-neutral: %s" % fill_light.get_path())
			return
	for building_id in EXPECTED_BUILDINGS:
		if int(counts_by_building.get(building_id, 0)) != 1:
			_fail("Building %s must use one contained soft-area light" % building_id)
			return

	for boundary_hour in [6, 12, 18]:
		var before := _sample_clinic_color(time_system, controller, boundary_hour, -1)
		var at_boundary := _sample_clinic_color(time_system, controller, boundary_hour, 0)
		var after := _sample_clinic_color(time_system, controller, boundary_hour, 1)
		if _color_distance(at_boundary, before) > 0.002 or _color_distance(after, at_boundary) > 0.002:
			_fail("Interior tint jumps at %02d:00" % boundary_hour)
			return

	time_system.call("set_current_time", 3, 12, 0, 0)
	roof_controller.call("debug_apply_distance", 80.0)
	var closed_fill := (controller.call("get_debug_snapshot") as Dictionary).get("interior_fill", {}) as Dictionary
	if int(closed_fill.get("active_light_count", -1)) != 0:
		_fail("Noon daylight area fill leaked through opaque roofs")
		return

	print("T0135-P7R3 interior daylight tint verification passed: %s" % str({
		"night_clinic": night_clinic,
		"morning_clinic": morning_clinic,
		"noon_clinic": noon_clinic,
		"daylight_target": daylight_target,
		"soft_area_lights": fill_lights.size(),
	}))
	quit(0)


func _building_color(fill: Dictionary, building_id: String) -> Color:
	return (fill.get("color_by_building", {}) as Dictionary).get(building_id, Color.BLACK)


func _color_distance(first: Color, second: Color) -> float:
	return Vector3(first.r, first.g, first.b).distance_to(Vector3(second.r, second.g, second.b))


func _sample_clinic_color(time_system: Node, controller: Node, hour: int, second_offset: int) -> Color:
	var total_seconds := hour * 3600 + second_offset
	var wrapped := posmod(total_seconds, 86400)
	time_system.call("set_current_time", 3, wrapped / 3600, (wrapped % 3600) / 60, wrapped % 60)
	var fill := (controller.call("get_debug_snapshot") as Dictionary).get("interior_fill", {}) as Dictionary
	return _building_color(fill, "clinic")


func _all_descendants(parent: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in parent.get_children():
		result.append(child)
		result.append_array(_all_descendants(child))
	return result


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
