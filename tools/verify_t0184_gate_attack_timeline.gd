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
	_check(combat_system != null and building_system != null and time_system != null and event_bus != null, "T0184 systems missing")
	if not _failures.is_empty():
		_finish()
		return

	time_system.set_paused(true)
	var started: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(started.get("ok", false)), "T0184 first wave failed to spawn: %s" % started)
	if not bool(started.get("ok", false)):
		_finish()
		return
	var gate: Dictionary = building_system._buildings.get("front_gate", {})
	gate["hp"] = 100000
	gate["max_hp"] = 100000
	building_system._buildings["front_gate"] = gate
	combat_system.debug_step_enemy_ai(0.1)

	var lease_holders: Array[String] = []
	for raw_lease in combat_system.debug_get_enemy_attack_position_snapshot().get("leases", []):
		var lease := raw_lease as Dictionary
		var enemy_id := str(lease.get("enemy_id", ""))
		var actor := combat_system.get_node_or_null(combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
		if actor == null:
			continue
		var attack_position := _to_vector3(lease.get("position", actor.global_position))
		var contact_position := _to_vector3(lease.get("contact_position", attack_position))
		var outward := attack_position - contact_position
		outward.y = 0.0
		outward = outward.normalized() if outward.length_squared() > 0.0001 else Vector3.FORWARD
		actor.cancel_motion("superseded")
		actor.global_position = attack_position + outward * 0.30
		actor.velocity = Vector3.ZERO
		var enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
		enemy["position"] = actor.global_position
		combat_system._active_enemies[enemy_id] = enemy
		lease_holders.append(enemy_id)
	_check(lease_holders.size() == 7, "T0184 expected seven occupied gate attackers, got %d" % lease_holders.size())

	combat_system.debug_step_enemy_ai(0.01)
	if not event_bus.event_recorded.is_connected(_on_event_recorded):
		event_bus.event_recorded.connect(_on_event_recorded)
	var initial_sequences: Dictionary = {}
	var max_elapsed: Dictionary = {}
	for enemy_id in lease_holders:
		var enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
		initial_sequences[enemy_id] = int(enemy.get("attack_sequence", 0))
		max_elapsed[enemy_id] = float(enemy.get("attack_cycle_elapsed", 0.0))

	# Reproduce the real 1:1 runtime as 180 small physics frames. This catches
	# timelines that only work when GM advances them in one coarse step.
	time_system.set_paused(false)
	for _frame in range(180):
		await physics_frame
		for enemy_id in lease_holders:
			var enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
			max_elapsed[enemy_id] = maxf(float(max_elapsed.get(enemy_id, 0.0)), float(enemy.get("attack_cycle_elapsed", 0.0)))

	var diagnostics: Array[Dictionary] = []
	for enemy_id in lease_holders:
		var enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
		var art := {}
		for raw_snapshot in combat_system.debug_get_enemy_art_snapshots():
			if str((raw_snapshot as Dictionary).get("enemy_id", "")) == enemy_id:
				var raw_art: Dictionary = (raw_snapshot as Dictionary).get("art", {})
				art = {
					"state": str(raw_art.get("current_state", "")),
					"clip": str(raw_art.get("current_clip", "")),
					"speed_scale": float(raw_art.get("combat_attack_animation_speed_scale", 0.0)),
					"position": float(raw_art.get("combat_attack_animation_position", -1.0))
				}
				break
		diagnostics.append({
			"enemy_id": enemy_id,
			"phase": str(enemy.get("attack_cycle_phase", "idle")),
			"sequence_before": int(initial_sequences.get(enemy_id, 0)),
			"sequence_after": int(enemy.get("attack_sequence", 0)),
			"max_elapsed": float(max_elapsed.get(enemy_id, 0.0)),
			"damage_committed": _gate_damage_sources.has(enemy_id),
			"art": art
		})
		_check(float(max_elapsed.get(enemy_id, 0.0)) > 0.05, "T0184 attack elapsed did not advance: %s" % diagnostics[-1])
		_check(int(enemy.get("attack_sequence", 0)) > int(initial_sequences.get(enemy_id, 0)), "T0184 attack sequence never completed/restarted: %s" % diagnostics[-1])
		_check(str(art.get("state", "")) == "attack", "T0184 occupied attacker did not play its attack state: %s" % diagnostics[-1])
		_check(float(art.get("speed_scale", 0.0)) > 0.1, "T0184 attack animation remained frozen/near-frozen: %s" % diagnostics[-1])
		_check(_gate_damage_sources.has(enemy_id), "T0184 occupied attacker never damaged gate: %s" % diagnostics[-1])

	_check(int(building_system.get_building("front_gate").get("hp", 100000)) < 100000, "T0184 front gate HP did not decrease: %s" % [diagnostics])
	combat_system.clear_spawned_enemies()
	_finish()


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
		print("T0184_GATE_ATTACK_TIMELINE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
