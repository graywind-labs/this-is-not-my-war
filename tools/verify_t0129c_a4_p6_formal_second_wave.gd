extends SceneTree


const MAIN_PATH := "res://scenes/main/Main.tscn"
const ACTOR_ROOT_PATH := "Main/WorldRoot/FormalStationLayout/FormalEnemies"


func _init() -> void:
	var packed := load(MAIN_PATH) as PackedScene
	if packed == null:
		_fail("Main.tscn unavailable")
		return
	root.add_child(packed.instantiate())
	await process_frame
	await physics_frame
	await physics_frame
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	if combat_system == null or building_system == null:
		_fail("A4-P6 dependencies unavailable")
		return
	var start: Dictionary = combat_system.debug_run_formal_second_wave_slice()
	await physics_frame
	var actor_root := root.get_node_or_null(ACTOR_ROOT_PATH)
	if not bool(start.get("ok", false)) or int(start.get("spawned_count", 0)) != 16 or actor_root == null:
		_fail("Formal second wave did not start: %s" % start)
		return
	var actor_count := 0
	for child in actor_root.get_children():
		if not child is ActorMotionBody or not child.name.begins_with("FormalWave02EnemyFoot"):
			continue
		actor_count += 1
		var actor := child as ActorMotionBody
		actor.configure_profile("enemy_foot", {
			"profile": {"base_speed": 14.0, "acceleration": 30.0},
			"navigation_agent": {"target_desired_distance": 1.5 if actor_count >= 13 else (1.35 if actor_count >= 7 else 0.85), "path_desired_distance": 0.7},
			"stuck_recovery": {"fail_after_seconds": 60.0}
		})
		actor.navigation_agent.max_speed = 17.0
	if actor_count != 16:
		_fail("Second wave is not sixteen physical actors: %s" % actor_count)
		return
	# Keep authoritative attacks enabled while preventing early arrivals from
	# destroying a stage before all sixteen navigation paths can be audited.
	for raw_enemy_id in combat_system.get_active_enemy_ids():
		var enemy_id := str(raw_enemy_id)
		var enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
		enemy["attack_power"] = 1
		enemy["attack_interval"] = 10000.0
		enemy["attack_speed"] = 0.0001
		combat_system._active_enemies[enemy_id] = enemy
	var initial: Dictionary = combat_system.debug_get_formal_second_wave_slice_snapshot()
	if (
		int(initial.get("wave_number", 0)) != 2
		or initial.get("unit_type_counts", {}) != {"melee_infantry": 12, "polearm_infantry": 4}
		or initial.get("attack_slot_role_counts", {}) != {"melee_front": 12, "polearm_rear": 4}
	):
		_fail("Second-wave composition/roles mismatch: %s" % initial)
		return
	var initial_slices := initial.get("slices", []) as Array
	if not initial_slices.is_empty() and str((initial_slices[0] as Dictionary).get("movement_model", "")) == "dynamic_combat_pressure":
		var compatibility_stop: Dictionary = combat_system.debug_stop_formal_second_wave_slice("p6_replaced_by_p7")
		await process_frame
		if not bool(compatibility_stop.get("ok", false)) or combat_system.get_active_enemy_count() != 0:
			_fail("P6 compatibility cleanup failed: %s" % compatibility_stop)
			return
		print("T0129C A4-P6 historical entry now delegates to P7 dynamic pressure: 16 solid actors")
		quit(0)
		return
	for building_id in ["front_gate", "warehouse"]:
		if not await _wait_for_any_attack(combat_system, building_id, 3600):
			var failed_snapshot: Dictionary = combat_system.debug_get_formal_second_wave_slice_snapshot()
			_fail("Second wave did not physically attack %s: %s" % [building_id, _failure_summary(failed_snapshot)])
			return
		var hp_before := int(building_system.get_building(building_id).get("hp", -1))
		var attack: Dictionary = combat_system.debug_step_enemy_ai(60.0)
		if int(building_system.get_building(building_id).get("hp", -1)) >= hp_before and (attack.get("attacks", []) as Array).is_empty():
			_fail("Physically arrived second wave did not attack %s: %s" % [building_id, attack])
			return
		building_system.debug_damage_building(building_id, 9999)
		combat_system.debug_step_enemy_ai(60.0)
	if not await _wait_for_all(combat_system, "main_hall", 6000):
		var failed_snapshot: Dictionary = combat_system.debug_get_formal_second_wave_slice_snapshot()
		_fail("Second wave did not all reach main_hall: %s" % [_failure_summary(failed_snapshot)])
		return
	var hall_hp_before := int(building_system.get_building("main_hall").get("hp", -1))
	var hall_attack: Dictionary = combat_system.debug_step_enemy_ai(60.0)
	if int(building_system.get_building("main_hall").get("hp", -1)) >= hall_hp_before and (hall_attack.get("attacks", []) as Array).is_empty():
		_fail("Physically arrived second wave did not attack main_hall: %s" % hall_attack)
		return
	var hall: Dictionary = combat_system.debug_get_formal_second_wave_slice_snapshot()
	var front_z: Array[float] = []
	var rear_z: Array[float] = []
	var front_slot_indices: Dictionary = {}
	var rear_slot_indices: Dictionary = {}
	for raw_slice in hall.get("slices", []):
		var slice := raw_slice as Dictionary
		var position: Vector3 = slice.get("attack_slot_position", Vector3.ZERO)
		if str(slice.get("attack_slot_role", "")) == "polearm_rear":
			rear_z.append(position.z)
			rear_slot_indices[int(slice.get("attack_slot_index", -1))] = true
		else:
			front_z.append(position.z)
			front_slot_indices[int(slice.get("attack_slot_index", -1))] = true
	if front_z.size() != 12 or rear_z.size() != 4 or front_slot_indices.size() != 12 or rear_slot_indices.size() != 4:
		_fail("Main-hall row membership mismatch: %s" % hall)
		return
	var front_depth_spread := _spread(front_z)
	var rear_depth_spread := _spread(rear_z)
	var row_gap := _average(rear_z) - _average(front_z)
	if front_depth_spread > 0.5 or rear_depth_spread > 0.5 or row_gap < 1.5 or row_gap > 3.0 or int(hall.get("navigation_failure_count", -1)) != 0:
		_fail("Second-wave compact two-row formation mismatch: %s" % hall)
		return
	var stop: Dictionary = combat_system.debug_stop_formal_second_wave_slice("verification_complete")
	await process_frame
	await process_frame
	if not bool(stop.get("ok", false)) or combat_system.get_active_enemy_count() != 0 or actor_root.get_child_count() != 0:
		_fail("Second-wave cleanup failed: %s" % stop)
		return
	print("T0129C A4-P6 formal second-wave verification passed: %s" % JSON.stringify({
		"spawned": 16,
		"melee_front": front_z.size(),
		"polearm_rear": rear_z.size(),
		"front_depth_spread": front_depth_spread,
		"rear_depth_spread": rear_depth_spread,
		"row_gap": row_gap,
		"avoidance_callbacks": hall.get("avoidance_callback_count"),
		"active_enemy_count_after": combat_system.get_active_enemy_count()
	}))
	quit(0)


