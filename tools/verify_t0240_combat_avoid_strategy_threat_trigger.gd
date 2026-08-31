extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const NPC_ID := "veteran_deputy_01"

var _failures: PackedStringArray = []


func _init() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(8):
		await process_frame
		await physics_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var formal_layout := root.get_node_or_null("Main/WorldRoot/FormalStationLayout") as Node3D
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	_check(combat_system != null and npc_system != null and time_system != null and formal_layout != null and memory_system != null, "T0240 core systems missing")
	if not _failures.is_empty():
		_finish()
		return
	time_system.set_paused(true)

	var spawned: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(spawned.get("ok", false)), "T0240 formal wave fixture failed: %s" % spawned)
	var enemy_ids: Array[String] = combat_system.get_active_enemy_ids()
	_check(enemy_ids.size() >= 3, "T0240 requires at least three active enemies")
	if not _failures.is_empty():
		_finish()
		return

	var origin := formal_layout.to_global(Vector3(0.0, 0.0, 0.0))
	var far_locked_id := enemy_ids[0]
	var near_id := enemy_ids[1]
	var flank_id := enemy_ids[2]
	_set_npc_position(npc_system, NPC_ID, origin)
	_set_enemy_position(combat_system, far_locked_id, origin + Vector3(0.0, 0.0, 12.0))
	_set_enemy_position(combat_system, near_id, origin + Vector3(3.0, 0.0, 0.0))
	_set_enemy_position(combat_system, flank_id, origin + Vector3(4.0, 0.0, 4.0))
	for index in range(3, enemy_ids.size()):
		_set_enemy_position(combat_system, enemy_ids[index], origin + Vector3(120.0 + float(index), 0.0, 120.0))

	npc_system.set_npc_behavior_mode(NPC_ID, "combat", "t0240_far_lock_near_threat", {
		"state_changes": {
			"current_action": "combat_ready",
			"combat_target_enemy_id": far_locked_id,
			"combat_attack_phase": "idle",
			"combat_attack_cooldown": 0.0,
			"combat_mounted": false,
			"combat_mount_phase": "unmounted"
		},
		"request_plan_reevaluation": false
	})
	npc_system.stop_npc_movement_with_state(NPC_ID, {
		"current_action": "combat_ready",
		"combat_target_enemy_id": far_locked_id,
		"combat_mounted": false,
		"combat_mount_phase": "unmounted"
	})
	var strategy_result: Dictionary = combat_system.set_npc_combat_strategy(NPC_ID, "avoid", "private", "t0240_fixture")
	_check(bool(strategy_result.get("ok", false)), "T0240 could not select avoid strategy")
	var enemy_hp_before := _enemy_hp_snapshot(combat_system, [far_locked_id, near_id, flank_id])
	var avoid_result: Dictionary = combat_system._advance_single_npc_combat_attack(NPC_ID, 1.0)
	var avoid_movement: Dictionary = avoid_result.get("strategy_movement", {})
	var avoid_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	var avoid_direction := _to_vector3(avoid_state.get("combat_strategy_avoid_direction", {}))
	_check(str(avoid_state.get("current_action", "")).begins_with("moving_to_combat_strategy_avoid_"), "T0240 near threat did not start combat avoidance: %s" % avoid_state)
	_check(str(avoid_state.get("combat_target_enemy_id", "")) == far_locked_id, "T0240 avoidance movement overwrote the durable combat target lock")
	_check(str(avoid_state.get("combat_strategy_move_enemy_id", "")) == near_id, "T0240 avoidance trigger did not use the nearest actual threat: %s" % avoid_state)
	_check(int(avoid_state.get("combat_strategy_avoid_threat_count", 0)) == 3, "T0240 weighted threat field did not include all in-range enemies: %s" % avoid_state)
	_check(avoid_direction.dot(Vector3.LEFT) > 0.55, "T0240 weighted avoidance direction was not dominated by the nearest east-side enemy: %s" % avoid_direction)
	_check(str(avoid_state.get("behavior_mode", "")) == "combat", "T0240 combat avoidance incorrectly left combat behavior mode")
	_check(_enemy_hp_snapshot(combat_system, [far_locked_id, near_id, flank_id]) == enemy_hp_before, "T0240 combat avoidance dealt attack damage")
	_check(str(avoid_movement.get("enemy_id", "")) == near_id and int(avoid_movement.get("threat_count", 0)) == 3, "T0240 movement result did not expose nearest/all-threat evidence: %s" % avoid_movement)
	await process_frame
	var npc_actor := _get_npc_node(npc_system, NPC_ID)
	var status_label := npc_actor.get_node_or_null("StatusLabel") as Label3D if npc_actor != null else null
	_check(status_label != null and status_label.text.contains("正在避战"), "T0240 moving combat avoidance still displays as generic engagement: %s" % (status_label.text if status_label != null else "missing"))
	_check(str(memory_system._format_action_status(str(avoid_state.get("current_action", "")))) == "正在避战", "T0240 location action summary does not identify moving avoidance")

	# Reproduce switching from a live attack movement to avoidance. Selection must
	# stop the old request immediately; the next combat decision authors a fresh
	# weighted avoidance leg instead of treating the approach as already avoiding.
	if npc_actor != null and npc_actor.has_method("stop_movement"):
		npc_actor.stop_movement()
	combat_system.set_npc_combat_strategy(NPC_ID, "attack", "private", "t0240_old_move_fixture")
	npc_system.stop_npc_movement_with_state(NPC_ID, {
		"current_action": "combat_ready",
		"combat_target_enemy_id": far_locked_id
	})
	var old_attack_target := origin + Vector3(0.0, 0.0, 6.0)
	var old_move_started := bool(npc_system.move_npc_to_world_position(
		NPC_ID,
		"combat_strategy_attack_t0240",
		"旧进攻移动",
		old_attack_target,
		{"current_action": "combat_ready", "combat_target_enemy_id": far_locked_id},
		{}
	))
	_check(old_move_started and npc_system.is_npc_world_movement_active(NPC_ID), "T0240 could not establish old attack movement fixture")
	var switch_result: Dictionary = combat_system.set_npc_combat_strategy(NPC_ID, "avoid", "private", "t0240_switch")
	var after_switch: Dictionary = npc_system.get_npc_state(NPC_ID)
	_check(bool(switch_result.get("ok", false)) and not npc_system.is_npc_world_movement_active(NPC_ID), "T0240 selecting avoid did not cancel the old strategy motion")
	_check(str(after_switch.get("last_action_result", "")) == "combat_strategy_changed_to_avoid", "T0240 old strategy cancellation reason missing: %s" % after_switch)
	var switched_result: Dictionary = combat_system._advance_single_npc_combat_attack(NPC_ID, 1.0)
	var switched_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	_check(str(switched_state.get("current_action", "")).begins_with("moving_to_combat_strategy_avoid_"), "T0240 did not replace old attack motion with avoidance in the next combat decision")
	_check(str(switched_state.get("combat_strategy_move_strategy_id", "")) == "avoid", "T0240 replacement movement lacks avoid strategy identity")
	_check(_to_vector3(switched_state.get("combat_strategy_move_target_position", {})).distance_to(old_attack_target) > 0.8, "T0240 avoidance reused the old attack destination")
	_check(str((switched_result.get("strategy_movement", {}) as Dictionary).get("enemy_id", "")) == near_id, "T0240 switched avoidance did not use nearest threat")

	# Physical cancellation must recover the exact committed avoidance endpoint.
	var committed_target := _to_vector3(switched_state.get("combat_strategy_move_target_position", {}))
	if npc_actor != null and npc_actor.has_method("stop_movement"):
		npc_actor.stop_movement()
	_check(not npc_system.is_npc_world_movement_active(NPC_ID), "T0240 stale avoidance fixture still has physical movement")
	var recovered_result: Dictionary = combat_system._advance_single_npc_combat_attack(NPC_ID, 1.0)
	var recovered_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	var recovered_target := _to_vector3(recovered_state.get("combat_strategy_move_target_position", {}))
	_check(npc_system.is_npc_world_movement_active(NPC_ID), "T0240 interrupted combat avoidance was not recovered")
	_check(recovered_target.distance_to(committed_target) <= 0.01, "T0240 recovery changed the committed avoidance endpoint: %s -> %s" % [committed_target, recovered_target])
	_check(int(recovered_state.get("combat_strategy_avoid_movement_recovery_count", 0)) == 1, "T0240 avoidance recovery count missing: %s" % recovered_state)
	_check(str((recovered_result.get("strategy_movement", {}) as Dictionary).get("reason", "")) == "combat_strategy_avoid_movement_recovered", "T0240 avoidance recovery reason missing")
	combat_system._settle_combat_strategy_move_handoff(
		NPC_ID,
		"avoid",
		{"enemy_id": near_id},
		"t0240_arrival_lock_fixture"
	)
	var arrived_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	_check(str(arrived_state.get("combat_target_enemy_id", "")) == far_locked_id, "T0240 completed avoidance leg overwrote the durable combat target lock")

	# Once every actual threat is outside the safe threshold, avoidance remains in
	# combat mode but becomes an explicit avoidance hold instead of "engaging".
	_set_enemy_position(combat_system, far_locked_id, origin + Vector3(0.0, 0.0, 12.0))
	_set_enemy_position(combat_system, near_id, origin + Vector3(12.0, 0.0, 0.0))
	_set_enemy_position(combat_system, flank_id, origin + Vector3(10.0, 0.0, 10.0))
	var hold_result: Dictionary = combat_system._advance_single_npc_combat_attack(NPC_ID, 1.0)
	var hold_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	_check(str(hold_state.get("current_action", "")) == "combat_strategy_avoid_holding", "T0240 safe avoidance still displays combat_ready: %s" % hold_state)
	_check(not npc_system.is_npc_world_movement_active(NPC_ID), "T0240 safe avoidance did not stop movement")
	_check(str(hold_state.get("behavior_mode", "")) == "combat", "T0240 avoidance hold left combat behavior mode")
	_check(bool((hold_result.get("strategy_movement", {}) as Dictionary).get("holding", false)), "T0240 avoidance hold result missing")
	await process_frame
	_check(status_label != null and status_label.text.contains("避战待命"), "T0240 safe avoidance still displays 接敌: %s" % (status_label.text if status_label != null else "missing"))
	_check(str(memory_system._format_action_status("combat_strategy_avoid_holding")) == "避战待命", "T0240 location summary does not identify avoidance hold")

	print("T0240_COMBAT_AVOID_STRATEGY_THREAT_TRIGGER_OK %s" % JSON.stringify({
		"durable_lock": far_locked_id,
		"nearest_trigger": near_id,
		"threat_count": avoid_state.get("combat_strategy_avoid_threat_count", 0),
		"recovery_count": recovered_state.get("combat_strategy_avoid_movement_recovery_count", 0),
		"moving_label": "正在避战",
		"holding_label": "避战待命"
	}))
	combat_system.clear_spawned_enemies()
	_finish()


