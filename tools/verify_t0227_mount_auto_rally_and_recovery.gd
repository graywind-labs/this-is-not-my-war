extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const NPC_ID := "veteran_deputy_01"
const OUTSIDE_CONTACT_ORIGIN := Vector3(0.0, 0.0, 72.0)
const OUTSIDE_CONTACT_ENEMY := Vector3(0.0, 0.0, 82.0)
const PARKED_ENEMY_POSITION := Vector3(0.0, 0.0, 160.0)
const MAX_MOUNT_FRAMES := 3000
const MAX_GATE_FRAMES := 2400
const MAX_RALLY_FRAMES := 2400

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
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var gate_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/WallsAndGates/FrontGate") as Node3D
	_check(combat_system != null and npc_system != null and horse_system != null, "T0227 core systems missing")
	_check(time_system != null and gate_root != null, "T0227 time system or front gate missing")
	if not _failures.is_empty():
		_finish({})
		return
	time_system.set_paused(false)

	var horse_ids: Array = horse_system.get_horse_ids()
	_check(not horse_ids.is_empty(), "T0227 requires an initial horse")
	if not _failures.is_empty():
		_finish({})
		return
	var horse_id := str(horse_ids[0])
	npc_system.set_npc_behavior_mode(NPC_ID, "work", "t0227_reset", {"force_idle": true})
	var assignment: Dictionary = horse_system.assign_horse_to_npc(NPC_ID, horse_id, "private")
	_check(bool(assignment.get("ok", false)), "T0227 horse assignment failed: %s" % assignment)

	var spawned: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(spawned.get("ok", false)), "T0227 enemy fixture failed: %s" % spawned)
	var enemy_ids: Array[String] = combat_system.get_active_enemy_ids()
	_check(not enemy_ids.is_empty(), "T0227 active enemy missing")
	if not _failures.is_empty():
		_finish({})
		return
	for index in range(1, enemy_ids.size()):
		combat_system._remove_enemy_from_combat(enemy_ids[index])
	var enemy_id := enemy_ids[0]
	_set_npc_position(npc_system, NPC_ID, OUTSIDE_CONTACT_ORIGIN)
	_set_enemy_position(combat_system, enemy_id, OUTSIDE_CONTACT_ENEMY)
	combat_system._advance_behavior_mode_contacts()
	var contact_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	_check(str(contact_state.get("behavior_mode", "")) == "combat", "T0227 direct contact did not enter combat: %s" % contact_state)
	_check(str(contact_state.get("combat_mount_phase", "")) == "going_to_stable_horse", "T0227 direct contact did not start stable pickup: %s" % contact_state)

	# Keep the original contact alive but outside the mounted rider's legal scope.
	# This proves mount completion supplies a rally command instead of depending on
	# the old encounter lock or on an earlier alarm reservation.
	_set_enemy_position(combat_system, enemy_id, PARKED_ENEMY_POSITION)
	var mounted := false
	var auto_rally: Dictionary = {}
	for _frame in range(MAX_MOUNT_FRAMES):
		await physics_frame
		_set_enemy_position(combat_system, enemy_id, PARKED_ENEMY_POSITION)
		var state: Dictionary = npc_system.get_npc_state(NPC_ID)
		if bool(state.get("combat_mounted", false)):
			mounted = true
			auto_rally = _find_rally(combat_system.get_active_rallies(), NPC_ID)
			if str(auto_rally.get("status", "")) == "moving":
				break
	_check(mounted, "T0227 direct-contact rider never mounted")
	_check(str(npc_system.get_npc_state(NPC_ID).get("behavior_mode", "")) == "rally", "T0227 newly mounted rider did not receive automatic rally mode")
	_check(str(auto_rally.get("command_reason", "")) == "horse_mounted_auto_rally", "T0227 automatic rally reason missing: %s" % auto_rally)
	_check(str(auto_rally.get("formation_row", "")).begins_with("cavalry_"), "T0227 automatic rally did not reserve a cavalry wing: %s" % auto_rally)
	_check(npc_system.is_npc_world_movement_active(NPC_ID), "T0227 automatic rally navigation is inactive")
	if not _failures.is_empty():
		_finish({"contact_state": contact_state, "auto_rally": auto_rally})
		return

	var actor := _get_npc_node(npc_system, NPC_ID) as Node3D
	var gate_approach_observed := false
	for _frame in range(MAX_GATE_FRAMES):
		await physics_frame
		_set_enemy_position(combat_system, enemy_id, PARKED_ENEMY_POSITION)
		if actor != null and actor.global_position.distance_to(gate_root.global_position) <= 6.0:
			var rally_target := _to_vector3(auto_rally.get("position", {}))
			if actor.global_position.distance_to(rally_target) > 1.0:
				gate_approach_observed = true
				break
	_check(gate_approach_observed, "T0227 rider never reached the front-gate approach before rally point")
	if not _failures.is_empty():
		_finish({"auto_rally": auto_rally})
		return

	# Reproduce the user's door freeze: preserve the moving_to_* state label while
	# dropping the physical request before the reserved point.
	actor.stop_movement()
	var interrupted_position := actor.global_position
	var stale_action := str(npc_system.get_npc_state(NPC_ID).get("current_action", ""))
	_check(stale_action.begins_with("moving_to_combat_rally_"), "T0227 fixture lost stale rally action: %s" % stale_action)
	_check(not npc_system.is_npc_world_movement_active(NPC_ID), "T0227 fixture failed to interrupt rally navigation")
	combat_system._advance_rally_units(0.0)
	var recovered_rally := _find_rally(combat_system.get_active_rallies(), NPC_ID)
	_check(npc_system.is_npc_world_movement_active(NPC_ID), "T0227 rally updater did not restore interrupted gate navigation")
	_check(int(recovered_rally.get("movement_recovery_count", 0)) == 1, "T0227 rally recovery count mismatch: %s" % recovered_rally)
	_check(str(recovered_rally.get("last_movement_recovery_reason", "")) == "rally_movement_recovered", "T0227 rally recovery reason mismatch: %s" % recovered_rally)

	var rallied := false
	var rally_position := _to_vector3(recovered_rally.get("position", {}))
	for _frame in range(MAX_RALLY_FRAMES):
		await physics_frame
		_set_enemy_position(combat_system, enemy_id, PARKED_ENEMY_POSITION)
		var rally := _find_rally(combat_system.get_active_rallies(), NPC_ID)
		var raw_position: Variant = npc_system.get_npc_world_position(NPC_ID)
		var npc_position: Vector3 = raw_position if raw_position is Vector3 else Vector3.ZERO
		if str(rally.get("status", "")) == "rallied" and npc_position.distance_to(rally_position) <= 0.35:
			rallied = true
			break
	_check(rallied, "T0227 recovered rider did not reach reserved rally point")

	# The supplementary command still uses the ordinary encounter handoff.
	var final_position: Vector3 = npc_system.get_npc_world_position(NPC_ID)
	_set_enemy_position(combat_system, enemy_id, final_position + Vector3(0.0, 0.0, 10.0))
	combat_system._advance_rally_units(0.0)
	var combat_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	_check(str(combat_state.get("behavior_mode", "")) == "combat", "T0227 rallied rider did not enter combat on contact: %s" % combat_state)
	_check(str(combat_state.get("combat_target_enemy_id", "")) == enemy_id, "T0227 rally encounter did not lock the enemy: %s" % combat_state)

	_finish({
		"contact_state": contact_state,
		"auto_rally": auto_rally,
		"interrupted_position": interrupted_position,
		"recovered_rally": recovered_rally,
		"rally_position": rally_position,
		"final_position": final_position,
		"combat_target_enemy_id": str(combat_state.get("combat_target_enemy_id", ""))
	})


