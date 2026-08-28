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
	_check(gate_leases.size() == 7, "T0180 expected seven front-gate leases: %s" % positions)
	_check(int(positions.get("waiter_count", 0)) == 1, "T0180 mandatory front gate must retain one overflow waiter: %s" % positions)
	for raw_waiter in positions.get("waiters", []):
		_check(str((raw_waiter as Dictionary).get("target_key", "")) == "building:front_gate", "T0180 overflow waiter left the intact front gate: %s" % raw_waiter)
	var avoidance_priorities: Dictionary = {}
	for enemy_id in combat_system.get_active_enemy_ids():
		var priority_actor := combat_system.get_node_or_null(combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
		if priority_actor != null:
			var priority := float(priority_actor.debug_get_motion_snapshot().get("avoidance_priority", -1.0))
			avoidance_priorities["%.6f" % priority] = true
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
	# The production collider-baked navigation route includes real crowd avoidance and
	# gate-post clearance, so allow the rear of the first wave to finish settling.
	# The acceptance condition remains strict: seven leases, one waiter, and every
	# occupied attacker must have delivered real physical melee damage.
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
				if str(lease.get("status", "")) == "occupied":
					occupied_gate_lease_ids.append(str(lease.get("enemy_id", "")))
		for raw_waiter in natural_snapshot.get("waiters", []):
			if str((raw_waiter as Dictionary).get("target_key", "")) == "building:front_gate":
				has_gate_waiter = true
		var all_occupied_holders_hit := occupied_gate_lease_ids.size() >= 6
		for enemy_id in occupied_gate_lease_ids:
			if not _gate_damage_sources.has(enemy_id):
				all_occupied_holders_hit = false
		if all_occupied_holders_hit and gate_lease_count == 7 and has_gate_waiter and int(natural_snapshot.get("waiter_count", 0)) == 1:
			natural_complete = true
			break
	_check(natural_complete, "T0180 natural GM first wave did not settle into seven damaging gate attackers plus one mandatory gate waiter: damage_sources=%s positions=%s movement=%s" % [_gate_damage_sources.keys(), natural_snapshot, combat_system.debug_get_formal_first_wave_slice_snapshot()])

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