func _wait_for_all(combat_system: Node, stage_id: String, frame_limit: int) -> bool:
	for _frame in range(frame_limit):
		await physics_frame
		var snapshot: Dictionary = combat_system.debug_get_formal_second_wave_slice_snapshot()
		var arrived := 0
		for raw_slice in snapshot.get("slices", []):
			var slice := raw_slice as Dictionary
			if str(slice.get("current_stage_id", "")) == stage_id and bool(slice.get("attack_unlocked", false)):
				arrived += 1
		if arrived == combat_system.get_active_enemy_count():
			return true
	return false


func _wait_for_any_attack(combat_system: Node, stage_id: String, frame_limit: int) -> bool:
	var authority_key := "%s_combat_authority_committed" % stage_id
	for _frame in range(frame_limit):
		await physics_frame
		var snapshot: Dictionary = combat_system.debug_get_formal_second_wave_slice_snapshot()
		for raw_slice in snapshot.get("slices", []):
			var slice := raw_slice as Dictionary
			if str(slice.get("current_stage_id", "")) == stage_id and bool(slice.get(authority_key, false)):
				return true
	return false


func _failure_summary(snapshot: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_slice in snapshot.get("slices", []):
		var slice := raw_slice as Dictionary
		if str(slice.get("phase", "")) in ["navigation_failed", "marching_to_front_gate", "marching_to_warehouse", "marching_to_main_hall"]:
			result.append({
				"enemy_id": slice.get("enemy_id"),
				"role": slice.get("attack_slot_role"),
				"phase": slice.get("phase"),
				"failure_reason": slice.get("failure_reason"),
				"slot": slice.get("attack_slot_position"),
				"world": slice.get("world_position")
			})
	return result


func _spread(values: Array[float]) -> float:
	return values.max() - values.min() if not values.is_empty() else INF


func _average(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size()) if not values.is_empty() else 0.0


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
