extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(4):
		await process_frame
		await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(npc_system != null and combat_system != null and building_system != null, "T0176 NPC/combat/building systems missing")
	if not _failures.is_empty():
		_finish()
		return

	await _verify_shared_endpoint_has_bounded_recovery(npc_system)
	await _verify_intact_gate_blocks_targets_behind_it(combat_system, building_system, time_system)
	_finish()


func _verify_shared_endpoint_has_bounded_recovery(npc_system: Node) -> void:
	var npc_ids: Array[String] = npc_system.get_npc_ids()
	_check(npc_ids.size() >= 2, "T0176 needs two formal NPC actors")
	if npc_ids.size() < 2:
		return
	var blocker := npc_system.get_node_or_null(npc_system._npc_nodes.get(npc_ids[0], NodePath())) as ActorMotionBody
	var mover := npc_system.get_node_or_null(npc_system._npc_nodes.get(npc_ids[1], NodePath())) as ActorMotionBody
	_check(blocker != null and mover != null, "T0176 formal NPC actor nodes missing")
	if blocker == null or mover == null:
		return
	var navigation_map := mover.get_navigation_map()
	_check(navigation_map.is_valid(), "T0176 NPC production navigation map missing")
	if not navigation_map.is_valid():
		return

	var target := NavigationServer3D.map_get_closest_point(navigation_map, Vector3(0.0, mover.global_position.y, 12.0))
	var start := NavigationServer3D.map_get_closest_point(navigation_map, target + Vector3(3.0, 0.0, 0.0))
	blocker.stop_movement()
	mover.stop_movement()
	blocker.global_position = target
	mover.global_position = start
	blocker.velocity = Vector3.ZERO
	mover.velocity = Vector3.ZERO
	mover.move_to_location("t0176_shared_endpoint", target)

	var maximum_frames := 660
	for _frame in range(maximum_frames):
		await physics_frame
		if not mover.is_motion_active():
			break
	var snapshot: Dictionary = mover.debug_get_motion_snapshot()
	_check(not bool(snapshot.get("active", true)), "T0176 occupied endpoint still moves forever: %s" % snapshot)
	_check(str(snapshot.get("last_result", "")) in ["arrived", "stuck_timeout"], "T0176 occupied endpoint ended without a bounded result: %s" % snapshot)
	if str(snapshot.get("last_result", "")) == "stuck_timeout":
		_check(int(snapshot.get("repath_count", 0)) > 0, "T0176 stuck endpoint did not request a repath: %s" % snapshot)
		_check(float(snapshot.get("stuck_elapsed_seconds", 0.0)) >= 7.5, "T0176 stuck endpoint recovery window was reset: %s" % snapshot)
	_check(float(snapshot.get("last_sample_displacement", 0.0)) >= 0.0, "T0176 displacement diagnostic missing")
	_check(snapshot.has("last_sample_path_progress"), "T0176 path-progress diagnostic missing")


func _verify_intact_gate_blocks_targets_behind_it(combat_system: Node, building_system: Node, time_system: Node) -> void:
	if time_system != null:
		time_system.set_paused(true)
	var started: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(started.get("ok", false)), "T0176 first formal wave failed to spawn: %s" % started)
	if not bool(started.get("ok", false)):
		return
	combat_system.debug_step_enemy_ai(0.1)
	var positions: Dictionary = combat_system.debug_get_enemy_attack_position_snapshot()
	_check(int(positions.get("lease_count", 0)) == 7, "T0176 intact front gate should expose seven tight attack positions: %s" % positions)
	_check(int(positions.get("waiter_count", 0)) == 1, "T0176 eighth enemy should wait behind the intact front gate: %s" % positions)
	for raw_lease in positions.get("leases", []):
		var lease := raw_lease as Dictionary
		_check(str(lease.get("target_key", "")) == "building:front_gate", "T0176 lease escaped past intact gate: %s" % lease)
	for raw_waiter in positions.get("waiters", []):
		var waiter := raw_waiter as Dictionary
		_check(str(waiter.get("target_key", "")) == "building:front_gate", "T0176 waiter targeted a building behind the intact gate: %s" % waiter)

	var lease_holders: Array[String] = []
	for raw_lease in positions.get("leases", []):
		var lease := raw_lease as Dictionary
		var holder_id := str(lease.get("enemy_id", ""))
		lease_holders.append(holder_id)
		var holder_actor := combat_system.get_node_or_null(combat_system._formal_first_wave_node_paths.get(holder_id, NodePath())) as ActorMotionBody
		if holder_actor != null:
			var approach_position := _to_vector3(lease.get("position", holder_actor.global_position)) + Vector3(0.0, 0.0, 4.0)
			holder_actor.global_position = approach_position
			holder_actor.velocity = Vector3.ZERO
			var holder_enemy: Dictionary = combat_system._active_enemies.get(holder_id, {})
			holder_enemy["position"] = approach_position
			combat_system._active_enemies[holder_id] = holder_enemy
	for enemy_id in combat_system.get_active_enemy_ids():
		var target: Dictionary = combat_system.debug_get_enemy_target(enemy_id)
		_check(str(target.get("id", "")) == "front_gate", "T0176 intact gate was bypassed by %s: %s" % [enemy_id, target])
		var actor := combat_system.get_node_or_null(combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
		if actor == null:
			_check(false, "T0176 enemy actor missing: %s" % enemy_id)
			continue
		_check(is_equal_approx(actor.navigation_agent.target_desired_distance, 0.32), "T0176 attack-position arrival tolerance drifted: %s" % actor.navigation_agent.target_desired_distance)
		var motion: Dictionary = actor.debug_get_motion_snapshot()
		var expected_rvo_radius := float(motion.get("body_radius", 0.0)) + 0.04
		_check(is_equal_approx(actor.navigation_agent.radius, expected_rvo_radius), "T0176 RVO radius no longer matches tight slot spacing: %s vs %s" % [actor.navigation_agent.radius, expected_rvo_radius])

	# Keep the obstruction alive long enough to prove all seven tightly packed
	# actors can physically enter their reserved positions instead of orbiting.
	var gate: Dictionary = building_system._buildings.get("front_gate", {})
	gate["hp"] = 10000
	gate["max_hp"] = 10000
	building_system._buildings["front_gate"] = gate
	if time_system != null:
		time_system.set_paused(false)
	var reached: Dictionary = {}
	var final_motion: Dictionary = {}
	for _frame in range(300):
		await physics_frame
		for enemy_id in lease_holders:
			var actor := combat_system.get_node_or_null(combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
			if actor == null:
				continue
			var motion: Dictionary = actor.debug_get_motion_snapshot()
			final_motion[enemy_id] = motion
			if float(motion.get("minimum_target_distance", INF)) <= 0.325:
				reached[enemy_id] = true
		if reached.size() == lease_holders.size():
			break
	_check(reached.size() == lease_holders.size(), "T0176 tight gate positions did not all become reachable: reached=%s holders=%s motion=%s" % [reached.keys(), lease_holders, final_motion])


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _to_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Dictionary:
		return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
	return Vector3.ZERO


func _finish() -> void:
	if _failures.is_empty():
		print("T0176_NAVIGATION_RECOVERY_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
