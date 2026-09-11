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
	for _frame in range(5):
		await process_frame
		await physics_frame

	var combat := root.get_node_or_null("Main/Systems/CombatSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(combat != null and time_system != null, "T0211 combat dependencies missing")
	if not _failures.is_empty():
		_finish()
		return
	time_system.set_paused(true)
	var started: Dictionary = combat.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(started.get("ok", false)), "T0211 formal wave failed to spawn: %s" % started)
	var enemy_ids: Array[String] = combat.get_active_enemy_ids()
	_check(enemy_ids.size() >= 2, "T0211 needs two production enemies")
	if not _failures.is_empty():
		_finish()
		return
	for index in range(2, enemy_ids.size()):
		combat._remove_enemy_from_combat(enemy_ids[index])
	var owner_id := enemy_ids[0]
	var waiter_id := enemy_ids[1]
	var owner_actor := root.get_node_or_null(combat._formal_first_wave_node_paths.get(owner_id, NodePath())) as ActorMotionBody
	var waiter_actor := root.get_node_or_null(combat._formal_first_wave_node_paths.get(waiter_id, NodePath())) as ActorMotionBody
	_check(owner_actor != null and waiter_actor != null, "T0211 production actors missing")
	if not _failures.is_empty():
		_finish()
		return

	var target: Dictionary = combat._make_building_target("front_gate")
	var owner: Dictionary = combat.get_enemy(owner_id)
	var candidates: Array[Dictionary] = combat._get_enemy_attack_position_candidates(owner_id, owner, target)
	_check(candidates.size() == 5, "T0211 front gate did not expose five real attack positions: %s" % [candidates])
	_check(combat._uses_enemy_attack_position_leases(owner_id), "T0211 owner lost formal dynamic-pressure lease mode")
	_check(combat._uses_enemy_attack_position_leases(waiter_id), "T0211 waiter lost formal dynamic-pressure lease mode")
	var chosen: Dictionary = combat._resolve_reachable_enemy_attack_position(owner_id, candidates[2]) if candidates.size() >= 3 else {}
	_check(not chosen.is_empty(), "T0211 center attack position was not reachable")
	if not _failures.is_empty():
		_finish()
		return
	if str(combat._formal_attack_position_policy.get("schema", "")) == "enemy_attack_guidance_zones_v2":
		_set_enemy_position(combat, owner_id, owner_actor, chosen.get("position", Vector3.ZERO))
		var guided: Dictionary = combat._ensure_enemy_attack_position(waiter_id, combat.get_enemy(waiter_id), target, true)
		_check(str(guided.get("attack_position_status", "")) == "guiding", "T0211/T0243 blocked attacker did not receive a density guide: %s" % guided)
		_check(str(guided.get("attack_position_id", "")) != str(chosen.get("slot_id", "")), "T0211/T0243 selected the occupied zone instead of a sparse zone")
		_check((combat._enemy_attack_wait_queues as Dictionary).is_empty(), "T0211/T0243 retained a waiter queue")
		combat.clear_spawned_enemies()
		_finish()
		return

	combat._enemy_attack_position_leases.clear()
	combat._enemy_attack_position_by_enemy.clear()
	combat._enemy_attack_wait_queues.clear()
	combat._enemy_attack_unreachable_until_frame.clear()
	var target_key: String = combat._enemy_attack_target_key(target)
	for index in range(candidates.size()):
		var lease := (candidates[index] as Dictionary).duplicate(true)
		lease["target_key"] = target_key
		if index == 2:
			lease.merge(chosen, true)
			lease["enemy_id"] = owner_id
			lease["status"] = "occupied"
			combat._enemy_attack_position_by_enemy[owner_id] = str(lease.get("slot_id", ""))
		else:
			lease["enemy_id"] = "t0211_reserved_owner_%02d" % index
			lease["status"] = "reserved"
		combat._enemy_attack_position_leases[str(lease.get("slot_id", ""))] = lease

	var owner_position: Vector3 = chosen.get("position", Vector3.ZERO)
	_set_enemy_position(combat, owner_id, owner_actor, owner_position)
	owner = combat.get_enemy(owner_id)
	owner["target"] = combat._decorate_target_with_enemy_attack_position(target, chosen.merged({
		"target_key": target_key,
		"enemy_id": owner_id,
		"status": "occupied"
	}, true))
	owner["current_action"] = "attacking_front_gate"
	combat._active_enemies[owner_id] = owner
	owner_actor.set_motion_paused(true)

	var outward: Vector3 = target.get("facing_direction", Vector3.FORWARD)
	outward.y = 0.0
	outward = outward.normalized() if outward.length_squared() > 0.0001 else Vector3.FORWARD
	var waiter_start := owner_position + outward * 4.0
	_set_enemy_position(combat, waiter_id, waiter_actor, waiter_start)
	var waiter: Dictionary = combat.get_enemy(waiter_id)
	var pre_wait_diagnostics := {
		"uses_leases": combat._uses_enemy_attack_position_leases(waiter_id),
		"target_key": target_key,
		"lease_count": combat._enemy_attack_position_leases.size(),
		"opportunity": combat._preview_enemy_target_opportunity(waiter_id, waiter, target),
		"candidate_conflicts": combat._get_enemy_attack_position_candidates(waiter_id, waiter, target).map(
			func(candidate: Dictionary) -> bool: return combat._is_enemy_attack_position_conflict(target_key, candidate, waiter_id)
		)
	}
	var waiting: Dictionary = combat._ensure_enemy_attack_position(waiter_id, waiter, target, true)
	print("T0211_PRE_WAIT %s" % JSON.stringify(pre_wait_diagnostics))
	_check(str(waiting.get("attack_position_status", "")) == "waiting", "T0211 candidate received a lease instead of waiting: %s" % waiting)
	_check(str(waiting.get("attack_position_wait_target_id", "")) == str(chosen.get("slot_id", "")), "T0211 waiter did not select the real occupied attack position: %s" % waiting)
	_check(str(waiting.get("attack_position_wait_movement_policy", "")) == "pressure_assigned_attack_position", "T0211 pressure movement policy missing: %s" % waiting)
	_check(not combat._enemy_attack_position_by_enemy.has(waiter_id), "T0211 waiter received combat authority before promotion")
	waiter = combat.get_enemy(waiter_id)
	waiter["target"] = waiting
	waiter["current_action"] = "waiting_for_attack_position"
	combat._active_enemies[waiter_id] = waiter
	combat._configure_enemy_attack_wait_avoidance(waiter_id, true)
	combat._ensure_formal_dynamic_pressure_motion(waiter_id, waiting)
	waiter_actor.set_motion_paused(false)
	combat.set_process(false)
	combat.set_physics_process(false)

	var pressure_position: Vector3 = waiting.get("attack_position", waiter_start)
	var start_distance := _horizontal_distance(waiter_start, pressure_position)
	var owner_start := owner_actor.global_position
	for _frame in range(90):
		await physics_frame
	var end_distance := _horizontal_distance(waiter_actor.global_position, pressure_position)
	var owner_displacement := _horizontal_distance(owner_actor.global_position, owner_start)
	var body_clearance := _horizontal_distance(waiter_actor.global_position, owner_actor.global_position)
	var waiter_priority_before_promotion := float(waiter_actor.debug_get_motion_snapshot().get("avoidance_priority", 1.0))
	var owner_priority := float(owner_actor.debug_get_motion_snapshot().get("avoidance_priority", 0.0))
	_check(end_distance < start_distance - 0.75, "T0211 waiter did not advance toward its desired attack position: %.3f -> %.3f" % [start_distance, end_distance])
	_check(owner_displacement <= 0.02, "T0211 waiter displaced the occupied attacker by %.3f m" % owner_displacement)
	_check(body_clearance >= 0.80, "T0211 waiter overlapped the occupied attacker instead of queuing behind it: %.3f m" % body_clearance)
	_check(str(combat.get_enemy(waiter_id).get("attack_cycle_phase", "idle")) == "idle", "T0211 waiter started an attack before promotion")
	_check(waiter_priority_before_promotion < owner_priority, "T0211 waiter did not yield RVO priority to the occupied attacker")

	combat._release_enemy_attack_position(owner_id, "t0211_release_owner")
	var promoted: Dictionary = combat.get_enemy(waiter_id).get("target", {}) as Dictionary
	_check(str(promoted.get("attack_position_status", "")) == "reserved", "T0211 released slot did not promote the waiter: %s" % promoted)
	_check(combat._enemy_attack_position_by_enemy.has(waiter_id), "T0211 promoted waiter did not receive a lease")

	print("T0211_ATTACK_WAIT_PRESSURE_DIAGNOSTICS %s" % JSON.stringify({
		"start_distance": start_distance,
		"end_distance": end_distance,
		"owner_displacement": owner_displacement,
		"body_clearance": body_clearance,
		"waiter_priority_before_promotion": waiter_priority_before_promotion,
		"waiter_priority_after_promotion": waiter_actor.debug_get_motion_snapshot().get("avoidance_priority", -1.0),
		"owner_priority": owner_priority,
		"promoted_slot": str(promoted.get("attack_position_id", ""))
	}))
	combat.clear_spawned_enemies()
	_finish()


func _set_enemy_position(combat: Node, enemy_id: String, actor: Node3D, position: Vector3) -> void:
	actor.global_position = position
	var enemy: Dictionary = combat.get_enemy(enemy_id)
	enemy["position"] = position
	combat._active_enemies[enemy_id] = enemy


func _horizontal_distance(left: Vector3, right: Vector3) -> float:
	return Vector2(left.x, left.z).distance_to(Vector2(right.x, right.z))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0211_ATTACK_WAIT_PRESSURE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
