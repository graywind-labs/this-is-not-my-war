extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const MAX_GATE_APPROACH_FRAMES := 3600
const POST_SPAWN_FRAMES := 900

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
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var gate := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/WallsAndGates/FrontGate") as Node3D
	var gate_art := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/WallsAndGates/FortificationArt/GateArt/FrontGateArt") as Node3D
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(combat_system != null and npc_system != null and equipment_system != null, "T0229 core systems missing")
	_check(gate != null and gate_art != null and time_system != null, "T0229 front gate or time system missing")
	if not _failures.is_empty():
		_finish({})
		return
	time_system.set_paused(false)

	var preset: Dictionary = equipment_system.debug_apply_combat_loadout_preset()
	_check(bool(preset.get("ok", false)), "T0229 GM recruit/equip preset failed: %s" % preset)
	var alarm: Dictionary = combat_system.debug_trigger_combat_alarm()
	_check(bool(alarm.get("ok", false)), "T0229 alarm failed: %s" % alarm)
	if not _failures.is_empty():
		_finish({"preset": preset, "alarm": alarm})
		return

	var mounted_ids: Array[String] = []
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var unit: Dictionary = equipment_system.get_unit_type_snapshot(npc_id)
		if bool(unit.get("has_mount", false)):
			mounted_ids.append(npc_id)
	_check(mounted_ids.size() == 4, "T0229 expected four assigned riders: %s" % [mounted_ids])

	var gate_ready := false
	for _frame in range(MAX_GATE_APPROACH_FRAMES):
		await physics_frame
		var ready_count := 0
		for npc_id in mounted_ids:
			var actor := _get_npc_actor(npc_system, npc_id)
			var state: Dictionary = npc_system.get_npc_state(npc_id)
			if (
				actor != null
				and bool(state.get("combat_mounted", false))
				and actor.global_position.distance_to(gate.global_position) <= 6.0
				and str(state.get("current_action", "")).begins_with("moving_to_combat_rally_")
			):
				ready_count += 1
		if ready_count >= 2:
			gate_ready = true
			break
	_check(gate_ready, "T0229 fewer than two mounted rally riders reached the gate before spawning")
	if not _failures.is_empty():
		_finish({"before_spawn": _capture(npc_system, gate, gate_art, mounted_ids)})
		return

	var before_spawn := _capture(npc_system, gate, gate_art, mounted_ids)
	var spawn: Dictionary = combat_system.debug_spawn_wave(5, false, true)
	_check(bool(spawn.get("ok", false)), "T0229 GM near-gate wave spawn failed: %s" % spawn)
	var samples: Array[Dictionary] = []
	var repeat_alarm: Dictionary = {}
	for frame in range(POST_SPAWN_FRAMES):
		await physics_frame
		if frame == 599:
			repeat_alarm = combat_system.debug_trigger_combat_alarm()
		if frame in [59, 299, 599, 899]:
			samples.append(_capture(npc_system, gate, gate_art, mounted_ids))
	var final_sample: Dictionary = samples[samples.size() - 1] if not samples.is_empty() else {}
	for npc_id in mounted_ids:
		var before_rider := _find_capture(before_spawn, npc_id)
		var final_rider := _find_capture(final_sample, npc_id)
		var before_position: Vector3 = before_rider.get("position", Vector3.ZERO)
		var final_position: Vector3 = final_rider.get("position", before_position)
		var displacement := Vector2(before_position.x, before_position.z).distance_to(Vector2(final_position.x, final_position.z))
		_check(not final_rider.is_empty(), "T0229 final rider capture missing: %s" % npc_id)
		_check(displacement >= 5.0, "T0229 rider remained stalled at the front gate after engagement: %s displacement=%.3f" % [npc_id, displacement])
		_check(float(final_rider.get("gate_distance", 0.0)) >= 8.0, "T0229 rider remained inside the front-gate congestion band: %s final=%s" % [npc_id, final_rider])
		_check(str(final_rider.get("behavior_mode", "")) == "combat", "T0229 rider did not remain in combat after wave handoff: %s" % npc_id)
		_check(not str(final_rider.get("combat_target_enemy_id", "")).is_empty(), "T0229 rider lost combat lock without reacquiring a wave target: %s" % npc_id)
	_check(int(repeat_alarm.get("target_locked_count", 0)) >= mounted_ids.size(), "T0229 repeated alarm did not classify active combat locks: %s" % repeat_alarm)
	_check(int(repeat_alarm.get("rallied_count", 0)) == 0, "T0229 repeated alarm overrode valid combat locks: %s" % repeat_alarm)

	_finish({
		"before_spawn": before_spawn,
		"spawn": {"enemy_count": int(spawn.get("active_enemy_count", 0))},
		"repeat_alarm": {
			"eligible_count": int(repeat_alarm.get("eligible_count", 0)),
			"rallied_count": int(repeat_alarm.get("rallied_count", 0)),
			"target_locked_count": int(repeat_alarm.get("target_locked_count", 0)),
			"ignored_count": int(repeat_alarm.get("ignored_count", 0))
		},
		"samples": samples
	})


