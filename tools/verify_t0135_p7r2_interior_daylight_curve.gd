extends SceneTree

const EXPECTED_BUILDINGS := [
	"blacksmith", "workshop", "chapel", "clinic", "dining_hall", "dormitory", "tavern",
]
const SAMPLE_HOURS := [0, 6, 7, 9, 12, 15, 17, 18, 20]


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
		_fail("P7R2 integration nodes are missing")
		return
	time_system.call("set_paused", true)
	roof_controller.call("debug_apply_distance", 50.0)

	var samples: Dictionary = {}
	for hour in SAMPLE_HOURS:
		time_system.call("set_current_time", 3, hour, 0, 0)
		var fill := (controller.call("get_debug_snapshot") as Dictionary).get("interior_fill", {}) as Dictionary
		if int(fill.get("revealed_building_count", 0)) != EXPECTED_BUILDINGS.size():
			_fail("All closed enterable interiors must remain revealed at hour %02d: %s" % [hour, str(fill)])
			return
		if int(fill.get("active_light_count", 0)) != EXPECTED_BUILDINGS.size():
			_fail("All interior fill lights must remain active at hour %02d: %s" % [hour, str(fill)])
			return
		samples[hour] = fill.duplicate(true)

	var clinic_energy: Dictionary = {}
	for hour in SAMPLE_HOURS:
		clinic_energy[hour] = float(((samples[hour] as Dictionary).get("energy_by_building", {}) as Dictionary).get("clinic", 0.0))
	if not (clinic_energy[6] < clinic_energy[7] and clinic_energy[7] < clinic_energy[9] and clinic_energy[9] < clinic_energy[12]):
		_fail("Interior daylight curve must rise continuously from 06:00 to 12:00: %s" % str(clinic_energy))
		return
	if not (clinic_energy[12] > clinic_energy[15] and clinic_energy[15] > clinic_energy[17] and clinic_energy[17] > clinic_energy[18]):
		_fail("Interior daylight curve must fall continuously from 12:00 to 18:00: %s" % str(clinic_energy))
		return
	for pair in [[0, 6], [6, 18], [18, 20], [7, 17], [9, 15]]:
		if not is_equal_approx(float(clinic_energy[pair[0]]), float(clinic_energy[pair[1]])):
			_fail("Interior daylight curve lost its configured baseline/symmetry at %s: %s" % [str(pair), str(clinic_energy)])
			return
	if float(clinic_energy[12]) < float(clinic_energy[0]) * 1.29:
		_fail("Noon interior peak is below the configured 30%% lift: %s" % str(clinic_energy))
		return
	if str((samples[6] as Dictionary).get("lighting_phase", "")) != "morning_rise" \
	or str((samples[12] as Dictionary).get("lighting_phase", "")) != "day_peak" \
	or str((samples[18] as Dictionary).get("lighting_phase", "")) != "afternoon_fall" \
	or str((samples[20] as Dictionary).get("lighting_phase", "")) != "night_base":
		_fail("Interior lighting phases do not match 06/12/18 boundaries: %s" % str(samples))
		return

	var noon_fill := samples[12] as Dictionary
	var noon_scale := float(noon_fill.get("time_scale", 0.0))
	var noon_energies := noon_fill.get("energy_by_building", {}) as Dictionary
	for building_id in EXPECTED_BUILDINGS:
		if not noon_energies.has(building_id) or float(noon_energies[building_id]) <= 0.0:
			_fail("Noon curve did not reach building %s: %s" % [building_id, str(noon_energies)])
			return
		var night_energy := float(((samples[0] as Dictionary).get("energy_by_building", {}) as Dictionary).get(building_id, 0.0))
		if not is_equal_approx(float(noon_energies[building_id]) / night_energy, noon_scale):
			_fail("Building %s does not share the common daylight multiplier" % building_id)
			return

	for boundary_hour in [6, 12, 18]:
		var before := _sample_clinic_energy(time_system, controller, boundary_hour, 0, -1)
		var at_boundary := _sample_clinic_energy(time_system, controller, boundary_hour, 0, 0)
		var after := _sample_clinic_energy(time_system, controller, boundary_hour, 0, 1)
		if absf(at_boundary - before) > 0.002 or absf(after - at_boundary) > 0.002:
			_fail("Interior curve jumps at %02d:00: before=%.6f at=%.6f after=%.6f" % [boundary_hour, before, at_boundary, after])
			return

	time_system.call("set_current_time", 3, 12, 0, 0)
	roof_controller.call("debug_apply_distance", 80.0)
	var closed_fill := (controller.call("get_debug_snapshot") as Dictionary).get("interior_fill", {}) as Dictionary
	if int(closed_fill.get("active_light_count", -1)) != 0:
		_fail("Daylight peak leaked through closed roofs: %s" % str(closed_fill))
		return

	print("T0135-P7R2 interior daylight curve verification passed: %s" % str({
		"clinic_energy": clinic_energy,
		"noon_scale": noon_scale,
		"phases": {
			"06": (samples[6] as Dictionary).get("lighting_phase"),
			"12": (samples[12] as Dictionary).get("lighting_phase"),
			"18": (samples[18] as Dictionary).get("lighting_phase"),
			"20": (samples[20] as Dictionary).get("lighting_phase"),
		},
	}))
	quit(0)


func _sample_clinic_energy(time_system: Node, controller: Node, hour: int, minute: int, second_offset: int) -> float:
	var total_seconds := hour * 3600 + minute * 60 + second_offset
	var wrapped := posmod(total_seconds, 86400)
	time_system.call("set_current_time", 3, wrapped / 3600, (wrapped % 3600) / 60, wrapped % 60)
	var fill := (controller.call("get_debug_snapshot") as Dictionary).get("interior_fill", {}) as Dictionary
	return float((fill.get("energy_by_building", {}) as Dictionary).get("clinic", 0.0))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
