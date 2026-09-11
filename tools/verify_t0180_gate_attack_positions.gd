extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")

var _failures: PackedStringArray = []
var _gate_damage_sources: Dictionary = {}


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

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(combat_system != null and building_system != null and time_system != null, "T0180 systems missing")
	if not _failures.is_empty():
		_finish()
		return

	time_system.set_paused(true)
	var started: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(started.get("ok", false)), "T0180 first wave failed to spawn: %s" % started)
	if not bool(started.get("ok", false)):
		_finish()
		return
	var gate: Dictionary = building_system._buildings.get("front_gate", {})
	gate["hp"] = 100000
	gate["max_hp"] = 100000
	building_system._buildings["front_gate"] = gate
	combat_system.debug_step_enemy_ai(0.1)

	var positions: Dictionary = combat_system.debug_get_enemy_attack_position_snapshot()
	var gate_leases: Array[Dictionary] = []
	for raw_lease in positions.get("leases", []):
		var lease := raw_lease as Dictionary
		if str(lease.get("target_key", "")) == "building:front_gate":
			gate_leases.append(lease)
	var guided_schema := str(positions.get("schema", "")) == "enemy_attack_guidance_zones_v2"
	var expected_gate_assignments := 8 if guided_schema else 5
	var expected_waiters := 0 if guided_schema else 3
	_check(gate_leases.size() == expected_gate_assignments, "T0180 expected %d front-gate assignments: %s" % [expected_gate_assignments, positions])
	_check(int(positions.get("waiter_count", 0)) == expected_waiters, "T0180 front-gate waiter contract mismatch: %s" % positions)
	for raw_waiter in positions.get("waiters", []):
		_check(str((raw_waiter as Dictionary).get("target_key", "")) == "building:front_gate", "T0180 overflow waiter left the intact front gate: %s" % raw_waiter)
	var avoidance_priorities: Dictionary = {}
	for enemy_id in combat_system.get_active_enemy_ids():
		var priority_actor := combat_system.get_node_or_null(combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
		if priority_actor != null:
			var motion_snapshot: Dictionary = priority_actor.debug_get_motion_snapshot()
			var priority := float(motion_snapshot.get("avoidance_priority", -1.0))
			avoidance_priorities["%.6f" % priority] = true
			var enemy_snapshot: Dictionary = combat_system.get_enemy(enemy_id)
			var target_snapshot: Dictionary = enemy_snapshot.get("target", {}) if enemy_snapshot.get("target", {}) is Dictionary else {}
			if str(target_snapshot.get("id", "")) == "front_gate" and str(enemy_snapshot.get("weapon_type", "")) in ["sword_shield", "polearm"]:
				var dynamic_tolerance := float(target_snapshot.get("attack_guidance_arrival_tolerance", -1.0))
				_check(dynamic_tolerance >= 0.05 and dynamic_tolerance <= 0.08, "T0180 front-gate melee tolerance did not use effective reach slack: enemy=%s tolerance=%.4f target=%s" % [enemy_id, dynamic_tolerance, target_snapshot])
				_check(absf(float(motion_snapshot.get("target_desired_distance", -1.0)) - dynamic_tolerance) <= 0.002, "T0180 ActorMotion did not receive dynamic gate tolerance: enemy=%s motion=%s target=%s" % [enemy_id, motion_snapshot, target_snapshot])
	_check(avoidance_priorities.size() == 8, "T0180 crowded wave lacks stable per-actor RVO tie-breaks: %s" % [avoidance_priorities.keys()])

	var lease_holders: Array[String] = []
	for lease in gate_leases:
		var enemy_id := str(lease.get("enemy_id", ""))
		lease_holders.append(enemy_id)
		var actor := combat_system.get_node_or_null(combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
		_check(actor != null, "T0180 lease holder actor missing: %s" % enemy_id)
		if actor == null:
			continue
		var attack_position := _to_vector3(lease.get("position", actor.global_position))
		var contact_position := _to_vector3(lease.get("contact_position", attack_position))
		var arrival_outward := attack_position - contact_position
		arrival_outward.y = 0.0
		arrival_outward = arrival_outward.normalized() if arrival_outward.length_squared() > 0.0001 else Vector3.FORWARD
		var navigation_arrival_position := attack_position + arrival_outward * 0.30
		actor.cancel_motion("superseded")
		actor.global_position = navigation_arrival_position
		actor.velocity = Vector3.ZERO
		var enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
		enemy["position"] = navigation_arrival_position
		combat_system._active_enemies[enemy_id] = enemy

	# T0243 guidance intentionally re-evaluates crowd density after every body move.
	# Isolate one physical handoff probe here; testing all eight at the former fixed
	# slot centers would itself change occupancy and invalidate those destinations.
	if guided_schema and not lease_holders.is_empty():
		var probe_id := lease_holders[0]
		for index in range(1, lease_holders.size()):
			var remote_id := lease_holders[index]
			var remote_actor := combat_system.get_node_or_null(combat_system._formal_first_wave_node_paths.get(remote_id, NodePath())) as ActorMotionBody
			if remote_actor == null:
				continue
			var remote_position := Vector3(80.0 + float(index) * 3.0, remote_actor.global_position.y, 80.0)
			remote_actor.cancel_motion("superseded")
			remote_actor.global_position = remote_position
			remote_actor.velocity = Vector3.ZERO
			var remote_enemy: Dictionary = combat_system._active_enemies.get(remote_id, {})
			remote_enemy["position"] = remote_position
			combat_system._active_enemies[remote_id] = remote_enemy
		var probe_enemy: Dictionary = combat_system._active_enemies.get(probe_id, {})
		var probe_target: Dictionary = probe_enemy.get("target", {}) if probe_enemy.get("target", {}) is Dictionary else {}
		probe_target = combat_system._ensure_enemy_attack_position(probe_id, probe_enemy, probe_target, true)
		var probe_actor := combat_system.get_node_or_null(combat_system._formal_first_wave_node_paths.get(probe_id, NodePath())) as ActorMotionBody
		if probe_actor != null:
			var probe_contact := _to_vector3(probe_target.get("attack_contact_position", probe_target.get("position", probe_actor.global_position)))
			var probe_center := _to_vector3(probe_target.get("attack_position", probe_contact))
			var probe_outward := probe_center - probe_contact
			probe_outward.y = 0.0
			probe_outward = probe_outward.normalized() if probe_outward.length_squared() > 0.0001 else Vector3.FORWARD
			var probe_handoff := float(probe_target.get("attack_guidance_handoff_range", probe_enemy.get("attack_range", 1.0)))
			var probe_position := probe_contact + probe_outward * probe_handoff * 0.85
			probe_actor.cancel_motion("superseded")
			probe_actor.global_position = probe_position
			probe_actor.velocity = Vector3.ZERO
			probe_enemy["position"] = probe_position
			combat_system._active_enemies[probe_id] = probe_enemy
		lease_holders.clear()
		lease_holders.append(probe_id)

	combat_system.debug_step_enemy_ai(0.1)
	var unlocked: Array[String] = []
	var diagnostics: Array[Dictionary] = []
	for enemy_id in lease_holders:
		var enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
		var target: Dictionary = enemy.get("target", {}) if enemy.get("target", {}) is Dictionary else {}
		var actor := combat_system.get_node_or_null(combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
		var actor_position := actor.global_position if actor != null else _to_vector3(enemy.get("position", Vector3.ZERO))
		var target_position := _to_vector3(target.get("position", actor_position))
		var attack_position := _to_vector3(target.get("attack_position", actor_position))
		var action := str(enemy.get("current_action", ""))
		if action.begins_with("winding_up_") or action.begins_with("attacking_"):
			unlocked.append(enemy_id)
		diagnostics.append({
			"enemy_id": enemy_id,
			"action": action,
			"slot_error": _horizontal_distance(actor_position, attack_position),
			"center_distance": _horizontal_distance(actor_position, target_position),
			"attack_range": float(enemy.get("attack_range", 0.0)),
			"attack_position_id": str(target.get("attack_position_id", "")),
			"contact_position": target.get("attack_contact_position", null)
		})
	_check(unlocked.size() == lease_holders.size(), "T0180 not every occupied front-gate slot unlocked attack: unlocked=%s holders=%s diagnostics=%s" % [unlocked, lease_holders, diagnostics])

	var event_bus := root.get_node_or_null("EventBus")
	if event_bus != null and not event_bus.event_recorded.is_connected(_on_event_recorded):
		event_bus.event_recorded.connect(_on_event_recorded)
	time_system.set_paused(false)
	for _frame in range(600):
		await physics_frame
		if _gate_damage_sources.size() == lease_holders.size():
			break
	var missing_damage_sources: Array[String] = []
	for enemy_id in lease_holders:
		if not _gate_damage_sources.has(enemy_id):
			missing_damage_sources.append(enemy_id)
	_check(missing_damage_sources.is_empty(), "T0180 occupied attackers did not all produce physical gate hits: missing=%s observed=%s" % [missing_damage_sources, _gate_damage_sources.keys()])

	combat_system.clear_spawned_enemies()
	_gate_damage_sources.clear()
	var natural_started: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(natural_started.get("ok", false)), "T0180 natural GM first wave failed to spawn: %s" % natural_started)
	gate = building_system._buildings.get("front_gate", {})
	gate["hp"] = 100000
	gate["max_hp"] = 100000
	building_system._buildings["front_gate"] = gate
	time_system.set_paused(false)
	var natural_complete := false
	var natural_snapshot := {}
	var natural_attackers_seen: Dictionary = {}
	var maximum_stationary_outside_range: Dictionary = {}
	# The production collider-baked navigation route includes real crowd avoidance and
	# gate-post clearance, so allow the rear of the first wave to finish settling.
	# Guidance has no exclusive capacity: all eight must remain guided without a
	# waiter, while natural crowd flow must produce real physical gate damage.
	for _frame in range(2400):
		await physics_frame
		if _frame % 6 != 0:
			continue
		natural_snapshot = combat_system.debug_get_enemy_attack_position_snapshot()
		var gate_lease_count := 0
		var occupied_gate_lease_ids: Array[String] = []
		var has_gate_waiter := false
		for raw_lease in natural_snapshot.get("leases", []):
			var lease := raw_lease as Dictionary
			var target_key := str(lease.get("target_key", ""))
			if target_key == "building:front_gate":
				gate_lease_count += 1
				if str(lease.get("status", "")) == "occupied" or (guided_schema and str(lease.get("status", "")) in ["guiding", "engaging"]):
					occupied_gate_lease_ids.append(str(lease.get("enemy_id", "")))
		for raw_waiter in natural_snapshot.get("waiters", []):
			if str((raw_waiter as Dictionary).get("target_key", "")) == "building:front_gate":
				has_gate_waiter = true
		for enemy_id in combat_system.get_active_enemy_ids():
			var enemy: Dictionary = combat_system.get_enemy(enemy_id)
			var action := str(enemy.get("current_action", ""))
			if action.begins_with("winding_up_front_gate") or action.begins_with("attacking_front_gate") or action.begins_with("recovering_from_front_gate"):
				natural_attackers_seen[enemy_id] = true
			var actor := combat_system.get_node_or_null(combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
			if actor != null and action == "pressing_to_front_gate":
				var stationary_seconds := float(actor.debug_get_motion_snapshot().get("stationary_elapsed_seconds", 0.0))
				maximum_stationary_outside_range[enemy_id] = maxf(float(maximum_stationary_outside_range.get(enemy_id, 0.0)), stationary_seconds)
		var all_occupied_holders_hit := occupied_gate_lease_ids.size() == expected_gate_assignments
		if guided_schema:
			all_occupied_holders_hit = (
				all_occupied_holders_hit
				and natural_attackers_seen.size() == expected_gate_assignments
				and _gate_damage_sources.size() == expected_gate_assignments
			)
		else:
			for enemy_id in occupied_gate_lease_ids:
				if not _gate_damage_sources.has(enemy_id):
					all_occupied_holders_hit = false
		var waiter_contract_ok := (
			not has_gate_waiter and int(natural_snapshot.get("waiter_count", 0)) == 0
			if guided_schema
			else has_gate_waiter and int(natural_snapshot.get("waiter_count", 0)) == 3
		)
		if all_occupied_holders_hit and gate_lease_count == expected_gate_assignments and waiter_contract_ok:
			natural_complete = true
			break
	_check(natural_complete, "T0180 natural GM first wave did not keep %d guided attackers waiter-free while every attacker entered its timeline and produced physical gate damage: attackers=%s damage_sources=%s max_stationary=%s positions=%s movement=%s" % [expected_gate_assignments, natural_attackers_seen.keys(), _gate_damage_sources.keys(), maximum_stationary_outside_range, natural_snapshot, combat_system.debug_get_formal_first_wave_slice_snapshot()])
	if guided_schema and natural_complete:
		var natural_metrics: Dictionary = natural_snapshot.get("metrics", {}) as Dictionary
		_check(int(natural_metrics.get("guidance_stall_recoveries_started", 0)) >= 1, "T0180 natural crowd did not exercise continuous guidance-stall recovery: %s" % natural_metrics)
		_check(int(natural_metrics.get("guidance_stall_recoveries_completed", 0)) >= 1, "T0180 guidance-stall recovery did not complete after movement/range handoff: %s" % natural_metrics)
		_check(int(natural_metrics.get("guidance_stall_reselections", 0)) >= 1, "T0180 stalled attacker never reselected a guidance zone: %s" % natural_metrics)
		for enemy_id in combat_system.get_active_enemy_ids():
			var recovered_actor := combat_system.get_node_or_null(combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
			if recovered_actor != null:
				_check(bool(recovered_actor.debug_get_motion_snapshot().get("runtime_actor_collision_enabled", false)), "T0180 recovery left actor collision disabled: %s" % enemy_id)

	combat_system.clear_spawned_enemies()
	_finish()


func _horizontal_distance(left: Vector3, right: Vector3) -> float:
	return Vector2(left.x, left.z).distance_to(Vector2(right.x, right.z))


func _to_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Dictionary:
		return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
	return Vector3.ZERO


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _on_event_recorded(event: Dictionary) -> void:
	if str(event.get("type", "")) != "building_damaged":
		return
	var payload: Dictionary = event.get("payload", {}) if event.get("payload", {}) is Dictionary else {}
	if str(payload.get("building_id", "")) != "front_gate":
		return
	for raw_actor_id in event.get("actor_ids", []):
		_gate_damage_sources[str(raw_actor_id)] = true


func _finish() -> void:
	if _failures.is_empty():
		print("T0180_GATE_ATTACK_POSITIONS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
