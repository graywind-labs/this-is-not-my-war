extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
# Mounted pickup/mount authority has its own lifecycle regression. This focused
# recovery fixture keeps actors on foot so an assigned horse cannot replace the
# deliberately stalled tactical movement request under test.
const TEST_CASES := [
	{"npc_id": "doctor_01", "mounted": false, "strategy_id": "attack", "x": -5.0},
	{"npc_id": "priest_01", "mounted": false, "strategy_id": "keep_distance", "x": -2.0}
]

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(10):
		await process_frame
		await physics_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	_check(combat_system != null and npc_system != null and equipment_system != null, "T0235 core systems missing")
	if not _failures.is_empty():
		_finish({})
		return

	var preset: Dictionary = equipment_system.debug_apply_combat_loadout_preset()
	_check(bool(preset.get("ok", false)), "T0235 recruit/equip preset failed: %s" % preset)
	var spawn: Dictionary = combat_system.debug_spawn_wave(1, true)
	_check(bool(spawn.get("ok", false)), "T0235 formal wave spawn failed: %s" % spawn)
	for _frame in range(8):
		await physics_frame
	if not _failures.is_empty():
		_finish({"preset": preset, "spawn": spawn})
		return

	var enemy_ids: Array = combat_system.get_active_enemy_ids()
	_check(not enemy_ids.is_empty(), "T0235 active enemy fixture missing")
	if not _failures.is_empty():
		_finish({})
		return
	var enemy_id := str(enemy_ids[0])
	var metrics: Array[Dictionary] = []
	for test_case in TEST_CASES:
		metrics.append(_verify_case(combat_system, npc_system, equipment_system, enemy_id, test_case))

	_finish({"cases": metrics})


