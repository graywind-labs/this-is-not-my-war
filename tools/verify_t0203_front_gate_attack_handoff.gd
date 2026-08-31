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
	var event_bus := root.get_node_or_null("EventBus")
	_check(combat_system != null and building_system != null and time_system != null, "T0203 systems missing")
	if not _failures.is_empty():
		_finish()
		return

	if event_bus != null:
		event_bus.event_recorded.connect(_on_event_recorded)
	var started: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(started.get("ok", false)), "T0203 first wave failed to spawn: %s" % started)
	var gate: Dictionary = building_system._buildings.get("front_gate", {})
	gate["hp"] = 100000
	gate["max_hp"] = 100000
	building_system._buildings["front_gate"] = gate
	time_system.set_paused(false)

	var final_diagnostics: Array[Dictionary] = []
	var all_lease_holders_hit := false
	for frame in range(3600):
		await physics_frame
		if frame % 12 != 0:
			continue
		final_diagnostics = _collect_gate_diagnostics(combat_system)
		if final_diagnostics.size() != 5:
			continue
		all_lease_holders_hit = true
		for diagnostic in final_diagnostics:
			if not bool(diagnostic.get("damaged_gate", false)):
				all_lease_holders_hit = false
				break
		if all_lease_holders_hit:
			break

	_check(
		all_lease_holders_hit,
		"T0203 every leased front-gate attacker must hand off from movement and deal damage: %s" % [final_diagnostics]
	)
	combat_system.clear_spawned_enemies()
	_finish()


func _collect_gate_diagnostics(combat_system: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var positions: Dictionary = combat_system.debug_get_enemy_attack_position_snapshot()
	for raw_lease in positions.get("leases", []):
		var lease := raw_lease as Dictionary
		if str(lease.get("target_key", "")) != "building:front_gate":
			continue
		var enemy_id := str(lease.get("enemy_id", ""))
		var enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
		var target: Dictionary = enemy.get("target", {}) if enemy.get("target", {}) is Dictionary else {}
		var actor := combat_system.get_node_or_null(combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
		var actor_position := actor.global_position if actor != null else _to_vector3(enemy.get("position", Vector3.ZERO))
		var attack_position := _to_vector3(target.get("attack_position", lease.get("position", actor_position)))
		var motion := actor.debug_get_motion_snapshot() if actor != null else {}
		result.append({
			"enemy_id": enemy_id,
			"action": str(enemy.get("current_action", "")),
			"slot_id": str(lease.get("slot_id", "")),
			"lease_status": str(lease.get("status", "")),
			"slot_error": snappedf(_horizontal_distance(actor_position, attack_position), 0.001),
			"damaged_gate": _gate_damage_sources.has(enemy_id),
			"motion_active": bool(motion.get("active", false)),
			"motion_state": str(motion.get("state", "")),
			"motion_result": str(motion.get("last_result", "")),
			"remaining_path_distance": snappedf(float(motion.get("remaining_path_distance", 0.0)), 0.001),
			"minimum_target_distance": snappedf(float(motion.get("minimum_target_distance", 0.0)), 0.001),
			"stuck_seconds": snappedf(float(motion.get("stuck_elapsed_seconds", 0.0)), 0.001),
			"repath_count": int(motion.get("repath_count", 0)),
		})
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("slot_id", "")) < str(right.get("slot_id", "")))
	return result


func _horizontal_distance(left: Vector3, right: Vector3) -> float:
	return Vector2(left.x, left.z).distance_to(Vector2(right.x, right.z))


func _to_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Dictionary:
		return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
	return Vector3.ZERO


func _on_event_recorded(event: Dictionary) -> void:
	if str(event.get("type", "")) != "building_damaged":
		return
	var payload: Dictionary = event.get("payload", {}) if event.get("payload", {}) is Dictionary else {}
	if str(payload.get("building_id", "")) != "front_gate":
		return
	for raw_actor_id in event.get("actor_ids", []):
		_gate_damage_sources[str(raw_actor_id)] = true


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0203_FRONT_GATE_ATTACK_HANDOFF_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
