extends SceneTree


const MAIN_PATH := "res://scenes/main/Main.tscn"
const ACTOR_ROOT_PATH := "Main/WorldRoot/FormalStationLayout/FormalEnemies"


func _init() -> void:
	var packed := load(MAIN_PATH) as PackedScene
	if packed == null:
		_fail("Main.tscn unavailable")
		return
	root.add_child(packed.instantiate())
	await process_frame
	await physics_frame
	await physics_frame
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	if combat_system == null:
		_fail("CombatSystem unavailable")
		return
	var expected_counts := {1: 8, 2: 16, 3: 24, 4: 36, 5: 48}
	for wave_number in range(1, 6):
		var started: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(wave_number)
		await physics_frame
		var snapshot: Dictionary = combat_system.debug_get_formal_dynamic_wave_slice_snapshot()
		if not bool(started.get("ok", false)) or int(started.get("spawned_count", 0)) != expected_counts[wave_number]:
			_fail("Wave %d dynamic spawn mismatch: %s" % [wave_number, started])
			return
		if int(snapshot.get("formal_actor_count", 0)) != expected_counts[wave_number]:
			_fail("Wave %d physical actor mismatch: %s" % [wave_number, snapshot])
			return
		for raw_slice in snapshot.get("slices", []):
			var slice := raw_slice as Dictionary
			if str(slice.get("movement_model", "")) != "dynamic_combat_pressure":
				_fail("Wave %d retained fixed-slot runtime: %s" % [wave_number, slice])
				return
			var motion := slice.get("motion", {}) as Dictionary
			if int(motion.get("body_collision_layer", 0)) != 2 or int(motion.get("body_collision_mask", 0)) != 3:
				_fail("Wave %d actor lacks solid body collision: %s" % [wave_number, motion])
				return
			if not is_equal_approx(float(motion.get("navigation_max_speed", -1.0)), float(motion.get("profile_base_speed", -2.0))):
				_fail("Wave %d actor NavigationAgent max speed is not bound to its movement profile: %s" % [wave_number, motion])
				return
		combat_system.debug_stop_formal_dynamic_wave_slice("wave_factory_audit")
		await process_frame

	var start_pressure: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(2)
	if not bool(start_pressure.get("ok", false)):
		_fail("Pressure wave failed to start: %s" % start_pressure)
		return
	await physics_frame
	var actor_root := root.get_node_or_null(ACTOR_ROOT_PATH)
	for child in actor_root.get_children():
		if not child is ActorMotionBody:
			continue
		var actor := child as ActorMotionBody
		actor.configure_profile("enemy_foot", {
			"profile": {"base_speed": 12.0, "acceleration": 30.0},
			"navigation_agent": {
				"target_desired_distance": 0.18,
				"path_desired_distance": 0.35,
				"neighbor_distance": 1.8,
				"max_neighbors": 12,
				"time_horizon_agents": 0.6,
				"time_horizon_obstacles": 0.8
			},
			"stuck_recovery": {"fail_after_seconds": 4.5, "maximum_repaths_per_target": 3}
		})
	for raw_enemy_id in combat_system.get_active_enemy_ids():
		var enemy_id := str(raw_enemy_id)
		var enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
		enemy["attack_power"] = 1
		enemy["attack_interval"] = 10000.0
		enemy["attack_speed"] = 0.0001
		combat_system._active_enemies[enemy_id] = enemy

	var contact_seen := false
	for frame in range(1800):
		await physics_frame
		if frame % 10 == 0:
			combat_system.debug_step_enemy_ai(1.0)
		var pressure_snapshot: Dictionary = combat_system.debug_get_formal_dynamic_wave_slice_snapshot()
		for raw_slice in pressure_snapshot.get("slices", []):
			var slice := raw_slice as Dictionary
			if bool(slice.get("front_gate_combat_authority_committed", false)):
				contact_seen = true
				break
		if contact_seen:
			break
	if not contact_seen:
		_fail("Dynamic pressure never produced physical gate contact: %s" % combat_system.debug_get_formal_dynamic_wave_slice_snapshot())
		return
	var contact_snapshot: Dictionary = combat_system.debug_get_formal_dynamic_wave_slice_snapshot()
	var shared_targets: Dictionary = {}
	var pressing_count := 0
	var contact_count := 0
	var pressing_ids: Dictionary = {}
	var front_victim_position := Vector3.ZERO
	var front_victim_found := false
	var maximum_observed_speed := 0.0
	var maximum_frame_displacement := 0.0
	var maximum_turn_radians_per_frame := 0.0
	for raw_slice in contact_snapshot.get("slices", []):
		var slice := raw_slice as Dictionary
		var motion := slice.get("motion", {}) as Dictionary
		var profile_speed := float(motion.get("profile_base_speed", 0.0))
		maximum_observed_speed = maxf(maximum_observed_speed, float(motion.get("maximum_observed_speed", 0.0)))
		maximum_frame_displacement = maxf(maximum_frame_displacement, float(motion.get("maximum_frame_displacement", 0.0)))
		maximum_turn_radians_per_frame = maxf(maximum_turn_radians_per_frame, float(slice.get("presentation_max_turn_radians_per_frame", 0.0)))
		if not is_equal_approx(float(motion.get("navigation_max_speed", -1.0)), profile_speed):
			_fail("Pressure actor lost its profile speed contract: %s" % slice)
			return
		if float(motion.get("maximum_observed_speed", 0.0)) > profile_speed + 0.02:
			_fail("RVO pushed an actor beyond profile speed: %s" % slice)
			return
		# CharacterBody contact recovery may add a fraction of one body radius to
		# velocity integration. A full-radius jump is still treated as ejection.
		var contact_recovery_allowance := float(motion.get("body_radius", 0.0)) * 0.6
		if float(motion.get("maximum_frame_displacement", 0.0)) > profile_speed / 60.0 + contact_recovery_allowance:
			_fail("Crowd contact displaced an actor by a flight-like single-frame distance: %s" % slice)
			return
		if float(slice.get("presentation_max_turn_radians_per_frame", 0.0)) > TAU / 60.0 + 0.01:
			_fail("Crowd avoidance produced an unbounded visible turn: %s" % slice)
			return
		var target_position: Vector3 = slice.get("motion_target_position", Vector3.ZERO)
		shared_targets["%.2f,%.2f" % [target_position.x, target_position.z]] = true
		if str(slice.get("phase", "")).begins_with("attacking_"):
			contact_count += 1
			if not front_victim_found:
				front_victim_position = slice.get("world_position", Vector3.ZERO)
				front_victim_found = true
		else:
			pressing_count += 1
			pressing_ids[str(slice.get("enemy_id", ""))] = true
		if int(slice.get("attack_slot_index", -1)) != -1:
			_fail("Fixed attack slot survived in P7: %s" % slice)
			return
	if shared_targets.size() != 1 or contact_count <= 0 or pressing_count <= 0:
		_fail("Crowd did not share a contested target with front contact and rear pressure: %s" % contact_snapshot)
		return
	if float(contact_snapshot.get("minimum_pair_distance", 0.0)) < 0.75:
		_fail("Solid enemy bodies overlapped beyond tolerance: %s" % contact_snapshot)
		return
	var defeated: Dictionary = combat_system.apply_enemy_area_damage(front_victim_position, 0.1, 9999.0, {"max_targets": 1, "source_type": "pressure_refill_verification"})
	if int(defeated.get("defeated_count", 0)) != 1:
		_fail("Could not remove one front contact for refill verification: %s" % defeated)
		return
	var refill_enemy_id := ""
	for frame in range(720):
		await physics_frame
		if frame % 10 == 0:
			combat_system.debug_step_enemy_ai(1.0)
		var refill_snapshot: Dictionary = combat_system.debug_get_formal_dynamic_wave_slice_snapshot()
		for raw_slice in refill_snapshot.get("slices", []):
			var slice := raw_slice as Dictionary
			var enemy_id := str(slice.get("enemy_id", ""))
			if pressing_ids.has(enemy_id) and str(slice.get("phase", "")).begins_with("attacking_"):
				refill_enemy_id = enemy_id
				break
		if not refill_enemy_id.is_empty():
			break
	if refill_enemy_id.is_empty():
		_fail("No rear pressure actor refilled the released front contact")
		return
	combat_system.debug_stop_formal_dynamic_wave_slice("verification_complete")
	await process_frame
	print("T0129C A4-P7 dynamic combat pressure verification passed: %s" % JSON.stringify({
		"wave_counts": expected_counts,
		"contact_count": contact_count,
		"pressing_count": pressing_count,
		"refill_enemy_id": refill_enemy_id,
		"minimum_pair_distance": contact_snapshot.get("minimum_pair_distance"),
		"avoidance_callbacks": contact_snapshot.get("avoidance_callback_count"),
		"maximum_observed_speed": maximum_observed_speed,
		"maximum_frame_displacement": maximum_frame_displacement,
		"maximum_turn_radians_per_frame": maximum_turn_radians_per_frame
	}))
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