func _verify_case(
	combat_system: Node,
	npc_system: Node,
	equipment_system: Node,
	enemy_id: String,
	test_case: Dictionary
) -> Dictionary:
	var npc_id := str(test_case.get("npc_id", ""))
	var mounted := bool(test_case.get("mounted", false))
	var strategy_id := str(test_case.get("strategy_id", "attack"))
	var actor := _get_npc_actor(npc_system, npc_id)
	_check(actor != null, "T0235 NPC actor missing: %s" % npc_id)
	if actor == null:
		return {"npc_id": npc_id}

	var unit: Dictionary = equipment_system.get_unit_type_snapshot(npc_id)
	_check(str(unit.get("unit_type", "")) in ["archer", "crossbowman", "mounted_ranged"], "T0235 fixture is not ranged: %s" % unit)
	var strategy: Dictionary = combat_system.set_npc_combat_strategy(npc_id, strategy_id, "private")
	_check(bool(strategy.get("ok", false)), "T0235 %s strategy failed for %s: %s" % [strategy_id, npc_id, strategy])

	var origin := Vector3(float(test_case.get("x", 0.0)), 0.04, 65.0)
	var enemy_position := Vector3(origin.x, 0.04, 90.0)
	actor.global_position = origin
	_place_enemy(combat_system, enemy_id, enemy_position)
	npc_system.set_npc_behavior_mode(npc_id, "combat", "verify_t0235", {
		"state_changes": {
			"current_action": "combat_ready",
			"combat_target_enemy_id": enemy_id,
			"combat_attack_cooldown": 0.0
		},
		"request_plan_reevaluation": false
	})
	npc_system.stop_npc_movement_with_state(npc_id, {
		"combat_mounted": mounted,
		"combat_mount_phase": "mounted" if mounted else "unmounted",
		"current_action": "combat_ready",
		"combat_target_enemy_id": enemy_id,
		"combat_strategy_move_recovery_count": 0,
		"combat_strategy_last_stall": {}
	})
	actor.global_position = origin

	var state: Dictionary = npc_system.get_npc_state(npc_id)
	var attack_context: Dictionary = combat_system._calculate_npc_attack_context(npc_id, npc_system.get_npc(npc_id), state)
	attack_context["strategy_id"] = strategy_id
	var attack_range := float(attack_context.get("range", 0.0))
	var weapon_id := str(attack_context.get("weapon_id", ""))
	var encounter := _make_encounter(enemy_id, enemy_position, actor.global_position)
	var selected: Dictionary = combat_system._select_ranged_attack_position(npc_id, encounter, attack_range, weapon_id)
	var selected_position: Vector3 = selected.get("position", origin)
	var arrival_tolerance := float(selected.get("target_desired_distance", 0.0))
	var endpoint_distance := _horizontal_distance(selected_position, enemy_position)
	_check(
		endpoint_distance + arrival_tolerance <= attack_range * 0.95 + 0.01,
		"T0235 ranged endpoint did not reserve arrival tolerance for %s: endpoint=%.3f tolerance=%.3f range=%.3f target=%s" % [npc_id, endpoint_distance, arrival_tolerance, attack_range, selected]
	)
	_check(bool(selected.get("line_of_fire_clear", false)), "T0235 open-road attack point has no clear attack line: %s" % selected)
	var outward := selected_position - enemy_position
	outward.y = 0.0
	if outward.length() <= 0.001:
		outward = Vector3.BACK
	else:
		outward = outward.normalized()
	actor.global_position = selected_position + outward * arrival_tolerance
	npc_system.stop_npc_movement_with_state(npc_id, {
		"current_action": "combat_ready",
		"combat_target_enemy_id": enemy_id,
		"combat_attack_cooldown": 0.0,
		"combat_attack_next_sequence_time": 0.0,
		"combat_attack_phase": "idle",
		"combat_attack_target_enemy_id": ""
	})
	var handoff_result: Dictionary = combat_system._advance_single_npc_combat_attack(npc_id, 0.1)
	var handoff_state: Dictionary = npc_system.get_npc_state(npc_id)
	_check(not handoff_result.is_empty(), "T0235 arrival-edge combat step returned no result: %s" % npc_id)
	_check(
		str(handoff_state.get("current_action", "")).begins_with("winding_up_")
			or str(handoff_state.get("current_action", "")).begins_with("attacking_"),
		"T0235 arrival edge did not hand off to attack for %s: result=%s state=%s" % [npc_id, handoff_result, handoff_state]
	)
	_check(not npc_system.is_npc_world_movement_active(npc_id), "T0235 attack handoff left movement authority active: %s" % npc_id)
	actor.global_position = origin
	npc_system.stop_npc_movement_with_state(npc_id, {
		"combat_mounted": mounted,
		"combat_mount_phase": "mounted" if mounted else "unmounted",
		"current_action": "combat_ready",
		"combat_target_enemy_id": enemy_id,
		"combat_attack_cooldown": 0.0,
		"combat_attack_next_sequence_time": 0.0,
		"combat_attack_phase": "idle",
		"combat_attack_target_enemy_id": ""
	})
	state = npc_system.get_npc_state(npc_id)

	var started: Dictionary = combat_system._advance_npc_combat_strategy_movement(
		npc_id,
		state,
		attack_context,
		{},
		encounter
	)
	state = npc_system.get_npc_state(npc_id)
	var first_target := _dict_to_v3(state.get("combat_strategy_move_target_position", {}))
	_check(bool(started.get("ok", false)), "T0235 tactical approach did not start for %s: %s" % [npc_id, started])
	_check(npc_system.is_npc_world_movement_active(npc_id), "T0235 physical movement inactive after approach start: %s" % npc_id)
	_check(str(state.get("current_action", "")).begins_with("moving_to_combat_strategy_"), "T0235 tactical movement state missing: %s" % state)

	actor.set("_stationary_elapsed_seconds", 3.0)
	var moved_target := first_target + Vector3(0.6, 0.0, 0.0)
	var target_updated: bool = bool(npc_system.update_npc_world_movement_target(npc_id, moved_target, {
		"combat_strategy_move_target_position": _v3_to_dict(moved_target)
	}))
	var progress_after_update: Dictionary = npc_system.get_npc_world_movement_progress(npc_id)
	_check(target_updated, "T0235 moving-target fixture failed to update endpoint: %s" % npc_id)
	_check(
		float(progress_after_update.get("stationary_elapsed_seconds", 0.0)) >= 3.0,
		"T0235 target update erased physical no-movement evidence: %s" % progress_after_update
	)

	state = npc_system.get_npc_state(npc_id)
	encounter = _make_encounter(enemy_id, enemy_position, actor.global_position)
	var recovered: Dictionary = combat_system._advance_npc_combat_strategy_movement(
		npc_id,
		state,
		attack_context,
		{},
		encounter
	)
	var recovered_state: Dictionary = npc_system.get_npc_state(npc_id)
	var recovered_target := _dict_to_v3(recovered_state.get("combat_strategy_move_target_position", {}))
	var target_separation := _horizontal_distance(moved_target, recovered_target)
	_check(str(recovered.get("reason", "")) == "combat_strategy_stalled_position_reselected", "T0235 active-but-stuck request was not recovered: %s" % recovered)
	_check(int(recovered_state.get("combat_strategy_move_recovery_count", 0)) == 1, "T0235 recovery count mismatch: %s" % recovered_state)
	_check(target_separation >= 0.79, "T0235 recovery reused the stalled attack point for %s: separation=%.3f" % [npc_id, target_separation])
	_check(npc_system.is_npc_world_movement_active(npc_id), "T0235 replacement tactical movement inactive: %s" % npc_id)

	npc_system.stop_npc_movement_with_state(npc_id, {
		"current_action": "combat_ready",
		"combat_target_enemy_id": enemy_id
	})
	return {
		"npc_id": npc_id,
		"mounted": mounted,
		"strategy_id": strategy_id,
		"weapon_id": weapon_id,
		"attack_range": attack_range,
		"endpoint_distance": endpoint_distance,
		"arrival_tolerance": arrival_tolerance,
		"target_separation": target_separation,
		"recovery_count": int(recovered_state.get("combat_strategy_move_recovery_count", 0))
	}


