extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const NPC_ID := "cook_01"

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
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
	_check(combat_system != null and npc_system != null and time_system != null, "T0226 core systems missing")
	if not _failures.is_empty():
		_finish()
		return
	time_system.set_paused(true)

	var spawned: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(spawned.get("ok", false)), "T0226 formal enemy fixture failed: %s" % spawned)
	var enemy_ids: Array[String] = combat_system.get_active_enemy_ids()
	_check(not enemy_ids.is_empty(), "T0226 active enemy missing")
	if not _failures.is_empty():
		_finish()
		return
	for index in range(1, enemy_ids.size()):
		combat_system._remove_enemy_from_combat(enemy_ids[index])
	var enemy_id := enemy_ids[0]
	var origin := Vector3(0.0, 0.0, 10.0)
	_set_npc_position(npc_system, NPC_ID, origin)
	_set_enemy_position(combat_system, enemy_id, origin + Vector3(10.0, 0.0, 0.0))
	npc_system.set_npc_behavior_mode(NPC_ID, "work", "t0226_fixture", {
		"force_idle": true,
		"request_plan_reevaluation": false
	})
	combat_system._active_avoidances.erase(NPC_ID)
	combat_system._advance_behavior_mode_contacts()
	await process_frame

	var actor := _get_npc_node(npc_system, NPC_ID)
	var started := _find_avoidance(combat_system.get_active_avoidances(), NPC_ID)
	var committed_target := _to_vector3(started.get("target_position", {}))
	_check(str(npc_system.get_npc_behavior_mode_snapshot(NPC_ID).get("behavior_mode", "")) == "avoid_combat", "T0226 NPC did not enter avoid_combat")
	_check(actor != null and npc_system.is_npc_world_movement_active(NPC_ID), "T0226 initial avoidance motion missing")

	# Reproduce the reported stale-state case: the physical request is gone, but
	# NPC state still says moving_to_avoid_shelter_*. The old updater trusted only
	# that string and therefore never issued another movement request.
	if actor != null:
		actor.stop_movement()
	var stale_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	_check(str(stale_state.get("current_action", "")).begins_with("moving_to_avoid_shelter_"), "T0226 fixture lost stale movement label")
	_check(not npc_system.is_npc_world_movement_active(NPC_ID), "T0226 fixture failed to interrupt physical motion")
	combat_system._advance_avoidance_units()
	await process_frame
	var recovered_with_threat := _find_avoidance(combat_system.get_active_avoidances(), NPC_ID)
	_check(npc_system.is_npc_world_movement_active(NPC_ID), "T0226 did not recover interrupted avoidance while threat remained")
	_check(int(recovered_with_threat.get("movement_recovery_count", 0)) == 1, "T0226 recovery count missing after current-threat recovery: %s" % recovered_with_threat)
	_check(str(recovered_with_threat.get("last_movement_recovery_reason", "")) == "avoidance_movement_recovered", "T0226 current-threat recovery reason mismatch: %s" % recovered_with_threat)

	# Once a leg has been committed, losing the threat at the edge of the radius
	# must not make an interrupted NPC freeze halfway to the safe/re-entry point.
	if actor != null:
		actor.stop_movement()
	_set_enemy_position(combat_system, enemy_id, origin + Vector3(100.0, 0.0, 0.0))
	combat_system._advance_avoidance_units()
	await process_frame
	var recovered_without_threat := _find_avoidance(combat_system.get_active_avoidances(), NPC_ID)
	var restored_target := _to_vector3(recovered_without_threat.get("target_position", {}))
	_check(npc_system.is_npc_world_movement_active(NPC_ID), "T0226 did not restore committed avoidance leg after threat left range")
	_check(int(recovered_without_threat.get("movement_recovery_count", 0)) == 2, "T0226 no-threat recovery count mismatch: %s" % recovered_without_threat)
	_check(str(recovered_without_threat.get("last_movement_recovery_reason", "")) == "avoidance_movement_recovered_without_current_threat", "T0226 no-threat recovery reason mismatch: %s" % recovered_without_threat)
	_check(restored_target.distance_to(committed_target) <= 0.01, "T0226 no-threat recovery changed committed destination: %s -> %s" % [committed_target, restored_target])

	var before_motion: Vector3 = npc_system.get_npc_world_position(NPC_ID)
	time_system.set_paused(false)
	for _frame in range(90):
		await physics_frame
	time_system.set_paused(true)
	var after_motion: Vector3 = npc_system.get_npc_world_position(NPC_ID)
	_check(after_motion.distance_to(before_motion) > 0.25, "T0226 recovered request did not produce physical displacement: %s -> %s" % [before_motion, after_motion])

	print("T0226_AVOIDANCE_MOTION_RECOVERY_DIAGNOSTICS %s" % JSON.stringify({
		"started": started,
		"recovered_with_threat": recovered_with_threat,
		"recovered_without_threat": recovered_without_threat,
		"position_before": before_motion,
		"position_after": after_motion
	}))
	combat_system.clear_spawned_enemies()
	_finish()


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
		_failures.append("T0226 NPC actor missing: %s" % npc_id)
		return
	if actor.has_method("stop_movement"):
		actor.stop_movement()
	actor.global_position = position


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(paths.get(npc_id, NodePath("")))


func _find_avoidance(avoidances: Array[Dictionary], npc_id: String) -> Dictionary:
	for avoidance in avoidances:
		if str(avoidance.get("npc_id", "")) == npc_id:
			return avoidance
	return {}


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
		print("T0226_AVOIDANCE_MOTION_RECOVERY_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
