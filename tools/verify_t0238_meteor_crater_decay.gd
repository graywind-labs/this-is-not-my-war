extends SceneTree


const TEST_TARGET := Vector3(120.0, 0.0, 120.0)
const HALF_DAY_SECONDS := 43200.0
const ELEVEN_HOURS_SECONDS := 39600.0
const ONE_HOUR_SECONDS := 3600.0


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var piety_system := root.get_node_or_null("Main/Systems/PietySystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if combat_system == null or piety_system == null or time_system == null:
		_fail("T0238 requires CombatSystem, PietySystem and TimeSystem")
		return

	var meteor_config: Dictionary = piety_system.get_meteor_config()
	if not is_equal_approx(float(meteor_config.get("crater_lifetime_game_seconds", 0.0)), 86400.0):
		_fail("Crater lifetime must be exactly 24 game hours")
		return

	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		_fail("Could not start battle for crater lifecycle verification")
		return
	piety_system.debug_fill_piety()
	var cast_result: Dictionary = piety_system.request_meteor_cast(TEST_TARGET)
	if not bool(cast_result.get("ok", false)):
		_fail("Could not cast meteor: %s" % JSON.stringify(cast_result))
		return
	piety_system.debug_advance_effects(float(meteor_config.get("fall_duration_seconds", 2.8)) + 0.1)

	var snapshot: Dictionary = piety_system.get_piety_snapshot()
	var craters: Array = snapshot.get("craters", [])
	if craters.size() != 1:
		_fail("Impact should create one fading crater")
		return
	var crater: Dictionary = craters[0]
	if (
		not is_equal_approx(float(crater.get("fade_progress", -1.0)), 0.0)
		or not is_equal_approx(float(crater.get("opacity", -1.0)), 1.0)
	):
		_fail("New crater should begin fully visible: %s" % JSON.stringify(crater))
		return

	var cast_id := str(cast_result.get("cast_id", ""))
	var crater_visuals: Dictionary = piety_system.get("_permanent_crater_visuals")
	var visual := crater_visuals.get(cast_id, null) as Node
	if visual == null or not visual.has_method("has_crater") or not bool(visual.has_crater()):
		_fail("Crater presentation is missing after impact")
		return

	# Real-frame presentation time and an ordinary pause do not age the crater.
	time_system.set_paused(true)
	piety_system._process(HALF_DAY_SECONDS)
	snapshot = piety_system.get_piety_snapshot()
	crater = (snapshot.get("craters", []) as Array)[0]
	if not is_equal_approx(float(crater.get("elapsed_game_seconds", -1.0)), 0.0):
		_fail("Paused real-frame time should not age the crater")
		return
	time_system.set_paused(false)

	# The authoritative logical game-time channel drives a linear fade.
	piety_system._on_logical_time_tick(HALF_DAY_SECONDS, 1.0)
	snapshot = piety_system.get_piety_snapshot()
	crater = (snapshot.get("craters", []) as Array)[0]
	if (
		absf(float(crater.get("fade_progress", 0.0)) - 0.5) > 0.001
		or absf(float(crater.get("opacity", 0.0)) - 0.5) > 0.001
	):
		_fail("Crater should be half faded after 12 game hours: %s" % JSON.stringify(crater))
		return
	var crater_materials: Array = visual.get("_crater_materials")
	if crater_materials.is_empty():
		_fail("Crater presentation does not expose fadeable materials")
		return
	var sample_material := crater_materials[0] as StandardMaterial3D
	if sample_material == null or absf(sample_material.albedo_color.a - 0.5) > 0.001:
		_fail("Crater material alpha did not follow lifecycle opacity")
		return

	piety_system._on_logical_time_tick(ELEVEN_HOURS_SECONDS, 1.0)
	snapshot = piety_system.get_piety_snapshot()
	craters = snapshot.get("craters", [])
	if craters.size() != 1 or not bool(visual.has_crater()):
		_fail("Crater must remain present before the 24-hour boundary")
		return

	piety_system._on_logical_time_tick(ONE_HOUR_SECONDS, 1.0)
	snapshot = piety_system.get_piety_snapshot()
	if (
		not (snapshot.get("craters", []) as Array).is_empty()
		or not (snapshot.get("permanent_craters", []) as Array).is_empty()
		or bool(visual.has_crater())
	):
		_fail("Crater should be removed exactly at 24 game hours")
		return
	if not bool(visual.has_body()):
		_fail("Crater expiry must not remove the active battle's meteor body")
		return

	combat_system.clear_spawned_enemies()
	await process_frame
	if is_instance_valid(visual) and bool(visual.has_body()):
		_fail("Combat end should still remove the landed meteor body")
		return

	print("T0238_METEOR_CRATER_DECAY_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
