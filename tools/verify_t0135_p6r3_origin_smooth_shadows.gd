extends SceneTree


func _init() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn unavailable")
		return
	root.add_child(packed.instantiate())
	for _frame in range(4):
		await process_frame
	await physics_frame
	await physics_frame

	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var camera_rig := root.get_node_or_null("Main/CameraRig") as Node3D
	var celestial := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/FormalEnvironmentArtView/CelestialCycleController"
	)
	var game_state := root.get_node_or_null("GameState")
	if controller == null or npc_system == null or camera_rig == null or celestial == null or game_state == null:
		_fail("P6R3 runtime dependencies unavailable")
		return

	var layout := controller.get_validation_snapshot() as Dictionary
	var formal_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout") as Node3D
	if (
		formal_root == null
		or formal_root.global_position.distance_to(Vector3.ZERO) > 0.001
		or str(layout.get("world_origin_mode", "")) != "formal_default_at_origin"
		or not bool(layout.get("legacy_visuals_hidden", false))
	):
		_fail("Formal world was not rebased cleanly to the origin: %s" % JSON.stringify(layout))
		return
	if absf(camera_rig.global_position.x) > 80.0 or absf(camera_rig.global_position.z) > 100.0:
		_fail("Formal camera still carries the retired preview offset: %s" % str(camera_rig.global_position))
		return
	for path in ["Main/WorldRoot/Station/Ground", "Main/WorldRoot/Station/Buildings", "Main/WorldRoot/Station/Props"]:
		var legacy_visual := root.get_node_or_null(path) as Node3D
		if legacy_visual == null or legacy_visual.visible:
			_fail("Legacy placeholder visual overlaps the origin-rebased formal world: %s" % path)
			return
		for raw_collision in legacy_visual.find_children("*", "CollisionObject3D", true, false):
			var collision := raw_collision as CollisionObject3D
			if collision != null and (collision.collision_layer != 0 or collision.collision_mask != 0):
				_fail("Hidden legacy collision still blocks the origin-rebased formal world: %s" % str(collision.get_path()))
				return

	var residents := npc_system.get_default_formal_world_snapshot() as Dictionary
	if not bool(residents.get("active", false)) or int(residents.get("actor_count", 0)) != 8:
		_fail("Default formal residents did not survive the origin rebase: %s" % JSON.stringify(residents))
		return
	for raw_actor in residents.get("actors", []):
		var actor := raw_actor as Dictionary
		var actor_position := actor.get("world_position", Vector3.ZERO) as Vector3
		if (
			absf(actor_position.x) > 80.0
			or absf(actor_position.z) > 100.0
			or not bool(actor.get("navigation_motion_enabled", false))
			or not bool(actor.get("navigation_map_matches", false))
		):
			_fail("Origin-rebased resident lacks valid formal navigation: %s" % JSON.stringify(actor))
			return

	var enemy_route := controller.get_enemy_route_world() as Dictionary
	var merchant_route := controller.get_formal_merchant_route_world() as Dictionary
	var escape_route := controller.get_formal_escape_route_world() as Dictionary
	if (
		(enemy_route.get("spawn_zone_center", Vector3.ZERO) as Vector3).x > 100.0
		or (merchant_route.get("spawn", Vector3.ZERO) as Vector3).x > 100.0
		or (escape_route.get("completion", Vector3.ZERO) as Vector3).x > 100.0
	):
		_fail("A formal route retained the retired X=1000 offset")
		return

	var original_time := {
		"day": int(game_state.current_day),
		"hour": int(game_state.current_hour),
		"minute": int(game_state.current_minute),
		"second": int(game_state.current_second),
	}
	game_state.set_time(2, 9, 0, 0)
	await process_frame
	var sun := celestial.get_node_or_null("SunDirectionalLight") as DirectionalLight3D
	var start := celestial.get_debug_snapshot() as Dictionary
	var start_shadow := start.get("directional_shadow", {}) as Dictionary
	var start_basis := sun.basis if sun != null else Basis.IDENTITY
	var start_count := int(start_shadow.get("transform_update_count", -1))
	if sun == null or not is_zero_approx(float(start_shadow.get("transform_update_interval_game_seconds", -1.0))):
		_fail("Production directional light is not in continuous update mode: %s" % str(start_shadow))
		return
	game_state.set_time(2, 9, 0, 1)
	await process_frame
	var next := celestial.get_debug_snapshot() as Dictionary
	var next_shadow := next.get("directional_shadow", {}) as Dictionary
	if sun.basis.is_equal_approx(start_basis) or int(next_shadow.get("transform_update_count", -1)) != start_count + 1:
		_fail("DirectionalLight basis did not advance smoothly on the next game-second signal: %s" % str(next_shadow))
		return
	var second_basis := sun.basis
	game_state.set_time(2, 9, 0, 2)
	await process_frame
	var third_basis := sun.basis
	if third_basis.is_equal_approx(second_basis):
		_fail("DirectionalLight basis froze between consecutive game-second signals")
		return
	var final_snapshot := celestial.get_debug_snapshot() as Dictionary
	if int((final_snapshot.get("directional_shadow", {}) as Dictionary).get("transform_update_count", -1)) != start_count + 2:
		_fail("Continuous mode did not update exactly once per time signal")
		return

	var migrated := controller.migrate_legacy_formal_world_position(Vector3(1002.0, 0.2, 10.0)) as Vector3
	if migrated.distance_to(Vector3(2.0, 0.2, 10.0)) > 0.001:
		_fail("Legacy formal save position was not rebased: %s" % str(migrated))
		return
	var checkpoint := npc_system.create_formal_spatial_checkpoint() as Dictionary
	var checkpoint_origin := checkpoint.get("world_origin", {}) as Dictionary
	if not is_zero_approx(float(checkpoint_origin.get("x", INF))) or not is_zero_approx(float(checkpoint_origin.get("z", INF))):
		_fail("New spatial checkpoints do not record the rebased origin: %s" % JSON.stringify(checkpoint))
		return

	game_state.set_time(original_time.day, original_time.hour, original_time.minute, original_time.second)
	print("T0135-P6R3 origin rebase and smooth shadow verification passed: %s" % str({
		"formal_root": formal_root.global_position,
		"camera_rig": camera_rig.global_position,
		"resident_count": int(residents.get("actor_count", 0)),
		"direction_updates": 2,
		"legacy_position_migrated": migrated,
	}))
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
