extends SceneTree


const MAIN_PATH := "res://scenes/main/Main.tscn"
const ACTOR_ROOT_PATH := "Main/WorldRoot/FormalStationLayout/FormalEnemies"


func _init() -> void:
	var packed := load(MAIN_PATH) as PackedScene
	if packed == null:
		_fail("Main.tscn unavailable")
		return
	var main := packed.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	await process_frame
	await physics_frame
	await physics_frame
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if combat_system == null or time_system == null:
		_fail("CombatSystem or TimeSystem unavailable")
		return
	# Physical enemy movement now correctly obeys the persisted gameplay pause.
	# This movement fixture must explicitly enter a running game state.
	time_system.set_paused(false)
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

	# Factory-audit setup may leave the static/headless fixture paused after its
	# repeated battle teardown. The pressure section is explicitly a live-motion
	# verification, so normalize it again at that boundary.
	time_system.set_paused(false)
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
		# T0142 makes attack_interval the full authored cycle. Keeping the old
		# 10000-second suppression here also postpones impact for 2000 seconds,
		# contradicting this test's requirement to observe a real gate commit.
		enemy["attack_interval"] = 0.5
		enemy["attack_speed"] = 2.0
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
	var attack_position_snapshot: Dictionary = combat_system.debug_get_enemy_attack_position_snapshot()
	var pressing_count := 0
	var contact_count := 0
	var front_victim_position := Vector3.ZERO
	var front_victim_id := ""
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
		if str(slice.get("phase", "")).begins_with("attacking_"):
			contact_count += 1
			if not front_victim_found:
				front_victim_position = slice.get("world_position", Vector3.ZERO)
				front_victim_id = str(slice.get("enemy_id", ""))
				front_victim_found = true
		else:
			pressing_count += 1
		if int(slice.get("attack_slot_index", -1)) != -1:
			_fail("Fixed attack slot survived in P7: %s" % slice)
			return
	var shared_target_keys: Dictionary = {}
	for raw_lease in attack_position_snapshot.get("leases", []):
		shared_target_keys[str((raw_lease as Dictionary).get("target_key", ""))] = true
	for raw_waiter in attack_position_snapshot.get("waiters", []):
		shared_target_keys[str((raw_waiter as Dictionary).get("target_key", ""))] = true
	if str(attack_position_snapshot.get("schema", "")) != "enemy_attack_position_leases_v1":
		_fail("Dynamic pressure did not expose the T0149 attack-position lease contract: %s" % attack_position_snapshot)
		return
	if int(attack_position_snapshot.get("lease_count", 0)) + int(attack_position_snapshot.get("waiter_count", 0)) != expected_counts[2]:
		_fail("Dynamic pressure left an enemy without a lease or wait entry: %s" % attack_position_snapshot)
		return
	if (
		not shared_target_keys.has("building:front_gate")
		or shared_target_keys.has("building:warehouse")
		or shared_target_keys.has("building:main_hall")
		or contact_count <= 0
		or pressing_count <= 0
	):
		_fail("Crowd did not keep full-position overflow queued behind the intact front gate: %s / %s" % [contact_snapshot, attack_position_snapshot])
		return
	if float(contact_snapshot.get("minimum_pair_distance", 0.0)) < 0.75:
		_fail("Solid enemy bodies overlapped beyond tolerance: %s" % contact_snapshot)
		return
	var victim_role := ""
	var victim_target_key := ""
	for raw_lease in attack_position_snapshot.get("leases", []):
		var lease := raw_lease as Dictionary
		if str(lease.get("enemy_id", "")) == front_victim_id:
			victim_role = str(lease.get("role", ""))
			victim_target_key = str(lease.get("target_key", ""))
			break
	var compatible_waiter_before := false
	for raw_waiter in attack_position_snapshot.get("waiters", []):
		var waiter := raw_waiter as Dictionary
		if str(waiter.get("role", "")) == victim_role and str(waiter.get("target_key", "")) == victim_target_key:
			compatible_waiter_before = true
			break
	var position_metrics_before := attack_position_snapshot.get("metrics", {}) as Dictionary
	var promotions_before := int(position_metrics_before.get("waiters_promoted", 0))
	var defeated: Dictionary = combat_system.apply_enemy_area_damage(front_victim_position, 0.1, 9999.0, {"max_targets": 1, "source_type": "pressure_refill_verification"})
	if int(defeated.get("defeated_count", 0)) != 1:
		_fail("Could not remove one front contact for refill verification: %s" % defeated)
		return
	await physics_frame
	combat_system.debug_step_enemy_ai(0.1)
	var post_defeat_positions: Dictionary = combat_system.debug_get_enemy_attack_position_snapshot()
	var post_defeat_assignment_count := int(post_defeat_positions.get("lease_count", 0)) + int(post_defeat_positions.get("waiter_count", 0))
	if post_defeat_assignment_count != expected_counts[2] - 1:
		_fail("Defeat left a lease leak or an unassigned surviving enemy: %s" % post_defeat_positions)
		return
	for collection_name in ["leases", "waiters"]:
		for raw_entry in post_defeat_positions.get(collection_name, []):
			if str((raw_entry as Dictionary).get("enemy_id", "")) == front_victim_id:
				_fail("Defeated front contact retained an attack-position entry: %s" % post_defeat_positions)
				return
	var position_metrics_after := post_defeat_positions.get("metrics", {}) as Dictionary
	var promoted_during_release := int(position_metrics_after.get("waiters_promoted", 0)) - promotions_before
	if compatible_waiter_before and promoted_during_release <= 0:
		_fail("A compatible candidate queue existed but no waiter refilled the released lease: %s" % post_defeat_positions)
		return
	combat_system.debug_stop_formal_dynamic_wave_slice("verification_complete")
	await process_frame
	print("T0129C A4-P7 dynamic combat pressure verification passed: %s" % JSON.stringify({
		"wave_counts": expected_counts,
		"contact_count": contact_count,
		"pressing_count": pressing_count,
		"released_enemy_id": front_victim_id,
		"waiters_promoted_during_release": promoted_during_release,
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