func _place_enemy(combat_system: Node, enemy_id: String, position: Vector3) -> void:
	var active_enemies: Dictionary = combat_system.get("_active_enemies")
	var enemy: Dictionary = active_enemies.get(enemy_id, {})
	enemy["position"] = position
	enemy["move_speed"] = 0.0
	enemy["alive"] = true
	active_enemies[enemy_id] = enemy
	combat_system.set("_active_enemies", active_enemies)
	combat_system._refresh_enemy_node(enemy_id)


func _make_encounter(enemy_id: String, enemy_position: Vector3, npc_position: Vector3) -> Dictionary:
	return {
		"id": enemy_id,
		"enemy_id": enemy_id,
		"name": enemy_id,
		"enemy_name": enemy_id,
		"position": enemy_position,
		"distance": _horizontal_distance(npc_position, enemy_position)
	}


func _get_npc_actor(npc_system: Node, npc_id: String) -> Node3D:
	var paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(paths.get(npc_id, NodePath(""))) as Node3D


func _dict_to_v3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if not value is Dictionary:
		return Vector3.ZERO
	var data := value as Dictionary
	return Vector3(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("z", 0.0)))


func _v3_to_dict(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


func _horizontal_distance(left: Vector3, right: Vector3) -> float:
	return Vector2(left.x, left.z).distance_to(Vector2(right.x, right.z))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish(metrics: Dictionary) -> void:
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	if combat_system != null and combat_system.has_method("debug_clear_enemies"):
		combat_system.debug_clear_enemies()
	if _failures.is_empty():
		print("T0235_FRIENDLY_RANGED_TACTICAL_RECOVERY_OK %s" % JSON.stringify(metrics))
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0235_FRIENDLY_RANGED_TACTICAL_RECOVERY_FAILED %s" % JSON.stringify(metrics))
	quit(1)
