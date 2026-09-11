extends SceneTree


func _init() -> void:
	var ballista_scene := load("res://scenes/defense_devices/FormalBallistaArtView.tscn") as PackedScene
	if ballista_scene == null:
		_fail("Formal ballista scene is missing")
		return
	var ballista := ballista_scene.instantiate() as Node3D
	root.add_child(ballista)
	await process_frame
	var snapshot: Dictionary = ballista.get_debug_snapshot()
	if str(snapshot.get("art_revision", "")) != "t0132_p4a" or str(snapshot.get("formal_device_kind", "")) != "ballista":
		_fail("Formal ballista identity contract is missing")
		return
	var footprint := _dict_to_vector3(snapshot.get("footprint_size", {}))
	if footprint.x > 3.2 or footprint.z > 3.2 or footprint.y > 2.2:
		_fail("Ballista does not fit both formal platform envelopes: %s" % str(footprint))
		return
	if not bool(snapshot.get("has_carriage", false)) or not bool(snapshot.get("has_turntable", false)) or not bool(snapshot.get("has_winch", false)) or not bool(snapshot.get("has_dynamic_string", false)):
		_fail("Ballista structure is missing carriage, turntable, winch, or dynamic string")
		return
	if int(snapshot.get("structure_parts", 0)) < 48:
		_fail("Formal ballista detail density regressed below the approved low-poly baseline")
		return
	if not bool(snapshot.get("loaded_bolt_visible", false)):
		_fail("Idle ballista should visibly carry one loaded bolt")
		return
	for texture_path in [str(snapshot.get("wood_texture", "")), str(snapshot.get("metal_texture", ""))]:
		if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
			_fail("Formal Quaternius PBR texture is missing: %s" % texture_path)
			return
	if ballista.find_child("LoadedHeavyBolt", true, false) == null or ballista.find_child("ReloadWinch", true, false) == null or ballista.find_child("LeftDynamicBowString", true, false) == null:
		_fail("Visible load / reload components are missing")
		return

	ballista.configure_device({
		"effect": {"attack_interval": 0.60},
		"presentation": {"projectile_speed": 52.0, "reload_fraction": 0.62}
	})
	ballista.debug_play_attack(Vector3(8.0, 0.0, 14.0), 0.60)
	await process_frame
	snapshot = ballista.get_debug_snapshot()
	if int(snapshot.get("shot_count", 0)) != 1 or bool(snapshot.get("loaded_bolt_visible", true)):
		_fail("Launch did not remove the loaded bolt for reload")
		return
	if int(snapshot.get("active_projectile_count", 0)) != 1:
		_fail("Launch did not create one visible heavy bolt projectile")
		return
	if float(snapshot.get("last_flight_seconds", 0.0)) <= 0.0 or float(snapshot.get("last_reload_seconds", 0.0)) <= 0.0:
		_fail("Attack did not derive flight and reload timing")
		return
	await create_timer(0.78).timeout
	snapshot = ballista.get_debug_snapshot()
	if not bool(snapshot.get("loaded_bolt_visible", false)):
		_fail("Reload cycle did not place the next visible bolt")
		return
	if int(snapshot.get("active_projectile_count", -1)) != 0:
		_fail("Presentation projectile was not cleaned after flight")
		return

	var device_view_scene := load("res://scenes/defense_devices/DefenseDeviceView.tscn") as PackedScene
	var device_view := device_view_scene.instantiate() as Node3D
	root.add_child(device_view)
	await process_frame
	device_view.configure_device({
		"deployment_id": "test_ballista",
		"device_id": "wall_ballista",
		"device_name": "弩床",
		"slot_id": "wall_slot_01",
		"position": {"x": 2.0, "y": 3.55, "z": 4.0},
		"rotation_y_degrees": 18.0,
		"hp": 55,
		"max_hp": 55,
		"effect": {"range": 34.0, "attack_interval": 4.25},
		"presentation": {
			"model_scene": "res://scenes/defense_devices/FormalBallistaArtView.tscn",
			"projectile_speed": 52.0,
			"reload_fraction": 0.62,
			"status_label_height": 2.05
		}
	})
	await process_frame
	var view_snapshot: Dictionary = device_view.get_debug_snapshot()
	if not bool(view_snapshot.get("has_formal_model", false)) or str(view_snapshot.get("model_scene", "")) != "res://scenes/defense_devices/FormalBallistaArtView.tscn":
		_fail("DefenseDeviceView did not replace the placeholder with the formal scene")
		return
	if not is_equal_approx(float(device_view.get_node("StatusLabel").position.y), 2.05):
		_fail("Ballista status label height overlaps the formal model")
		return

	print("T0132-P4a formal ballista art slice verification passed.")
	quit(0)


func _dict_to_vector3(raw: Variant) -> Vector3:
	if raw is Vector3:
		return raw
	if not raw is Dictionary:
		return Vector3.ZERO
	return Vector3(float(raw.get("x", 0.0)), float(raw.get("y", 0.0)), float(raw.get("z", 0.0)))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
