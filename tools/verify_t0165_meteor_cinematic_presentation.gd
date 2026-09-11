extends SceneTree


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Could not load Main.tscn")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var piety_system := root.get_node_or_null("Main/Systems/PietySystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var camera_rig := root.get_node_or_null("Main/CameraRig")
	if piety_system == null or combat_system == null or camera_rig == null:
		_fail("T0165 requires PietySystem, CombatSystem and CameraRig")
		return

	var config: Dictionary = piety_system.get_meteor_config()
	var damage_radius := float(config.get("radius", 0.0))
	var body_radius := float(config.get("body_radius", 0.0))
	if (
		body_radius < damage_radius * 0.7
		or body_radius >= damage_radius
		or float(config.get("fall_duration_seconds", 0.0)) < 2.5
		or not is_equal_approx(float(config.get("impact_camera_shake_duration_seconds", 0.0)), 2.0)
	):
		_fail("Meteor scale, descent duration or two-second impact shake is not configured")
		return

	var spawn: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn.get("ok", false)):
		_fail("Could not start a battle for meteor lifecycle verification")
		return
	piety_system.debug_fill_piety()
	var target := Vector3(0.0, 0.0, 75.0)
	var cast: Dictionary = piety_system.request_meteor_cast(target)
	if not bool(cast.get("ok", false)):
		_fail("Could not cast meteor: %s" % str(cast))
		return
	var snapshot: Dictionary = piety_system.get_piety_snapshot()
	var pending: Array = snapshot.get("pending_meteors", [])
	if pending.size() != 1:
		_fail("Meteor was not registered as pending")
		return
	var start: Dictionary = pending[0].get("start_position", {})
	if (
		float(start.get("y", 0.0)) < 29.0
		or Vector2(float(start.get("x", 0.0)), float(start.get("z", 0.0))).distance_to(Vector2(target.x, target.z)) < 14.0
	):
		_fail("Meteor does not begin high above the camera on a diagonal path")
		return
	var descent_shake: Dictionary = camera_rig.get_camera_shake_snapshot()
	if not bool(descent_shake.get("active", false)) or float(descent_shake.get("amplitude", 0.0)) <= 0.0:
		_fail("Meteor descent did not start the mild camera tremor")
		return

	var meteor_visuals: Dictionary = piety_system.get("_meteor_visuals")
	var cast_id := str(cast.get("cast_id", ""))
	var visual := meteor_visuals.get(cast_id, null) as Node3D
	if (
		visual == null
		or visual.find_child("FracturedMeteor", true, false) == null
		or visual.find_child("FlameTail", true, false) == null
		or visual.find_child("SmokeTail", true, false) == null
	):
		_fail("Falling meteor is missing approved fractured rock, fire or smoke")
		return

	var fall_game_seconds := float(config.get("fall_duration_seconds", 1.0)) + 1.0
	piety_system.debug_advance_effects(fall_game_seconds)
	snapshot = piety_system.get_piety_snapshot()
	var landed: Array = snapshot.get("landed_meteors", [])
	var craters: Array = snapshot.get("permanent_craters", [])
	if landed.size() != 1 or craters.size() != 1:
		_fail("Impact did not create both a landed meteor and permanent crater")
		return
	var presentation: Dictionary = landed[0].get("presentation", {})
	if not bool(presentation.get("body_present", false)) or not bool(presentation.get("permanent_crater", false)):
		_fail("Landed meteor body or crater is missing")
		return
	if (
		visual.find_child("MeteorStaticBody", true, false) == null
		or visual.find_child("BrokenEarthAndScorch", true, false) == null
		or visual.find_child("EjectedRimFragment0", true, false) == null
		or visual.find_child("AirPressureFront", true, false) == null
		or visual.find_child("FlyingFragment0", true, false) == null
	):
		_fail("Impact is missing collision, crater, ash, shockwave or debris")
		return
	var impact_shake: Dictionary = camera_rig.get_camera_shake_snapshot()
	if (
		not bool(impact_shake.get("active", false))
		or not is_equal_approx(float(impact_shake.get("duration_seconds", 0.0)), 2.0)
		or float(impact_shake.get("amplitude", 0.0)) < 0.8
	):
		_fail("Impact did not replace the mild tremor with the strong two-second shake")
		return

	combat_system.clear_spawned_enemies()
	await process_frame
	snapshot = piety_system.get_piety_snapshot()
	if not (snapshot.get("landed_meteors", []) as Array).is_empty():
		_fail("Landed meteor entity remained after combat_ended")
		return
	craters = snapshot.get("permanent_craters", [])
	if (
		craters.size() != 1
		or bool(craters[0].get("presentation", {}).get("body_present", true))
		or not bool(craters[0].get("presentation", {}).get("permanent_crater", false))
	):
		_fail("Combat end removed the permanent crater/ash or retained the meteor body")
		return

	print("T0165_METEOR_CINEMATIC_PRESENTATION_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