func _capture(npc_system: Node, gate: Node3D, gate_art: Node3D, npc_ids: Array[String]) -> Dictionary:
	var riders: Array[Dictionary] = []
	for npc_id in npc_ids:
		var actor := _get_npc_actor(npc_system, npc_id)
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		var motion: Dictionary = actor.debug_get_motion_snapshot() if actor != null and actor.has_method("debug_get_motion_snapshot") else {}
		var velocity_text := str(motion.get("velocity", "(0, 0, 0)"))
		riders.append({
			"npc_id": npc_id,
			"position": actor.global_position if actor != null else Vector3.ZERO,
			"gate_distance": actor.global_position.distance_to(gate.global_position) if actor != null else -1.0,
			"behavior_mode": str(state.get("behavior_mode", "")),
			"current_action": str(state.get("current_action", "")),
			"combat_target_enemy_id": str(state.get("combat_target_enemy_id", "")),
			"strategy_enemy_id": str(state.get("combat_strategy_move_enemy_id", "")),
			"movement_active": npc_system.is_npc_world_movement_active(npc_id),
			"request_id": str(motion.get("request_id", "")),
			"motion_state": str(motion.get("state", "")),
			"motion_last_result": str(motion.get("last_result", "")),
			"movement_purpose": str(motion.get("movement_purpose", "")),
			"direct_distance": float(motion.get("direct_distance", -1.0)),
			"remaining_path_distance": float(motion.get("remaining_path_distance", -1.0)),
			"no_progress_samples": int(motion.get("no_progress_samples", 0)),
			"stuck_elapsed_seconds": float(motion.get("stuck_elapsed_seconds", 0.0)),
			"velocity": velocity_text
		})
	return {
		"gate": gate_art.debug_get_snapshot() if gate_art.has_method("debug_get_snapshot") else {},
		"riders": riders
	}


func _get_npc_actor(npc_system: Node, npc_id: String) -> Node3D:
	var paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(paths.get(npc_id, NodePath(""))) as Node3D


func _find_capture(capture: Dictionary, npc_id: String) -> Dictionary:
	for raw_rider in capture.get("riders", []):
		var rider: Dictionary = raw_rider
		if str(rider.get("npc_id", "")) == npc_id:
			return rider
	return {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish(metrics: Dictionary) -> void:
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	if combat_system != null and combat_system.has_method("debug_clear_enemies"):
		combat_system.debug_clear_enemies()
	if _failures.is_empty():
		print("T0229_MOUNTED_GATE_WAVE_HANDOFF_OK %s" % JSON.stringify(metrics))
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0229_MOUNTED_GATE_WAVE_HANDOFF_FAILED %s" % JSON.stringify(metrics))
	quit(1)
