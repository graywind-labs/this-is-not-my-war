extends SceneTree


func _init() -> void:
	var platform_scene := load("res://scenes/defense_devices/FormalMainHallDefensePlatformArtView.tscn") as PackedScene
	if platform_scene == null:
		_fail("Formal main-hall timber platform scene is missing")
		return
	var platform := platform_scene.instantiate() as Node3D
	root.add_child(platform)
	await process_frame
	var platform_snapshot: Dictionary = platform.get_debug_snapshot()
	var platform_footprint := _dict_to_vector3(platform_snapshot.get("footprint_size", {}))
	if platform_footprint.x > 3.6 or platform_footprint.z > 3.6:
		_fail("Main-hall platform exceeds its unchanged slot envelope")
		return
	if not bool(platform_snapshot.get("has_timber_corbel_frame", false)) or int(platform_snapshot.get("structure_parts", 0)) < 24:
		_fail("Main-hall platform did not become a complete timber structure")
		return
	if not is_equal_approx(float(platform_snapshot.get("device_anchor_local_y", 0.0)), 0.88):
		_fail("Main-hall device anchor height contract drifted")
		return

	var fixture_data := _load_json("res://data/building_fixture_layouts.json")
	var hall: Dictionary = (fixture_data.get("buildings", {}) as Dictionary).get("main_hall", {})
	var platform_count := 0
	for raw_fixture in hall.get("fixtures", []):
		var fixture: Dictionary = raw_fixture
		if str(fixture.get("kind", "")) != "main_hall_device_platform":
			continue
		platform_count += 1
		if str(fixture.get("asset_path", "")) != "res://scenes/defense_devices/FormalMainHallDefensePlatformArtView.tscn":
			_fail("A main-hall slot still uses the rejected stone platform")
			return
		if not is_equal_approx(float(fixture.get("device_anchor_y", 0.0)), 3.93):
			_fail("Main-hall authoritative device anchor changed")
			return
	if platform_count != 4:
		_fail("Expected four unchanged main-hall defense platforms")
		return

	var arrow_scene := load("res://scenes/defense_devices/FormalArrowTowerArtView.tscn") as PackedScene
	if arrow_scene == null:
		_fail("Formal arrow-tower scene is missing")
		return
	var arrow_tower := arrow_scene.instantiate() as Node3D
	root.add_child(arrow_tower)
	await process_frame
	var snapshot: Dictionary = arrow_tower.get_debug_snapshot()
	if str(snapshot.get("art_revision", "")) != "t0132_p4b" or str(snapshot.get("formal_device_kind", "")) != "arrow_tower":
		_fail("Formal arrow-tower identity contract is missing")
		return
	var footprint := _dict_to_vector3(snapshot.get("footprint_size", {}))
	if footprint.x > 3.3 or footprint.z > 3.3 or footprint.y > 3.6:
		_fail("Arrow tower does not fit both formal platform envelopes: %s" % str(footprint))
		return
	if int(snapshot.get("structure_parts", 0)) < 70:
		_fail("Formal arrow-tower detail density regressed below the approved low-poly baseline")
		return
	if not bool(snapshot.get("has_timber_tower", false)) or not bool(snapshot.get("has_tiled_canopy", false)) or not bool(snapshot.get("has_arrow_racks", false)) or not bool(snapshot.get("has_dynamic_string", false)):
		_fail("Arrow tower lacks its tower, canopy, ammunition racks, or firing mechanism")
		return
	if str(snapshot.get("roof_profile", "")) != "closed_convex_gable" or not bool(snapshot.get("ridge_supported_by_slopes", false)):
		_fail("Arrow tower roof is not the approved closed convex gable")
		return
	var left_roof := arrow_tower.find_child("LeftRoofSlope", true, false) as Node3D
	var right_roof := arrow_tower.find_child("RightRoofSlope", true, false) as Node3D
	var roof_ridge := arrow_tower.find_child("RoofRidge", true, false) as Node3D
	if left_roof == null or right_roof == null or roof_ridge == null or left_roof.rotation.z <= 0.0 or right_roof.rotation.z >= 0.0 or roof_ridge.position.y < 3.35:
		_fail("Arrow-tower slopes descend toward the ridge or leave its beam floating")
		return
	if bool(snapshot.get("has_fake_operator", true)):
		_fail("Presentation must not invent an operator without gameplay authority")
		return
	if not bool(snapshot.get("loaded_arrow_visible", false)):
		_fail("Idle arrow tower should visibly carry one loaded arrow")
		return
	for texture_path in [str(snapshot.get("wood_texture", "")), str(snapshot.get("metal_texture", "")), str(snapshot.get("roof_texture", ""))]:
		if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
			_fail("Formal Quaternius PBR texture is missing: %s" % texture_path)
			return

	arrow_tower.configure_device({
		"effect": {"attack_interval": 0.70},
		"presentation": {"projectile_speed": 64.0, "reload_fraction": 0.58}
	})
	arrow_tower.debug_play_attack(Vector3(7.0, 0.0, 15.0), 0.70)
	await process_frame
	snapshot = arrow_tower.get_debug_snapshot()
	if int(snapshot.get("shot_count", 0)) != 1 or bool(snapshot.get("loaded_arrow_visible", true)):
		_fail("Arrow launch did not create a visible empty reload state")
		return
	if int(snapshot.get("active_projectile_count", 0)) != 1:
		_fail("Arrow launch did not create one visible projectile")
		return
	await create_timer(0.72).timeout
	snapshot = arrow_tower.get_debug_snapshot()
	if not bool(snapshot.get("loaded_arrow_visible", false)):
		_fail("Attack-speed-synchronized reload did not place the next arrow")
		return
	if int(snapshot.get("active_projectile_count", -1)) != 0:
		_fail("Arrow presentation projectile was not cleaned after flight")
		return

	var defs := _load_json("res://data/defense_device_defs.json")
	var arrow_definition: Dictionary = {}
	for raw_device in defs.get("devices", []):
		var device: Dictionary = raw_device
		if str(device.get("id", "")) == "wall_arrow_tower":
			arrow_definition = device
			break
	if arrow_definition.is_empty() or str((arrow_definition.get("presentation", {}) as Dictionary).get("model_scene", "")) != "res://scenes/defense_devices/FormalArrowTowerArtView.tscn":
		_fail("wall_arrow_tower did not switch from placeholder to the formal scene")
		return
	if not is_equal_approx(float((arrow_definition.get("effect", {}) as Dictionary).get("attack_interval", 0.0)), 1.39):
		_fail("Arrow tower authoritative attack interval changed")
		return

	var device_view_scene := load("res://scenes/defense_devices/DefenseDeviceView.tscn") as PackedScene
	var device_view := device_view_scene.instantiate() as Node3D
	root.add_child(device_view)
	await process_frame
	device_view.configure_device({
		"deployment_id": "test_arrow_tower",
		"device_id": "wall_arrow_tower",
		"device_name": "箭塔",
		"slot_id": "main_hall_slot_01",
		"position": {"x": 2.0, "y": 3.93, "z": 4.0},
		"rotation_y_degrees": 0.0,
		"hp": 110,
		"max_hp": 110,
		"effect": {"range": 56.0, "attack_interval": 1.39},
		"presentation": {
			"model_scene": "res://scenes/defense_devices/FormalArrowTowerArtView.tscn",
			"projectile_speed": 64.0,
			"reload_fraction": 0.58,
			"status_label_height": 3.75
		}
	})
	await process_frame
	var view_snapshot: Dictionary = device_view.get_debug_snapshot()
	if not bool(view_snapshot.get("has_formal_model", false)):
		_fail("DefenseDeviceView did not instantiate the formal arrow tower")
		return
	if not is_equal_approx(float(device_view.get_node("StatusLabel").position.y), 3.75):
		_fail("Arrow tower status label overlaps the canopy")
		return

	print("T0132-P4b timber platforms and formal arrow tower verification passed.")
	quit(0)


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _dict_to_vector3(raw: Variant) -> Vector3:
	if raw is Vector3:
		return raw
	if not raw is Dictionary:
		return Vector3.ZERO
	return Vector3(float(raw.get("x", 0.0)), float(raw.get("y", 0.0)), float(raw.get("z", 0.0)))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