func _enemy_hp_snapshot(combat_system: Node, enemy_ids: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for enemy_id in enemy_ids:
		result[enemy_id] = int(combat_system.get_enemy(enemy_id).get("hp", 0))
	return result


func _set_enemy_position(combat_system: Node, enemy_id: String, position: Vector3) -> void:
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	enemy["position"] = position
	enemy["alive"] = true
	enemy["hp"] = maxi(10000, int(enemy.get("hp", 0)))
	enemy["max_hp"] = maxi(10000, int(enemy.get("max_hp", 0)))
	combat_system._active_enemies[enemy_id] = enemy
	var actor_path: NodePath = combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())
	var actor := combat_system.get_node_or_null(actor_path) as Node3D
	if actor != null:
		actor.global_position = position
	combat_system._refresh_enemy_node(enemy_id)


func _set_npc_position(npc_system: Node, npc_id: String, position: Vector3) -> void:
	var actor := _get_npc_node(npc_system, npc_id) as Node3D
	if actor == null:
		_failures.append("T0240 NPC actor missing: %s" % npc_id)
		return
	if actor.has_method("stop_movement"):
		actor.stop_movement()
	actor.global_position = position


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(paths.get(npc_id, NodePath("")))


func _to_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Dictionary:
		return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
	return Vector3.ZERO


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