func _set_enemy_position(combat_system: Node, enemy_id: String, position: Vector3) -> void:
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	enemy["position"] = position
	enemy["alive"] = true
	enemy["hp"] = maxi(10000, int(enemy.get("hp", 0)))
	enemy["max_hp"] = maxi(10000, int(enemy.get("max_hp", 0)))
	enemy["target"] = {}
	combat_system._active_enemies[enemy_id] = enemy
	var actor_path: NodePath = combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())
	var actor := combat_system.get_node_or_null(actor_path) as Node3D
	if actor != null:
		if actor.has_method("stop_movement"):
			actor.stop_movement()
		actor.global_position = position
	combat_system._refresh_enemy_node(enemy_id)


func _set_npc_position(npc_system: Node, npc_id: String, position: Vector3) -> void:
	var actor := _get_npc_node(npc_system, npc_id) as Node3D
	if actor == null:
		_failures.append("T0227 NPC actor missing: %s" % npc_id)
		return
	if actor.has_method("stop_movement"):
		actor.stop_movement()
	actor.global_position = position


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(paths.get(npc_id, NodePath("")))


func _find_rally(entries: Array, npc_id: String) -> Dictionary:
	for raw_entry in entries:
		if raw_entry is Dictionary and str((raw_entry as Dictionary).get("npc_id", "")) == npc_id:
			return (raw_entry as Dictionary).duplicate(true)
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


func _finish(metrics: Dictionary) -> void:
	if _failures.is_empty():
		print("T0227_MOUNT_AUTO_RALLY_AND_RECOVERY_OK %s" % JSON.stringify(metrics))
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0227_MOUNT_AUTO_RALLY_AND_RECOVERY_DIAGNOSTICS %s" % JSON.stringify(metrics))
	quit(1)
